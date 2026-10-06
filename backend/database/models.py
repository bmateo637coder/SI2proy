from sqlalchemy import Column, Integer, String, ForeignKey, TIMESTAMP, Numeric, Date, Text, Boolean, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database.database import Base

class Tenant(Base):
    __tablename__ = "tenant"
    id_tenant = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(150), nullable=False)
    slug = Column(String(100), unique=True, nullable=False, index=True)
    plan = Column(String(50), nullable=False, default="basico")
    max_propiedades = Column(Integer, nullable=False, default=10)
    fecha_registro = Column(TIMESTAMP, server_default=func.current_timestamp())
    estado = Column(Boolean, default=True)
    fecha_vencimiento_pago = Column(Date, nullable=True)

    usuarios = relationship("Usuario", back_populates="tenant")
    propietarios = relationship("Propietario", back_populates="tenant")
    agentes = relationship("Agente", back_populates="tenant")
    clientes = relationship("Cliente", back_populates="tenant")
    propiedades = relationship("Propiedad", back_populates="tenant")
    visitas = relationship("Visita", back_populates="tenant")
    contratos = relationship("Contrato", back_populates="tenant")
    roles = relationship("Rol", back_populates="tenant")


class Rol(Base):
    __tablename__ = "rol"
    id_rol = Column(Integer, primary_key=True, index=True)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=True)
    nombre = Column(String(50), nullable=False)
    
    tenant = relationship("Tenant", back_populates="roles")
    usuarios = relationship("Usuario", back_populates="rol")
    permisos = relationship("Permiso", secondary="rol_permiso", back_populates="roles")

class Permiso(Base):
    __tablename__ = "permiso"
    id_permiso = Column(Integer, primary_key=True, index=True)
    codigo = Column(String(50), unique=True, nullable=False)
    descripcion = Column(String(255))
    tipo = Column(String(50), nullable=False)
    
    roles = relationship("Rol", secondary="rol_permiso", back_populates="permisos")

class RolPermiso(Base):
    __tablename__ = "rol_permiso"
    id_rol = Column(Integer, ForeignKey("rol.id_rol", ondelete="CASCADE"), primary_key=True)
    id_permiso = Column(Integer, ForeignKey("permiso.id_permiso", ondelete="CASCADE"), primary_key=True)

class Usuario(Base):
    __tablename__ = "usuario"
    ci = Column(String(20), primary_key=True, index=True)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=True)
    nombre = Column(String(100), nullable=False)
    correo = Column(String(100), index=True, nullable=False)
    telefono = Column(String(20))
    id_rol = Column(Integer, ForeignKey("rol.id_rol"))
    password_hash = Column(String(255), nullable=False)
    
    tenant = relationship("Tenant", back_populates="usuarios")
    rol = relationship("Rol", back_populates="usuarios")
    bitacoras = relationship("Bitacora", back_populates="usuario")
    propietario = relationship("Propietario", back_populates="usuario", uselist=False)
    agente = relationship("Agente", back_populates="usuario", uselist=False)
    cliente = relationship("Cliente", back_populates="usuario", uselist=False)

    __table_args__ = (
        UniqueConstraint("id_tenant", "correo", name="uq_usuario_tenant_correo"),
        UniqueConstraint("id_tenant", "ci", name="uq_usuario_tenant_ci"),
    )

