"""CU-30 favoritos y alertas de búsqueda; CU-31 búsqueda semántica y recomendaciones."""
import json
from collections import Counter
from datetime import datetime
from statistics import median
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean, UniqueConstraint
from sqlalchemy.orm import Session
from database.database import Base, get_db
from database.models import Propiedad, Tenant, Cliente, Visita
from sprint4_core import get_current_user, scoped, property_visible
from sprint4_ia import FiltrosBusqueda, interpretar_busqueda, normalizar
from schemas import PropiedadCatalogoResponse as PropiedadResponse

router = APIRouter(prefix="/api", tags=["Fidelización y búsqueda inteligente"])


class Favorito(Base):
    __tablename__ = "favorito"
    id = Column(Integer, primary_key=True)
    id_usuario = Column(String(20), ForeignKey("usuario.ci"), nullable=False, index=True)
    id_propiedad = Column(Integer, ForeignKey("propiedad.id_propiedad", ondelete="CASCADE"), nullable=False)
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)
    __table_args__ = (UniqueConstraint("id_usuario", "id_propiedad", name="uq_favorito"),)


class AlertaBusqueda(Base):
    __tablename__ = "alerta_busqueda"
    id = Column(Integer, primary_key=True)
    id_usuario = Column(String(20), ForeignKey("usuario.ci"), nullable=False, index=True)
    nombre = Column(String(100), nullable=False)
    criterios = Column(Text, nullable=False)      # JSON de FiltrosBusqueda
    activa = Column(Boolean, nullable=False, default=True)
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)


class AlertaEnviada(Base):
    __tablename__ = "alerta_enviada"
    id = Column(Integer, primary_key=True)
    id_alerta = Column(Integer, ForeignKey("alerta_busqueda.id", ondelete="CASCADE"), nullable=False)
    id_propiedad = Column(Integer, ForeignKey("propiedad.id_propiedad", ondelete="CASCADE"), nullable=False)
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)
    __table_args__ = (UniqueConstraint("id_alerta", "id_propiedad", name="uq_alerta_enviada"),)


class BusquedaHistorial(Base):
    __tablename__ = "busqueda_historial"
    id = Column(Integer, primary_key=True)
    id_usuario = Column(String(20), ForeignKey("usuario.ci"), nullable=False, index=True)
    texto = Column(String(500), nullable=False)
    filtros = Column(Text, nullable=False)
    modo = Column(String(10), nullable=False)
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)


# ---------------------------------------------------------------- búsqueda
def catalogo_publico(db, user=None):
    """Inmuebles disponibles de empresas activas y al día (igual que el catálogo público)."""
    query = db.query(Propiedad).join(Tenant).filter(Tenant.estado.is_(True), Propiedad.estado == "Disponible")
    from saas import summary
    bloqueadas = [t.id_tenant for t in db.query(Tenant).all() if summary(db, t.id_tenant)["estado"] != "activa"]
    if user is not None: query = scoped(query, user, Propiedad.id_tenant)
    if bloqueadas:
        query = query.filter(~Propiedad.id_tenant.in_(bloqueadas))
    return query


def texto_propiedad(p):
    return normalizar(" ".join([p.titulo or "", p.direccion or "", p.descripcion or "",
                                p.zona.nombre if p.zona else "", p.tipo_inmueble.nombre if p.tipo_inmueble else ""]))


def propiedad_cumple(p, f: FiltrosBusqueda):
    precio = float(p.precio)
    return all([
        f.tipo_operacion is None or p.tipo_operacion == f.tipo_operacion,
        f.precio_min is None or precio >= f.precio_min,
        f.precio_max is None or precio <= f.precio_max,
        f.cuartos is None or (p.habitaciones or 0) >= f.cuartos,
        f.banos is None or (p.banos or 0) >= f.banos,
        f.metros_min is None or float(p.superficie_m2 or 0) >= f.metros_min,
        f.zona is None or (p.zona is not None and normalizar(f.zona) in normalizar(p.zona.nombre)),
        f.tipo_inmueble is None or (p.tipo_inmueble is not None and p.tipo_inmueble.nombre == f.tipo_inmueble),
        not f.amueblado or p.amueblado,
        not f.garaje or bool(p.garaje),
    ])


