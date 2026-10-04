import sqlite3
import bcrypt

conn = sqlite3.connect('C:/Si2/SI2-Backend-main/database/inmobiliaria.db')
c = conn.cursor()

# Hashed password for admin123
pwd_hash = b'$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'

c.execute('''
INSERT INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
VALUES ('0000000', NULL, 'Super Admin SaaS', 'super@saas.com', '70000000', 1, ?)
''', (pwd_hash,))
conn.commit()
print("Super Admin created!")
conn.close()
