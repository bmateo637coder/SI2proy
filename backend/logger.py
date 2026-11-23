import json
from datetime import datetime
from cryptography.fernet import Fernet
import os
import hashlib
import uuid
from sqlalchemy import Column, Integer, String, Text
from sqlalchemy.orm import Session
from database.database import Base, engine


class RegistroAuditoria(Base):
    __tablename__ = 'auditoria_cifrada'
    id = Column(Integer, primary_key=True)
    identidad = Column(String(80), nullable=False, unique=True)
    contenido = Column(Text, nullable=False)

_fernet_key = os.getenv("BITACORA_FERNET_KEY")
if not _fernet_key:
    raise RuntimeError("BITACORA_FERNET_KEY debe estar configurada antes de iniciar la aplicación.")

DEV_SECRET_KEY = _fernet_key.encode("utf-8")
fernet = Fernet(DEV_SECRET_KEY)
LOG_FILE_PATH = os.path.join(os.path.dirname(__file__), "bitacora_segura.log")

def log_accion_segura(ip: str, usuario: str, accion: str):
    """
    Toma los datos, los convierte en un JSON, los encripta y los guarda en una nueva línea del archivo.
    """
    registro = {
        "ip": ip,
        "usuario": usuario,
        "accion": accion,
        "fecha_hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    registro_json = json.dumps(registro)
    registro_encriptado = fernet.encrypt(registro_json.encode('utf-8')).decode('utf-8')
    
    try:
        with Session(engine) as db:
            db.add(RegistroAuditoria(identidad=str(uuid.uuid4()), contenido=registro_encriptado))
            db.commit()
    except Exception:
        # Respaldo local si la base no está disponible; nunca perder el evento silenciosamente.
        with open(LOG_FILE_PATH, "a", encoding='utf-8') as file:
            file.write(registro_encriptado + "\n")

def leer_bitacora_segura(dev_key: str):
    """
    Lee el archivo encriptado, desencripta línea por línea y devuelve la lista de registros.
    """
    if dev_key != DEV_SECRET_KEY.decode('utf-8'):
        raise ValueError("Llave de desarrollador inválida")
        
    try:
        with Session(engine) as db:
            rows = db.query(RegistroAuditoria).order_by(RegistroAuditoria.id.desc()).limit(1000).all()
            encrypted = [r.contenido for r in rows]
    except Exception:
        encrypted = []
        
    registros = []
    if os.path.exists(LOG_FILE_PATH):
        with open(LOG_FILE_PATH, "r", encoding='utf-8') as file:
            encrypted += file.readlines()[-1000:]
    for linea in encrypted:
            linea = linea.strip()
            if linea:
                try:
                    registro_desencriptado = fernet.decrypt(linea.encode('utf-8')).decode('utf-8')
                    registros.append(json.loads(registro_desencriptado))
                except Exception as e:
                    # En caso de que una línea haya sido manipulada, la ignoramos o marcamos el error.
                    registros.append({"error": "Linea corrupta o manipulada externamente"})
                    
    errors = [r for r in registros if 'error' in r]
    return errors + sorted([r for r in registros if 'error' not in r], key=lambda r: r.get('fecha_hora', ''), reverse=True)[:1000]


def importar_bitacora(dev_key, registros):
    if dev_key != DEV_SECRET_KEY.decode('utf-8'):
        raise ValueError('Llave de desarrollador inválida')
    canonical = json.dumps(registros, ensure_ascii=False, sort_keys=True)
    batch = hashlib.sha256(canonical.encode()).hexdigest()
    added = 0
    with Session(engine) as db:
        for index, row in enumerate(registros):
            identity = batch + ':' + str(index)
            if db.query(RegistroAuditoria).filter_by(identidad=identity).first(): continue
            data = {**row, 'origen': 'Respaldo previo a migración'}
            db.add(RegistroAuditoria(identidad=identity, contenido=fernet.encrypt(json.dumps(data, ensure_ascii=False).encode()).decode()))
            added += 1
        db.commit()
    return added
