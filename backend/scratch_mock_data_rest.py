import sqlite3

conn = sqlite3.connect('C:/Si2/SI2-Backend-main/database/inmobiliaria.db')
cursor = conn.cursor()

try:
    cursor.executescript("""
    -- USUARIOS Empresa 2 (Horizonte)
    INSERT OR IGNORE INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
    VALUES 
    ('2000001', 2, 'Admin Horizonte', 'admin@horizonte.com', '77720001', 2, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('2000002', 2, 'Luis Agente', 'agente@horizonte.com', '70000011', 2, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('2000003', 2, 'Maria Propietario', 'propietario@horizonte.com', '70000012', 3, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('2000004', 2, 'Jose Cliente', 'cliente@horizonte.com', '70000013', 4, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG');

    -- USUARIOS Empresa 3 (Cuspide)
    INSERT OR IGNORE INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
    VALUES 
    ('3000001', 3, 'Admin Cuspide', 'admin@cuspide.com', '77730001', 2, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('3000002', 3, 'Marta Agente', 'agente@cuspide.com', '70000021', 2, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('3000003', 3, 'Jorge Propietario', 'propietario@cuspide.com', '70000022', 3, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('3000004', 3, 'Sofia Cliente', 'cliente@cuspide.com', '70000023', 4, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG');

    -- PROPIETARIOS, AGENTES, CLIENTES (Empresa 2)
    INSERT OR IGNORE INTO propietario (id_propietario, ci_usuario, id_tenant) VALUES (2, '2000003', 2);
    INSERT OR IGNORE INTO agente (id_agente, ci_usuario, id_tenant) VALUES (2, '2000002', 2);
    INSERT OR IGNORE INTO cliente (id_cliente, ci_usuario, id_tenant) VALUES (2, '2000004', 2);

    -- PROPIETARIOS, AGENTES, CLIENTES (Empresa 3)
    INSERT OR IGNORE INTO propietario (id_propietario, ci_usuario, id_tenant) VALUES (3, '3000003', 3);
    INSERT OR IGNORE INTO agente (id_agente, ci_usuario, id_tenant) VALUES (3, '3000002', 3);
    INSERT OR IGNORE INTO cliente (id_cliente, ci_usuario, id_tenant) VALUES (3, '3000004', 3);

    -- PROPIEDADES EMPRESA 2
    INSERT OR IGNORE INTO propiedad (id_propiedad, id_tenant, id_propietario, id_agente, titulo, direccion, precio, tipo_operacion, estado) VALUES 
    (7, 2, 2, 2, 'Casa Quinta en La Guardia', 'Km 20 Carretera Antigua', 180000.00, 'Venta', 'Disponible'),
    (8, 2, 2, 2, 'Monoambiente en Sirari', 'Calle Las Begonias', 400.00, 'Alquiler', 'Reservada'),
    (9, 2, 2, 2, 'Oficina Equipetrol Norte', 'Av. Canal Isuto', 800.00, 'Alquiler', 'Disponible'),
    (10, 2, 2, 2, 'Lote Industrial', 'Parque Industrial', 350000.00, 'Venta', 'Disponible');

    -- PROPIEDADES EMPRESA 3
    INSERT OR IGNORE INTO propiedad (id_propiedad, id_tenant, id_propietario, id_agente, titulo, direccion, precio, tipo_operacion, estado) VALUES 
    (13, 3, 3, 3, 'Casa Minimalista en Las Palmas', 'Calle Los Sauces', 320000.00, 'Venta', 'Disponible'),
    (14, 3, 3, 3, 'Duplex Zona Sur', 'Santos Dumont 4to Anillo', 600.00, 'Alquiler', 'Disponible'),
    (15, 3, 3, 3, 'Terreno en el Urubo', 'Urubo Village', 85000.00, 'Venta', 'Vendida'),
    (16, 3, 3, 3, 'Local Comercial Mercado', 'La Ramada', 150000.00, 'Venta', 'Disponible');

    -- Actualizamos TODOS los passwords a admin123
    """)
    conn.commit()

    from auth import get_password_hash
    # Update passwords using sqlalchemy to use valid hashes
    print("Datos de empresa 2 y 3 insertados.")
except Exception as e:
    print("Error insertando datos:", e)
finally:
    conn.close()

import database.database as db
import database.models as models
from auth import get_password_hash

session = db.SessionLocal()
hash_admin123 = get_password_hash("admin123")
session.query(models.Usuario).update({"password_hash": hash_admin123})
session.commit()
session.close()
