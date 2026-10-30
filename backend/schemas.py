from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime, date

# Esquemas para Token
class Token(BaseModel):
    access_token: str
    token_type: str

from pydantic import BaseModel, EmailStr, Field, field_validator, AliasChoices
import re

# Esquemas para Usuario
class UsuarioBase(BaseModel):
    ci: str
    id_tenant: Optional[int] = None
    nombre: str
    correo: EmailStr
    telefono: Optional[str] = None
    id_rol: int

class UsuarioCreate(UsuarioBase):
    password: str = Field(..., min_length=4)

class UsuarioLogin(BaseModel):
    correo: EmailStr
    password: str
    id_tenant: Optional[int] = None

class UsuarioResponse(UsuarioBase):
    permisos: list[str] = [] # Se llenará dinámicamente con los códigos de permiso
    es_agente: bool = False

    class Config:
        from_attributes = True

# Esquemas para Rol
class RolBase(BaseModel):
    nombre: str
    id_tenant: Optional[int] = None

class RolCreate(RolBase):
    pass

class RolResponse(RolBase):
    id_rol: int
    permisos: list[int] = []

    class Config:
        from_attributes = True

# Esquemas para Permiso
class PermisoBase(BaseModel):
    codigo: str
    descripcion: Optional[str] = None
    tipo: str

class PermisoCreate(PermisoBase):
    pass

class PermisoResponse(PermisoBase):
    id_permiso: int

    class Config:
        from_attributes = True

# Esquemas para Empresa
class EmpresaBase(BaseModel):
    nombre: str
    slug: str = Field(validation_alias=AliasChoices('slug', 'dominio'), min_length=1, max_length=100, pattern=r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
    plan: str = "basico"
    max_propiedades: int = 10
    estado: Optional[bool] = True

class EmpresaCreate(EmpresaBase):
    pass

class EmpresaConAdminCreate(EmpresaBase):
    admin_ci: str
    admin_nombre: str
    admin_correo: EmailStr
    admin_telefono: Optional[str] = None

class EmpresaResponse(EmpresaBase):
    id_tenant: int
    fecha_registro: Optional[datetime] = None
    fecha_vencimiento_pago: Optional[date] = None

    class Config:
        from_attributes = True

# Esquemas para Catálogo de Propiedades

class ImagenResponse(BaseModel):
    id_imagen: int
    url: str

    class Config:
        from_attributes = True

class CaracteristicaResponse(BaseModel):
    nombre: str
    valor: str

    class Config:
        from_attributes = True

class PropiedadCatalogoResponse(BaseModel):
    id_propiedad: int
    id_tenant: int
    titulo: str
    descripcion: Optional[str] = None
    direccion: str
    precio: float
    tipo_operacion: str
    estado: str
    imagenes: list[ImagenResponse] = []
    caracteristicas: list[CaracteristicaResponse] = []

    class Config:
        from_attributes = True

# ============================================================
# SCHEMAS MÓDULO INMUEBLES (ADMIN)
# ============================================================

class PropiedadCreate(BaseModel):
    id_propietario: int
    id_agente: int
    titulo: str
    descripcion: Optional[str] = None
    direccion: str
    precio: float = Field(gt=0, le=9999999999.99)
    tipo_operacion: str  # 'Venta', 'Alquiler', 'Anticretico'
    imagenes: list[str] = []
    id_sucursal: Optional[int] = None

class PropiedadEstadoUpdate(BaseModel):
    estado: str  # 'Disponible', 'Reservada', 'Vendida', 'Alquilada'

class PropiedadAdminResponse(BaseModel):
    id_propiedad: int
    id_tenant: int
    id_propietario: int
    id_agente: int
    titulo: str
    descripcion: Optional[str] = None
    direccion: str
    precio: float
    tipo_operacion: str
    estado: str
    imagenes: list[ImagenResponse] = []
    caracteristicas: list[CaracteristicaResponse] = []

    class Config:
        from_attributes = True

class PropietarioCreate(BaseModel):
    ci_usuario: str

class PersonaUpdate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    correo: EmailStr
    telefono: Optional[str] = None

class PropietarioResponse(BaseModel):
    id_propietario: int
    ci_usuario: str
    id_tenant: int
    nombre: Optional[str] = None
    correo: Optional[str] = None
    telefono: Optional[str] = None

    class Config:
        from_attributes = True

class AgenteResponse(BaseModel):
    id_agente: int
    ci_usuario: str
    id_tenant: int
    nombre: Optional[str] = None
    correo: Optional[str] = None

    class Config:
        from_attributes = True

class ClienteCreate(BaseModel):
    ci_usuario: str

class ClienteResponse(BaseModel):
    id_cliente: int
    ci_usuario: str
    id_tenant: int
    nombre: Optional[str] = None
    correo: Optional[str] = None
    telefono: Optional[str] = None

    class Config:
        from_attributes = True

# ============================================================
# SCHEMAS MÓDULO REPORTES DINÁMICOS
# ============================================================
from typing import Any

class ReporteFiltro(BaseModel):
    columna: str
    operador: str # 'eq', 'gt', 'lt', 'gte', 'lte', 'like'
    valor: Any

class ReporteOrden(BaseModel):
    columna: str
    direccion: str # 'asc' o 'desc'

class ReporteRequest(BaseModel):
    entidad: str # 'usuarios', 'propiedades'
    columnas: list[str]
    filtros: list[ReporteFiltro] = []
    orden: Optional[ReporteOrden] = None

class ReporteGuardadoCreate(BaseModel):
    nombre: str
    configuracion: str # JSON string of ReporteRequest

class ReporteGuardadoResponse(BaseModel):
    id_reporte: int
    nombre: str
    configuracion: str
    fecha_creacion: datetime

    class Config:
        from_attributes = True

# ============================================================
# SCHEMAS MÓDULO CONTRATOS Y PAGOS (CU-18 / CU-19)
# ============================================================

class ContratoCreate(BaseModel):
    id_cliente: int
    id_propiedad: int
    tipo_contrato: str  # 'Venta', 'Alquiler', 'Anticretico'
    monto_total: float = Field(gt=0, le=9999999999.99)
    fecha_inicio: date
    fecha_fin: Optional[date] = None
    num_cuotas: Optional[int] = Field(default=None, ge=1, le=360)
    observacion: Optional[str] = None

class PagoCreate(BaseModel):
    monto: float = Field(gt=0, le=9999999999.99)
    metodo_pago: str  # 'Transferencia', 'Efectivo', 'QR'
    observacion: Optional[str] = None
