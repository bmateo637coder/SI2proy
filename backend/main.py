from fastapi import FastAPI, Depends, HTTPException, status, BackgroundTasks, WebSocket, WebSocketDisconnect, UploadFile, File
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import timedelta
import os

# Importaciones locales
from database.database import engine, get_db
from database import models
from auth import get_password_hash, verify_password, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES, get_current_user, SECRET_KEY, ALGORITHM, require_admin, require_staff
from auth import is_all_tenants, scope_query, label_tenants, require_reader
from jose import jwt, JWTError
import schemas
from logger import log_accion_segura, leer_bitacora_segura
from fastapi import Request
from ws_manager import manager


def get_default_admin_password() -> str:
    password = os.getenv("DEFAULT_ADMIN_PASSWORD")
    if not password:
        raise HTTPException(
            status_code=500,
            detail="DEFAULT_ADMIN_PASSWORD no está configurada en el servidor."
        )
    return password

import ia_router
import contratos_router
import scheduler
import saas
import offline
import reportes_generativos
import analitica_ml
import vista_global

from contextlib import asynccontextmanager


@asynccontextmanager
async def lifespan(_app: FastAPI):
    scheduler.iniciar_scheduler()
    yield


app = FastAPI(title="Raíces - Inmobiliaria API", version="2.0.0", lifespan=lifespan)

app.include_router(ia_router.router)
app.include_router(contratos_router.router)
app.include_router(saas.router)
app.include_router(offline.router)
app.include_router(reportes_generativos.router)
app.include_router(analitica_ml.router)
app.include_router(vista_global.router)
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# CORS setup for Angular frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:4200",
        "http://127.0.0.1:4173",
        "http://localhost:4173",
        "https://bmateo637coder.github.io",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    # Ignorar rutas estáticas o de salud
    if request.url.path in ["/api/health", "/docs", "/openapi.json"]:
        return await call_next(request)

    # Extraer IP
    ip = request.client.host if request.client else "Desconocida"

    # Extraer Usuario (Intentar leer del header Authorization sin requerir DB)
    usuario = "Anónimo"
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            usuario = payload.get("sub", "Anónimo")
        except JWTError:
            pass

    # Extraer Acción
    accion = f"{request.method} {request.url.path}"

    # Registrar de forma asíncrona pero sin bloquear si falla
    try:
        log_accion_segura(ip, usuario, accion)
    except Exception as e:
        print(f"Error guardando bitacora: {e}")

    response = await call_next(request)
    return response

@app.get("/")
def read_root():
    return {"message": "Bienvenido a la API de Inmobiliaria Raíces"}

@app.get("/api/health")
def health_check():
    return {"status": "ok", "version": app.version, "commit": os.getenv("RENDER_GIT_COMMIT", "local")[:12],
            "features": ["saas", "offline", "analitica", "tenant_scope_all"]}

# ==========================================
# ENDPOINTS DE AUTENTICACIÓN (SPRINT 0)
# ==========================================

@app.post("/register", response_model=schemas.UsuarioResponse, status_code=status.HTTP_201_CREATED)
@app.post("/gestion_usuarios/auth/register", response_model=schemas.UsuarioResponse, status_code=201)
def register_user(user: schemas.UsuarioCreate, db: Session = Depends(get_db)):
    saas.require_active(db, user.id_tenant)
    # Verificar si el usuario ya existe
    db_user = db.query(models.Usuario).filter((models.Usuario.correo == user.correo) | (models.Usuario.ci == user.ci)).first()
    if db_user:
        raise HTTPException(status_code=400, detail="El correo o CI ya está registrado")

    # Hashear contraseña y crear usuario
    hashed_password = get_password_hash(user.password)
    # Un registro público siempre crea un cliente, sin aceptar privilegios del cliente HTTP.
    role = db.query(models.Rol).filter_by(id_tenant=user.id_tenant, nombre="Cliente").first()
    if not role:
        role = models.Rol(id_tenant=user.id_tenant, nombre="Cliente")
        db.add(role)
        db.flush()
    new_user = models.Usuario(
        ci=user.ci,
        id_tenant=user.id_tenant,
        nombre=user.nombre,
        correo=user.correo,
        telefono=user.telefono,
        id_rol=role.id_rol,
        password_hash=hashed_password
    )
    db.add(new_user)
    db.flush()
    db.add(models.Cliente(ci_usuario=new_user.ci, id_tenant=new_user.id_tenant))
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/login", response_model=schemas.Token)
def login(user_credentials: schemas.UsuarioLogin, db: Session = Depends(get_db)):
    # Buscar usuario por correo
    query = db.query(models.Usuario).filter(models.Usuario.correo == user_credentials.correo)
    if user_credentials.id_tenant is not None:
        query = query.filter(models.Usuario.id_tenant == user_credentials.id_tenant)
    matches = query.limit(2).all()
    if len(matches) > 1:
        raise HTTPException(409, "Indique el ID de su inmobiliaria para iniciar sesión.")
    user = matches[0] if matches else None
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")

    # Verificar contraseña
    if not verify_password(user_credentials.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")

    # Generar Token JWT
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.correo, "ci": user.ci, "rol": user.id_rol, "id_tenant": user.id_tenant}, expires_delta=access_token_expires
    )

    return {"access_token": access_token, "token_type": "bearer"}

from pydantic import BaseModel, Field, EmailStr, field_validator
import re

class PasswordUpdate(BaseModel):
    nueva_password: str = Field(..., min_length=8)

    @field_validator('nueva_password')
    def validate_password(cls, v):
        if not re.match(r"^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$", v):
            raise ValueError('La contraseña no cumple con los requisitos de seguridad')
        return v

