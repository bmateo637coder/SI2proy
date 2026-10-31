"""Consultas consolidadas explícitas, disponibles solo para el superadministrador."""
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session, joinedload, selectinload

from auth import get_current_user
from database import models as m
from database.database import get_db
from saas import today

router = APIRouter(prefix='/admin/vista-global', tags=['Vista global SaaS'])
Entity = Literal['propiedades', 'clientes', 'propietarios', 'agentes', 'contratos', 'usuarios', 'sucursales']
MODELS = {'propiedades': m.Propiedad, 'clientes': m.Cliente, 'propietarios': m.Propietario,
          'agentes': m.Agente, 'contratos': m.Contrato, 'usuarios': m.Usuario, 'sucursales': m.Sucursal}


def require_superadmin(user=Depends(get_current_user)):
    if user.id_rol != 1:
        raise HTTPException(403, 'La vista global está disponible solo para el superadministrador SaaS.')
    return user


@router.get('/resumen')
def summary(db: Session = Depends(get_db), user=Depends(require_superadmin)):
    counts = {name: dict(db.query(model.id_tenant, func.count()).group_by(model.id_tenant).all())
              for name, model in MODELS.items()}
    companies = db.query(m.Tenant, m.Suscripcion).outerjoin(m.Suscripcion, m.Suscripcion.id_tenant == m.Tenant.id_tenant).order_by(m.Tenant.nombre, m.Tenant.id_tenant).all()
    rows = []
    for company, sub in companies:
        state = 'sin_suscripcion'
        if sub:
            state = sub.estado
            if not company.estado:
                state = 'suspendida'
            elif today() > sub.vencimiento:
                state = 'vencida'
            elif today() < sub.inicio:
                state = 'pendiente'
        rows.append({'id_tenant': company.id_tenant, 'nombre': company.nombre, 'activa': company.estado,
                     'plan': sub.codigo_plan if sub else company.plan, 'suscripcion': state,
                     'vencimiento': sub.vencimiento if sub else None,
                     'conteos': {name: values.get(company.id_tenant, 0) for name, values in counts.items()}})
    return {'empresas': rows, 'totales': {name: sum(r['conteos'][name] for r in rows) for name in MODELS},
            'inmobiliarias': len(rows)}


@router.get('/{entidad}')
def records(entidad: Entity, id_tenant: int | None = Query(None, ge=1), buscar: str = Query('', max_length=150),
            limite: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0, le=100000),
            db: Session = Depends(get_db), user=Depends(require_superadmin)):
    if id_tenant is not None and not db.get(m.Tenant, id_tenant):
        raise HTTPException(404, 'Inmobiliaria no encontrada.')
    model = MODELS[entidad]
    query = db.query(model, m.Tenant.nombre).join(m.Tenant, model.id_tenant == m.Tenant.id_tenant)
    search_columns = [m.Tenant.nombre]
    if entidad in ('clientes', 'propietarios', 'agentes'):
        query = query.join(m.Usuario, and_(model.ci_usuario == m.Usuario.ci, model.id_tenant == m.Usuario.id_tenant))
        query = query.options(joinedload(model.usuario))
        search_columns += [m.Usuario.nombre, m.Usuario.correo, m.Usuario.ci]
    elif entidad == 'propiedades':
        query = query.options(selectinload(m.Propiedad.imagenes), selectinload(m.Propiedad.caracteristicas))
        search_columns += [m.Propiedad.titulo, m.Propiedad.direccion, m.Propiedad.tipo_operacion, m.Propiedad.estado]
    elif entidad == 'contratos':
        query = query.join(m.Propiedad, and_(m.Contrato.id_propiedad == m.Propiedad.id_propiedad, m.Contrato.id_tenant == m.Propiedad.id_tenant))
        query = query.options(joinedload(m.Contrato.propiedad))
        search_columns += [m.Propiedad.titulo, m.Contrato.tipo_contrato]
    elif entidad == 'usuarios':
        query = query.options(joinedload(m.Usuario.rol))
        search_columns += [m.Usuario.nombre, m.Usuario.correo, m.Usuario.ci]
    else:
        search_columns += [m.Sucursal.nombre, m.Sucursal.direccion]
    if id_tenant is not None:
        query = query.filter(model.id_tenant == id_tenant)
    if buscar.strip():
        query = query.filter(or_(*(c.icontains(buscar.strip(), autoescape=True) for c in search_columns)))
    total = query.count()
    pk = list(model.__table__.primary_key.columns)[0]
    rows = query.order_by(m.Tenant.nombre, model.id_tenant, pk).offset(offset).limit(limite).all()
    data = []
    for record, company_name in rows:
        row = {'id_tenant': record.id_tenant, 'inmobiliaria': company_name}
        if entidad == 'propiedades':
            row.update({k: getattr(record, k) for k in ('id_propiedad', 'titulo', 'direccion', 'descripcion', 'precio', 'tipo_operacion', 'estado')})
            row['imagen'] = record.imagenes[0].url if record.imagenes else None
            row['caracteristicas'] = [{'nombre': c.nombre, 'valor': c.valor} for c in record.caracteristicas]
        elif entidad in ('clientes', 'propietarios', 'agentes'):
            row.update({k: getattr(record.usuario, k) for k in ('ci', 'nombre', 'correo', 'telefono')})
        elif entidad == 'contratos':
            row.update({k: getattr(record, k) for k in ('id_contrato', 'tipo_contrato', 'monto_total', 'fecha_inicio', 'fecha_fin')})
            row['propiedad'] = record.propiedad.titulo
        elif entidad == 'usuarios':
            row.update({k: getattr(record, k) for k in ('ci', 'nombre', 'correo', 'telefono')})
            row['rol'] = record.rol.nombre if record.rol else 'Sin rol'
        else:
            row.update({k: getattr(record, k) for k in ('id_sucursal', 'nombre', 'direccion', 'activa')})
        data.append(row)
    return {'entidad': entidad, 'data': data, 'total': total, 'limite': limite, 'offset': offset}
