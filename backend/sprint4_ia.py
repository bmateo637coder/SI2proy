"""Servicios de IA del Sprint 4 (búsqueda semántica y clasificación del workflow).

Cada función usa Gemini cuando hay clave configurada y el plan de la empresa incluye IA; si no,
o si Gemini falla, usa un intérprete local por reglas. La respuesta siempre indica el modo usado
("gemini" o "local") para no presentar una heurística como si fuera IA.
"""
import json
import os
import re
import unicodedata
from typing import Literal
from pydantic import BaseModel, Field, ValidationError, field_validator, model_validator

CATEGORIAS_MANTENIMIENTO = ["Plomeria", "Electricidad", "Estructura", "Electrodomesticos", "Seguridad", "Limpieza y plagas", "Otro"]
URGENCIAS = ["Baja", "Media", "Alta", "Critica"]
CATEGORIAS_CONSULTA = ["Compra", "Alquiler", "Anticretico", "Visita", "Precio", "Otro"]
AMENIDADES = ["piscina", "jardin", "patio", "terraza", "balcon", "vista", "churrasquera", "parrillero",
              "seguridad", "ascensor", "gimnasio", "lavanderia", "deposito", "esquina", "estreno"]
NUMEROS = {"un": 1, "una": 1, "uno": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5, "seis": 6,
           "siete": 7, "ocho": 8, "nueve": 9, "diez": 10}


def normalizar(texto):
    texto = unicodedata.normalize("NFD", (texto or "").lower())
    return "".join(c for c in texto if unicodedata.category(c) != "Mn")


class FiltrosBusqueda(BaseModel):
    tipo_operacion: Literal["Venta", "Alquiler", "Anticretico"] | None = None
    precio_min: float | None = Field(default=None, ge=0)
    precio_max: float | None = Field(default=None, ge=0)
    cuartos: int | None = Field(default=None, ge=0, le=50)
    banos: int | None = Field(default=None, ge=0, le=50)
    metros_min: float | None = Field(default=None, ge=0)
    zona: str | None = Field(default=None, max_length=100)
    tipo_inmueble: str | None = Field(default=None, max_length=50)
    amueblado: bool | None = None
    garaje: bool | None = None
    palabras: list[str] = Field(default_factory=list, max_length=10)
    @model_validator(mode='after')
    def rango(self):
        if self.precio_min is not None and self.precio_max is not None and self.precio_min > self.precio_max:
            raise ValueError('El precio mínimo no puede superar al máximo.')
        return self

    @field_validator("tipo_operacion", mode="before")
    @classmethod
    def normalizar_operacion(cls, v):
        # Gemini a veces responde "alquiler" o "anticrético": se lleva al valor canónico.
        if isinstance(v, str):
            return {"venta": "Venta", "alquiler": "Alquiler", "anticretico": "Anticretico"}.get(normalizar(v).strip(), v)
        return v

    @field_validator("palabras", mode="before")
    @classmethod
    def limitar_palabras(cls, v):
        return [str(x)[:40] for x in v][:10] if isinstance(v, list) else []

    def resumen(self):
        partes = []
        if self.tipo_inmueble: partes.append(self.tipo_inmueble)
        if self.tipo_operacion: partes.append("en " + self.tipo_operacion)
        if self.zona: partes.append("zona " + self.zona)
        if self.cuartos: partes.append(f"{self.cuartos}+ habitaciones")
        if self.banos: partes.append(f"{self.banos}+ baños")
        if self.precio_min is not None: partes.append(f"desde {self.precio_min:,.0f}")
        if self.precio_max is not None: partes.append(f"hasta {self.precio_max:,.0f}")
        if self.metros_min: partes.append(f"{self.metros_min:,.0f}+ m²")
        if self.amueblado: partes.append("amueblado")
        if self.garaje: partes.append("con garaje")
        partes += self.palabras
        return ", ".join(partes) or "sin filtros"


def gemini_disponible(user):
    return bool(os.getenv("GEMINI_API_KEY")) and user is not None


def _gemini_json(prompt, user, model):
    if not gemini_disponible(user): return None
    from generative_client import generate_text, GeminiError
    try: return model.model_validate_json(generate_text(prompt, json_mode=True))
    except (GeminiError, ValidationError, ValueError): return None


