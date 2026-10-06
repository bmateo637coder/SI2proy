from fastapi import APIRouter, Depends, HTTPException, Header
from fastapi.responses import Response
from pydantic import BaseModel
import os
import json
import google.generativeai as genai
from typing import Optional
from sqlalchemy.orm import Session
from auth import get_current_user
from database import models
from database.database import get_db

router = APIRouter(prefix="/api/ia", tags=["IA"])

# Configure Gemini
api_key = os.getenv("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)

class VozRequest(BaseModel):
    texto: str

@router.post("/reporte-voz")
async def generar_reporte_por_voz(req: VozRequest):
    if not api_key:
        # Fallback local (mock) si no hay API key para el demo
        txt = req.texto.lower()
        if "casas disponibles" in txt or "disponible" in txt:
            return {"success": True, "config": {
                "entidad": "propiedades",
                "columnas": ["titulo", "precio", "estado"],
                "filtros": [{"columna": "estado", "operador": "eq", "valor": "Disponible"}],
                "ordenColumna": "precio",
                "ordenDireccion": "asc"
            }}
        elif "usuario" in txt or "cliente" in txt:
            return {"success": True, "config": {
                "entidad": "usuarios",
                "columnas": ["ci", "nombre", "correo", "telefono"],
                "filtros": [],
                "ordenColumna": "nombre",
                "ordenDireccion": "asc"
            }}
        elif "venta" in txt or "menor" in txt or "100" in txt or "cien" in txt:
            return {"success": True, "config": {
                "entidad": "propiedades",
                "columnas": ["titulo", "precio", "tipo_operacion"],
                "filtros": [
                    {"columna": "precio", "operador": "lt", "valor": "100000"}
                ],
                "ordenColumna": "precio",
                "ordenDireccion": "asc"
            }}
        else:
            return {"success": False, "error": "No entendí tu comando. En el modo demo, intenta decir: 'casas disponibles', 'mostrar usuarios', o 'casas menores a 100 mil'."}
    
    prompt = f"""
    Eres un asistente experto en sistemas inmobiliarios. El usuario ha dictado por voz lo siguiente:
    "{req.texto}"
    
    Debes convertir esa orden natural en un formato JSON exacto para configurar un reporte dinámico.
    
    Reglas:
    1. 'entidad' puede ser "propiedades" o "usuarios".
    2. 'columnas' es un arreglo de strings (para propiedades: titulo, direccion, precio, tipo_operacion, estado) (para usuarios: ci, nombre, correo, telefono).
    3. 'filtros' es un arreglo de objetos con 'columna', 'operador' (eq, like, gt, lt, gte, lte) y 'valor'.
    4. 'ordenColumna' (ej. precio) y 'ordenDireccion' (asc o desc).
    
    Ejemplo de salida:
    {{
      "entidad": "propiedades",
      "columnas": ["titulo", "precio", "estado"],
      "filtros": [
        {{"columna": "precio", "operador": "lt", "valor": "200000"}},
        {{"columna": "estado", "operador": "eq", "valor": "Disponible"}}
      ],
      "ordenColumna": "precio",
      "ordenDireccion": "asc"
    }}
    
    Devuelve ÚNICAMENTE código JSON válido, sin Markdown, sin backticks y sin texto adicional.
    """
    
    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        # Limpiar posible markdown
        text = response.text.replace("```json", "").replace("```", "").strip()
        configuracion = json.loads(text)
        return {"success": True, "config": configuracion}
    except Exception as e:
        print("Error IA:", str(e))
        raise HTTPException(status_code=500, detail="No se pudo interpretar el comando de voz.")

class DescripcionRequest(BaseModel):
    titulo: str
    direccion: str
    precio: float
    tipo_operacion: str

@router.post("/generar-descripcion")
async def generar_descripcion(req: DescripcionRequest):
    if not api_key:
        # Fallback local (mock) si no hay API key para el demo
        return {
            "success": True, 
            "descripcion": f"¡Increíble oportunidad de {req.tipo_operacion.lower()}! Descubre esta maravillosa propiedad ubicada en {req.direccion}. Su diseño y distribución hacen de este inmueble el lugar ideal para ti. Todo esto por tan solo $us {req.precio}. ¡No dejes pasar esta oportunidad y contáctanos hoy mismo!"
        }
    
    prompt = f"""
    Eres un experto agente inmobiliario y copywriter publicitario.
    Necesito que escribas una descripción atractiva, persuasiva y elegante para una propiedad con los siguientes datos:
    - Título: {req.titulo}
    - Dirección: {req.direccion}
    - Precio: $us {req.precio}
    - Operación: {req.tipo_operacion}
    
    La descripción debe tener entre 3 y 5 oraciones, destacar el valor de la propiedad, generar emoción y terminar con un llamado a la acción. 
    Devuelve ÚNICAMENTE el texto de la descripción, sin comillas, sin formato markdown y sin saludos.
    """
    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        return {"success": True, "descripcion": response.text.strip()}
    except Exception as e:
        print("Error IA:", str(e))
        raise HTTPException(status_code=500, detail="No se pudo generar la descripción.")


class RecomendarRequest(BaseModel):
    propiedad_id: Optional[int] = None
    limite: int = 5


class ChatRequest(BaseModel):
    mensaje: str


def _score_similitud(base: models.Propiedad, candidato: models.Propiedad) -> float:
    puntos = 0.0
    if base.tipo_operacion == candidato.tipo_operacion:
        puntos += 2.0
    if base.precio is not None and candidato.precio is not None:
        if abs(float(candidato.precio) - float(base.precio)) <= max(float(base.precio) * 0.30, 10000):
            puntos += 1.5
    carac_base = {(c.nombre, c.valor) for c in base.caracteristicas}
    for c in candidato.caracteristicas:
        if (c.nombre, c.valor) in carac_base:
            puntos += 1.0
    return puntos


def _serializar_recomendada(p: models.Propiedad) -> dict:
    return {
        "id_propiedad": p.id_propiedad,
        "titulo": p.titulo,
        "direccion": p.direccion,
        "precio": float(p.precio),
        "tipo_operacion": p.tipo_operacion,
        "estado": p.estado,
        "imagen": (p.imagenes[0].url if p.imagenes else None),
    }


@router.post("/recomendar")
def recomendar(
    req: RecomendarRequest,
    x_tenant_id: Optional[int] = Header(None),
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(get_current_user),
):
    tenant = x_tenant_id or current_user.id_tenant
    query = db.query(models.Propiedad).filter(
        models.Propiedad.id_tenant == tenant,
        models.Propiedad.estado.in_(["Disponible", "Reservada"]),
    )
    limite = max(1, min(req.limite, 20))

    if req.propiedad_id:
        base = db.query(models.Propiedad).filter_by(id_propiedad=req.propiedad_id).first()
        if not base:
            raise HTTPException(status_code=404, detail="Propiedad base no encontrada.")
        candidatas = query.filter(models.Propiedad.id_propiedad != req.propiedad_id).all()
        candidatas.sort(key=lambda p: _score_similitud(base, p), reverse=True)
    else:
        candidatas = query.order_by(models.Propiedad.id_propiedad.desc()).all()

    return {"recomendaciones": [_serializar_recomendada(p) for p in candidatas[:limite]]}


def _respuesta_fallback(mensaje: str) -> str:
    m = mensaje.lower()
    if any(w in m for w in ["hola", "buenos", "saludo", "hi ", "hey"]):
        return ("¡Hola! Soy Rai, el asistente virtual de Raíces. Puedo ayudarte con contratos y pagos, "
                "propiedades disponibles, clientes, respaldos automáticos y más.")
    if any(w in m for w in ["contrato", "cuota", "pago", "recibo", "comprobante"]):
        return ("En el módulo de Contratos y Pagos puedes formalizar ventas, alquileres y anticréticos; cada contrato "
                "genera un plan de cuotas y al registrar un pago se emite un recibo con comprobante PDF descargable.")
    if any(w in m for w in ["propiedad", "compra", "vender", "alquilar", "anticretico", "disponible", "catalogo", "catálogo", "inmueble"]):
        return ("En el catálogo encuentras las propiedades destacadas. Usa los filtros por operación y presupuesto, "
                "o en Propiedades puedes gestionarlas directamente si tienes ese permiso.")
    if any(w in m for w in ["cliente", "usuario", "registrar", "registro"]):
        return ("Los clientes se gestionan en el panel de Inmuebles. Puedes crear, editar y dar de baja clientes, "
                "propietarios y agentes desde sus respectivos módulos.")
    if any(w in m for w in ["backup", "respaldo", "copia de seguridad", "restaurar"]):
        return ("El sistema genera respaldos automáticos (SQL) a diario, los conserva localmente y, si está "
                "configurado, los publica en GitHub. Puedes consultar el estado desde el módulo Backup.")
    if any(w in m for w in ["recomend", "sugerir", "sugerencia"]):
        return ("Uso el semáforo de similitud (tipo de operación, rango de precio y características compartidas) "
                "para recomendarte las propiedades más parecidas. Revisa la sección Recomendados del catálogo.")
    if any(w in m for w in ["reporte", "voz", "descripcion", "descripción"]):
        return ("Puedo generar reportes dinámicos por voz y descripciones publicitarias de propiedades desde el "
                "módulo de IA cuando hay conexión a Gemini; sin API key se usan respuestas locales.")
    return ("Soy Rai, el asistente virtual de Raíces. Pregúntame sobre contratos y pagos, propiedades disponibles, "
            "clientes, recomendaciones o respaldos automáticos.")


@router.post("/chat")
async def chat(req: ChatRequest):
    if not req.mensaje or not req.mensaje.strip():
        raise HTTPException(status_code=400, detail="El mensaje no puede estar vacío.")
    if not api_key:
        return {"respuesta": _respuesta_fallback(req.mensaje)}

    prompt = f"""
    Eres Rai, el asistente virtual de la inmobiliaria Raíces. Responde de forma breve, útil y en español.
    Tema del sistema: gestión inmobiliaria con contratos, cuotas, pagos con comprobante PDF, propiedades,
    clientes, reportes y respaldos automáticos.
    Usuario pregunta: "{req.mensaje}"
    Devuelve ÚNICAMENTE tu respuesta, sin saludos repetidos ni formato markdown.
    """
    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        return {"respuesta": response.text.strip()}
    except Exception as e:
        print("Error IA chat:", str(e))
        return {"respuesta": _respuesta_fallback(req.mensaje)}
