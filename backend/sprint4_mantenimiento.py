"""CU-34 solicitudes de mantenimiento y CU-37 workflow inteligente (clasificación + asignación + notificación)."""
import uuid
from datetime import datetime
from decimal import Decimal
from pathlib import Path
import base64
from sqlalchemy import LargeBinary
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel, Field
from sqlalchemy import Column, Integer, String, Text, DateTime, Numeric, ForeignKey
from sqlalchemy.orm import Session, relationship
from database.database import Base, get_db
from database.models import Propiedad, Agente, Usuario, Contrato, Cliente, Propietario
from sprint4_core import get_current_user, require_staff, is_admin, role_name, scoped, in_scope
from sprint4_ia import CATEGORIAS_MANTENIMIENTO, clasificar_solicitud

router = APIRouter(prefix="/api/mantenimiento", tags=["Mantenimiento y workflow"])
UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
ESTADOS = ["Recibida", "Asignada", "En progreso", "Resuelta", "Cerrada", "Rechazada"]
ABIERTAS = ["Recibida", "Asignada", "En progreso"]
TRANSICIONES = {
    "Recibida": {"Asignada", "Rechazada"},
    "Asignada": {"En progreso", "Rechazada", "Resuelta"},
    "En progreso": {"Resuelta", "Asignada"},
    "Resuelta": {"Cerrada", "En progreso"},
    "Cerrada": set(),
    "Rechazada": set(),
}
CARGA_MAXIMA = 5   # solicitudes abiertas a partir de las cuales se reparte a otro responsable
Estado = Literal["Recibida", "Asignada", "En progreso", "Resuelta", "Cerrada", "Rechazada"]
Urgencia = Literal["Baja", "Media", "Alta", "Critica"]


class Solicitud(Base):
    __tablename__ = "solicitud_mantenimiento"
    id = Column(Integer, primary_key=True)
    version = Column(Integer, nullable=False, default=1)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant"), nullable=False, index=True)
    id_propiedad = Column(Integer, ForeignKey("propiedad.id_propiedad"), nullable=False)
    id_reportante = Column(String(20), ForeignKey("usuario.ci"), nullable=False)
    id_responsable = Column(String(20), ForeignKey("usuario.ci"))
    contratista = Column(String(150), default="")
    titulo = Column(String(150), nullable=False)
    descripcion = Column(Text, nullable=False)
    categoria = Column(String(30), nullable=False, default="Otro")
    urgencia = Column(String(10), nullable=False, default="Media")
    estado = Column(String(20), nullable=False, default="Recibida")
    clasificacion_modo = Column(String(10), default="local")
    justificacion = Column(String(500), default="")
    creado = Column(DateTime, nullable=False, default=datetime.utcnow)
    actualizado = Column(DateTime, nullable=False, default=datetime.utcnow)
    resuelto_en = Column(DateTime)

    propiedad = relationship("Propiedad")
    reportante = relationship("Usuario", foreign_keys=[id_reportante])
    responsable = relationship("Usuario", foreign_keys=[id_responsable])
    fotos = relationship("SolicitudFoto", cascade="all, delete-orphan")
    costos = relationship("SolicitudCosto", cascade="all, delete-orphan")


class SolicitudFoto(Base):
    __tablename__ = "solicitud_foto"
    id = Column(Integer, primary_key=True)
    id_solicitud = Column(Integer, ForeignKey("solicitud_mantenimiento.id", ondelete="CASCADE"), nullable=False)
    url = Column(String(255), nullable=False)
    contenido = Column(LargeBinary, nullable=False)
    mime = Column(String(30), nullable=False)
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)


class SolicitudCosto(Base):
    __tablename__ = "solicitud_costo"
    id = Column(Integer, primary_key=True)
    id_solicitud = Column(Integer, ForeignKey("solicitud_mantenimiento.id", ondelete="CASCADE"), nullable=False)
    concepto = Column(String(150), nullable=False)
    monto = Column(Numeric(12, 2), nullable=False)
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)


