import asyncio
import os
from datetime import date, datetime, timedelta

from database.database import SessionLocal
from database import models
from logger import log_accion_segura

"""
Scheduler de procesos periódicos (Web - Procesos Periódicos).
Ejecuta tareas diarias automáticas:
  - Backup automático de la base de datos (con publicación opcional en GitHub).
  - Detección y registro de cuotas vencidas / próximas a vencer (pagos).

Se inicia junto con la aplicación FastAPI (lifespan). No requiere claves extra.
En Render, la hora se controla con BACKUP_HORA_UTC (por defecto 02:00 UTC).
"""

_TAREA_INICIADA = False


def _registrar_vencimientos():
    db = SessionLocal()
    try:
        hoy = date.today()
        vencidas = db.query(models.Cuota).filter(
            models.Cuota.estado == "Pendiente",
            models.Cuota.fecha_vencimiento < hoy,
        ).all()
        proximas = db.query(models.Cuota).filter(
            models.Cuota.estado == "Pendiente",
            models.Cuota.fecha_vencimiento >= hoy,
            models.Cuota.fecha_vencimiento <= hoy + timedelta(days=7),
        ).all()

        for cuota in vencidas:
            log_accion_segura(
                "Scheduler",
                "vencimiento_pagos",
                f"Cuota {cuota.numero_cuota} del contrato {cuota.id_contrato} VENCIDA el {cuota.fecha_vencimiento}.",
            )
        for cuota in proximas:
            log_accion_segura(
                "Scheduler",
                "vencimiento_pagos",
                f"Cuota {cuota.numero_cuota} del contrato {cuota.id_contrato} vence pronto: {cuota.fecha_vencimiento}.",
            )

        db.query(models.Cuota).filter(
            models.Cuota.estado == "Pendiente",
            models.Cuota.fecha_vencimiento < hoy,
        ).update({"estado": "Vencida"}, synchronize_session=False)
        db.commit()
    finally:
        db.close()


def _backup_diario():
    from backup_service import backup_diario

    try:
        resultado = backup_diario()
        detalle = f"Backup diario OK: {resultado.get('archivo')}"
        if resultado.get("url"):
            detalle += f" publicado en {resultado['url']}"
        else:
            detalle += " (sin publicación en GitHub)."
        log_accion_segura("Scheduler", "backup_automatico", detalle)
    except Exception as e:
        print(f"Error en backup diario: {e}")
        log_accion_segura("Scheduler", "backup_automatico", f"Fallo backup diario: {e}")


async def _ejecutar_tareas():
    _backup_diario()
    try:
        _registrar_vencimientos()
    except Exception as e:
        print(f"Error registrando vencimientos: {e}")


async def _bucle():
    hora = int(os.getenv("BACKUP_HORA_UTC", "2"))
    while True:
        ahora = datetime.utcnow()
        proxima = (ahora + timedelta(days=1)).replace(hour=hora, minute=0, second=0, microsecond=0)
        segundos = (proxima - ahora).total_seconds()
        print(f"Scheduler: próximo trabajo diario en {int(max(segundos, 1))}s")
        await asyncio.sleep(max(segundos, 1))
        try:
            await _ejecutar_tareas()
        except Exception as e:
            print(f"Scheduler: error de ciclo: {e}")


def iniciar_scheduler():
    """Registra la tarea asíncrona de procesos periódicos (una sola vez)."""
    global _TAREA_INICIADA
    if _TAREA_INICIADA:
        return
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(_bucle())
        loop.create_task(_bucle_notificaciones())
        _TAREA_INICIADA = True
        print("Scheduler de procesos periódicos iniciado.")
    except RuntimeError:
        print("Scheduler: no hay event loop activo, se omitió su inicio.")


async def _bucle_notificaciones():
    """Trabajo corto en un hilo: no bloquear el event loop con Firebase ni SQL."""
    def process():
        from database.database import SessionLocal
        from sprint4_notificaciones import entregar_pendientes
        with SessionLocal() as db:
            entregar_pendientes(db)
    while True:
        try:
            await asyncio.to_thread(process)
        except Exception:
            print('Notificaciones: no se pudo completar este ciclo; se reintentará.')
        await asyncio.sleep(30)
