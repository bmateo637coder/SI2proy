"""Contrato común para IndexedDB y SQLite. Cada operación se confirma atómicamente."""
import hashlib
import json
import logging
import os
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session, selectinload

from auth import require_staff
from database import models as m
from database.database import get_db
from saas import branch_ids, branch_scope, require_active

router = APIRouter(prefix="/api/offline", tags=["Operaciones offline"])
log = logging.getLogger("raices.sync")


class Operation(BaseModel):
    uuid: UUID
    id_tenant: int
    id_sucursal: int
    ci_usuario: str
    id_cliente: int
    id_propiedad: int
    tipo: Literal["reserva", "venta_contado"]
    registrado_en: datetime
    version: int = Field(ge=1)
    precio: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    total: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    cantidad: Literal[1] = 1
    forma_pago: Literal["Efectivo"] = "Efectivo"

    @field_validator("registrado_en")
    @classmethod
    def timezone_required(cls, value):
        if value.tzinfo is None:
            raise ValueError("La fecha debe incluir zona horaria.")
        if value > datetime.now(timezone.utc) + timedelta(minutes=10):
            raise ValueError("La fecha de registro está en el futuro.")
        return value


def receipt(row, duplicate=False):
    return {"uuid": row.uuid, "estado": row.estado, "motivo": row.motivo,
            "id_contrato": row.id_contrato, "duplicada": duplicate, "procesado_en": row.procesado_en}


@router.get("/catalogo")
def snapshot(db: Session = Depends(get_db), user=Depends(require_staff)):
    require_active(db, user.id_tenant)
    ids = branch_ids(db, user)
    props = db.query(m.Propiedad).filter(m.Propiedad.id_tenant == user.id_tenant,
            m.Propiedad.id_sucursal.in_(ids)).options(selectinload(m.Propiedad.caracteristicas)).order_by(m.Propiedad.id_propiedad).limit(2000).all()
    clients = db.query(m.Cliente).filter_by(id_tenant=user.id_tenant).options(selectinload(m.Cliente.usuario)).limit(2000).all()
    return {"id_tenant": user.id_tenant, "ci_usuario": user.ci, "descargado_en": datetime.now(timezone.utc),
            "limite": 2000, "sucursales": db.query(m.Sucursal).filter(m.Sucursal.id_sucursal.in_(ids)).all(),
            "clientes": [{"id_cliente": c.id_cliente, "nombre": c.usuario.nombre} for c in clients],
            "propiedades": [{"id_propiedad": p.id_propiedad, "id_sucursal": p.id_sucursal,
                "titulo": p.titulo, "direccion": p.direccion, "precio": str(p.precio),
                "tipo_operacion": p.tipo_operacion, "estado": p.estado, "version": p.version,
                "caracteristicas": [{"nombre": c.nombre, "valor": c.valor} for c in p.caracteristicas]} for p in props]}


@router.get("/operaciones")
def history(db: Session = Depends(get_db), user=Depends(require_staff)):
    return [receipt(o) for o in db.query(m.OperacionOffline).filter_by(id_tenant=user.id_tenant,
        ci_usuario=user.ci).order_by(m.OperacionOffline.id.desc()).limit(500)]