class Bitacora(Base):
    __tablename__ = "bitacora"
    id_bitacora = Column(Integer, primary_key=True, index=True)
    ci_usuario = Column(String(20), ForeignKey("usuario.ci", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    accion = Column(String(255), nullable=False)
    fecha_hora = Column(TIMESTAMP, server_default=func.current_timestamp())
    
    usuario = relationship("Usuario", back_populates="bitacoras")

class Propietario(Base):
    __tablename__ = "propietario"
    id_propietario = Column(Integer, primary_key=True, index=True)
    ci_usuario = Column(String(20), ForeignKey("usuario.ci", onupdate="CASCADE", ondelete="CASCADE"), unique=True, nullable=False)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    
    tenant = relationship("Tenant", back_populates="propietarios")
    usuario = relationship("Usuario", back_populates="propietario")
    propiedades = relationship("Propiedad", back_populates="propietario")

class Agente(Base):
    __tablename__ = "agente"
    id_agente = Column(Integer, primary_key=True, index=True)
    ci_usuario = Column(String(20), ForeignKey("usuario.ci", onupdate="CASCADE", ondelete="CASCADE"), unique=True, nullable=False)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    
    tenant = relationship("Tenant", back_populates="agentes")
    usuario = relationship("Usuario", back_populates="agente")
    propiedades = relationship("Propiedad", back_populates="agente")
    visitas = relationship("Visita", back_populates="agente")
    contratos = relationship("Contrato", back_populates="agente")

class Cliente(Base):
    __tablename__ = "cliente"
    id_cliente = Column(Integer, primary_key=True, index=True)
    ci_usuario = Column(String(20), ForeignKey("usuario.ci", onupdate="CASCADE", ondelete="CASCADE"), unique=True, nullable=False)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    
    tenant = relationship("Tenant", back_populates="clientes")
    usuario = relationship("Usuario", back_populates="cliente")
    visitas = relationship("Visita", back_populates="cliente")
    contratos = relationship("Contrato", back_populates="cliente")

class Propiedad(Base):
    __tablename__ = "propiedad"
    id_propiedad = Column(Integer, primary_key=True, index=True)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    id_propietario = Column(Integer, ForeignKey("propietario.id_propietario", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    id_agente = Column(Integer, ForeignKey("agente.id_agente", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    titulo = Column(String(150), nullable=False)
    descripcion = Column(String(1000), nullable=True)
    direccion = Column(String(255), nullable=False)
    precio = Column(Numeric(12, 2), nullable=False)
    tipo_operacion = Column(String(20), nullable=False) # 'Venta', 'Alquiler', 'Anticretico'
    estado = Column(String(20), default='Disponible') # 'Disponible', 'Reservada', 'Vendida', 'Alquilada'
    
    tenant = relationship("Tenant", back_populates="propiedades")
    propietario = relationship("Propietario", back_populates="propiedades")
    agente = relationship("Agente", back_populates="propiedades")
    imagenes = relationship("Imagen", back_populates="propiedad")
    caracteristicas = relationship("Caracteristica", back_populates="propiedad")
    visitas = relationship("Visita", back_populates="propiedad")
    contratos = relationship("Contrato", back_populates="propiedad")

class Imagen(Base):
    __tablename__ = "imagen"
    id_imagen = Column(Integer, primary_key=True, index=True)
    id_propiedad = Column(Integer, ForeignKey("propiedad.id_propiedad", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    url = Column(String(255), nullable=False)
    
    propiedad = relationship("Propiedad", back_populates="imagenes")

class Caracteristica(Base):
    __tablename__ = "caracteristica"
    id_caracteristica = Column(Integer, primary_key=True, index=True)
    id_propiedad = Column(Integer, ForeignKey("propiedad.id_propiedad", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    nombre = Column(String(100), nullable=False)
    valor = Column(String(100), nullable=False)
    
    propiedad = relationship("Propiedad", back_populates="caracteristicas")

class Visita(Base):
    __tablename__ = "visita"
    id_visita = Column(Integer, primary_key=True, index=True)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    id_cliente = Column(Integer, ForeignKey("cliente.id_cliente", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    id_propiedad = Column(Integer, ForeignKey("propiedad.id_propiedad", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    id_agente = Column(Integer, ForeignKey("agente.id_agente", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    fecha_hora = Column(TIMESTAMP, nullable=False)
    comentario = Column(Text)
    estado = Column(String(20), default='Programada') # 'Programada', 'Realizada', 'Cancelada'
    
    tenant = relationship("Tenant", back_populates="visitas")
    cliente = relationship("Cliente", back_populates="visitas")
    propiedad = relationship("Propiedad", back_populates="visitas")
    agente = relationship("Agente", back_populates="visitas")

class Contrato(Base):
    __tablename__ = "contrato"
    id_contrato = Column(Integer, primary_key=True, index=True)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    id_cliente = Column(Integer, ForeignKey("cliente.id_cliente", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    id_propiedad = Column(Integer, ForeignKey("propiedad.id_propiedad", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    id_agente = Column(Integer, ForeignKey("agente.id_agente", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    tipo_contrato = Column(String(50), nullable=False) # 'Alquiler', 'Venta', 'Anticretico'
    monto_total = Column(Numeric(12, 2), nullable=False)
    fecha_inicio = Column(Date, nullable=False)
    fecha_fin = Column(Date)
    
    tenant = relationship("Tenant", back_populates="contratos")
    cliente = relationship("Cliente", back_populates="contratos")
    propiedad = relationship("Propiedad", back_populates="contratos")
    agente = relationship("Agente", back_populates="contratos")
    pagos = relationship("Pago", back_populates="contrato")
    cuotas = relationship("Cuota", back_populates="contrato", cascade="all, delete-orphan")

class Cuota(Base):
    __tablename__ = "cuota"
    id_cuota = Column(Integer, primary_key=True, index=True)
    id_contrato = Column(Integer, ForeignKey("contrato.id_contrato", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    numero_cuota = Column(Integer, nullable=False)
    monto = Column(Numeric(12, 2), nullable=False)
    fecha_vencimiento = Column(Date, nullable=False)
    estado = Column(String(20), default='Pendiente')  # 'Pendiente', 'Pagada', 'Vencida'
    fecha_pago = Column(TIMESTAMP)

    contrato = relationship("Contrato", back_populates="cuotas")

class Pago(Base):
    __tablename__ = "pago"
    id_pago = Column(Integer, primary_key=True, index=True)
    id_contrato = Column(Integer, ForeignKey("contrato.id_contrato", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    monto = Column(Numeric(12, 2), nullable=False)
    fecha_pago = Column(TIMESTAMP, server_default=func.current_timestamp())
    metodo_pago = Column(String(50), nullable=False) # 'Transferencia', 'Efectivo', 'QR'
    numero_recibo = Column(String(50))
    
    contrato = relationship("Contrato", back_populates="pagos")

class ReporteGuardado(Base):
    __tablename__ = "reporte_guardado"
    id_reporte = Column(Integer, primary_key=True, index=True)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    ci_usuario = Column(String(20), ForeignKey("usuario.ci", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    nombre = Column(String(150), nullable=False)
    configuracion = Column(Text, nullable=False) # Guardaremos un JSON con la estructura del reporte
    fecha_creacion = Column(TIMESTAMP, server_default=func.current_timestamp())

    tenant = relationship("Tenant")
    usuario = relationship("Usuario")
