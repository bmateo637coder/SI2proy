"""Políticas SaaS compartidas por API, sincronización y analítica."""
from datetime import date, datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator
from sqlalchemy.orm import Session

from auth import get_current_user, require_admin, require_staff, require_reader, is_all_tenants, scope_query, label_tenants
from database import models as m
from database.database import get_db

router = APIRouter(prefix="/api/saas", tags=["SaaS y sucursales"])


def today():
    return datetime.now(ZoneInfo("America/La_Paz")).date()


def subscription(db, tid):
    return db.get(m.Suscripcion, tid)


def require_active(db, tid):
    tenant = db.get(m.Tenant, tid)
    sub = subscription(db, tid)
    if not tenant or not tenant.estado or not sub or sub.estado != "activa" or not sub.inicio <= today() <= sub.vencimiento:
        raise HTTPException(402, "Suscripción inactiva o vencida. Revise el plan de su empresa.")
    return sub


def require_ai(db, user):
    if is_all_tenants(user):
        return
    sub = require_active(db, user.id_tenant)
    if not sub.plan.reportes_ia:
        raise HTTPException(403, "Los reportes generativos y la analítica requieren el plan Profesional.")


def tenant_scope(user, tid):
    if user.id_rol != 1 and user.id_tenant != tid:
        raise HTTPException(403, "No puede acceder a otra inmobiliaria.")


def branch_scope(db, user, branch_id):
    branch = db.query(m.Sucursal).filter_by(id_sucursal=branch_id, id_tenant=user.id_tenant, activa=True).first()
    assigned = db.get(m.UsuarioSucursal, (user.ci, branch_id))
    if not branch or (user.id_rol not in (1, 2) and not assigned):
        raise HTTPException(403, "Sucursal no autorizada o inactiva.")
    return branch


def branch_ids(db, user):
    q = db.query(m.Sucursal.id_sucursal).filter_by(id_tenant=user.id_tenant, activa=True)
    if user.id_rol not in (1, 2):
        q = q.join(m.UsuarioSucursal).filter(m.UsuarioSucursal.ci_usuario == user.ci)
    return [r[0] for r in q.all()]


def summary(db, tid):
    sub = subscription(db, tid)
    if not sub:
        return {"id_tenant": tid, "estado": "sin_suscripcion"}
    tenant = db.get(m.Tenant, tid)
    state = sub.estado
    if not tenant.estado:
        state = "suspendida"
    elif today() > sub.vencimiento:
        state = "vencida"
    elif today() < sub.inicio:
        state = "pendiente"
    return {"id_tenant": tid, "codigo_plan": sub.codigo_plan, "estado": state,
            "inicio": sub.inicio, "vencimiento": sub.vencimiento,
            "max_sucursales": sub.plan.max_sucursales, "reportes_ia": sub.plan.reportes_ia,
            "sucursales_activas": db.query(m.Sucursal).filter_by(id_tenant=tid, activa=True).count()}


@router.get("/planes")
def plans(db: Session = Depends(get_db), user=Depends(get_current_user)):
    return db.query(m.Plan).order_by(m.Plan.max_sucursales).all()


class PlanUpdate(BaseModel):
    nombre: str = Field(min_length=1, max_length=80)
    max_sucursales: int = Field(ge=1, le=1000)
    reportes_ia: bool


@router.put("/planes/{codigo}")
def update_plan(codigo: str, body: PlanUpdate, db: Session = Depends(get_db), user=Depends(require_admin)):
    if user.id_rol != 1:
        raise HTTPException(403, "Solo el administrador de plataforma configura los límites.")
    # Serializa cambios de planes con altas/reactivaciones de sucursales.
    db.query(m.Tenant).order_by(m.Tenant.id_tenant).with_for_update().all()
    plan = db.get(m.Plan, codigo)
    if not plan:
        raise HTTPException(404, "Plan no encontrado.")
    for sub in db.query(m.Suscripcion).filter_by(codigo_plan=codigo):
        if db.query(m.Sucursal).filter_by(id_tenant=sub.id_tenant, activa=True).count() > body.max_sucursales:
            raise HTTPException(409, "Una empresa excede el nuevo límite. Reduzca sus sucursales primero.")
    for key, value in body.model_dump().items():
        setattr(plan, key, value)
    db.commit()
    return plan


@router.get("/suscripcion")
def my_subscription(db: Session = Depends(get_db), user=Depends(get_current_user)):
    return summary(db, user.id_tenant)


class SubscriptionUpdate(BaseModel):
    codigo_plan: str
    inicio: date
    vencimiento: date
    estado: str = Field(pattern="^(activa|suspendida|cancelada)$")

    @model_validator(mode="after")
    def valid_dates(self):
        if self.vencimiento < self.inicio:
            raise ValueError("Vencimiento anterior al inicio.")
        return self


