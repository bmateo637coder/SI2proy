import sqlite3

conn = sqlite3.connect('C:/Si2/SI2-Backend-main/database/inmobiliaria.db')
cursor = conn.cursor()

try:
    cursor.executescript("""
    -- EMPRESAS/TENANTS ya insertados por seed.py (Raices y Horizonte)
    -- Insertemos la tercera
    INSERT OR IGNORE INTO tenant (id_tenant, nombre, slug, plan, max_propiedades) VALUES 
    (3, 'Cúspide Propiedades', 'cuspide', 'basico', 10);

    -- USUARIOS (Agentes, Clientes, Propietarios de Empresa 1)
    INSERT OR IGNORE INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
    VALUES 
    ('1000002', 1, 'Ana Agente', 'agente@raices.com', '70000001', 2, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('1000003', 1, 'Pablo Propietario', 'propietario@raices.com', '70000002', 3, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG'),
    ('1000004', 1, 'Carlos Cliente', 'cliente@raices.com', '70000003', 4, '$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG');

    -- PROPIETARIOS, AGENTES, CLIENTES (Empresa 1)
    INSERT OR IGNORE INTO propietario (id_propietario, ci_usuario, id_tenant) VALUES (1, '1000003', 1);
    INSERT OR IGNORE INTO agente (id_agente, ci_usuario, id_tenant) VALUES (1, '1000002', 1);
    INSERT OR IGNORE INTO cliente (id_cliente, ci_usuario, id_tenant) VALUES (1, '1000004', 1);

    -- PROPIEDADES
    INSERT OR IGNORE INTO propiedad (id_propiedad, id_tenant, id_propietario, id_agente, titulo, direccion, precio, tipo_operacion, estado) VALUES 
    (1, 1, 1, 1, 'Hermosa Casa en Equipetrol', 'Av. San Martin, 3er Anillo Interno', 250000.00, 'Venta', 'Disponible'),
    (2, 1, 1, 1, 'Departamento de Lujo en Urubo', 'Condominio Urubo Golf', 1200.00, 'Alquiler', 'Disponible'),
    (3, 1, 1, 1, 'Local Comercial Centro', 'Calle 24 de Septiembre', 30000.00, 'Anticretico', 'Disponible'),
    (4, 1, 1, 1, 'Casa Familiar Norte', 'Av. Banzer 6to Anillo', 150000.00, 'Venta', 'Disponible');

    -- IMAGENES
    INSERT OR IGNORE INTO imagen (id_imagen, id_propiedad, url) VALUES 
    (1, 1, 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800'),
    (2, 2, 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800'),
    (3, 3, 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800'),
    (4, 4, 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800');
    """)
    conn.commit()
    print("Datos mock insertados correctamente en SQLite.")
except Exception as e:
    print("Error insertando datos:", e)
finally:
    conn.close()
