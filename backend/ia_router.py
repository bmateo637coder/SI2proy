from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import os
import json
import google.generativeai as genai
from typing import Optional

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
