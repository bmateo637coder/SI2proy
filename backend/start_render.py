"""Arranque de producción: migración aditiva antes de aceptar solicitudes."""
import os
import sys

from migrate_parcial2 import migrate


def main():
    # Cualquier fallo impide arrancar una API con un esquema incompleto.
    # No ejecutar semillas, recrear tablas ni restablecer contraseñas en producción.
    migrate()
    port = str(int(os.getenv("PORT", "8000")))
    os.execv(sys.executable, [sys.executable, "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", port])


if __name__ == "__main__":
    main()