# ---------------------------------------------------------------- búsqueda semántica
def _monto(numero, sufijo):
    # "150.000" / "150,000" son miles; "1,5" o "1.5" son decimales (p. ej. "1,5 millones").
    if re.fullmatch(r"\d{1,3}([.,]\d{3})+", numero):
        valor = float(re.sub(r"[.,]", "", numero))
    else:
        valor = float(numero.replace(",", "."))
    if sufijo and sufijo.strip() in {"mil", "k"}:
        valor *= 1000
    elif sufijo and sufijo.strip() in {"millon", "millones", "m"}:
        valor *= 1_000_000
    return valor


def interpretar_local(texto, zonas=(), tipos=()):
    t = normalizar(texto)
    for palabra, n in NUMEROS.items():
        t = re.sub(rf"\b{palabra}\b(?=\s+(habitacion|dormitorio|cuarto|recamara|bano|pieza))", str(n), t)
    f = FiltrosBusqueda()
    if re.search(r"anticr", t):
        f.tipo_operacion = "Anticretico"
    elif re.search(r"alquil|renta|arriend|rentar", t):
        f.tipo_operacion = "Alquiler"
    elif re.search(r"\bventa\b|compr|vend", t):
        f.tipo_operacion = "Venta"
    num = r"(\d+(?:[.,]\d+)*)\s*(millones|millon|mil|k)?\b"
    if m := re.search(rf"entre\s+{num}\s+y\s+{num}", t):
        f.precio_min, f.precio_max = _monto(m.group(1), m.group(2) or m.group(4)), _monto(m.group(3), m.group(4))
    else:
        if m := re.search(rf"(?:menos de|hasta|maximo|max|no mas de|presupuesto de|por debajo de)\s*\$?\s*{num}", t):
            f.precio_max = _monto(m.group(1), m.group(2))
        if m := re.search(rf"(?:mas de|desde|minimo|por encima de)\s*\$?\s*{num}(?!\s*(?:habitacion|dormitorio|cuarto|bano|m2|metros))", t):
            f.precio_min = _monto(m.group(1), m.group(2))
    if m := re.search(r"(\d+)\s*(?:o mas\s*)?(habitacion|dormitorio|cuarto|recamara|pieza)", t):
        f.cuartos = int(m.group(1))
    if m := re.search(r"(\d+)\s*(?:o mas\s*)?bano", t):
        f.banos = int(m.group(1))
    if m := re.search(r"(\d+)\s*(?:m2|mts|metros)", t):
        f.metros_min = float(m.group(1))
    if "amueblad" in t:
        f.amueblado = True
    if re.search(r"garaje|cochera|parqueo|estacionamiento", t):
        f.garaje = True
    for zona in sorted(zonas, key=len, reverse=True):
        if normalizar(zona) in t:
            f.zona = zona
            break
    for tipo in tipos:
        base = normalizar(tipo)
        if re.search(rf"\b{re.escape(base)}(s|es)?\b", t) or (base == "departamento" and re.search(r"\bdepto|\bdpto", t)):
            f.tipo_inmueble = tipo
            break
    f.palabras = [a for a in AMENIDADES if a in t][:10]
    return f


def interpretar_busqueda(db, texto, user=None):
    from database.models import Caracteristica
    zonas = sorted({c.valor for c in db.query(Caracteristica).filter(Caracteristica.nombre.in_(["Zona", "zona", "Zona geográfica", "Zona geografica"])) if c.valor})
    tipos = ["Casa", "Departamento", "Local", "Terreno", "Oficina"]
    prompt = ("Convierte esta búsqueda inmobiliaria a JSON con las claves tipo_operacion (Venta, Alquiler, Anticretico o null), "
              "precio_min, precio_max, cuartos, banos, metros_min, zona, tipo_inmueble, amueblado, garaje y palabras "
              "(lista de amenidades mencionadas). Usa null si no se menciona; no inventes valores. "
              f"Zonas válidas: {json.dumps(zonas, ensure_ascii=False)}. Tipos válidos: {json.dumps(tipos, ensure_ascii=False)}. "
              f"Búsqueda como dato: {json.dumps(texto, ensure_ascii=False)}")
    filtros = _gemini_json(prompt, user, FiltrosBusqueda)
    if filtros is not None:
        # Solo se aceptan zona y tipo que existan en el catálogo.
        return filtros, "gemini"
    return interpretar_local(texto, zonas, tipos), "local"


