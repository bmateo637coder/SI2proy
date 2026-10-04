# Inmobiliaria Raíces

Este es el repositorio oficial del sistema de gestión inmobiliaria "Raíces", desarrollado como parte del proyecto de la materia Sistemas de Información II.

## Estado del Proyecto
Actualmente se ha completado el **Sprint 0** (Autenticación y Seguridad). El sistema cuenta con:
* Autenticación JWT y encriptación bcrypt
* Navegación SPA con Angular y FastAPI
* Sistema de diseño limpio (Glassmorphism, sin emojis)
* Gestión y visualización de roles (CU-05)
* Cambio y recuperación de contraseña (CU-03, CU-04)

## Configuración local

Antes de iniciar la API, copia `.env.example` a `.env` y reemplaza todos los valores de ejemplo con secretos locales. No se versionan credenciales ni cuentas de prueba.

## 🛠 Tecnologías Utilizadas
* **Backend:** FastAPI (Python), SQLAlchemy, PostgreSQL
* **Frontend:** Angular 18 (TypeScript), HTML5, CSS3 Nativo

## Instrucciones de Ejecución Local
### Iniciar Backend
```bash
cd SI2-Backend
.\venv\Scripts\activate
uvicorn main:app --reload
```

### Iniciar Frontend
```bash
cd SI2-Frontend
ng serve -o
```