class SolicitudEvento(Base):
    __tablename__ = "solicitud_evento"
    id = Column(Integer, primary_key=True)
    id_solicitud = Column(Integer, ForeignKey("solicitud_mantenimiento.id", ondelete="CASCADE"), nullable=False, index=True)
    estado = Column(String(20), nullable=False)
    detalle = Column(String(500), default="")
    id_usuario = Column(String(20), ForeignKey("usuario.ci"))
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)


def total_costos(s):
    return sum((c.monto for c in s.costos), Decimal("0"))


def solicitud_json(s, detalle=False, db=None):
    data = {"id": s.id, "version": s.version, "id_propiedad": s.id_propiedad, "propiedad": s.propiedad.titulo if s.propiedad else None,
            "id_tenant": s.id_tenant, "inmobiliaria": s.propiedad.tenant.nombre, "contratista": s.contratista, "titulo": s.titulo, "descripcion": s.descripcion, "categoria": s.categoria, "urgencia": s.urgencia,
            "estado": s.estado, "clasificacion_modo": s.clasificacion_modo, "justificacion": s.justificacion,
            "reportante": s.reportante.nombre if s.reportante else None,
            "id_responsable": s.id_responsable, "responsable": s.responsable.nombre if s.responsable else None,
            "costo_total": total_costos(s), "fotos": [{"id": f.id, "url": f"data:{f.mime};base64," + base64.b64encode(f.contenido).decode('ascii')} for f in s.fotos],
            "creado": s.creado, "actualizado": s.actualizado, "resuelto_en": s.resuelto_en}
    if detalle and db is not None:
        data["costos"] = [{"id": c.id, "concepto": c.concepto, "monto": c.monto, "fecha": c.fecha} for c in s.costos]
        data["eventos"] = [{"estado": e.estado, "detalle": e.detalle, "fecha": e.fecha} for e in
                           db.query(SolicitudEvento).filter_by(id_solicitud=s.id).order_by(SolicitudEvento.fecha)]
    return data


def relacion(db, user, prop):
    """'staff' (empresa del inmueble), 'propietario', 'inquilino' (cliente con contrato) o None."""
    if in_scope(user, prop.id_tenant) and (is_admin(user) or user.agente is not None or role_name(user) in {"agente", "agente inmobiliario"}):
        return "staff"
    if prop.propietario and prop.propietario.id_usuario == user.id:
        return "propietario"
    cliente = db.query(Cliente).filter(Cliente.id_usuario == user.id).first()
    if cliente and db.query(Contrato).filter_by(id_propiedad=prop.id_propiedad, id_cliente=cliente.id_cliente).first():
        return "inquilino"
    return None


def evento(db, s, detalle, actor=None):
    db.add(SolicitudEvento(id_solicitud=s.id, estado=s.estado, detalle=detalle[:500], id_usuario=actor.id if actor else None))


def carga(db, id_usuario):
    return db.query(Solicitud).filter(Solicitud.id_responsable == id_usuario, Solicitud.estado.in_(ABIERTAS)).count()


def elegir_responsable(db, prop, urgencia):
    """Regla del workflow: el agente del inmueble atiende lo urgente o si tiene poca carga;
    si está saturado, se asigna al agente (o administrador) de la empresa con menos solicitudes abiertas."""
    agente_prop = prop.agente.id_usuario if prop.agente else None
    if agente_prop and (urgencia in {"Alta", "Critica"} or carga(db, agente_prop) < CARGA_MAXIMA):
        return agente_prop, "agente del inmueble"
    candidatos = [a.id_usuario for a in db.query(Agente).join(Usuario).filter(Usuario.id_tenant == prop.id_tenant)]
    if not candidatos:
        candidatos = [u.id for u in db.query(Usuario).filter(Usuario.id_tenant == prop.id_tenant).all() if is_admin(u)]
    if not candidatos:
        return None, "sin personal disponible"
    elegido = min(candidatos, key=lambda uid: (carga(db, uid), uid))
    return elegido, "menor carga de trabajo"


def obtener(db, user, ident):
    s = db.get(Solicitud, ident)
    if not s or relacion(db, user, s.propiedad) is None and s.id_reportante != user.id:
        raise HTTPException(404, "Solicitud no encontrada.")
    return s


