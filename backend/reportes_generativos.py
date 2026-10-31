"""La IA propone parámetros tipados; solo el servidor construye consultas SQLAlchemy."""
import calendar
import json
import os
import re
import unicodedata
from datetime import date, timedelta
from typing import Literal
from generative_client import generate_text, GeminiError

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator, ConfigDict
from sqlalchemy import func
from sqlalchemy.orm import Session

from auth import require_staff
from database import models as m
from database.database import get_db
from saas import branch_scope, require_ai, today

router = APIRouter(prefix="/api/analitica", tags=["Reportes generativos y analítica"])
ReportType = Literal["ventas_sucursal", "ingresos_semana", "cartera_estado", "ranking_agentes", "reservas_sucursal"]


class ReportSpec(BaseModel):
    model_config = ConfigDict(extra="forbid")
    tipo: ReportType
    desde: date | None = None
    hasta: date | None = None
    id_sucursal: int | None = None
    tipo_contrato: Literal["Venta", "Alquiler", "Anticretico"] | None = None
    estado: Literal["Disponible", "Reservada", "Vendida", "Alquilada"] | None = None
    limite: int = Field(default=100, ge=1, le=500)

    @model_validator(mode="after")
    def dates(self):
        if self.desde and self.hasta and self.desde > self.hasta:
            raise ValueError("Rango de fechas invertido.")
        return self


class NaturalRequest(BaseModel):
    texto: str = Field(min_length=4, max_length=1500)


def normalized(text):
    return "".join(c for c in unicodedata.normalize("NFKD", text.lower()) if not unicodedata.combining(c))


def local_spec(text):
    """Modo explícito de reglas, para seguir consultando datos sin proveedor de IA."""
    t = normalized(text)
    if "reserva" in t:
        kind = "reservas_sucursal"
    elif any(w in t for w in ("cartera", "disponib", "propiedades por estado", "inmuebles por estado")):
        kind = "cartera_estado"
    elif "agente" in t:
        kind = "ranking_agentes"
    elif any(w in t for w in ("seman", "ingreso", "cobro", "pago")):
        kind = "ingresos_semana"
    elif any(w in t for w in ("venta", "contrato", "alquiler", "anticretico")):
        kind = "ventas_sucursal"
    else:
        raise HTTPException(422, "Indique un reporte: ventas por sucursal, ingresos por semana, cartera por estado, ranking de agentes o reservas por sucursal.")
    spec = {"tipo": kind}
    dates = re.findall(r"\b\d{4}-\d{2}-\d{2}\b", t)
    if dates:
        spec.update(desde=date.fromisoformat(dates[0]), hasta=date.fromisoformat(dates[-1]))
    elif "este mes" in t:
        spec.update(desde=today().replace(day=1), hasta=today())
    elif "este ano" in t:
        spec.update(desde=today().replace(month=1, day=1), hasta=today())
    elif "ultimos tres meses" in t or "ultimo trimestre" in t:
        spec.update(desde=today() - timedelta(days=90), hasta=today())
    else:
        months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        found = [i + 1 for i, name in enumerate(months) if name in t]
        if len(found) > 1:
            raise HTTPException(422, "Para varios meses indique un rango YYYY-MM-DD a YYYY-MM-DD.")
        if found:
            year = re.search(r"\b(20\d{2})\b", t)
            year = int(year[0]) if year else today().year
            spec.update(desde=date(year, found[0], 1), hasta=date(year, found[0], calendar.monthrange(year, found[0])[1]))
    branch = re.search(r"sucursal\s*(?:#|id\s*)?(\d+)", t)
    if branch:
        spec["id_sucursal"] = int(branch[1])
    elif re.search(r"sucursal\s+(?!durante|este|del|de\b|en\b|por\b)[a-z]+", t):
        raise HTTPException(422, "Indique el número de sucursal para filtrar, por ejemplo: sucursal 1.")
    for word, value in [("alquiler", "Alquiler"), ("anticretico", "Anticretico"), ("venta", "Venta")]:
        if word in t:
            spec["tipo_contrato"] = value
            break
    for word, value in [("disponib", "Disponible"), ("vendida", "Vendida"), ("alquilada", "Alquilada"), ("reservada", "Reservada")]:
        if word in t:
            spec["estado"] = value
            break
    top = re.search(r"(?:top|primeros|mejores)\s*(\d+)", t)
    if top:
        spec["limite"] = int(top[1])
    return ReportSpec(**spec)


