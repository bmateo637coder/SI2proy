# Inmobiliaria Raíces

Este es el repositorio oficial del sistema de gestión inmobiliaria "Raíces", desarrollado como parte del proyecto de la materia Sistemas de Información II.

## Estado del Proyecto
Actualmente se ha completado el **Sprint 0** (Autenticación y Seguridad). El sistema cuenta con:
* Autenticación JWT y encriptación bcrypt
* Navegación SPA con Angular y FastAPI
* Sistema de diseño limpio (Glassmorphism, sin emojis)
* Gestión y visualización de roles (CU-05)
* Cambio y recuperación de contraseña (CU-03, CU-04)

## Credenciales de Acceso (Usuarios de Prueba)
Se han generado cuentas de prueba con los diferentes roles activos en el sistema para facilitar la validación de las vistas y permisos.

Todas las contraseñas cumplen con las políticas de seguridad (mínimo 8 caracteres, mayúsculas, números y símbolos).

| Rol | Correo / Usuario | Contraseña |
| --- | --- | --- |
| **Administrador** | `admin@raices.com` | `Admin.123@` |
| **Agente Inmobiliario** | `agente@raices.com` | `Password.123@` |
| **Propietario** | `propietario@raices.com` | `Password.123@` |
| **Cliente** | `cliente@raices.com` | `Password.123@` |

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