def buscar_propiedades(db, f: FiltrosBusqueda, limite=30, user=None):
    """Filtros estructurados obligatorios; las amenidades (palabras) ordenan por relevancia."""
    query = catalogo_publico(db, user)
    if f.tipo_operacion: query = query.filter(Propiedad.tipo_operacion == f.tipo_operacion)
    if f.precio_min is not None: query = query.filter(Propiedad.precio >= f.precio_min)
    if f.precio_max is not None: query = query.filter(Propiedad.precio <= f.precio_max)
    candidatos = [p for p in query.all() if propiedad_cumple(p, f)]
    palabras = [normalizar(w) for w in f.palabras]
    puntuados = [(sum(w in texto_propiedad(p) for w in palabras), p) for p in candidatos]
    puntuados.sort(key=lambda x: (-x[0], x[1].id_propiedad))
    return [p for _, p in puntuados[:limite]]


class BusquedaRequest(BaseModel):
    texto: str = Field(min_length=2, max_length=500)
    limite: int = Field(default=30, ge=1, le=100)


@router.post("/busqueda-semantica")
def busqueda_semantica(data: BusquedaRequest, db: Session = Depends(get_db), user=Depends(get_current_user)):
    filtros, modo = interpretar_busqueda(db, data.texto, user)
    resultados = buscar_propiedades(db, filtros, data.limite, user)
    db.add(BusquedaHistorial(id_usuario=user.id, texto=data.texto, filtros=filtros.model_dump_json(), modo=modo))
    db.commit()
    return {"filtros": filtros.model_dump(), "resumen": filtros.resumen(), "modo": modo, "total": len(resultados),
            "resultados": [PropiedadResponse.model_validate(p) for p in resultados]}


@router.get("/busquedas/historial")
def historial(db: Session = Depends(get_db), user=Depends(get_current_user)):
    rows = db.query(BusquedaHistorial).filter_by(id_usuario=user.id).order_by(BusquedaHistorial.fecha.desc()).limit(20).all()
    return [{"id": r.id, "texto": r.texto, "modo": r.modo, "fecha": r.fecha} for r in rows]


# ---------------------------------------------------------------- recomendaciones
def perfil_usuario(db, user):
    """Propiedades que reflejan los gustos del usuario: favoritos, visitas y búsquedas recientes."""
    vistas = [f.id_propiedad for f in db.query(Favorito).filter_by(id_usuario=user.id).all()]
    from sprint4_api import Feedback
    vistas += [f.id_propiedad for f in db.query(Feedback).filter(Feedback.ci_usuario == user.ci, Feedback.valoracion >= 4)]
    cliente = db.query(Cliente).filter(Cliente.id_usuario == user.id).first()
    if cliente:
        vistas += [v.id_propiedad for v in db.query(Visita).filter(Visita.id_cliente == cliente.id_cliente).all()]
    props = db.query(Propiedad).filter(Propiedad.id_propiedad.in_(vistas)).all() if vistas else []
    busquedas = [FiltrosBusqueda.model_validate_json(b.filtros) for b in
                 db.query(BusquedaHistorial).filter_by(id_usuario=user.id).order_by(BusquedaHistorial.fecha.desc()).limit(10)]
    return set(vistas), props, busquedas