def interpret(text):
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        try:
            return local_spec(text), "reglas_locales"
        except ValueError:
            raise HTTPException(422, "Revise las fechas y el límite solicitados.") from None
    schema = ReportSpec.model_json_schema()
    prompt = (f"Fecha actual en Bolivia: {today()}. Interpreta un reporte inmobiliario. "
        "Solo produce JSON según este esquema; nunca SQL. Si es ambiguo o no soportado devuelve {\"error\":\"explicacion\"}. "
        "No inventes IDs. Usa número de sucursal solo si se indica. "
        f"Esquema: {json.dumps(schema)}. Solicitud del usuario: {text}")
    try:
        parsed = json.loads(generate_text(prompt, json_mode=True))
        if "error" in parsed:
            raise HTTPException(422, str(parsed["error"])[:300])
        return ReportSpec.model_validate(parsed), "gemini"
    except HTTPException:
        raise
    except GeminiError as error:
        raise HTTPException(503, str(error)) from None
    except Exception:
        raise HTTPException(503, "No se pudo interpretar la solicitud con IA. Intente de nuevo o use el reporte convencional.")


def build_report(db, user, spec):
    tid = user.id_tenant
    if spec.id_sucursal is not None:
        branch_scope(db, user, spec.id_sucursal)
    # Joins explícitos con tenant también en las entidades relacionadas.
    contract = db.query(m.Contrato).join(m.Propiedad, m.Propiedad.id_propiedad == m.Contrato.id_propiedad).filter(
        m.Contrato.id_tenant == tid, m.Propiedad.id_tenant == tid)
    props = db.query(m.Propiedad).filter(m.Propiedad.id_tenant == tid)
    if spec.id_sucursal is not None:
        contract = contract.filter(m.Propiedad.id_sucursal == spec.id_sucursal)
        props = props.filter(m.Propiedad.id_sucursal == spec.id_sucursal)
    if spec.tipo_contrato:
        contract = contract.filter(m.Contrato.tipo_contrato == spec.tipo_contrato)
        props = props.filter(m.Propiedad.tipo_operacion == spec.tipo_contrato)
    if spec.estado:
        props = props.filter(m.Propiedad.estado == spec.estado)
    if spec.desde:
        contract = contract.filter(m.Contrato.fecha_inicio >= spec.desde)
    if spec.hasta:
        contract = contract.filter(m.Contrato.fecha_inicio <= spec.hasta)
    notes = []
    if spec.tipo == "ventas_sucursal":
        rows = contract.join(m.Sucursal, m.Sucursal.id_sucursal == m.Propiedad.id_sucursal).filter(m.Sucursal.id_tenant == tid).with_entities(
            m.Sucursal.nombre, func.count(m.Contrato.id_contrato), func.sum(m.Contrato.monto_total)).group_by(m.Sucursal.nombre).limit(spec.limite).all()
        columns, title = ["Sucursal", "Contratos", "Monto contratado"], "Contratos por sucursal"
        if spec.estado:
            raise HTTPException(422, "El estado de cartera no es un filtro de contratos.")
    elif spec.tipo == "ranking_agentes":
        rows = contract.join(m.Agente, m.Agente.id_agente == m.Contrato.id_agente).join(m.Usuario, m.Usuario.ci == m.Agente.ci_usuario).filter(
            m.Agente.id_tenant == tid, m.Usuario.id_tenant == tid).with_entities(m.Usuario.nombre,
            func.count(m.Contrato.id_contrato), func.sum(m.Contrato.monto_total)).group_by(m.Usuario.ci, m.Usuario.nombre).order_by(
            func.sum(m.Contrato.monto_total).desc()).limit(spec.limite).all()
        columns, title = ["Agente", "Contratos", "Monto contratado"], "Ranking de agentes"
        if spec.estado:
            raise HTTPException(422, "El estado de cartera no es un filtro de contratos.")
    elif spec.tipo == "cartera_estado":
        if spec.desde or spec.hasta:
            raise HTTPException(422, "La cartera muestra el estado actual. No existe un historial de cartera por fecha.")
        rows = props.with_entities(m.Propiedad.estado, func.count(m.Propiedad.id_propiedad), func.sum(m.Propiedad.precio)).group_by(m.Propiedad.estado).limit(spec.limite).all()
        columns, title = ["Estado", "Propiedades", "Valor de cartera"], "Cartera actual por estado"
    elif spec.tipo == "reservas_sucursal":
        if spec.tipo_contrato or spec.estado:
            raise HTTPException(422, "Para reservas use fecha y sucursal; los filtros de contrato/estado no se aplican.")
        q = db.query(m.Sucursal.nombre, func.count(m.OperacionOffline.id)).join(m.OperacionOffline,
            m.OperacionOffline.id_sucursal == m.Sucursal.id_sucursal).filter(m.Sucursal.id_tenant == tid,
            m.OperacionOffline.id_tenant == tid, m.OperacionOffline.tipo == "reserva", m.OperacionOffline.estado == "confirmada")
        if spec.id_sucursal is not None:
            q = q.filter(m.Sucursal.id_sucursal == spec.id_sucursal)
        if spec.desde:
            q = q.filter(func.date(m.OperacionOffline.registrado_en) >= spec.desde)
        if spec.hasta:
            q = q.filter(func.date(m.OperacionOffline.registrado_en) <= spec.hasta)
        rows = q.group_by(m.Sucursal.nombre).limit(spec.limite).all()
        columns, title = ["Sucursal", "Reservas confirmadas"], "Reservas por sucursal"
    else:
        if spec.estado:
            raise HTTPException(422, "El estado de cartera no es un filtro de ingresos.")
        # Los ingresos usan la fecha del pago, no la fecha de inicio del contrato.
        q = db.query(m.Pago.fecha_pago, m.Pago.monto).join(m.Contrato).join(m.Propiedad).filter(
            m.Contrato.id_tenant == tid, m.Propiedad.id_tenant == tid)
        if spec.id_sucursal is not None:
            q = q.filter(m.Propiedad.id_sucursal == spec.id_sucursal)
        if spec.tipo_contrato:
            q = q.filter(m.Contrato.tipo_contrato == spec.tipo_contrato)
        if spec.desde:
            q = q.filter(func.date(m.Pago.fecha_pago) >= spec.desde)
        if spec.hasta:
            q = q.filter(func.date(m.Pago.fecha_pago) <= spec.hasta)
        grouped = {}
        payments = q.order_by(m.Pago.fecha_pago.desc()).limit(10001).all()
        if len(payments) > 10000:
            raise HTTPException(422, "Acote las fechas: el reporte supera 10000 pagos.")
        for stamp, amount in payments:
            if stamp:
                monday = stamp.date() - timedelta(days=stamp.weekday())
                grouped[monday.isoformat()] = grouped.get(monday.isoformat(), 0) + amount
        rows = sorted(grouped.items())[:spec.limite]
        columns, title = ["Semana desde", "Ingresos cobrados"], "Ingresos por semana"
    values = [[float(v) if hasattr(v, "as_tuple") else v for v in row] for row in rows]
    return {"titulo": title, "columnas": columns, "filas": values,
            "filtros": spec.model_dump(mode="json"), "generado_en": today(), "id_tenant": tid,
            "grafico": "barras", "notas": notes,
            "resumen": f"{len(values)} grupos encontrados en los datos reales de su inmobiliaria."}


@router.post("/reporte")
def natural_report(body: NaturalRequest, db: Session = Depends(get_db), user=Depends(require_staff)):
    require_ai(db, user)
    try:
        spec, provider = interpret(body.texto)
    except (ValueError, TypeError):
        raise HTTPException(422, "La solicitud contiene fechas o parámetros no válidos.")
    return {**build_report(db, user, spec), "interprete": provider}


@router.post("/convencional")
def conventional_report(spec: ReportSpec, db: Session = Depends(get_db), user=Depends(require_staff)):
    from saas import require_active
    require_active(db, user.id_tenant)
    return {**build_report(db, user, spec), "interprete": "seleccion_manual"}
