from database.database import Base, engine
from sqlalchemy.orm import Session
from database import models
from auth import get_password_hash

Base.metadata.create_all(bind=engine)

db = Session(bind=engine)

try:
    # Empresas
    tenants = [
        models.Tenant(id_tenant=1, nombre="Raíces Inmobiliaria", slug="raices", plan="pro", max_propiedades=50),
        models.Tenant(id_tenant=2, nombre="Horizonte Bienes Raíces", slug="horizonte", plan="basico", max_propiedades=10),
        models.Tenant(id_tenant=3, nombre="Cúspide Propiedades", slug="cuspide", plan="basico", max_propiedades=10),
    ]
    db.add_all(tenants)
    db.flush()

    # Roles
    roles = [
        models.Rol(id_rol=1, id_tenant=None, nombre="Super Administrador"),
        models.Rol(id_rol=2, id_tenant=None, nombre="Administrador de Empresa"),
        models.Rol(id_rol=3, id_tenant=1, nombre="Agente Raíces"),
        models.Rol(id_rol=4, id_tenant=1, nombre="Cliente Raíces"),
    ]
    db.add_all(roles)
    db.flush()

    # Permisos
    permisos = [
        (1, "UI:MENU_CATALOGO", "Ver menú de catálogo de propiedades", "UI_Menu"),
        (2, "UI:BTN_CREAR_PROP", "Botón para crear una nueva propiedad", "UI_Boton"),
        (3, "UI:BTN_ELIMINAR_PROP", "Botón para eliminar propiedad", "UI_Boton"),
        (4, "API:USUARIOS_CREAR", "Permiso para crear usuarios", "Endpoint"),
        (5, "UI:MENU_USUARIOS", "Ver menú de usuarios", "UI_Menu"),
        (6, "UI:MENU_ROLES", "Ver menú de roles", "UI_Menu"),
        (7, "UI:MENU_CLIENTES", "Ver menú de clientes", "UI_Menu"),
        (8, "UI:MENU_PROPIETARIOS", "Ver menú de propietarios", "UI_Menu"),
        (9, "UI:MENU_AGENTES", "Ver menú de agentes", "UI_Menu"),
        (10, "UI:MENU_PROPIEDADES", "Ver menú de propiedades", "UI_Menu"),
        (11, "UI:MENU_BITACORA", "Ver menú de bitacora segura", "UI_Menu"),
        (12, "UI:MENU_EMPRESAS", "Ver menú de empresas", "UI_Menu"),
    ]
    for pid, codigo, desc, tipo in permisos:
        db.add(models.Permiso(id_permiso=pid, codigo=codigo, descripcion=desc, tipo=tipo))
    db.flush()

    # Rol-Permiso (Super lo ve todo; Admin de empresa; Agile sees clientes/propietarios/agentes/propiedades)
    super_ids = [p[0] for p in permisos]
    admin_ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    agente_ids = [1, 2, 7, 8, 9, 10]
    for rol, ids in ((1, super_ids), (2, admin_ids), (3, agente_ids)):
        for pid in ids:
            db.add(models.RolPermiso(id_rol=rol, id_permiso=pid))
    db.flush()

    # Usuarios (con contraseñas de demo conocidas)
    usuarios_demo = [
        ("0000000", None, 1, "Super Admin", "super@saas.com", "70000000", "Super.123@"),
        ("1000001", 1, 2, "Admin Raices", "admin@raices.com", "77712345", "Admin.123@"),
        ("1000002", 1, 3, "Ana Agente", "agente@raices.com", "70000001", "Password.123@"),
        ("1000003", 1, 4, "Pablo Propietario", "propietario@raices.com", "70000002", "Password.123@"),
        ("1000004", 1, 4, "Carlos Cliente", "cliente@raices.com", "70000003", "Password.123@"),
        ("1000005", 1, 4, "Rosa Cliente", "rosa@raices.com", "70000004", "Password.123@"),
        ("1000006", 1, 4, "Juan Cliente", "juan@raices.com", "70000005", "Password.123@"),
    ]
    for ci, tid, rid, nombre, correo, tel, pwd in usuarios_demo:
        db.add(models.Usuario(
            ci=ci, id_tenant=tid, id_rol=rid, nombre=nombre,
            correo=correo, telefono=tel, password_hash=get_password_hash(pwd),
        ))
    db.flush()

    # Roles de módulo (propietario, agente, clientes)
    db.add(models.Propietario(id_propietario=1, ci_usuario="1000003", id_tenant=1))
    db.add(models.Agente(id_agente=1, ci_usuario="1000002", id_tenant=1))
    db.add(models.Cliente(id_cliente=1, ci_usuario="1000004", id_tenant=1))
    db.add(models.Cliente(id_cliente=2, ci_usuario="1000005", id_tenant=1))
    db.add(models.Cliente(id_cliente=3, ci_usuario="1000006", id_tenant=1))
    db.flush()

    # Propiedades de catálogo (Raíces)
    props = [
        models.Propiedad(
            id_propiedad=1, id_tenant=1, id_propietario=1, id_agente=1,
            titulo="Hermosa Casa en Equipetrol", direccion="Av. San Martin, 3er Anillo Interno",
            precio=250000.00, tipo_operacion="Venta", estado="Disponible",
            descripcion="Casa moderna de dos plantas con piscina.",
        ),
        models.Propiedad(
            id_propiedad=2, id_tenant=1, id_propietario=1, id_agente=1,
            titulo="Departamento de Lujo en Urubo", direccion="Condominio Urubo Golf",
            precio=1200.00, tipo_operacion="Alquiler", estado="Disponible",
            descripcion="Amplio departamento amoblado con vista al golf.",
        ),
        models.Propiedad(
            id_propiedad=3, id_tenant=1, id_propietario=1, id_agente=1,
            titulo="Local Comercial Centro", direccion="Calle 24 de Septiembre",
            precio=30000.00, tipo_operacion="Anticretico", estado="Disponible",
            descripcion="Local comercial en pleno centro.",
        ),
    ]
    db.add_all(props)
    db.flush()

    imgs = [
        (1, 1, "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800"),
        (2, 1, "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800"),
        (3, 2, "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800"),
        (4, 3, "https://images.unsplash.com/photo-1497366216548-37526070297c?w=800"),
    ]
    for iid, pid, url in imgs:
        db.add(models.Imagen(id_imagen=iid, id_propiedad=pid, url=url))
    db.flush()

    carac = [
        (1, 1, "Cuartos", "4"), (2, 1, "Baños", "3"), (3, 1, "Metros Cuadrados", "350"),
        (4, 2, "Cuartos", "2"), (5, 2, "Baños", "2"), (6, 2, "Metros Cuadrados", "120"), (7, 2, "Amoblado", "Sí"),
        (8, 3, "Cuartos", "1"), (9, 3, "Baños", "1"), (10, 3, "Metros Cuadrados", "50"),
    ]
    for cid, pid, nombre, valor in carac:
        db.add(models.Caracteristica(id_caracteristica=cid, id_propiedad=pid, nombre=nombre, valor=valor))
    db.flush()

    db.commit()

    from sqlalchemy import text
    for tabla, columna in [
        ("tenant", "id_tenant"), ("rol", "id_rol"), ("permiso", "id_permiso"),
        ("cliente", "id_cliente"), ("propietario", "id_propietario"),
        ("agente", "id_agente"), ("propiedad", "id_propiedad"),
        ("imagen", "id_imagen"), ("caracteristica", "id_caracteristica"),
    ]:
        db.execute(text(
            f"SELECT setval(pg_get_serial_sequence('{tabla}', '{columna}'), "
            f"COALESCE((SELECT MAX({columna}) FROM {tabla}), 1))"
        ))
    db.commit()

    print("Seed local OK: 3 tenants, 4 roles, 12 permisos, 7 usuarios, 3 clientes, 3 propiedades.")
except Exception as e:
    db.rollback()
    print(f"ERROR: {e}")
    raise
finally:
    db.close()