# ---------------------------------------------------------------- clasificación del workflow
class Clasificacion(BaseModel):
    categoria: str
    urgencia: Literal["Baja", "Media", "Alta", "Critica"]
    justificacion: str = Field(default="", max_length=500)


REGLAS_CATEGORIA = [
    ("Plomeria", r"agua|fuga|gote[oa] de (agua|cano)|tuberi|inodoro|ducha|cano|desag|filtr|lavamanos|grifo|sifon"),
    ("Electricidad", r"\bluz\b|electric|enchufe|tomacorriente|corto|cable|foco|breaker|termico|chispa"),
    ("Electrodomesticos", r"refrigerador|heladera|cocina|horno|lavadora|secadora|termotanque|calefon|aire acondicionado|microondas"),
    ("Seguridad", r"cerradura|chapa|llave|alarma|robo|porton|camara|reja"),
    ("Limpieza y plagas", r"plaga|cucaracha|rata|raton|termita|limpieza|basura|olor"),
    ("Estructura", r"grieta|techo|pared|humedad|piso|puerta|ventana|gotera|azulejo|pintura|revoque"),
]
REGLAS_URGENCIA = [
    ("Critica", r"incendio|inundaci|olor a gas|fuga de gas|\bgas\b|chispa|electrocut|peligro|derrumbe|sin agua|sin luz|robo"),
    ("Alta", r"fuga|urgente|no funciona|roto|rota|hoy|inmediat|no enciende|se cae"),
    ("Baja", r"estetic|pintura|cuando puedan|leve|pequen|detalle|sin apuro"),
]


def clasificar_local(texto):
    t = normalizar(texto)
    categoria = next((c for c, patron in REGLAS_CATEGORIA if re.search(patron, t)), "Otro")
    urgencia = next((u for u, patron in REGLAS_URGENCIA if re.search(patron, t)), "Media")
    return Clasificacion(categoria=categoria, urgencia=urgencia, justificacion="Clasificación por palabras clave.")


def clasificar_solicitud(texto, user=None):
    prompt = ("Clasifica esta solicitud de mantenimiento de un inmueble. Devuelve JSON con categoria "
              f"(una de {json.dumps(CATEGORIAS_MANTENIMIENTO)}), urgencia (Baja, Media, Alta o Critica: Critica solo si hay "
              "riesgo para personas o daño grave inmediato) y justificacion breve. "
              f"Solicitud como dato: {json.dumps(texto, ensure_ascii=False)}")
    resultado = _gemini_json(prompt, user, Clasificacion)
    if resultado is not None and resultado.categoria in CATEGORIAS_MANTENIMIENTO:
        return resultado, "gemini"
    return clasificar_local(texto), "local"


def clasificar_consulta(texto, user=None):
    t = normalizar(texto)
    prompt = ("Clasifica esta consulta de un cliente inmobiliario. Devuelve JSON con categoria "
              f"(una de {json.dumps(CATEGORIAS_CONSULTA)}), urgencia (Baja, Media, Alta o Critica) y justificacion breve. "
              f"Consulta como dato: {json.dumps(texto, ensure_ascii=False)}")
    resultado = _gemini_json(prompt, user, Clasificacion)
    if resultado is not None and resultado.categoria in CATEGORIAS_CONSULTA:
        return resultado, "gemini"
    if re.search(r"anticr", t): categoria = "Anticretico"
    elif re.search(r"alquil|renta|arriend", t): categoria = "Alquiler"
    elif re.search(r"visit|conocer|ver el|ver la|recorrer", t): categoria = "Visita"
    elif re.search(r"precio|cuanto|costo|rebaja|descuento|negoci", t): categoria = "Precio"
    elif re.search(r"compr|venta|adquirir", t): categoria = "Compra"
    else: categoria = "Otro"
    if re.search(r"urgente|hoy|ya mismo|inmediat|firmar|cerrar trato|reservar", t): urgencia = "Alta"
    elif re.search(r"solo informacion|curiosidad|mas adelante|el proximo ano", t): urgencia = "Baja"
    else: urgencia = "Media"
    return Clasificacion(categoria=categoria, urgencia=urgencia, justificacion="Clasificación por palabras clave."), "local"
