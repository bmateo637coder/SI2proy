import sqlite3

conn = sqlite3.connect('C:/Si2/SI2-Backend-main/database/inmobiliaria.db')
c = conn.cursor()

# Bajar a admin@raices.com al rol 2 (Admin de Empresa)
c.execute("UPDATE usuario SET id_rol = 2 WHERE correo = 'admin@raices.com'")

# Asignar permisos al rol 2 (Admin de Empresa)
# Todo menos 'UI:MENU_EMPRESAS' (id=12)
permisos_empresa = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

# Asegurar que el rol 2 existe
c.execute("INSERT OR IGNORE INTO rol (id_rol, id_tenant, nombre) VALUES (2, NULL, 'Administrador de Empresa')")

# Limpiar permisos antiguos para rol 2 por si acaso
c.execute("DELETE FROM rol_permiso WHERE id_rol = 2")

for p_id in permisos_empresa:
    c.execute("INSERT INTO rol_permiso (id_rol, id_permiso) VALUES (2, ?)", (p_id,))

conn.commit()
print("Roles y permisos ajustados.")
conn.close()