@router.get("/recomendaciones")
def recomendaciones(limite: int = Query(6, ge=1, le=30), db: Session = Depends(get_db), user=Depends(get_current_user)):
    from sprint4_api import Feedback
    rechazadas = {f.id_propiedad for f in db.query(Feedback).filter(Feedback.ci_usuario == user.ci, Feedback.valoracion <= 2)}
    ya_vistas, props, busquedas = perfil_usuario(db, user)
    operaciones = Counter([p.tipo_operacion for p in props] + [b.tipo_operacion for b in busquedas if b.tipo_operacion])
    zonas = Counter([p.id_zona for p in props])
    zonas_texto = [normalizar(b.zona) for b in busquedas if b.zona]
    tipos = Counter([p.id_tipo_inmueble for p in props])
    tipos_texto = {b.tipo_inmueble for b in busquedas if b.tipo_inmueble}
    precios = [float(p.precio) for p in props] + [b.precio_max for b in busquedas if b.precio_max]
    precio_ref = median(precios) if precios else None
    candidatos = [p for p in catalogo_publico(db, user).all() if p.id_propiedad not in ya_vistas and p.id_propiedad not in rechazadas]
    if not (props or busquedas):
        recientes = sorted(candidatos, key=lambda p: -p.id_propiedad)[:limite]
        return {"basado_en": "novedades", "recomendaciones": [
            {"propiedad": PropiedadResponse.model_validate(p), "puntaje": 0, "motivos": ["Publicación reciente"]} for p in recientes]}
    resultado = []
    for p in candidatos:
        puntaje, motivos = 0.0, []
        if operaciones and p.tipo_operacion == operaciones.most_common(1)[0][0]:
            puntaje += 3; motivos.append(f"Busca inmuebles en {p.tipo_operacion}")
        if zonas.get(p.id_zona) or (p.zona and any(z in normalizar(p.zona.nombre) for z in zonas_texto)):
            puntaje += 2; motivos.append(f"Zona de su interés: {p.zona.nombre if p.zona else ''}")
        if tipos.get(p.id_tipo_inmueble) or (p.tipo_inmueble and p.tipo_inmueble.nombre in tipos_texto):
            puntaje += 2; motivos.append(f"Tipo similar: {p.tipo_inmueble.nombre if p.tipo_inmueble else ''}")
        if precio_ref:
            cercania = max(0.0, 1 - abs(float(p.precio) - precio_ref) / precio_ref)
            if cercania > 0.6:
                puntaje += 2 * cercania; motivos.append("Precio dentro de su rango habitual")
        if puntaje > 0:
            resultado.append((puntaje, p, motivos))
    resultado.sort(key=lambda x: (-x[0], -x[1].id_propiedad))
    return {"basado_en": "historial", "recomendaciones": [
        {"propiedad": PropiedadResponse.model_validate(p), "puntaje": round(s, 2), "motivos": m} for s, p, m in resultado[:limite]]}


# ---------------------------------------------------------------- favoritos
@router.get("/favoritos")
def favoritos(db: Session = Depends(get_db), user=Depends(get_current_user)):
    rows = db.query(Favorito).filter_by(id_usuario=user.id).order_by(Favorito.fecha.desc()).all()
    props = {p.id_propiedad: p for p in db.query(Propiedad).filter(Propiedad.id_propiedad.in_([r.id_propiedad for r in rows])).all()} if rows else {}
    return [{"id_propiedad": r.id_propiedad, "fecha": r.fecha, "disponible": props[r.id_propiedad].estado == "Disponible",
             "propiedad": PropiedadResponse.model_validate(props[r.id_propiedad])} for r in rows if r.id_propiedad in props and property_visible(db, user, r.id_propiedad)]


