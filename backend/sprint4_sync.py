"""Comandos móviles idempotentes: cambio de dominio y recibo en la misma transacción."""
import base64
import hashlib
import json
import re
from io import BytesIO
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy import Column, String, Integer, JSON, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Session
from database.database import Base, get_db
from database import models as m
from auth import get_current_user, require_staff, require_admin, scope_query
from replica import WorkSession
import sprint4_api as api
import sprint4_fidelizacion as f
import sprint4_mantenimiento as mant
import sprint4_notificaciones as notify

router = APIRouter(prefix='/api/servicios', tags=['Sincronización Sprint 4'])


class ReciboServicio(Base):
    __tablename__ = 'recibo_servicio'
    id = Column(Integer, primary_key=True)
    ci_usuario = Column(String(20), ForeignKey('usuario.ci'), nullable=False)
    uuid = Column(String(36), nullable=False)
    huella = Column(String(64), nullable=False)
    respuesta = Column(JSON, nullable=False)
    __table_args__ = (UniqueConstraint('ci_usuario', 'uuid'),)


class Comando(BaseModel):
    uuid: UUID
    metodo: str = Field(pattern='^(POST|PUT|DELETE)$')
    ruta: str = Field(max_length=200)
    datos: dict = Field(default_factory=dict)
    version: int | None = Field(default=None, ge=1)


def checked(model, data):
    try: return model.model_validate(data)
    except ValidationError as e: raise HTTPException(422, str(e)) from None


@router.post('/sync')
def sync(body: Comando, db: Session = Depends(get_db), user=Depends(get_current_user)):
    digest = hashlib.sha256(json.dumps({'scope': user.id_tenant, 'all': bool(getattr(user, 'all_tenants', False)),
        'body': body.model_dump(mode='json')}, sort_keys=True).encode()).hexdigest()
    db.query(m.Usuario).filter_by(ci=user.ci).with_for_update().one()
    old = db.query(ReciboServicio).filter_by(ci_usuario=user.ci, uuid=str(body.uuid)).first()
    if old:
        if old.huella != digest: raise HTTPException(409, 'El UUID ya fue utilizado para otro cambio.')
        return old.respuesta
    s = WorkSession(db)
    path, method, data = body.ruta, body.metodo, body.datos
    match = re.fullmatch(r'/api/(favoritos|alertas|promociones|comisiones|mantenimiento|bandeja|visitas)(?:/(\d+))?(?:/(costos|fotos|liquidar|leida|leer-todas))?(?:/(\d+))?', path)
    if path == '/api/recomendaciones/feedback' and method == 'POST':
        result = api.feedback(checked(api.FeedbackIn, data), s, user)
    elif match:
        entity, ident, action, child = match.groups(); ident = int(ident) if ident else None
        if entity in ('promociones', 'comisiones') or entity == 'mantenimiento' and (method == 'PUT' or action == 'costos'):
            require_staff(user)
        if entity == 'comisiones': require_admin(user)
        if entity == 'mantenimiento' and ident and body.version is not None:
            db.query(mant.Solicitud).filter_by(id=ident).with_for_update().first()
            row = mant.obtener(s, user, ident)
            if row.version != body.version:
                raise HTTPException(409, jsonable_encoder({'mensaje': 'La incidencia cambió en el servidor. Revisa el conflicto.', 'servidor': mant.solicitud_json(row, True, s)}))
        if entity == 'visitas' and method == 'POST' and ident is None:
            result = api.create_visit(checked(api.VisitIn, data), s, user)
        elif entity == 'visitas' and method == 'PUT' and ident:
            result = api.update_visit(ident, checked(api.VisitUpdate, data), s, user)
        elif entity == 'favoritos' and ident and method in ('POST', 'DELETE'):
            result = (f.agregar_favorito if method == 'POST' else f.quitar_favorito)(ident, s, user)
        elif entity == 'alertas' and not action:
            if method == 'POST' and ident is None: result = f.crear_alerta(checked(f.AlertaCreate, data), s, user)
            elif method == 'PUT' and ident: result = f.actualizar_alerta(ident, checked(f.AlertaUpdate, data), s, user)
            elif method == 'DELETE' and ident: result = f.borrar_alerta(ident, s, user)
            else: raise HTTPException(422, 'Comando de alerta inválido.')
        elif entity == 'mantenimiento':
            if ident is None and method == 'POST': result = mant.crear(checked(mant.SolicitudCreate, data), s, user)
            elif ident and method == 'PUT': result = mant.actualizar(ident, checked(mant.SolicitudUpdate, data), s, user)
            elif ident and method == 'POST' and action == 'costos': result = mant.agregar_costo(ident, checked(mant.CostoCreate, data), s, user)
            elif ident and method == 'DELETE' and action == 'costos' and child: result = mant.borrar_costo(ident, int(child), s, user)
            elif ident and method == 'POST' and action == 'fotos':
                raw = data.get('contenido', '')
                if not isinstance(raw, str) or len(raw) > 7 * 1024 * 1024: raise HTTPException(413, 'Foto demasiado grande.')
                try: content = base64.b64decode(raw, validate=True)
                except ValueError: raise HTTPException(422, 'Foto inválida.') from None
                result = mant.subir_foto(ident, UploadFile(file=BytesIO(content), filename='foto'), s, user)
            else: raise HTTPException(422, 'Comando de mantenimiento inválido.')
        elif entity == 'promociones':
            if method == 'POST' and ident is None: result = api.create_promo(checked(api.PromoIn, data), s, user)
            elif method == 'PUT' and ident: result = api.edit_promo(ident, checked(api.ActiveIn, data), s, user)
            elif method == 'DELETE' and ident: result = api.delete_promo(ident, s, user)
            else: raise HTTPException(422, 'Comando de promoción inválido.')
        elif entity == 'comisiones' and action == 'liquidar' and method == 'POST' and ident:
            result = api.settle(ident, s, user)
        elif entity == 'bandeja' and ident and action == 'leida' and method == 'PUT':
            result = notify.marcar_leida(ident, s, user)
        elif entity == 'bandeja' and action == 'leer-todas' and method == 'PUT':
            result = notify.leer_todas(s, user)
        else: raise HTTPException(422, 'Comando no permitido.')
    else: raise HTTPException(422, 'Ruta no permitida para sincronización.')
    result = jsonable_encoder(result)
    db.add(ReciboServicio(ci_usuario=user.ci, uuid=str(body.uuid), huella=digest, respuesta=result)); db.commit()
    return result
