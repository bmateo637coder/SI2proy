import os
for file_name in ['seed.py', 'generate_seed.py']:
    path = f'c:/Si2/SI2-Backend-main/{file_name}'
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()

        content = content.replace('id_empresa', 'id_tenant')
        content = content.replace('models.Empresa', 'models.Tenant')
        
        # Adding missing Tenant fields if any mock data is created
        content = content.replace(
            'models.Tenant(nombre=',
            'models.Tenant(slug="empresa-slug", plan="basico", nombre='
        )

        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
print("Refactor de seeds completado.")
