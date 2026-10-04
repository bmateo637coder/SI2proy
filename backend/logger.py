import json
from datetime import datetime
from cryptography.fernet import Fernet
import os

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
    
    with open(LOG_FILE_PATH, "a", encoding='utf-8') as file:
        file.write(registro_encriptado + "\n")

def leer_bitacora_segura(dev_key: str):
    """
    Lee el archivo encriptado, desencripta línea por línea y devuelve la lista de registros.
    """
    if dev_key != DEV_SECRET_KEY.decode('utf-8'):
        raise ValueError("Llave de desarrollador inválida")
        
    if not os.path.exists(LOG_FILE_PATH):
        return []
        
    registros = []
    with open(LOG_FILE_PATH, "r", encoding='utf-8') as file:
        lineas = file.readlines()
        for linea in lineas:
            linea = linea.strip()
            if linea:
                try:
                    registro_desencriptado = fernet.decrypt(linea.encode('utf-8')).decode('utf-8')
                    registros.append(json.loads(registro_desencriptado))
                except Exception as e:
                    # En caso de que una línea haya sido manipulada, la ignoramos o marcamos el error.
                    registros.append({"error": "Linea corrupta o manipulada externamente"})
                    
    return registros
