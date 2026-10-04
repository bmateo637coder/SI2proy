import re

with open('c:/Si2/SI2-Backend-main/database/models.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
content = content.replace(
    "from sqlalchemy import Column, Integer, String, ForeignKey, TIMESTAMP, Numeric, Date, Text",
    "from sqlalchemy import Column, Integer, String, ForeignKey, TIMESTAMP, Numeric, Date, Text, Boolean, UniqueConstraint"
)

# 2. Rename Empresa to Tenant and add fields
old_empresa = """class Empresa(Base):
    __tablename__ = "empresa"
    id_empresa = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(150), nullable=False)
    dominio = Column(String(100), unique=True)
    fecha_registro = Column(TIMESTAMP, server_default=func.current_timestamp())
    estado = Column(String(20), default='Activa')

    usuarios = relationship("Usuario", back_populates="empresa")
    propietarios = relationship("Propietario", back_populates="empresa")
    agentes = relationship("Agente", back_populates="empresa")
    clientes = relationship("Cliente", back_populates="empresa")
    propiedades = relationship("Propiedad", back_populates="empresa")
    visitas = relationship("Visita", back_populates="empresa")
    contratos = relationship("Contrato", back_populates="empresa")
    roles = relationship("Rol", back_populates="empresa")"""

new_tenant = """class Tenant(Base):
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
    roles = relationship("Rol", back_populates="tenant")"""
content = content.replace(old_empresa, new_tenant)

# 3. Replace all foreign keys to tenant and relationships
content = content.replace('id_empresa = Column(Integer, ForeignKey("empresa.id_empresa"', 'id_tenant = Column(Integer, ForeignKey("tenant.id_tenant"')
content = content.replace('id_empresa = Column(Integer', 'id_tenant = Column(Integer')
content = content.replace('empresa = relationship("Empresa"', 'tenant = relationship("Tenant"')
content = content.replace('back_populates="empresa"', 'back_populates="tenant"')
content = content.replace('ForeignKey("empresa.id_empresa"', 'ForeignKey("tenant.id_tenant"')

# 4. Update Usuario unique constraints
old_usuario = """class Usuario(Base):
    __tablename__ = "usuario"
    ci = Column(String(20), primary_key=True, index=True)
    id_tenant = Column(Integer, ForeignKey("tenant.id_tenant", onupdate="CASCADE", ondelete="CASCADE"), nullable=True)
    nombre = Column(String(100), nullable=False)
    correo = Column(String(100), unique=True, index=True, nullable=False)
    telefono = Column(String(20))
    id_rol = Column(Integer, ForeignKey("rol.id_rol"))
    password_hash = Column(String(255), nullable=False)
    
    tenant = relationship("Tenant", back_populates="usuarios")
    rol = relationship("Rol", back_populates="usuarios")
    bitacoras = relationship("Bitacora", back_populates="usuario")
    propietario = relationship("Propietario", back_populates="usuario", uselist=False)
    agente = relationship("Agente", back_populates="usuario", uselist=False)
    cliente = relationship("Cliente", back_populates="usuario", uselist=False)"""

new_usuario = """class Usuario(Base):
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
    )"""

content = content.replace(old_usuario, new_usuario)

with open('c:/Si2/SI2-Backend-main/database/models.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Refactor de models completado.")