@router.post("/favoritos/{id_propiedad}", status_code=201)
def agregar_favorito(id_propiedad: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    if not property_visible(db, user, id_propiedad):
        raise HTTPException(404, "Inmueble no encontrado.")
    if not db.query(Favorito).filter_by(id_usuario=user.id, id_propiedad=id_propiedad).first():
        db.add(Favorito(id_usuario=user.id, id_propiedad=id_propiedad))
        db.commit()
    return {"id_propiedad": id_propiedad, "favorito": True}


@router.delete("/favoritos/{id_propiedad}")
def quitar_favorito(id_propiedad: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    db.query(Favorito).filter_by(id_usuario=user.id, id_propiedad=id_propiedad).delete()
    db.commit()
    return {"id_propiedad": id_propiedad, "favorito": False}


# ---------------------------------------------------------------- alertas
class AlertaCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    criterios: FiltrosBusqueda | None = None
    texto: str | None = Field(default=None, min_length=2, max_length=500)

    @model_validator(mode="after")
    def origen(self):
        if self.criterios is None and not self.texto:
            raise ValueError("Indique criterios o una descripción en lenguaje natural.")
        return self


def alerta_json(a):
    f = FiltrosBusqueda.model_validate_json(a.criterios)
    return {"id": a.id, "nombre": a.nombre, "activa": a.activa, "criterios": f.model_dump(), "resumen": f.resumen(), "fecha": a.fecha}


@router.get("/alertas")
def alertas(db: Session = Depends(get_db), user=Depends(get_current_user)):
    return [alerta_json(a) for a in db.query(AlertaBusqueda).filter_by(id_usuario=user.id).order_by(AlertaBusqueda.fecha.desc())]


@router.post("/alertas", status_code=201)
def crear_alerta(data: AlertaCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    if db.query(AlertaBusqueda).filter_by(id_usuario=user.id).count() >= 20:
        raise HTTPException(409, "Puede tener como máximo 20 alertas.")
    modo = "manual"
    criterios = data.criterios
    if criterios is None:
        criterios, modo = interpretar_busqueda(db, data.texto, user)
    if criterios == FiltrosBusqueda():
        raise HTTPException(422, "La alerta necesita al menos un criterio.")
    alerta = AlertaBusqueda(id_usuario=user.id, nombre=data.nombre.strip(), criterios=criterios.model_dump_json())
    db.add(alerta)
    db.commit()
    return alerta_json(alerta) | {"modo": modo, "coincidencias_actuales": len(buscar_propiedades(db, criterios, 100, user))}


class AlertaUpdate(BaseModel):
    activa: bool


@router.put("/alertas/{ident}")
def actualizar_alerta(ident: int, data: AlertaUpdate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    a = db.query(AlertaBusqueda).filter_by(id=ident, id_usuario=user.id).first()
    if not a:
        raise HTTPException(404, "Alerta no encontrada.")
    a.activa = data.activa
    db.commit()
    return alerta_json(a)


@router.delete("/alertas/{ident}")
def borrar_alerta(ident: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    a = db.query(AlertaBusqueda).filter_by(id=ident, id_usuario=user.id).first()
    if not a:
        raise HTTPException(404, "Alerta no encontrada.")
    db.query(AlertaEnviada).filter_by(id_alerta=a.id).delete()
    db.delete(a)
    db.commit()
    return {"ok": True}


def procesar_alertas(db, prop):
    """Notifica (in-app + FCM) a los usuarios cuyas alertas coinciden con un inmueble publicado.
    Se llama después de crear un inmueble o volver a ponerlo Disponible. Cada alerta avisa una vez por inmueble."""
    from sprint4_notificaciones import notificar
    if prop.estado != "Disponible" or catalogo_publico(db).filter(Propiedad.id_propiedad == prop.id_propiedad).first() is None:
        return 0
    avisos = 0
    for a in db.query(AlertaBusqueda).filter(AlertaBusqueda.activa.is_(True)).all():
        from database.models import Usuario
        owner = db.get(Usuario, a.id_usuario)
        if not owner or owner.id_rol != 1 and owner.id_tenant != prop.id_tenant: continue
        if db.query(AlertaEnviada).filter_by(id_alerta=a.id, id_propiedad=prop.id_propiedad).first():
            continue
        if not propiedad_cumple(prop, FiltrosBusqueda.model_validate_json(a.criterios)):
            continue
        db.add(AlertaEnviada(id_alerta=a.id, id_propiedad=prop.id_propiedad))
        notificar(db, a.id_usuario, "alerta", f"Nuevo inmueble para \"{a.nombre}\"",
                  f"{prop.titulo} · {prop.tipo_operacion} · {prop.precio}", f"propiedad:{prop.id_propiedad}")
        avisos += 1
    db.commit()
    return avisos
