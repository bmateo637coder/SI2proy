import bcrypt
import os
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from database.database import get_db
from database.models import Usuario, Tenant


class ScopedUser:
    """Contexto de una petición; nunca modifica el usuario persistido ni su JWT."""
    def __init__(self, user, tenant_id):
        self._user = user
        self.id_tenant = tenant_id

    def __getattr__(self, name):
        return getattr(self._user, name)

# Configuración de Seguridad
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY debe estar configurada antes de iniciar la aplicación.")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db), request: Request = None):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        correo: str = payload.get("sub")
        if correo is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    query = db.query(Usuario).filter(Usuario.correo == correo)
    # El correo puede repetirse entre empresas: nunca resolverlo con first().
    if "id_tenant" not in payload:
        raise credentials_exception
    query = query.filter(Usuario.id_tenant == payload["id_tenant"])
    if payload.get("ci"):
        query = query.filter(Usuario.ci == payload["ci"])
    users = query.limit(2).all()
    user = users[0] if len(users) == 1 else None
    if user is None:
        raise credentials_exception
    if user.id_rol == 1 and user.id_tenant is not None:
        raise credentials_exception
    if request and request.headers.get("X-Tenant-ID"):
        try:
            tid = int(request.headers["X-Tenant-ID"])
        except ValueError:
            raise HTTPException(422, "Seleccione una inmobiliaria válida.")
        if user.id_rol != 1 and tid != user.id_tenant:
            raise HTTPException(403, "No puede acceder a otra inmobiliaria.")
        if not db.get(Tenant, tid):
            raise HTTPException(404, "Inmobiliaria no encontrada.")
        if user.id_rol == 1 and request.url.path != "/users/me":
            user = ScopedUser(user, tid)
    if request and user.id_rol != 1 and user.id_tenant and not request.url.path.startswith(("/api/saas/suscripcion", "/api/saas/planes", "/users/me")):
        if request.method in {"POST", "PUT", "PATCH", "DELETE"} or request.url.path.startswith("/api/ia"):
            from saas import require_active
            require_active(db, user.id_tenant)
    return user


def require_staff(user=Depends(get_current_user)):
    codes = {p.codigo for p in user.rol.permisos} if user.rol else set()
    if user.id_rol == 1 and not user.id_tenant:
        raise HTTPException(403, "Seleccione una inmobiliaria en la barra superior para continuar.")
    if not user.id_tenant or (user.id_rol not in (1, 2) and not user.agente and "API:OPERACIONES" not in codes):
        raise HTTPException(403, "Se requiere un administrador o agente de esta inmobiliaria.")
    return user


def require_admin(user=Depends(get_current_user)):
    if user.id_rol not in (1, 2):
        raise HTTPException(403, "Solo administradores.")
    return user
