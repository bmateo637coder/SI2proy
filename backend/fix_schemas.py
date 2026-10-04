import re
with open('c:/Si2/SI2-Backend-main/schemas.py', 'r', encoding='utf-8') as f:
    c = f.read()

# Make sure datetime and date are imported
if 'from datetime import date' not in c:
    c = c.replace('from datetime import datetime', 'from datetime import datetime, date')

old_emp = """class EmpresaBase(BaseModel):
    nombre: str
    dominio: Optional[str] = None
    estado: Optional[str] = 'Activa'

class EmpresaCreate(EmpresaBase):
    pass

class EmpresaResponse(EmpresaBase):
    id_tenant: int
    fecha_registro: datetime"""

new_emp = """class EmpresaBase(BaseModel):
    nombre: str
    slug: str
    plan: str = "basico"
    max_propiedades: int = 10
    estado: Optional[bool] = True

class EmpresaCreate(EmpresaBase):
    pass

class EmpresaResponse(EmpresaBase):
    id_tenant: int
    fecha_registro: datetime
    fecha_vencimiento_pago: Optional[date] = None"""

if old_emp in c:
    c = c.replace(old_emp, new_emp)
    with open('c:/Si2/SI2-Backend-main/schemas.py', 'w', encoding='utf-8') as f:
         f.write(c)
    print("Fixed schemas")
else:
    print("Could not find old schema text")