@router.post("/sincronizar")
def synchronize(body: Operation, db: Session = Depends(get_db), user=Depends(require_staff)):
    if body.id_tenant != user.id_tenant or body.ci_usuario != user.ci:
        raise HTTPException(403, "Empresa o responsable distintos de la sesión autenticada.")
    # Bloqueo por empresa serializa UUID, planes y cambios comerciales concurrentes.
    # PostgreSQL mantiene este bloqueo hasta commit/rollback, incluso entre workers.
    db.query(m.Tenant).filter_by(id_tenant=user.id_tenant).with_for_update().one()
    canonical = body.model_dump(mode="json")
    digest = hashlib.sha256(json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    old = db.query(m.OperacionOffline).filter_by(id_tenant=user.id_tenant, uuid=str(body.uuid)).first()
    if old:
        if old.payload_hash != digest or old.ci_usuario != user.ci:
            raise HTTPException(409, "UUID reutilizado con datos diferentes. Conserve el registro original.")
        return receipt(old, True)
    require_active(db, user.id_tenant)
    branch_scope(db, user, body.id_sucursal)
    client = db.query(m.Cliente).filter_by(id_cliente=body.id_cliente, id_tenant=user.id_tenant).first()
    prop = db.query(m.Propiedad).filter_by(id_propiedad=body.id_propiedad,
        id_tenant=user.id_tenant).with_for_update().first()
    if not client or not prop:
        raise HTTPException(404, "Cliente o propiedad no encontrados en esta empresa.")
    reason, state = None, "confirmada"
    if prop.id_sucursal != body.id_sucursal:
        reason, state = "La propiedad cambió de sucursal.", "conflicto"
    elif prop.version != body.version or prop.estado != "Disponible":
        reason, state = "Disponibilidad o versión modificadas; revise el catálogo actualizado.", "conflicto"
    elif prop.precio != body.precio:
        reason, state = "El precio cambió; requiere revisión con el cliente.", "conflicto"
    elif body.total != body.precio:
        reason, state = "El total debe coincidir con el precio de una propiedad.", "rechazada"
    elif body.tipo == "venta_contado" and prop.tipo_operacion != "Venta":
        reason, state = "Solo se admiten ventas de contado de propiedades en venta.", "rechazada"
    row = m.OperacionOffline(uuid=str(body.uuid), id_tenant=user.id_tenant, id_sucursal=body.id_sucursal,
        ci_usuario=user.ci, id_cliente=body.id_cliente, id_propiedad=body.id_propiedad,
        tipo=body.tipo, payload_hash=digest, datos=canonical, estado=state, motivo=reason,
        registrado_en=body.registrado_en)
    if state == "confirmada":
        if body.tipo == "venta_contado":
            contract = m.Contrato(id_tenant=user.id_tenant, id_cliente=client.id_cliente,
                id_propiedad=prop.id_propiedad, id_agente=prop.id_agente, tipo_contrato="Venta",
                monto_total=body.total, fecha_inicio=body.registrado_en.date())
            db.add(contract)
            db.flush()
            row.id_contrato = contract.id_contrato
            db.add(m.Pago(id_contrato=contract.id_contrato, monto=body.total, metodo_pago="Efectivo",
                numero_recibo=f"OFF-{body.uuid}", fecha_pago=body.registrado_en.replace(tzinfo=None)))
            db.add(m.Cuota(id_contrato=contract.id_contrato, numero_cuota=1, monto=body.total,
                fecha_vencimiento=contract.fecha_inicio, estado="Pagada", fecha_pago=body.registrado_en.replace(tzinfo=None)))
            prop.estado = "Vendida"
        else:
            prop.estado = "Reservada"
        prop.version += 1
    db.add(row)
    db.commit()
    db.refresh(row)
    log.info("sync tenant=%s uuid=%s estado=%s", user.id_tenant, row.uuid, row.estado)
    return receipt(row)


@router.put("/reservas/{operation_id}/cancelar")
def cancel_reservation(operation_id: UUID, db: Session = Depends(get_db), user=Depends(require_staff)):
    db.query(m.Tenant).filter_by(id_tenant=user.id_tenant).with_for_update().one()
    row = db.query(m.OperacionOffline).filter_by(id_tenant=user.id_tenant, uuid=str(operation_id), tipo="reserva").first()
    if not row or (user.id_rol not in (1, 2) and row.ci_usuario != user.ci):
        raise HTTPException(404, "Reserva no encontrada.")
    if row.estado == "cancelada":
        return receipt(row, True)
    require_active(db, user.id_tenant)
    stamp = row.procesado_en.replace(tzinfo=timezone.utc) if row.procesado_en.tzinfo is None else row.procesado_en
    hours = int(os.getenv("RESERVA_CANCEL_HORAS", "48"))
    if row.estado != "confirmada" or datetime.now(timezone.utc) - stamp > timedelta(hours=hours):
        raise HTTPException(409, f"Solo se cancelan reservas confirmadas durante las primeras {hours} horas.")
    prop = db.query(m.Propiedad).filter_by(id_propiedad=row.id_propiedad, id_tenant=user.id_tenant).with_for_update().one()
    if prop.estado != "Reservada" or prop.version != row.datos["version"] + 1:
        raise HTTPException(409, "La propiedad tuvo movimientos posteriores. Requiere revisión administrativa.")
    prop.estado = "Disponible"
    prop.version += 1
    row.estado = "cancelada"
    row.motivo = "Reserva cancelada dentro del plazo permitido; propiedad liberada."
    db.commit()
    return receipt(row)
