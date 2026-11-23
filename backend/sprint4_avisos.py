"""Avisos sin cuentas externas: Web Push VAPID y consulta Android limitada a la bandeja."""
import base64
import hashlib
import json
import secrets
from datetime import datetime, timedelta
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from database.database import Base, get_db
from sprint4_core import get_current_user
from sprint4_notificaciones import Notificacion, notificacion_json

router = APIRouter(prefix='/api/notificaciones', tags=['Avisos automáticos'])


class ClavePush(Base):
    __tablename__ = 'clave_webpush'
    id = Column(Integer, primary_key=True)
    publica = Column(String(150), nullable=False)
    privada_cifrada = Column(Text, nullable=False)


class NavegadorPush(Base):
    __tablename__ = 'navegador_webpush'
    endpoint = Column(String(2048), primary_key=True)
    ci_usuario = Column(String(20), ForeignKey('usuario.ci'), nullable=False, index=True)
    dispositivo = Column(String(100), nullable=False)
    suscripcion = Column(Text, nullable=False)


class DispositivoAvisos(Base):
    __tablename__ = 'dispositivo_avisos'
    dispositivo = Column(String(100), primary_key=True)
    ci_usuario = Column(String(20), ForeignKey('usuario.ci'), nullable=False, index=True)
    huella = Column(String(64), nullable=False, unique=True)
    vence = Column(DateTime, nullable=False)


def claves(db):
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives import serialization
    from logger import fernet
    row = db.get(ClavePush, 1)
    if not row:
        key = ec.generate_private_key(ec.SECP256R1())
        public = base64.urlsafe_b64encode(key.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)).decode().rstrip('=')
        private = key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.TraditionalOpenSSL, serialization.NoEncryption())
        row = ClavePush(id=1, publica=public, privada_cifrada=fernet.encrypt(private).decode())
        db.add(row)
        try: db.commit()
        except IntegrityError:
            db.rollback(); row = db.get(ClavePush, 1)
    return row


@router.get('/webpush/config')
def webpush_config(db: Session = Depends(get_db), user=Depends(get_current_user)):
    return {'clave_publica': claves(db).publica, 'modo': 'webpush'}


class RegistroWeb(BaseModel):
    dispositivo: str = Field(min_length=1, max_length=100)
    endpoint: str = Field(max_length=2048)
    keys: dict[str, str]

    @field_validator('endpoint')
    @classmethod
    def endpoint_valido(cls, value):
        url = urlsplit(value)
        host = url.hostname or ''
        allowed = host in {'fcm.googleapis.com', 'updates.push.services.mozilla.com', 'web.push.apple.com'} or host.endswith('.notify.windows.com') or host.endswith('.push.apple.com')
        if url.scheme != 'https' or url.username or url.password or url.port not in (None, 443) or not allowed:
            raise ValueError('Servicio de Web Push no permitido.')
        return value

    @field_validator('keys')
    @classmethod
    def keys_validas(cls, value):
        for name, length in [('p256dh', 65), ('auth', 16)]:
            raw = value.get(name, '')
            if len(raw) > 150: raise ValueError('Clave de suscripción inválida.')
            try: decoded = base64.urlsafe_b64decode(raw + '=' * (-len(raw) % 4))
            except Exception: raise ValueError('Clave de suscripción inválida.') from None
            if len(decoded) != length: raise ValueError('Clave de suscripción inválida.')
        return {k: value[k] for k in ('p256dh', 'auth')}


@router.put('/webpush')
def registrar_web(body: RegistroWeb, db: Session = Depends(get_db), user=Depends(get_current_user)):
    row = db.get(NavegadorPush, body.endpoint)
    if not row:
        row = NavegadorPush(endpoint=body.endpoint); db.add(row)
    row.ci_usuario = user.ci; row.dispositivo = body.dispositivo
    row.suscripcion = json.dumps({'endpoint': body.endpoint, 'keys': body.keys})
    db.commit()
    return {'registrado': True, 'modo': 'webpush'}


@router.delete('/webpush/{dispositivo}')
def eliminar_web(dispositivo: str, db: Session = Depends(get_db), user=Depends(get_current_user)):
    db.query(NavegadorPush).filter_by(ci_usuario=user.ci, dispositivo=dispositivo).delete(); db.commit()
    return {'eliminado': True}


def enviar_web(db, ci, titulo, cuerpo):
    from logger import fernet
    from pywebpush import webpush, WebPushException
    devices = db.query(NavegadorPush).filter_by(ci_usuario=ci).all()
    if not devices: return 0
    key = base64.urlsafe_b64encode(fernet.decrypt(claves(db).privada_cifrada.encode())).decode().rstrip('=')
    count = 0
    for device in devices:
        try:
            webpush(json.loads(device.suscripcion), data=json.dumps({'titulo': titulo, 'cuerpo': cuerpo[:200]}),
                    vapid_private_key=key, vapid_claims={'sub': 'https://bmateo637coder.github.io'}, ttl=3600, timeout=10)
            count += 1
        except WebPushException as e:
            if e.response is not None and e.response.status_code in (404, 410): db.delete(device)
        except Exception:
            continue
    return count


class RegistroAndroid(BaseModel):
    dispositivo: str = Field(min_length=1, max_length=100)


@router.put('/avisos/dispositivo')
def registrar_android(body: RegistroAndroid, db: Session = Depends(get_db), user=Depends(get_current_user)):
    value = secrets.token_urlsafe(32)
    row = db.get(DispositivoAvisos, body.dispositivo)
    if not row: row = DispositivoAvisos(dispositivo=body.dispositivo); db.add(row)
    row.ci_usuario = user.ci; row.huella = hashlib.sha256(value.encode()).hexdigest()
    row.vence = datetime.utcnow() + timedelta(days=90)
    db.commit()
    return {'token': value, 'vence': row.vence, 'modo': 'consulta_periodica'}


@router.delete('/avisos/dispositivo/{dispositivo}')
def eliminar_android(dispositivo: str, db: Session = Depends(get_db), user=Depends(get_current_user)):
    db.query(DispositivoAvisos).filter_by(ci_usuario=user.ci, dispositivo=dispositivo).delete(); db.commit()
    return {'eliminado': True}


@router.get('/avisos')
def avisos(x_avisos_token: str = Header(default='', max_length=200), db: Session = Depends(get_db)):
    row = db.query(DispositivoAvisos).filter_by(huella=hashlib.sha256(x_avisos_token.encode()).hexdigest()).first()
    if not row or row.vence <= datetime.utcnow(): raise HTTPException(401, 'Avisos desactivados. Active nuevamente desde su cuenta.')
    items = db.query(Notificacion).filter_by(id_usuario=row.ci_usuario, leida=False).order_by(Notificacion.id.desc()).limit(100).all()
    return {'notificaciones': [notificacion_json(n) for n in items]}