@router.put("/suscripcion/{tid}")
def update_subscription(tid: int, body: SubscriptionUpdate, db: Session = Depends(get_db), user=Depends(require_admin)):
    tenant_scope(user, tid)
    tenant = db.query(m.Tenant).filter_by(id_tenant=tid).with_for_update().first()
    if not tenant:
        raise HTTPException(404, "Empresa no encontrada.")
    plan = db.get(m.Plan, body.codigo_plan)
    if not plan:
        raise HTTPException(422, "Plan desconocido.")
    if db.query(m.Sucursal).filter_by(id_tenant=tid, activa=True).count() > plan.max_sucursales:
        raise HTTPException(409, "Desactive sucursales antes de cambiar a este plan.")
    row = subscription(db, tid)
    if not row:
        row = m.Suscripcion(id_tenant=tid)
        db.add(row)
    for key, value in body.model_dump().items():
        setattr(row, key, value)
    tenant.plan = body.codigo_plan
    tenant.fecha_vencimiento_pago = body.vencimiento
    db.commit()
    return summary(db, tid)


@router.get("/sucursales")
def branches(db: Session = Depends(get_db), user=Depends(require_reader)):
    q = scope_query(db.query(m.Sucursal), user, m.Sucursal.id_tenant)
    if user.id_rol not in (1, 2):
        q = q.filter(m.Sucursal.id_sucursal.in_(branch_ids(db, user)))
    return label_tenants(db, q.order_by(m.Sucursal.nombre).all())


class BranchInput(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    direccion: str = Field(default="", max_length=255)
    activa: bool = True


def save_branch(db, user, body, row=None):
    db.query(m.Tenant).filter_by(id_tenant=user.id_tenant).with_for_update().one()
    sub = require_active(db, user.id_tenant)
    if body.activa and (row is None or not row.activa):
        if db.query(m.Sucursal).filter_by(id_tenant=user.id_tenant, activa=True).count() >= sub.plan.max_sucursales:
            raise HTTPException(409, "Límite de sucursales activas del plan alcanzado.")
    duplicate = db.query(m.Sucursal).filter_by(id_tenant=user.id_tenant, nombre=body.nombre).first()
    if duplicate and (row is None or duplicate.id_sucursal != row.id_sucursal):
        raise HTTPException(409, "Ya existe una sucursal con ese nombre.")
    row = row or m.Sucursal(id_tenant=user.id_tenant)
    for key, value in body.model_dump().items():
        setattr(row, key, value)
    db.add(row)
    db.commit()
    return row


@router.post("/sucursales", status_code=201)
def create_branch(body: BranchInput, db: Session = Depends(get_db), user=Depends(require_admin)):
    if not user.id_tenant:
        raise HTTPException(422, "Ingrese como administrador de una inmobiliaria.")
    return save_branch(db, user, body)


@router.put("/sucursales/{sid}")
def update_branch(sid: int, body: BranchInput, db: Session = Depends(get_db), user=Depends(require_admin)):
    row = db.query(m.Sucursal).filter_by(id_sucursal=sid, id_tenant=user.id_tenant).first()
    if not row:
        raise HTTPException(404, "Sucursal no encontrada.")
    return save_branch(db, user, body, row)


class Assignment(BaseModel):
    ci_usuario: str


@router.post("/sucursales/{sid}/usuarios")
def assign_branch(sid: int, body: Assignment, db: Session = Depends(get_db), user=Depends(require_admin)):
    branch_scope(db, user, sid)
    target = db.query(m.Usuario).filter_by(ci=body.ci_usuario, id_tenant=user.id_tenant).first()
    if not target:
        raise HTTPException(404, "Usuario no encontrado en esta empresa.")
    if not db.get(m.UsuarioSucursal, (target.ci, sid)):
        db.add(m.UsuarioSucursal(ci_usuario=target.ci, id_sucursal=sid))
        db.commit()
    return {"asignado": True}


class PropertyBranch(BaseModel):
    id_sucursal: int


@router.put("/propiedades/{pid}/sucursal")
def assign_property(pid: int, body: PropertyBranch, db: Session = Depends(get_db), user=Depends(require_admin)):
    require_active(db, user.id_tenant)
    branch_scope(db, user, body.id_sucursal)
    prop = db.query(m.Propiedad).filter_by(id_propiedad=pid, id_tenant=user.id_tenant).with_for_update().first()
    if not prop:
        raise HTTPException(404, "Propiedad no encontrada.")
    prop.id_sucursal = body.id_sucursal
    prop.version += 1
    db.commit()
    return {"id_propiedad": pid, "id_sucursal": prop.id_sucursal, "version": prop.version}
