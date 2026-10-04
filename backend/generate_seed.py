import hashlib
import bcrypt

# Password: 12345
PASSWORD_HASH = "$2b$12$7jO3MSeR/WQ.QwZBqjICBegD.WQpCS3D5yq23NQYj6BVS5zyAk5pG"

sql = f"""-- ============================================================================
-- SCRIPT DE SEMILLA (SEED) MULTITENANT
-- ============================================================================

-- INSERCIÓN DE EMPRESAS
INSERT INTO empresa (id_tenant, nombre, dominio) VALUES 
(1, 'Raíces Inmobiliaria', 'raices.com'),
(2, 'Horizonte Bienes Raíces', 'horizonte.com'),
(3, 'Cúspide Propiedades', 'cuspide.com');

-- ROLES
INSERT INTO rol (id_rol, id_tenant, nombre) VALUES 
(1, NULL, 'Super Administrador'),
(2, NULL, 'Administrador de Empresa'),
(3, 1, 'Agente Raíces'),
(4, 1, 'Cliente Raíces'),
(5, 2, 'Agente Horizonte'),
(6, 2, 'Cliente Horizonte'),
(7, 3, 'Agente Cúspide'),
(8, 3, 'Cliente Cúspide');

-- PERMISOS
INSERT INTO permiso (id_permiso, codigo, descripcion, tipo) VALUES 
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
(12, 'UI:MENU_EMPRESAS', 'Ver menú de empresas', 'UI_Menu');

-- ROL_PERMISO
-- Super Admin lo ve todo
INSERT INTO rol_permiso (id_rol, id_permiso) VALUES 
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9), (1, 10), (1, 11), (1, 12);
-- Admin de Empresa
INSERT INTO rol_permiso (id_rol, id_permiso) VALUES 
(2, 1), (2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10);
-- Agentes (Ven inmuebles)
INSERT INTO rol_permiso (id_rol, id_permiso) VALUES 
(3, 1), (3, 2), (3, 7), (3, 8), (3, 9), (3, 10),
(5, 1), (5, 2), (5, 7), (5, 8), (5, 9), (5, 10),
(7, 1), (7, 2), (7, 7), (7, 8), (7, 9), (7, 10);

-- USUARIOS
-- Super Admin
INSERT INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
VALUES ('0000000', NULL, 'Super Admin', 'super@saas.com', '70000000', 1, '{PASSWORD_HASH}');

-- Empresa 1: Raíces
INSERT INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
VALUES 
('1000001', 1, 'Admin Raices', 'admin@raices.com', '77712345', 2, '{PASSWORD_HASH}'),
('1000002', 1, 'Ana Agente', 'agente@raices.com', '70000001', 3, '{PASSWORD_HASH}'),
('1000003', 1, 'Pablo Propietario', 'propietario@raices.com', '70000002', 4, '{PASSWORD_HASH}'),
('1000004', 1, 'Carlos Cliente', 'cliente@raices.com', '70000003', 4, '{PASSWORD_HASH}');

-- Empresa 2: Horizonte
INSERT INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
VALUES 
('2000001', 2, 'Admin Horizonte', 'admin@horizonte.com', '77720001', 2, '{PASSWORD_HASH}'),
('2000002', 2, 'Luis Agente', 'agente@horizonte.com', '70000011', 5, '{PASSWORD_HASH}'),
('2000003', 2, 'Maria Propietario', 'propietario@horizonte.com', '70000012', 6, '{PASSWORD_HASH}'),
('2000004', 2, 'Jose Cliente', 'cliente@horizonte.com', '70000013', 6, '{PASSWORD_HASH}');

-- Empresa 3: Cúspide
INSERT INTO usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) 
VALUES 
('3000001', 3, 'Admin Cuspide', 'admin@cuspide.com', '77730001', 2, '{PASSWORD_HASH}'),
('3000002', 3, 'Marta Agente', 'agente@cuspide.com', '70000021', 7, '{PASSWORD_HASH}'),
('3000003', 3, 'Jorge Propietario', 'propietario@cuspide.com', '70000022', 8, '{PASSWORD_HASH}'),
('3000004', 3, 'Sofia Cliente', 'cliente@cuspide.com', '70000023', 8, '{PASSWORD_HASH}');

-- PROPIETARIOS, AGENTES, CLIENTES
-- Empresa 1
INSERT INTO propietario (id_propietario, ci_usuario, id_tenant) VALUES (1, '1000003', 1);
INSERT INTO agente (id_agente, ci_usuario, id_tenant) VALUES (1, '1000002', 1);
INSERT INTO cliente (id_cliente, ci_usuario, id_tenant) VALUES (1, '1000004', 1);

-- Empresa 2
INSERT INTO propietario (id_propietario, ci_usuario, id_tenant) VALUES (2, '2000003', 2);
INSERT INTO agente (id_agente, ci_usuario, id_tenant) VALUES (2, '2000002', 2);
INSERT INTO cliente (id_cliente, ci_usuario, id_tenant) VALUES (2, '2000004', 2);

-- Empresa 3
INSERT INTO propietario (id_propietario, ci_usuario, id_tenant) VALUES (3, '3000003', 3);
INSERT INTO agente (id_agente, ci_usuario, id_tenant) VALUES (3, '3000002', 3);
INSERT INTO cliente (id_cliente, ci_usuario, id_tenant) VALUES (3, '3000004', 3);

-- PROPIEDADES
INSERT INTO propiedad (id_propiedad, id_tenant, id_propietario, id_agente, titulo, direccion, precio, tipo_operacion, estado) VALUES 
-- Empresa 1 (1-6)
(1, 1, 1, 1, 'Hermosa Casa en Equipetrol', 'Av. San Martin, 3er Anillo Interno', 250000.00, 'Venta', 'Disponible'),
(2, 1, 1, 1, 'Departamento de Lujo en Urubo', 'Condominio Urubo Golf', 1200.00, 'Alquiler', 'Disponible'),
(3, 1, 1, 1, 'Local Comercial Centro', 'Calle 24 de Septiembre', 30000.00, 'Anticretico', 'Disponible'),
(4, 1, 1, 1, 'Casa Familiar Norte', 'Av. Banzer 6to Anillo', 150000.00, 'Venta', 'Disponible'),
(5, 1, 1, 1, 'Terreno Zona Sur', 'Santos Dumont 8vo Anillo', 45000.00, 'Venta', 'Vendida'),
(6, 1, 1, 1, 'Oficina Corporativa', 'Equipetrol Norte', 800.00, 'Alquiler', 'Reservada'),

-- Empresa 2 (7-12)
(7, 2, 2, 2, 'Casa Quinta en La Guardia', 'Km 20 Carretera Antigua', 180000.00, 'Venta', 'Disponible'),
(8, 2, 2, 2, 'Monoambiente en Sirari', 'Calle Las Begonias', 400.00, 'Alquiler', 'Reservada'),
(9, 2, 2, 2, 'Oficina Equipetrol Norte', 'Av. Canal Isuto', 800.00, 'Alquiler', 'Disponible'),
(10, 2, 2, 2, 'Lote Industrial', 'Parque Industrial', 350000.00, 'Venta', 'Disponible'),
(11, 2, 2, 2, 'Departamento 3 Dormitorios', 'Zona Norte 3er Anillo', 900.00, 'Alquiler', 'Disponible'),
(12, 2, 2, 2, 'Casa Condominio Cerrado', 'Urubo', 280000.00, 'Venta', 'Disponible'),

-- Empresa 3 (13-18)
(13, 3, 3, 3, 'Casa Minimalista en Las Palmas', 'Calle Los Sauces', 320000.00, 'Venta', 'Disponible'),
(14, 3, 3, 3, 'Duplex Zona Sur', 'Santos Dumont 4to Anillo', 600.00, 'Alquiler', 'Disponible'),
(15, 3, 3, 3, 'Terreno en el Urubo', 'Urubo Village', 85000.00, 'Venta', 'Vendida'),
(16, 3, 3, 3, 'Local Comercial Mercado', 'La Ramada', 150000.00, 'Venta', 'Disponible'),
(17, 3, 3, 3, 'Penthouse Centro', 'Plaza 24 de Septiembre', 2500.00, 'Alquiler', 'Disponible'),
(18, 3, 3, 3, 'Casa en Alquiler Urbarí', 'Barrio Urbarí', 1000.00, 'Alquiler', 'Disponible');

-- CARACTERISTICAS
INSERT INTO caracteristica (id_caracteristica, id_propiedad, nombre, valor) VALUES 
(1, 1, 'Cuartos', '4'), (2, 1, 'Baños', '3'), (3, 1, 'Metros Cuadrados', '350'), (4, 1, 'Amoblado', 'No'),
(5, 2, 'Cuartos', '2'), (6, 2, 'Baños', '2'), (7, 2, 'Metros Cuadrados', '120'), (8, 2, 'Amoblado', 'Sí'),
(9, 3, 'Cuartos', '1'), (10, 3, 'Baños', '1'), (11, 3, 'Metros Cuadrados', '50'), (12, 3, 'Amoblado', 'No'),
(13, 4, 'Cuartos', '3'), (14, 4, 'Baños', '2'), (15, 4, 'Metros Cuadrados', '200'), (16, 4, 'Amoblado', 'No'),
(17, 5, 'Metros Cuadrados', '500'), (18, 5, 'Servicios', 'Sí'),
(19, 6, 'Ambientes', '2'), (20, 6, 'Baños', '1'), (21, 6, 'Metros Cuadrados', '80'), (22, 6, 'Amoblado', 'Sí'),

(23, 7, 'Cuartos', '5'), (24, 7, 'Baños', '4'), (25, 7, 'Metros Cuadrados', '1200'), (26, 7, 'Piscina', 'Sí'),
(27, 8, 'Cuartos', '1'), (28, 8, 'Baños', '1'), (29, 8, 'Metros Cuadrados', '45'), (30, 8, 'Amoblado', 'Sí'),
(31, 9, 'Ambientes', '3'), (32, 9, 'Baños', '2'), (33, 9, 'Metros Cuadrados', '120'), (34, 9, 'Parqueo', '2'),
(35, 10, 'Metros Cuadrados', '5000'), (36, 10, 'Servicios', 'Todos'),
(37, 11, 'Cuartos', '3'), (38, 11, 'Baños', '2'), (39, 11, 'Metros Cuadrados', '140'), (40, 11, 'Amoblado', 'No'),
(41, 12, 'Cuartos', '4'), (42, 12, 'Baños', '5'), (43, 12, 'Metros Cuadrados', '400'), (44, 12, 'Piscina', 'Sí'),

(45, 13, 'Cuartos', '3'), (46, 13, 'Baños', '3'), (47, 13, 'Metros Cuadrados', '400'), (48, 13, 'Amoblado', 'Sí'),
(49, 14, 'Cuartos', '2'), (50, 14, 'Baños', '2'), (51, 14, 'Metros Cuadrados', '150'), (52, 14, 'Amoblado', 'No'),
(53, 15, 'Metros Cuadrados', '600'), (54, 15, 'Ubicacion', 'Esquina'),
(55, 16, 'Metros Cuadrados', '100'), (56, 16, 'Cortina Metálica', 'Sí'),
(57, 17, 'Cuartos', '4'), (58, 17, 'Baños', '4'), (59, 17, 'Metros Cuadrados', '300'), (60, 17, 'Vista', 'Panorámica'),
(61, 18, 'Cuartos', '3'), (62, 18, 'Baños', '2'), (63, 18, 'Metros Cuadrados', '220'), (64, 18, 'Amoblado', 'No');

-- IMAGENES
INSERT INTO imagen (id_imagen, id_propiedad, url) VALUES 
(1, 1, 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800'),
(2, 2, 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800'),
(3, 3, 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800'),
(4, 4, 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800'),
(5, 5, 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800'),
(6, 6, 'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=800'),
(7, 7, 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800'),
(8, 8, 'https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=800'),
(9, 9, 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=800'),
(10, 10, 'https://images.unsplash.com/photo-1502672260266-1c1de24244e3?w=800'),
(11, 11, 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800'),
(12, 12, 'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'),
(13, 13, 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800'),
(14, 14, 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800'),
(15, 15, 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800'),
(16, 16, 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800'),
(17, 17, 'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?w=800'),
(18, 18, 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800');

"""

with open('database/schema.sql', 'w', encoding='utf-8') as f:
    f.write(sql)

print("schema.sql updated with rich mock data for 3 companies, 18 properties, and owners.")