@router.get("/mis-inmuebles")
def mis_inmuebles(db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Inmuebles sobre los que el usuario puede reportar: personal (su empresa), propietario (los suyos)
    o cliente (los que tiene bajo contrato)."""
    if is_admin(user) or user.agente is not None or role_name(user) in {"agente", "agente inmobiliario"}:
        props = scoped(db.query(Propiedad), user, Propiedad.id_tenant).all()
    else:
        ids = set()
        propietario = db.query(Propietario).filter(Propietario.id_usuario == user.id).first()
        if propietario:
            ids |= {p.id_propiedad for p in propietario.propiedades}
        cliente = db.query(Cliente).filter(Cliente.id_usuario == user.id).first()
        if cliente:
            ids |= {c.id_propiedad for c in db.query(Contrato).filter_by(id_cliente=cliente.id_cliente)}
        props = db.query(Propiedad).filter(Propiedad.id_propiedad.in_(ids)).all() if ids else []
    return [{"id_propiedad": p.id_propiedad, "titulo": p.titulo, "direccion": p.direccion} for p in props]


class ClasificarRequest(BaseModel):
    texto: str = Field(min_length=3, max_length=3000)


@router.post("/clasificar")
def clasificar(data: ClasificarRequest, user=Depends(get_current_user)):
    """Vista previa de la clasificación automática antes de enviar la solicitud."""
    resultado, modo = clasificar_solicitud(data.texto, user)
    return resultado.model_dump() | {"modo": modo}


class SolicitudCreate(BaseModel):
    id_propiedad: int
    titulo: str = Field(min_length=3, max_length=150)
    descripcion: str = Field(min_length=5, max_length=3000)


@router.post("", status_code=201)
def crear(data: SolicitudCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    if user.id_rol == 1 and not user.id_tenant:
        raise HTTPException(403, 'Seleccione una inmobiliaria concreta para registrar la incidencia.')
    from sprint4_notificaciones import notificar
    prop = db.get(Propiedad, data.id_propiedad)
    if not prop or relacion(db, user, prop) is None:
        raise HTTPException(403, "Solo el personal, el propietario o un cliente con contrato pueden reportar sobre este inmueble.")
    # 1) La IA (o reglas locales) clasifica categoría y urgencia.
    clasificacion, modo = clasificar_solicitud(f"{data.titulo}. {data.descripcion}", user)
    s = Solicitud(id_tenant=prop.id_tenant, id_propiedad=prop.id_propiedad, id_reportante=user.id, titulo=data.titulo.strip(),
                  descripcion=data.descripcion.strip(), categoria=clasificacion.categoria, urgencia=clasificacion.urgencia,
                  clasificacion_modo=modo, justificacion=clasificacion.justificacion, estado="Recibida")
    db.add(s)
    db.flush()
    evento(db, s, f"Clasificada como {s.categoria} / urgencia {s.urgencia} ({modo})", user)
    # 2) El workflow asigna responsable y cambia el estado automáticamente.
    responsable, motivo = elegir_responsable(db, prop, s.urgencia)
    if responsable:
        s.id_responsable, s.estado = responsable, "Asignada"
        evento(db, s, f"Asignada automáticamente ({motivo})")
        # 3) Notificación push/in-app al responsable.
        notificar(db, responsable, "mantenimiento", f"Solicitud {s.urgencia}: {s.titulo}",
                  f"{prop.titulo} · {s.categoria}", f"solicitud:{s.id}")
    if prop.propietario and prop.propietario.id_usuario != user.id:
        notificar(db, prop.propietario.id_usuario, "mantenimiento", f"Nueva solicitud en {prop.titulo}",
                  f"{s.categoria} · urgencia {s.urgencia}", f"solicitud:{s.id}", push=False)
    db.commit()
    db.refresh(s)
    return solicitud_json(s, True, db)


@router.post("/{ident}/fotos", status_code=201)
def subir_foto(ident: int, file: UploadFile = File(...), db: Session = Depends(get_db), user=Depends(get_current_user)):
    if user.id_rol == 1 and not user.id_tenant:
        raise HTTPException(403, 'Seleccione una inmobiliaria concreta para adjuntar fotos.')
    s = obtener(db, user, ident)
    if len(s.fotos) >= 10:
        raise HTTPException(409, "Máximo 10 fotos por solicitud.")
    content = file.file.read(5 * 1024 * 1024 + 1)
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(413, "La imagen no puede superar 5 MB.")
    if content.startswith(b"\x89PNG\r\n\x1a\n"): ext = ".png"
    elif content.startswith(b"\xff\xd8\xff"): ext = ".jpg"
    elif content.startswith(b"RIFF") and content[8:12] == b"WEBP": ext = ".webp"
    else: raise HTTPException(415, "Solo imágenes PNG, JPEG o WebP.")
    mime = {'.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp'}[ext]
    foto = SolicitudFoto(id_solicitud=s.id, url='foto' + ext, contenido=content, mime=mime)
    s.version += 1
    db.add(foto)
    db.commit()
    return {"id": foto.id, "url": f'data:{mime};base64,' + base64.b64encode(content).decode('ascii')}


@router.get("")
def listar(estado: Estado | None = None, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Personal: solicitudes de su empresa (el agente, las asignadas o de sus inmuebles).
    Propietario: las de sus inmuebles. Cliente: las que reportó."""
    es_staff = is_admin(user) or user.agente is not None or role_name(user) in {"agente", "agente inmobiliario"}
    query = db.query(Solicitud)
    if es_staff:
        query = scoped(query, user, Solicitud.id_tenant)
        if not is_admin(user):
            agente = db.query(Agente).filter(Agente.id_usuario == user.id).first()
            props = [p.id_propiedad for p in db.query(Propiedad).filter_by(id_agente=agente.id_agente)] if agente else []
            query = query.filter((Solicitud.id_responsable == user.id) | Solicitud.id_propiedad.in_(props or [-1]))
    else:
        propietario = db.query(Propietario).filter(Propietario.id_usuario == user.id).first()
        props = [p.id_propiedad for p in propietario.propiedades] if propietario else []
        query = query.filter((Solicitud.id_reportante == user.id) | Solicitud.id_propiedad.in_(props or [-1]))
    if estado:
        query = query.filter(Solicitud.estado == estado)
    return [solicitud_json(s) for s in query.order_by(Solicitud.creado.desc()).all()]


@router.get("/costos/resumen")
def resumen_costos(db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Costos consolidados por inmueble: el propietario ve los suyos; el personal, los de su empresa."""
    if is_admin(user) or user.agente is not None or role_name(user) in {"agente", "agente inmobiliario"}:
        solicitudes = scoped(db.query(Solicitud), user, Solicitud.id_tenant).all()
    else:
        propietario = db.query(Propietario).filter(Propietario.id_usuario == user.id).first()
        ids = [p.id_propiedad for p in propietario.propiedades] if propietario else []
        solicitudes = db.query(Solicitud).filter(Solicitud.id_propiedad.in_(ids)).all() if ids else []
    resumen = {}
    for s in solicitudes:
        r = resumen.setdefault(s.id_propiedad, {"id_propiedad": s.id_propiedad, "propiedad": s.propiedad.titulo,
                                                "solicitudes": 0, "abiertas": 0, "costo_total": Decimal("0"), "por_categoria": {}})
        r["solicitudes"] += 1
        r["abiertas"] += s.estado in ABIERTAS
        costo = total_costos(s)
        r["costo_total"] += costo
        r["por_categoria"][s.categoria] = r["por_categoria"].get(s.categoria, Decimal("0")) + costo
    filas = sorted(resumen.values(), key=lambda r: -r["costo_total"])
    return {"total_general": sum((r["costo_total"] for r in filas), Decimal("0")), "inmuebles": filas}


@router.get("/{ident}")
def detalle(ident: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return solicitud_json(obtener(db, user, ident), True, db)


class SolicitudUpdate(BaseModel):
    contratista: str | None = Field(default=None, max_length=150)
    estado: Estado | None = None
    id_responsable: str | None = None
    categoria: str | None = None
    urgencia: Urgencia | None = None
    comentario: str = Field(default="", max_length=500)


@router.put("/{ident}")
def actualizar(ident: int, data: SolicitudUpdate, db: Session = Depends(get_db), user=Depends(require_staff)):
    from sprint4_notificaciones import notificar
    s = obtener(db, user, ident)
    if s.id_tenant != user.id_tenant:
        raise HTTPException(404, "Solicitud no encontrada.")
    cambios = []
    if data.contratista is not None:
        s.contratista = data.contratista.strip(); cambios.append("contratista actualizado")
    if data.categoria is not None:
        if data.categoria not in CATEGORIAS_MANTENIMIENTO:
            raise HTTPException(422, "Categoría no válida.")
        s.categoria = data.categoria; cambios.append(f"categoría {data.categoria}")
    if data.urgencia is not None:
        s.urgencia = data.urgencia; cambios.append(f"urgencia {data.urgencia}")
    if data.id_responsable is not None and data.id_responsable != s.id_responsable:
        nuevo = db.get(Usuario, data.id_responsable)
        if not nuevo or nuevo.id_tenant != s.id_tenant or not (is_admin(nuevo) or nuevo.agente is not None or role_name(nuevo) in {"agente", "agente inmobiliario"}):
            raise HTTPException(422, "El responsable debe ser personal de la inmobiliaria.")
        s.id_responsable = nuevo.id
        cambios.append(f"responsable {nuevo.nombre}")
        notificar(db, nuevo.id, "mantenimiento", f"Se le asignó: {s.titulo}", f"Urgencia {s.urgencia}", f"solicitud:{s.id}")
        if s.estado == "Recibida":
            s.estado = "Asignada"
    if data.estado is not None and data.estado != s.estado:
        if data.estado not in TRANSICIONES[s.estado]:
            raise HTTPException(409, f"No se puede pasar de {s.estado} a {data.estado}.")
        s.estado = data.estado
        s.resuelto_en = datetime.utcnow() if data.estado in {"Resuelta", "Cerrada"} else None
        cambios.append(f"estado {data.estado}")
        notificar(db, s.id_reportante, "mantenimiento", f"Su solicitud está {data.estado}", s.titulo, f"solicitud:{s.id}")
        if data.estado == "Resuelta" and s.propiedad.propietario:
            notificar(db, s.propiedad.propietario.id_usuario, "mantenimiento", f"Solicitud resuelta en {s.propiedad.titulo}",
                      f"{s.titulo} · costo total {total_costos(s)}", f"solicitud:{s.id}", push=False)
    if not cambios and not data.comentario:
        raise HTTPException(422, "No hay cambios.")
    s.actualizado = datetime.utcnow()
    s.version += 1
    evento(db, s, ", ".join(cambios) + (f" — {data.comentario}" if data.comentario else ""), user)
    db.commit()
    return solicitud_json(s, True, db)


class CostoCreate(BaseModel):
    concepto: str = Field(min_length=1, max_length=150)
    monto: Decimal = Field(gt=0, max_digits=12, decimal_places=2)


@router.post("/{ident}/costos", status_code=201)
def agregar_costo(ident: int, data: CostoCreate, db: Session = Depends(get_db), user=Depends(require_staff)):
    s = obtener(db, user, ident)
    if s.id_tenant != user.id_tenant:
        raise HTTPException(404, "Solicitud no encontrada.")
    db.add(SolicitudCosto(id_solicitud=s.id, concepto=data.concepto.strip(), monto=data.monto))
    s.version += 1
    evento(db, s, f"Costo registrado: {data.concepto} {data.monto}", user)
    db.commit()
    db.refresh(s)
    return solicitud_json(s, True, db)


@router.delete("/{ident}/costos/{id_costo}")
def borrar_costo(ident: int, id_costo: int, db: Session = Depends(get_db), user=Depends(require_staff)):
    s = obtener(db, user, ident)
    costo = db.query(SolicitudCosto).filter_by(id=id_costo, id_solicitud=s.id).first()
    if not costo or s.id_tenant != user.id_tenant:
        raise HTTPException(404, "Costo no encontrado.")
    db.delete(costo)
    s.version += 1
    evento(db, s, f"Costo eliminado: {costo.concepto}", user)
    db.commit()
    db.refresh(s)
    return solicitud_json(s, True, db)
