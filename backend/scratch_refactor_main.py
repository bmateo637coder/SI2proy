with open('c:/Si2/SI2-Backend-main/main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace id_empresa with id_tenant globally
content = content.replace('id_empresa', 'id_tenant')

# Replace Empresa with Tenant
content = content.replace('models.Empresa', 'models.Tenant')

with open('c:/Si2/SI2-Backend-main/main.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Refactor de main completado.")