@app.get("/users/me", response_model=schemas.UsuarioResponse)
def get_user_profile(current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Obtiene el perfil del usuario autenticado, incluyendo sus permisos dinámicos."""
    permisos = []
    if current_user.rol:
        for p in current_user.rol.permisos:
            permisos.append(p.codigo)

    # Hacemos una copia para inyectar los permisos sin fallar el modelo de sqlalchemy
    user_dict = {
        "ci": current_user.ci,
        "id_tenant": current_user.id_tenant,
        "nombre": current_user.nombre,
        "correo": current_user.correo,
        "telefono": current_user.telefono,
        "id_rol": current_user.id_rol,
        "es_agente": bool(current_user.agente),
        "permisos": permisos
    }
    return user_dict

@app.put("/users/me/password")
def change_password(data: PasswordUpdate, current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """CU-04: Cambiar contraseña (Perfil)"""
    hashed_password = get_password_hash(data.nueva_password)
    current_user.password_hash = hashed_password
    db.commit()
    return {"message": "Contraseña actualizada exitosamente"}

class ForgotPasswordRequest(BaseModel):
    correo: EmailStr

@app.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """CU-03: Recuperar contraseña"""
    # No afirmar que se envió un correo: este despliegue no tiene proveedor de correo.
    return {"message": "Solicite al administrador de su inmobiliaria que restablezca su acceso. La recuperación automática por correo todavía no está habilitada.", "envio": False}

# ==========================================
# ENDPOINTS DE ROLES (CU-05)
# ==========================================

@app.get("/roles", response_model=list[schemas.RolResponse])
def get_roles(current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """CU-05: Obtener roles. Filtrados por empresa (SaaS) o todos si es SuperAdmin"""
    if current_user.id_rol == 1:
        roles_db = db.query(models.Rol).all()
    else:
        # Solo roles de su empresa o roles globales (id_tenant is null)
        roles_db = db.query(models.Rol).filter((models.Rol.id_tenant == current_user.id_tenant) | (models.Rol.id_tenant == None)).all()

    resultado = []
    for r in roles_db:
        resultado.append({
            "id_rol": r.id_rol,
            "nombre": r.nombre,
            "id_tenant": r.id_tenant,
            "permisos": [p.id_permiso for p in r.permisos]
        })
    return resultado

@app.post("/roles", response_model=schemas.RolResponse)
def create_rol(rol: schemas.RolCreate, current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """CU-05: Crear un nuevo rol para su propia empresa (o global si es SuperAdmin)"""
    if current_user.id_rol not in [1, 2]: # Solo SuperAdmin o Admin Empresa
        raise HTTPException(status_code=403, detail="Permiso denegado. Solo administradores.")

    db_rol = db.query(models.Rol).filter(models.Rol.nombre == rol.nombre).first()
    if db_rol:
        raise HTTPException(status_code=400, detail="Este rol ya existe")

    # Si es SuperAdmin puede crear rol global, de lo contrario se asigna a su empresa
    empresa_id = None if current_user.id_rol == 1 else current_user.id_tenant

    new_rol = models.Rol(nombre=rol.nombre, id_tenant=empresa_id)
    db.add(new_rol)
    db.commit()
    db.refresh(new_rol)
    return new_rol

# ==========================================
# ENDPOINTS DE BITACORA SEGURA (CU-06)
# ==========================================

@app.get("/admin/bitacora")
def get_bitacora_segura(dev_key: str, current_user: models.Usuario = Depends(get_current_user)):
    """Punto 3: Obtener la bitácora segura desencriptada. Solo SuperAdmin con la llave correcta."""
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Permiso denegado. Solo el Super Administrador puede ver la bitácora.")

    try:
        registros = leer_bitacora_segura(dev_key)
        return registros
    except ValueError:
        raise HTTPException(status_code=403, detail="Llave de desarrollador inválida")

# ==========================================
# ENDPOINTS DE PERMISOS (RBAC/CBAC)
# ==========================================

@app.get("/permisos", response_model=list[schemas.PermisoResponse])
def get_permisos(current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Obtener todos los componentes/permisos registrables del sistema"""
    return db.query(models.Permiso).all()

@app.post("/permisos", response_model=schemas.PermisoResponse)
def create_permiso(permiso: schemas.PermisoCreate, current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Registrar un nuevo componente protegible en el sistema (Solo Super Admin)"""
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Solo Super Admin puede crear permisos globales")

    db_permiso = db.query(models.Permiso).filter(models.Permiso.codigo == permiso.codigo).first()
    if db_permiso:
        raise HTTPException(status_code=400, detail="Código de permiso ya existe")

    new_permiso = models.Permiso(**permiso.model_dump())
    db.add(new_permiso)
    db.commit()
    db.refresh(new_permiso)
    return new_permiso

from typing import List

@app.put("/roles/{id_rol}/permisos")
def update_rol_permisos(id_rol: int, permisos_ids: List[int], current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Asigna/Revoca permisos a un rol específico"""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores")

    rol = db.query(models.Rol).filter(models.Rol.id_rol == id_rol).first()
    if not rol:
        raise HTTPException(status_code=404, detail="Rol no encontrado")

    # Validar que no está modificando un rol de otra empresa
    if current_user.id_rol != 1 and rol.id_tenant != current_user.id_tenant:
        raise HTTPException(status_code=403, detail="No puede modificar roles de otra empresa")

    # Limpiar y asignar nuevos permisos
    rol.permisos.clear()
    if permisos_ids:
        nuevos_permisos = db.query(models.Permiso).filter(models.Permiso.id_permiso.in_(permisos_ids)).all()
        rol.permisos.extend(nuevos_permisos)

    db.commit()
    return {"message": "Permisos actualizados exitosamente", "rol_id": id_rol}

# ==========================================
# ENDPOINTS DE EMPRESAS (SaaS)
# ==========================================

@app.post("/admin/empresas", response_model=schemas.EmpresaResponse)
def create_empresa(data: schemas.EmpresaConAdminCreate, current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Solo Super Admin")

    db_empresa = db.query(models.Tenant).filter(models.Tenant.nombre == data.nombre).first()
    if db_empresa:
        raise HTTPException(status_code=400, detail="La empresa ya existe")

    # Crear Empresa
    if db.query(models.Tenant).filter_by(slug=data.slug).first() or db.query(models.Usuario).filter_by(ci=data.admin_ci).first():
        raise HTTPException(409, "El identificador de empresa o CI del administrador ya existe.")
    new_empresa = models.Tenant(nombre=data.nombre, slug=data.slug, estado=data.estado, plan="basico")
    db.add(new_empresa)
    db.flush()
    from datetime import timedelta
    db.add(models.Suscripcion(id_tenant=new_empresa.id_tenant, codigo_plan="basico", inicio=saas.today(),
        vencimiento=saas.today() + timedelta(days=30), estado="activa"))
    db.add(models.Sucursal(id_tenant=new_empresa.id_tenant, nombre="Casa matriz", direccion=""))

    # Crear Admin de Empresa
    hashed_password = get_password_hash(get_default_admin_password())
    admin_user = models.Usuario(
        ci=data.admin_ci,
        id_tenant=new_empresa.id_tenant,
        nombre=data.admin_nombre,
        correo=data.admin_correo,
        telefono=data.admin_telefono,
        id_rol=2, # Admin de Empresa
        password_hash=hashed_password
    )
    db.add(admin_user)
    db.commit()

    return new_empresa

@app.get("/admin/empresas", response_model=list[schemas.EmpresaResponse])
def get_empresas(current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Solo Super Admin")
    return db.query(models.Tenant).all()

@app.put("/admin/empresas/{id_tenant}/reset-admin-password")
def reset_admin_password(id_tenant: int, current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Solo Super Admin")

    admin = db.query(models.Usuario).filter(models.Usuario.id_tenant == id_tenant, models.Usuario.id_rol == 2).first()
    if not admin:
        raise HTTPException(status_code=404, detail="Administrador de empresa no encontrado")

    admin.password_hash = get_password_hash(get_default_admin_password())
    db.commit()
    return {"message": "Contraseña restablecida exitosamente"}

# ==========================================
# ENDPOINTS DE GESTION DE USUARIOS
# ==========================================

@app.get("/gestion_usuarios/usuarios", response_model=list[schemas.UsuarioResponse])
def get_usuarios(current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.id_rol == 1:
        query = db.query(models.Usuario)
        usuarios = scope_query(query, current_user, models.Usuario.id_tenant).all() if is_all_tenants(current_user) or current_user.id_tenant else query.all()
    else:
        usuarios = db.query(models.Usuario).filter(models.Usuario.id_tenant == current_user.id_tenant).all()

    # Inject permissions dynamically
    for user in usuarios:
        user.permisos = [p.codigo for p in user.rol.permisos] if user.rol else []
    return label_tenants(db, usuarios)

@app.get("/gestion_usuarios/roles", response_model=list[schemas.RolResponse])
def get_roles_gestion(current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """ Alias de /roles para la UI de gestión de usuarios """
    return get_roles(current_user, db)

@app.post("/gestion_usuarios/usuarios", response_model=schemas.UsuarioResponse)
def create_usuario_gestion(user_data: schemas.UsuarioCreate, current_user: models.Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Permiso denegado")

    db_user = db.query(models.Usuario).filter((models.Usuario.correo == user_data.correo) | (models.Usuario.ci == user_data.ci)).first()
    if db_user:
        raise HTTPException(status_code=400, detail="El correo o CI ya está registrado")

    # Asignar id_tenant del admin actual (o el provisto si es superadmin)
    empresa_id = user_data.id_tenant if current_user.id_rol == 1 else current_user.id_tenant
    role = db.get(models.Rol, user_data.id_rol)
    if not role or role.id_tenant not in (None, empresa_id) or (current_user.id_rol != 1 and role.id_rol == 1):
        raise HTTPException(403, "Rol no autorizado para esta inmobiliaria.")

    hashed_password = get_password_hash(user_data.password)
    new_user = models.Usuario(
        ci=user_data.ci,
        id_tenant=empresa_id,
        nombre=user_data.nombre,
        correo=user_data.correo,
        telefono=user_data.telefono,
        id_rol=user_data.id_rol,
        password_hash=hashed_password
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user

# ==========================================
# ENDPOINTS DE PROPIEDADES (BÚSQUEDA / CATÁLOGO)
# ==========================================

from typing import Optional
from sqlalchemy import cast, Integer, Float, and_
from fastapi import Header

@app.get("/modulo_inmuebles/propiedades/catalogo", response_model=list[schemas.PropiedadCatalogoResponse])
def get_catalogo_propiedades(
    tipo_operacion: Optional[str] = None,
    precio_min: Optional[float] = None,
    precio_max: Optional[float] = None,
    cuartos: Optional[int] = None,
    banos: Optional[int] = None,
    salas: Optional[int] = None,
    metros_min: Optional[float] = None,
    metros_max: Optional[float] = None,
    zona: Optional[str] = None,
    amueblado: Optional[bool] = None,
    servicios_basicos: Optional[bool] = None,
    x_tenant_id: Optional[int] = Header(None, alias="X-Tenant-ID", description="ID de la Empresa/Agencia SaaS"),
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Obtiene el catálogo de propiedades con filtros avanzados.
    Soporta filtrado por atributos extendidos (EAV) y aislamiento Multi-tenant.
    """
    query = db.query(models.Propiedad).filter(models.Propiedad.estado == 'Disponible')
    if x_tenant_id is not None:
        saas.tenant_scope(current_user, x_tenant_id)
    tenant_id = x_tenant_id if current_user.id_rol == 1 else current_user.id_tenant
    query = scope_query(query, current_user, models.Propiedad.id_tenant)

    if tipo_operacion:
        query = query.filter(models.Propiedad.tipo_operacion == tipo_operacion)

    if precio_min is not None:
        query = query.filter(models.Propiedad.precio >= precio_min)

    if precio_max is not None:
        query = query.filter(models.Propiedad.precio <= precio_max)

    from sqlalchemy import case, func
    raw_value = func.replace(models.Caracteristica.valor, ',', '.')
    numeric_value = case((raw_value.regexp_match(r'^[0-9]+(\.[0-9]+)?$'), cast(raw_value, Float)), else_=None)

    if cuartos is not None:
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(func.lower(models.Caracteristica.nombre).in_(['cuartos', 'habitaciones', 'dormitorios']), numeric_value >= cuartos)
        ))

    if banos is not None:
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(models.Caracteristica.nombre == 'Baños', numeric_value >= banos)
        ))

    if salas is not None:
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(models.Caracteristica.nombre == 'Salas', numeric_value >= salas)
        ))

    if metros_min is not None:
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(func.lower(models.Caracteristica.nombre).in_(['metros cuadrados', 'superficie', 'm²', 'm2', 'area', 'metros_cuadrados']), numeric_value >= metros_min)
        ))

    if metros_max is not None:
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(func.lower(models.Caracteristica.nombre).in_(['metros cuadrados', 'superficie', 'm²', 'm2', 'area', 'metros_cuadrados']), numeric_value <= metros_max)
        ))

    if zona:
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(models.Caracteristica.nombre == 'Zona', models.Caracteristica.valor == zona)
        ))

    if amueblado is not None:
        valor_amueblado = 'Sí' if amueblado else 'No'
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(models.Caracteristica.nombre == 'Amueblado', models.Caracteristica.valor == valor_amueblado)
        ))

    if servicios_basicos is not None:
        valor_servicios = 'Sí' if servicios_basicos else 'No'
        query = query.filter(models.Propiedad.caracteristicas.any(
            and_(models.Caracteristica.nombre == 'Servicios Básicos', models.Caracteristica.valor == valor_servicios)
        ))

    propiedades = query.all()
    return label_tenants(db, propiedades)

# ==========================================
# ENDPOINTS DE BACKUP Y RESTORE
# ==========================================

import subprocess
import tempfile
import os
from fastapi import UploadFile, File as FastAPIFile
from fastapi.responses import Response

# Configuración de conexión (debe coincidir con database.py)
DB_NAME = os.getenv("POSTGRES_DB", "raices_db")
DB_USER = os.getenv("POSTGRES_USER", "postgres")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD")
DB_HOST = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT = os.getenv("POSTGRES_PORT", "5432")

# Ruta al directorio bin de PostgreSQL (ajustar si la versión cambia)
PG_BIN_PATH = os.getenv("PG_BIN_PATH", r"C:\Program Files\PostgreSQL\18\bin")


def get_postgres_password() -> str:
    if not DB_PASSWORD:
        raise HTTPException(
            status_code=500,
            detail="POSTGRES_PASSWORD no está configurada en el servidor."
        )
    return DB_PASSWORD

from backup_service import generar_backup_sql, uri_conexion, pg_bin_tool

@app.get("/admin/backup")
def descargar_backup(current_user: models.Usuario = Depends(get_current_user)):
    """Genera un backup de la base de datos PostgreSQL y lo devuelve como archivo .sql"""
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Solo Super Admin puede hacer backups")

    tmp_path = None
    try:
        tmp_path = generar_backup_sql()
        with open(tmp_path, "rb") as f:
            content = f.read()
        filename = os.path.basename(tmp_path)
        return Response(
            content=content,
            media_type="application/octet-stream",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'}
        )
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="pg_dump no encontrado. Verifique la instalación de PostgreSQL.")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)

@app.get("/admin/backup/estado")
def estado_backup(current_user: models.Usuario = Depends(get_current_user)):
    """Información del esquema de backup automático (procesos periódicos)."""
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Solo Super Admin puede consultar backups")
    from backup_service import listar_backups_dir
    return {
        "backup_automatico": True,
        "horario_utc": os.getenv("BACKUP_HORA_UTC", "02:00"),
        "publicacion_github": bool(os.getenv("BACKUP_GITHUB_REPO") and os.getenv("BACKUP_GITHUB_TOKEN")),
        "backups": listar_backups_dir(),
    }

@app.post("/admin/restore")
async def restaurar_backup(
    file: UploadFile = FastAPIFile(...),
    current_user: models.Usuario = Depends(get_current_user)
):
    """Restaura la base de datos desde un archivo .sql subido"""
    if current_user.id_rol != 1:
        raise HTTPException(status_code=403, detail="Solo Super Admin puede restaurar backups")

    if not file.filename.endswith(".sql"):
        raise HTTPException(status_code=400, detail="Solo se aceptan archivos .sql")

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".sql", prefix="restore_")
    try:
        content = await file.read()
        tmp.write(content)
        tmp.close()

        env = os.environ.copy()
        env["PGPASSWORD"] = get_postgres_password()

        psql_exe = pg_bin_tool("psql")
        result = subprocess.run(
            [psql_exe, uri_conexion(), "-f", tmp.name, "--no-password"],
            capture_output=True, text=True, env=env, timeout=120
        )

        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Error al restaurar: {result.stderr[:500]}")

        return {"mensaje": "Base de datos restaurada exitosamente"}
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Timeout al restaurar la base de datos")
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="psql no encontrado. Asegúrese de que PostgreSQL esté en el PATH del sistema.")
    finally:
        if os.path.exists(tmp.name):
            os.unlink(tmp.name)

# ==========================================
# ENDPOINTS ADMIN DE PROPIEDADES (CU-19)
# ==========================================

@app.get("/modulo_inmuebles/propiedades", response_model=list[schemas.PropiedadAdminResponse])
def get_propiedades_admin(
    id_tenant: Optional[int] = None,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Lista propiedades para administración. SuperAdmin puede filtrar por empresa; Admin de Empresa solo ve las suyas."""
    query = db.query(models.Propiedad)
    if current_user.id_rol == 1:
        # Super Admin: requiere seleccionar empresa
        if id_tenant or current_user.id_tenant:
            query = query.filter(models.Propiedad.id_tenant == (id_tenant or current_user.id_tenant))
        else:
            if not is_all_tenants(current_user):
                return []  # Requiere una selección explícita de empresa o de todas.
    else:
        query = query.filter(models.Propiedad.id_tenant == current_user.id_tenant)
    return label_tenants(db, query.all())

import uuid
import json

def validar_relaciones_propiedad(db, data, tenant_id):
    for model, key, ident in [(models.Propietario, "id_propietario", data.id_propietario),
                              (models.Agente, "id_agente", data.id_agente)]:
        if not db.query(model).filter(getattr(model, key) == ident, model.id_tenant == tenant_id).first():
            raise HTTPException(422, "El propietario y el agente deben pertenecer a esta inmobiliaria.")
    if data.tipo_operacion not in ("Venta", "Alquiler", "Anticretico"):
        raise HTTPException(422, "Tipo de operación inválido.")


def guardar_caracteristicas(db, propiedad, characteristics):
    if characteristics is None:
        return
    from reportes_generativos import normalized
    seen = set()
    for item in characteristics:
        name = normalized(item.nombre.strip())
        if not name or name in seen:
            raise HTTPException(422, "Las características deben tener nombres únicos.")
        seen.add(name)
        existing = next((c for c in propiedad.caracteristicas if normalized(c.nombre) == name), None)
        if existing:
            existing.valor = item.valor.strip()
        else:
            db.add(models.Caracteristica(id_propiedad=propiedad.id_propiedad, nombre=item.nombre.strip(), valor=item.valor.strip()))

@app.post("/upload")
async def upload_image(file: UploadFile = File(...), current_user=Depends(require_staff)):
    try:
        # Save file to uploads folder
        ext = file.filename.split('.')[-1]
        filename = f"{uuid.uuid4().hex}.{ext}"
        filepath = os.path.join("uploads", filename)
        with open(filepath, "wb") as f:
            f.write(await file.read())
        return {"url": f"/uploads/{filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/modulo_inmuebles/propiedades", response_model=schemas.PropiedadAdminResponse, status_code=201)
def create_propiedad(
    data: schemas.PropiedadCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Crea una nueva propiedad. Solo Admin de Empresa (rol 2) puede crear."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores pueden crear propiedades")

    # Determinar empresa
    empresa_id = current_user.id_tenant
    if empresa_id is None:
        raise HTTPException(status_code=400, detail="Super Admin debe operar a través del Admin de Empresa")
    validar_relaciones_propiedad(db, data, empresa_id)
    branch_id = data.id_sucursal
    if branch_id is None:
        branch = db.query(models.Sucursal).filter_by(id_tenant=empresa_id, activa=True).order_by(models.Sucursal.id_sucursal).first()
        branch_id = branch.id_sucursal if branch else None
    if branch_id is None:
        raise HTTPException(422, "Registre una sucursal activa antes de crear propiedades.")
    saas.branch_scope(db, current_user, branch_id)

    new_prop = models.Propiedad(
        id_tenant=empresa_id,
        id_propietario=data.id_propietario,
        id_agente=data.id_agente,
        titulo=data.titulo,
        descripcion=data.descripcion,
        direccion=data.direccion,
        precio=data.precio,
        tipo_operacion=data.tipo_operacion,
        estado="Disponible",
        id_sucursal=branch_id
    )
    db.add(new_prop)
    db.flush()
    guardar_caracteristicas(db, new_prop, data.caracteristicas)

    # Add images if provided
    if data.imagenes:
        for img_url in data.imagenes:
            img_url = img_url.strip()
            if img_url:
                new_img = models.Imagen(id_propiedad=new_prop.id_propiedad, url=img_url)
                db.add(new_img)
    db.commit()
    db.refresh(new_prop)
    return new_prop

@app.put("/modulo_inmuebles/propiedades/{id_propiedad}/estado")
def update_propiedad_estado(
    id_propiedad: int,
    data: schemas.PropiedadEstadoUpdate,
    background_tasks: BackgroundTasks,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Actualiza el estado de una propiedad."""
    propiedad = db.query(models.Propiedad).filter(models.Propiedad.id_propiedad == id_propiedad).with_for_update().first()
    if not propiedad:
        raise HTTPException(status_code=404, detail="Propiedad no encontrada")
    if current_user.id_rol not in [1, 2] and not current_user.agente:
        raise HTTPException(status_code=403, detail="Permiso denegado")
    saas.tenant_scope(current_user, propiedad.id_tenant)
    estados_validos = ["Disponible", "Reservada", "Vendida", "Alquilada"]
    if data.estado not in estados_validos:
        raise HTTPException(status_code=400, detail=f"Estado inválido. Use: {estados_validos}")
    propiedad.estado = data.estado
    propiedad.version += 1
    db.commit()
    db.refresh(propiedad)

    # Broadcast to all websocket clients
    background_tasks.add_task(
        manager.broadcast,
        {"event": "estado_updated", "id_propiedad": id_propiedad, "nuevo_estado": data.estado, "id_tenant": propiedad.id_tenant}
    )

    return {"message": "Estado actualizado", "estado": data.estado}

# ==========================================
# WEBSOCKETS (Tiempo Real)
# ==========================================

@app.websocket("/ws/propiedades")
async def websocket_endpoint(websocket: WebSocket, id_tenant: Optional[int] = None, scope: Optional[str] = None):
    from database.database import SessionLocal
    protocols = [p.strip() for p in websocket.headers.get("sec-websocket-protocol", "").split(",")]
    try:
        if len(protocols) != 2 or protocols[0] != "raices":
            raise ValueError("Missing credentials")
        with SessionLocal() as db:
            user = get_current_user(protocols[1], db)
            if scope is not None and (scope != 'all' or user.id_rol != 1 or id_tenant is not None):
                raise ValueError('Invalid scope')
            if id_tenant is not None:
                saas.tenant_scope(user, id_tenant)
                if not db.get(models.Tenant, id_tenant):
                    raise ValueError('Missing tenant')
            tenant_id = id_tenant if id_tenant is not None else user.id_tenant
            if not tenant_id and scope != 'all':
                raise ValueError("Missing tenant")
    except Exception:
        await websocket.close(code=1008)
        return
    await manager.connect(websocket, tenant_id)
    try:
        while True:
            data = await websocket.receive_text()
            # Echo if needed, otherwise ignore
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@app.put("/modulo_inmuebles/propiedades/{id_propiedad}", response_model=schemas.PropiedadAdminResponse)
def update_propiedad(
    id_propiedad: int,
    data: schemas.PropiedadCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Modifica los datos de una propiedad."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores pueden modificar propiedades")
    propiedad = db.query(models.Propiedad).filter(models.Propiedad.id_propiedad == id_propiedad).with_for_update().first()
    if not propiedad:
        raise HTTPException(status_code=404, detail="Propiedad no encontrada")
    if current_user.id_rol != 1 and propiedad.id_tenant != current_user.id_tenant:
        raise HTTPException(status_code=403, detail="No puede modificar propiedades de otra empresa")
    validar_relaciones_propiedad(db, data, propiedad.id_tenant)
    if data.id_sucursal is not None:
        saas.branch_scope(db, current_user, data.id_sucursal)
        propiedad.id_sucursal = data.id_sucursal
    propiedad.version += 1
    propiedad.id_propietario = data.id_propietario
    propiedad.id_agente = data.id_agente
    propiedad.titulo = data.titulo
    if data.descripcion is not None:
        propiedad.descripcion = data.descripcion
    propiedad.direccion = data.direccion
    propiedad.precio = data.precio
    propiedad.tipo_operacion = data.tipo_operacion
    guardar_caracteristicas(db, propiedad, data.caracteristicas)
    if "imagenes" in data.model_fields_set:
        db.query(models.Imagen).filter_by(id_propiedad=propiedad.id_propiedad).delete()
        for url in data.imagenes:
            if url.strip():
                db.add(models.Imagen(id_propiedad=propiedad.id_propiedad, url=url.strip()))
    db.commit()
    db.refresh(propiedad)
    return propiedad

@app.delete("/modulo_inmuebles/propiedades/{id_propiedad}")
def delete_propiedad(
    id_propiedad: int,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Elimina una propiedad."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores pueden eliminar propiedades")
    propiedad = db.query(models.Propiedad).filter(models.Propiedad.id_propiedad == id_propiedad).with_for_update().first()
    if not propiedad:
        raise HTTPException(status_code=404, detail="Propiedad no encontrada")
    if current_user.id_rol != 1 and propiedad.id_tenant != current_user.id_tenant:
        raise HTTPException(status_code=403, detail="No puede eliminar propiedades de otra empresa")
    db.delete(propiedad)
    db.commit()
    return {"message": "Propiedad eliminada"}

# ==========================================
# ENDPOINTS ADMIN DE PROPIETARIOS
# ==========================================

@app.get("/modulo_inmuebles/propietarios", response_model=list[schemas.PropietarioResponse])
def get_propietarios(
    id_tenant: Optional[int] = None,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Lista propietarios de la empresa del usuario autenticado (o filtrado por empresa para SuperAdmin)."""
    query = db.query(models.Propietario)
    if current_user.id_rol == 1:
        if id_tenant or current_user.id_tenant:
            query = query.filter(models.Propietario.id_tenant == (id_tenant or current_user.id_tenant))
    else:
        query = query.filter(models.Propietario.id_tenant == current_user.id_tenant)
    propietarios_db = query.all()
    resultado = []
    for p in propietarios_db:
        resultado.append({
            "id_propietario": p.id_propietario,
            "ci_usuario": p.ci_usuario,
            "id_tenant": p.id_tenant,
            "nombre": p.usuario.nombre if p.usuario else None,
            "correo": p.usuario.correo if p.usuario else None,
            "telefono": p.usuario.telefono if p.usuario else None,
        })
    return label_tenants(db, resultado)

@app.post("/modulo_inmuebles/propietarios", response_model=schemas.PropietarioResponse, status_code=201)
def create_propietario(
    data: schemas.PropietarioCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Asigna rol de propietario a un usuario existente en la empresa."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores pueden registrar propietarios")
    usuario = db.query(models.Usuario).filter(models.Usuario.ci == data.ci_usuario).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado con ese CI")
    saas.tenant_scope(current_user, usuario.id_tenant)
    empresa_id = current_user.id_tenant if current_user.id_rol != 1 else usuario.id_tenant
    if not empresa_id:
        raise HTTPException(status_code=400, detail="El usuario no tiene empresa asignada")
    # Verificar que no sea ya propietario
    existente = db.query(models.Propietario).filter(models.Propietario.ci_usuario == data.ci_usuario).first()
    if existente:
        raise HTTPException(status_code=400, detail="Este usuario ya es propietario")
    new_prop = models.Propietario(ci_usuario=data.ci_usuario, id_tenant=empresa_id)
    db.add(new_prop)
    db.commit()
    db.refresh(new_prop)
    return {
        "id_propietario": new_prop.id_propietario,
        "ci_usuario": new_prop.ci_usuario,
        "id_tenant": new_prop.id_tenant,
        "nombre": usuario.nombre,
        "correo": usuario.correo,
        "telefono": usuario.telefono,
    }

@app.put("/modulo_inmuebles/propietarios/{id_propietario}", response_model=schemas.PropietarioResponse)
def update_propietario(
    id_propietario: int,
    data: schemas.PropietarioCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Modifica el CI de usuario asociado a un propietario. Solo Admin de Empresa."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores pueden modificar propietarios")
    propietario = db.query(models.Propietario).filter(models.Propietario.id_propietario == id_propietario).first()
    if not propietario:
        raise HTTPException(status_code=404, detail="Propietario no encontrado")
    if current_user.id_rol != 1 and propietario.id_tenant != current_user.id_tenant:
        raise HTTPException(status_code=403, detail="No puede modificar propietarios de otra empresa")
    # Verificar que el nuevo CI existe
    nuevo_usuario = db.query(models.Usuario).filter(models.Usuario.ci == data.ci_usuario).first()
    if not nuevo_usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado con ese CI")
    if nuevo_usuario.id_tenant != propietario.id_tenant:
        raise HTTPException(403, "El usuario pertenece a otra inmobiliaria.")
    # Verificar que el nuevo CI no sea ya propietario (excepto el mismo)
    existente = db.query(models.Propietario).filter(
        models.Propietario.ci_usuario == data.ci_usuario,
        models.Propietario.id_propietario != id_propietario
    ).first()
    if existente:
        raise HTTPException(status_code=400, detail="Este usuario ya es propietario")
    propietario.ci_usuario = data.ci_usuario
    db.commit()
    db.refresh(propietario)
    return {
        "id_propietario": propietario.id_propietario,
        "ci_usuario": propietario.ci_usuario,
        "id_tenant": propietario.id_tenant,
        "nombre": nuevo_usuario.nombre,
        "correo": nuevo_usuario.correo,
        "telefono": nuevo_usuario.telefono,
    }

@app.delete("/modulo_inmuebles/propietarios/{id_propietario}")
def delete_propietario(
    id_propietario: int,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Elimina un propietario (no elimina el usuario base)."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores")
    propietario = db.query(models.Propietario).filter(models.Propietario.id_propietario == id_propietario).first()
    if not propietario:
        raise HTTPException(status_code=404, detail="Propietario no encontrado")
    if current_user.id_rol != 1 and propietario.id_tenant != current_user.id_tenant:
        raise HTTPException(status_code=403, detail="No puede eliminar propietarios de otra empresa")
    db.delete(propietario)
    db.commit()
    return {"message": "Propietario eliminado"}

# ==========================================
# ENDPOINTS ADMIN DE CLIENTES (CU-06)
# ==========================================

@app.get("/modulo_inmuebles/clientes", response_model=list[schemas.ClienteResponse])
def get_clientes(
    id_tenant: Optional[int] = None,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Lista clientes de la empresa del usuario autenticado (o filtrado por empresa para SuperAdmin)."""
    query = db.query(models.Cliente)
    if current_user.id_rol == 1:
        if id_tenant or current_user.id_tenant:
            query = query.filter(models.Cliente.id_tenant == (id_tenant or current_user.id_tenant))
    else:
        query = query.filter(models.Cliente.id_tenant == current_user.id_tenant)
    clientes_db = query.all()
    resultado = []
    for c in clientes_db:
        resultado.append({
            "id_cliente": c.id_cliente,
            "ci_usuario": c.ci_usuario,
            "id_tenant": c.id_tenant,
            "nombre": c.usuario.nombre if c.usuario else None,
            "correo": c.usuario.correo if c.usuario else None,
            "telefono": c.usuario.telefono if c.usuario else None,
        })
    return label_tenants(db, resultado)

@app.post("/modulo_inmuebles/clientes", response_model=schemas.ClienteResponse, status_code=201)
def create_cliente(
    data: schemas.ClienteCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Asigna rol de cliente a un usuario existente en la empresa."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores pueden registrar clientes")
    usuario = db.query(models.Usuario).filter(models.Usuario.ci == data.ci_usuario).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado con ese CI")
    saas.tenant_scope(current_user, usuario.id_tenant)
    empresa_id = current_user.id_tenant if current_user.id_rol != 1 else usuario.id_tenant
    if not empresa_id:
        raise HTTPException(status_code=400, detail="El usuario no tiene empresa asignada")
    # Verificar que no sea ya cliente
    existente = db.query(models.Cliente).filter(models.Cliente.ci_usuario == data.ci_usuario).first()
    if existente:
        raise HTTPException(status_code=400, detail="Este usuario ya es cliente")
    new_cliente = models.Cliente(ci_usuario=data.ci_usuario, id_tenant=empresa_id)
    db.add(new_cliente)
    db.commit()
    db.refresh(new_cliente)
    return {
        "id_cliente": new_cliente.id_cliente,
        "ci_usuario": new_cliente.ci_usuario,
        "id_tenant": new_cliente.id_tenant,
        "nombre": usuario.nombre,
        "correo": usuario.correo,
        "telefono": usuario.telefono,
    }

@app.put("/modulo_inmuebles/clientes/{id_cliente}", response_model=schemas.ClienteResponse)
def update_cliente(
    id_cliente: int,
    data: schemas.ClienteCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Modifica el CI de usuario asociado a un cliente. Solo Admin de Empresa."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores pueden modificar clientes")
    cliente = db.query(models.Cliente).filter(models.Cliente.id_cliente == id_cliente).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    if current_user.id_rol != 1 and cliente.id_tenant != current_user.id_tenant:
        raise HTTPException(status_code=403, detail="No puede modificar clientes de otra empresa")
    # Verificar que el nuevo CI existe
    nuevo_usuario = db.query(models.Usuario).filter(models.Usuario.ci == data.ci_usuario).first()
    if not nuevo_usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado con ese CI")
    if nuevo_usuario.id_tenant != cliente.id_tenant:
        raise HTTPException(403, "El usuario pertenece a otra inmobiliaria.")
    # Verificar que el nuevo CI no sea ya cliente (excepto el mismo)
    existente = db.query(models.Cliente).filter(
        models.Cliente.ci_usuario == data.ci_usuario,
        models.Cliente.id_cliente != id_cliente
    ).first()
    if existente:
        raise HTTPException(status_code=400, detail="Este usuario ya es cliente")
    cliente.ci_usuario = data.ci_usuario
    db.commit()
    db.refresh(cliente)
    return {
        "id_cliente": cliente.id_cliente,
        "ci_usuario": cliente.ci_usuario,
        "id_tenant": cliente.id_tenant,
        "nombre": nuevo_usuario.nombre,
        "correo": nuevo_usuario.correo,
        "telefono": nuevo_usuario.telefono,
    }

@app.delete("/modulo_inmuebles/clientes/{id_cliente}")
def delete_cliente(
    id_cliente: int,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Elimina un cliente (no elimina el usuario base)."""
    if current_user.id_rol not in [1, 2]:
        raise HTTPException(status_code=403, detail="Solo administradores")
    cliente = db.query(models.Cliente).filter(models.Cliente.id_cliente == id_cliente).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    if current_user.id_rol != 1 and cliente.id_tenant != current_user.id_tenant:
        raise HTTPException(status_code=403, detail="No puede eliminar clientes de otra empresa")
    db.delete(cliente)
    db.commit()
    return {"message": "Cliente eliminado"}

# ==========================================
# ENDPOINTS ADMIN DE AGENTES
# ==========================================

@app.post("/modulo_inmuebles/agentes", response_model=schemas.AgenteResponse, status_code=201)
def create_agente(data: schemas.ClienteCreate, db: Session = Depends(get_db), user=Depends(require_admin)):
    if not user.id_tenant:
        raise HTTPException(422, "Seleccione una inmobiliaria para registrar un agente.")
    saas.require_active(db, user.id_tenant)
    target = db.query(models.Usuario).filter_by(ci=data.ci_usuario, id_tenant=user.id_tenant).first()
    if not target:
        raise HTTPException(404, "El usuario no pertenece a la inmobiliaria seleccionada.")
    if db.query(models.Agente).filter_by(ci_usuario=target.ci).first():
        raise HTTPException(409, "El usuario ya está registrado como agente.")
    agent = models.Agente(ci_usuario=target.ci, id_tenant=user.id_tenant)
    db.add(agent)
    branch = db.query(models.Sucursal).filter_by(id_tenant=user.id_tenant, activa=True).order_by(models.Sucursal.id_sucursal).first()
    if branch and not db.get(models.UsuarioSucursal, (target.ci, branch.id_sucursal)):
        db.add(models.UsuarioSucursal(ci_usuario=target.ci, id_sucursal=branch.id_sucursal))
    db.commit()
    return {"id_agente": agent.id_agente, "id_tenant": agent.id_tenant, "ci_usuario": target.ci,
            "nombre": target.nombre, "correo": target.correo}


@app.delete("/modulo_inmuebles/agentes/{id_agente}")
def delete_agente(id_agente: int, db: Session = Depends(get_db), user=Depends(require_admin)):
    agent = db.query(models.Agente).filter_by(id_agente=id_agente, id_tenant=user.id_tenant).with_for_update().first()
    if not agent:
        raise HTTPException(404, "Agente no encontrado en la inmobiliaria seleccionada.")
    for model in (models.Propiedad, models.Contrato, models.Visita):
        if db.query(model).filter_by(id_agente=id_agente).first():
            raise HTTPException(409, "El agente tiene propiedades, contratos o visitas asociados. Conserve su historial o reasigne sus propiedades.")
    db.delete(agent)
    db.commit()
    return {"message": "Agente eliminado. La cuenta del usuario se conserva."}


@app.get("/modulo_inmuebles/agentes", response_model=list[schemas.AgenteResponse])
def get_agentes(
    id_tenant: Optional[int] = None,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Lista agentes de la empresa del usuario autenticado."""
    query = db.query(models.Agente)
    if current_user.id_rol == 1:
        if id_tenant or current_user.id_tenant:
            query = query.filter(models.Agente.id_tenant == (id_tenant or current_user.id_tenant))
    else:
        query = query.filter(models.Agente.id_tenant == current_user.id_tenant)
    agentes_db = query.all()
    resultado = []
    for a in agentes_db:
        resultado.append({
            "id_agente": a.id_agente,
            "ci_usuario": a.ci_usuario,
            "id_tenant": a.id_tenant,
            "nombre": a.usuario.nombre if a.usuario else None,
            "correo": a.usuario.correo if a.usuario else None,
        })
    return label_tenants(db, resultado)

# Alias para compatibilidad con frontend
@app.get("/modulo_inmuebles/propietarios_list", response_model=list[schemas.PropietarioResponse])
def get_propietarios_list(
    id_tenant: Optional[int] = None,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return get_propietarios(id_tenant, current_user, db)

# ==========================================
# ENDPOINTS REPORTES DINÁMICOS (PUNTO 5)
# ==========================================
from sqlalchemy import desc, asc

@app.post("/reportes/generar")
def generar_reporte_dinamico(
    request: schemas.ReporteRequest,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    require_reader(current_user)
    from reportes_dinamicos import execute_report
    return execute_report(db, current_user, request)

@app.post("/reportes/guardados", response_model=schemas.ReporteGuardadoResponse)
def guardar_reporte(
    data: schemas.ReporteGuardadoCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Guarda la configuración de un reporte para el usuario actual."""
    require_staff(current_user)
    from reportes_dinamicos import validate_config
    from pydantic import ValidationError
    try:
        config = json.loads(data.configuracion)
        spec = schemas.ReporteRequest.model_validate({
            **config, "orden": config.get("orden") or ({
                "columna": config["ordenColumna"], "direccion": config.get("ordenDireccion", "asc")
            } if config.get("ordenColumna") else None)
        })
        validate_config(spec)
    except (ValueError, TypeError, KeyError, ValidationError):
        raise HTTPException(422, "Configuración de reporte inválida.")
    empresa_id = current_user.id_tenant

    nuevo_reporte = models.ReporteGuardado(
        id_tenant=empresa_id,
        ci_usuario=current_user.ci,
        nombre=data.nombre,
        configuracion=data.configuracion
    )
    db.add(nuevo_reporte)
    db.commit()
    db.refresh(nuevo_reporte)
    return nuevo_reporte

@app.get("/reportes/guardados", response_model=list[schemas.ReporteGuardadoResponse])
def get_reportes_guardados(
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Obtiene los reportes guardados por el usuario."""
    require_reader(current_user)
    query = db.query(models.ReporteGuardado).filter_by(ci_usuario=current_user.ci)
    return scope_query(query, current_user, models.ReporteGuardado.id_tenant).order_by(models.ReporteGuardado.id_reporte.desc()).all()
