from database.database import SessionLocal
from database import models

db = SessionLocal()

permisos_data = [
    (1, 'UI:MENU_CATALOGO', 'Ver menú de catálogo de propiedades', 'UI_Menu'),
    (2, 'UI:BTN_CREAR_PROP', 'Botón para crear una nueva propiedad', 'UI_Boton'),
    (3, 'UI:BTN_ELIMINAR_PROP', 'Botón para eliminar propiedad', 'UI_Boton'),
    (4, 'API:USUARIOS_CREAR', 'Permiso para crear usuarios', 'Endpoint'),
    (5, 'UI:MENU_USUARIOS', 'Ver menú de usuarios', 'UI_Menu'),
    (6, 'UI:MENU_ROLES', 'Ver menú de roles', 'UI_Menu'),
    (7, 'UI:MENU_CLIENTES', 'Ver menú de clientes', 'UI_Menu'),
    (8, 'UI:MENU_PROPIETARIOS', 'Ver menú de propietarios', 'UI_Menu'),
    (9, 'UI:MENU_AGENTES', 'Ver menú de agentes', 'UI_Menu'),
    (10, 'UI:MENU_PROPIEDADES', 'Ver menú de propiedades', 'UI_Menu'),
    (11, 'UI:MENU_BITACORA', 'Ver menú de bitacora segura', 'UI_Menu'),
    (12, 'UI:MENU_EMPRESAS', 'Ver menú de empresas', 'UI_Menu')
]

for p in permisos_data:
    permiso = db.query(models.Permiso).filter_by(id_permiso=p[0]).first()
    if not permiso:
        db.add(models.Permiso(id_permiso=p[0], codigo=p[1], descripcion=p[2], tipo=p[3]))
db.commit()

# Asignar todos los permisos al rol 1 (Administrador / SuperAdmin)
rol_admin = db.query(models.Rol).filter_by(id_rol=1).first()
if rol_admin:
    permisos_db = db.query(models.Permiso).all()
    rol_admin.permisos = permisos_db
    db.commit()
    print("Permisos asignados al Administrador.")
else:
    print("No se encontró el rol 1.")

db.close()
