"""Bandeja de notificaciones in-app + envío push FCM (Sprint 4).

Toda notificación se guarda en la base (funciona sin Firebase). Si Firebase está configurado,
además se intenta un push a los dispositivos registrados del usuario.
"""
import os
import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import Session
from database.database import Base, get_db
from sprint4_core import get_current_user

router = APIRouter(prefix="/api/bandeja", tags=["Notificaciones in-app"])


class Notificacion(Base):
    __tablename__ = "notificacion"
    id = Column(Integer, primary_key=True)
    id_usuario = Column(String(20), ForeignKey("usuario.ci"), nullable=False, index=True)
    tipo = Column(String(30), nullable=False)          # alerta, mantenimiento, prospecto, visita...
    titulo = Column(String(150), nullable=False)
    cuerpo = Column(Text, nullable=False, default="")
    referencia = Column(String(80))                    # p. ej. "propiedad:12" o "solicitud:3"
    leida = Column(Boolean, nullable=False, default=False)
    push_enviado = Column(Boolean, nullable=False, default=False)
    push_solicitado = Column(Boolean, nullable=False, default=True)
    push_intentos = Column(Integer, nullable=False, default=0)
    fecha = Column(DateTime, nullable=False, default=datetime.utcnow)


def _firebase_app():
    if not os.getenv("GOOGLE_APPLICATION_CREDENTIALS") and not os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON"):
        return None
    try:
        import firebase_admin
        try:
            return firebase_admin.get_app()
        except ValueError:
            raw = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
            if raw:
                from firebase_admin import credentials
                return firebase_admin.initialize_app(credentials.Certificate(json.loads(raw)))
            return firebase_admin.initialize_app()
    except Exception:
        return None


def enviar_push(db, id_usuario, titulo, cuerpo, data=None):
    """Push best-effort. Devuelve cuántos dispositivos aceptaron el mensaje."""
    app = _firebase_app()
    if app is None:
        return 0
    from firebase_admin import messaging
    from sprint4_api import Dispositivo
    enviados = 0
    for device in db.query(Dispositivo).filter_by(id_usuario=id_usuario).all():
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(title=titulo, body=cuerpo[:200]),
                data={k: str(v) for k, v in (data or {}).items()}, token=device.token), app=app)
            enviados += 1
        except Exception:
            continue
    return enviados


def notificar(db, id_usuario, tipo, titulo, cuerpo="", referencia=None, push=True):
    """Guarda la notificación y, si se puede, la envía por FCM. No hace commit."""
    if not id_usuario:
        return None
    n = Notificacion(id_usuario=id_usuario, tipo=tipo, titulo=titulo[:150], cuerpo=cuerpo, referencia=referencia, push_solicitado=push)
    db.add(n)
    return n


def entregar_pendientes(db, ci=None):
    """El worker entrega únicamente notificaciones cuyo cambio ya fue confirmado en la BD."""
    if _firebase_app() is None: return 0
    from sprint4_api import Dispositivo
    query = db.query(Notificacion).filter_by(push_enviado=False, push_solicitado=True).filter(Notificacion.push_intentos < 5)
    if ci: query = query.filter_by(id_usuario=ci)
    count = 0
    for n in query.order_by(Notificacion.id).limit(50).with_for_update(skip_locked=True):
        if not db.query(Dispositivo).filter_by(id_usuario=n.id_usuario).first(): continue
        n.push_intentos += 1
        n.push_enviado = enviar_push(db, n.id_usuario, n.titulo, n.cuerpo, {'tipo': n.tipo, 'referencia': n.referencia or ''}) > 0
        count += bool(n.push_enviado)
    db.commit()
    return count


def notificacion_json(n):
    return {"id": n.id, "tipo": n.tipo, "titulo": n.titulo, "cuerpo": n.cuerpo, "referencia": n.referencia,
            "leida": n.leida, "push_enviado": n.push_enviado, "fecha": n.fecha}


@router.get("")
def bandeja(solo_no_leidas: bool = False, db: Session = Depends(get_db), user=Depends(get_current_user)):
    query = db.query(Notificacion).filter(Notificacion.id_usuario == user.id)
    if solo_no_leidas:
        query = query.filter(Notificacion.leida.is_(False))
    rows = query.order_by(Notificacion.fecha.desc()).limit(100).all()
    no_leidas = db.query(Notificacion).filter(Notificacion.id_usuario == user.id, Notificacion.leida.is_(False)).count()
    return {"no_leidas": no_leidas, "notificaciones": [notificacion_json(n) for n in rows]}


@router.put("/{ident}/leida")
def marcar_leida(ident: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    n = db.query(Notificacion).filter_by(id=ident, id_usuario=user.id).first()
    if not n:
        raise HTTPException(404, "Notificación no encontrada.")
    n.leida = True
    db.commit()
    return notificacion_json(n)


@router.put("/leer-todas")
def leer_todas(db: Session = Depends(get_db), user=Depends(get_current_user)):
    total = db.query(Notificacion).filter(Notificacion.id_usuario == user.id, Notificacion.leida.is_(False)) \
        .update({"leida": True})
    db.commit()
    return {"actualizadas": total}
