"""Copia autorizada para móviles y bandeja de cambios con control optimista e idempotencia."""
import hashlib
import json
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from auth import require_reader, require_staff, scope_query, label_tenants
from database import models as m
from database.database import get_db
from saas import require_active
import schemas
import contratos_router as contracts

router = APIRouter(prefix='/api/replica', tags=['Réplica móvil'])


def encoded(value):
    return jsonable_encoder(value)


def fingerprint(entity, row):
    if entity == 'propiedad':
        keys = ('id_propiedad', 'id_tenant', 'version', 'precio', 'estado', 'id_sucursal', 'titulo', 'descripcion', 'direccion', 'tipo_operacion', 'id_agente', 'id_propietario', 'caracteristicas', 'imagenes')
    elif entity == 'contrato':
        keys = ('id_contrato', 'id_tenant', 'id_cliente', 'id_propiedad', 'tipo_contrato', 'monto_total', 'fecha_inicio', 'fecha_fin', 'pagos', 'cuotas')
    else:
        keys = tuple(row)
    return hashlib.sha256(json.dumps({k: row.get(k) for k in keys}, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()).hexdigest()


def property_row(prop):
    return {**schemas.PropiedadAdminResponse.model_validate(prop).model_dump(mode='json'),
            'version': prop.version, 'id_sucursal': prop.id_sucursal,
            'latitud': getattr(prop, 'latitud', None), 'longitud': getattr(prop, 'longitud', None)}


def person_row(item, key):
    user = item.usuario
    return {key: getattr(item, key), 'id_tenant': item.id_tenant, 'inmobiliaria': item.tenant.nombre,
            'ci_usuario': item.ci_usuario, 'ci': item.ci_usuario,
            'nombre': user.nombre, 'correo': user.correo, 'telefono': user.telefono}


@router.get('/datos')
def snapshot(db: Session = Depends(get_db), user=Depends(require_reader)):
    props = label_tenants(db, scope_query(db.query(m.Propiedad), user, m.Propiedad.id_tenant).order_by(m.Propiedad.id_propiedad).all())
    contract_rows = [contracts._serializar_contrato(c, detalle=True) for c in scope_query(db.query(m.Contrato), user, m.Contrato.id_tenant).order_by(m.Contrato.id_contrato).all()]
    data = {
        'propiedades': [property_row(p) for p in props], 'contratos': contract_rows,
        'clientes': [person_row(c, 'id_cliente') for c in scope_query(db.query(m.Cliente), user, m.Cliente.id_tenant).all()],
        'propietarios': [person_row(c, 'id_propietario') for c in scope_query(db.query(m.Propietario), user, m.Propietario.id_tenant).all()],
        'agentes': [person_row(c, 'id_agente') for c in scope_query(db.query(m.Agente), user, m.Agente.id_tenant).all()],
        # Nunca serializar Usuario mediante __dict__: contiene el hash de contraseña.
        'usuarios': label_tenants(db, [{'ci': u.ci, 'id_tenant': u.id_tenant, 'nombre': u.nombre, 'correo': u.correo,
            'telefono': u.telefono, 'id_rol': u.id_rol, 'is_active': True} for u in scope_query(db.query(m.Usuario), user, m.Usuario.id_tenant).all()]),
        'sucursales': encoded(label_tenants(db, scope_query(db.query(m.Sucursal), user, m.Sucursal.id_tenant).all())),
        'reportes': [schemas.ReporteGuardadoResponse.model_validate(r).model_dump(mode='json') | {'id_tenant': r.id_tenant}
            for r in scope_query(db.query(m.ReporteGuardado).filter_by(ci_usuario=user.ci), user, m.ReporteGuardado.id_tenant).all()],
        'planes': encoded(db.query(m.Plan).all()),
        'reservas': encoded([{'uuid': o.uuid, 'id_tenant': o.id_tenant, 'id_sucursal': o.id_sucursal,
            'id_propiedad': o.id_propiedad, 'id_cliente': o.id_cliente, 'tipo': o.tipo,
            'estado': o.estado, 'registrado_en': o.registrado_en}
            for o in scope_query(db.query(m.OperacionOffline), user, m.OperacionOffline.id_tenant).all()]),
        'roles': [{'id_rol': r.id_rol, 'nombre': r.nombre, 'permisos': [p.codigo for p in r.permisos]} for r in db.query(m.Rol).all()],
    }
    return {'ci_usuario': user.ci, 'id_tenant': user.id_tenant, 'alcance': 'todas' if getattr(user, 'all_tenants', False) else 'empresa',
            'descargado_en': datetime.now(timezone.utc), 'completo': True, 'datos': data,
            'huellas': {**{f"propiedad:{p['id_propiedad']}": fingerprint('propiedad', p) for p in data['propiedades']},
                       **{f"contrato:{c['id_contrato']}": fingerprint('contrato', c) for c in contract_rows},
                       **{f"cliente:{c['id_cliente']}": fingerprint('cliente', c) for c in data['clientes']}}}


class Change(BaseModel):
    uuid: UUID
    id_tenant: int = Field(gt=0)
    ci_usuario: str = Field(min_length=1, max_length=20)
    tipo: Literal['cliente.crear', 'contrato.crear', 'pago.crear', 'contrato.eliminar', 'reporte.guardar',
                  'propiedad.crear', 'propiedad.actualizar', 'propiedad.estado', 'propiedad.eliminar']
    id: int | None = None
    datos: dict = Field(default_factory=dict)
    base: str | None = Field(default=None, max_length=64)
    dependencias: dict[str, UUID] = Field(default_factory=dict, max_length=5)


class WorkSession:
    """Los servicios existentes conservan su validación; su commit pasa a ser flush."""
    def __init__(self, session): self.session = session
    def __getattr__(self, name): return getattr(self.session, name)
    def commit(self): self.session.flush()


def current_row(db, user, entity, ident):
    model, key = {'propiedad': (m.Propiedad, 'id_propiedad'), 'contrato': (m.Contrato, 'id_contrato')}[entity]
    row = db.query(model).filter(getattr(model, key) == ident, model.id_tenant == user.id_tenant).with_for_update().first()
    if row is None: raise HTTPException(409, 'El registro fue eliminado o pertenece a otra inmobiliaria.')
    if entity == 'propiedad':
        label_tenants(db, [row])
        return property_row(row)
    return contracts._serializar_contrato(row, detalle=True)


@router.post('/cambios')
def synchronize(body: Change, background_tasks: BackgroundTasks, db: Session = Depends(get_db), user=Depends(require_staff)):
    if body.id_tenant != user.id_tenant or body.ci_usuario != user.ci:
        raise HTTPException(403, 'La operación pertenece a otra cuenta o inmobiliaria.')
    if len(json.dumps(body.datos)) > 50000: raise HTTPException(422, 'Cambio demasiado grande.')
    db.query(m.Tenant).filter_by(id_tenant=user.id_tenant).with_for_update().one()
    digest = hashlib.sha256(json.dumps(body.model_dump(mode='json'), sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    old = db.query(m.CambioReplica).filter_by(id_tenant=user.id_tenant, uuid=str(body.uuid)).first()
    if old:
        if old.payload_hash != digest or old.ci_usuario != user.ci: raise HTTPException(409, 'UUID reutilizado con otro contenido.')
        return old.resultado | {'duplicada': True}
    require_active(db, user.id_tenant)
    data, ident, expected = dict(body.datos), body.id, body.base
    base_receipt = None
    for field, operation_uuid in body.dependencias.items():
        prior = db.query(m.CambioReplica).filter_by(id_tenant=user.id_tenant, ci_usuario=user.ci, uuid=str(operation_uuid), estado='confirmada').first()
        if not prior: raise HTTPException(409, 'Primero sincroniza o resuelve el registro del que depende este cambio.')
        source = prior.resultado['data']
        if field == 'base':
            base_receipt = prior.resultado
            continue
        if field not in {'id', 'id_cliente', 'id_propiedad', 'id_contrato'}: raise HTTPException(422, 'Dependencia no permitida.')
        id_field = {'id': 'id_contrato' if body.tipo.startswith(('pago.', 'contrato.eliminar')) else 'id_propiedad'}.get(field, field)
        if id_field not in source: raise HTTPException(422, 'Dependencia incompatible.')
        if field == 'id':
            ident = source[id_field]
            expected = prior.resultado.get('huellas', {}).get(f"{'contrato' if id_field == 'id_contrato' else 'propiedad'}:{ident}")
        else:
            data[field] = source[id_field]
            if field == 'id_propiedad' and body.tipo == 'contrato.crear':
                expected = prior.resultado.get('huellas', {}).get(f"propiedad:{data[field]}")
    result = {'uuid': str(body.uuid), 'estado': 'confirmada', 'data': {}, 'huellas': {}}
    server = None
    try:
        with db.begin_nested():
            target = ('propiedad', data.get('id_propiedad')) if body.tipo == 'contrato.crear' else (
                ('contrato', ident) if body.tipo in {'pago.crear', 'contrato.eliminar'} else
                ('propiedad', ident) if body.tipo in {'propiedad.actualizar', 'propiedad.estado', 'propiedad.eliminar'} else None)
            if target:
                if base_receipt: expected = base_receipt.get('huellas', {}).get(f'{target[0]}:{target[1]}')
                server = current_row(db, user, *target)
                if not expected or fingerprint(target[0], server) != expected:
                    raise HTTPException(409, 'El registro cambió en el servidor. Revisa ambos datos antes de volver a enviar.')
            import main
            work = WorkSession(db)
            if body.tipo == 'cliente.crear':
                account = db.get(m.Usuario, data.get('ci_usuario'))
                if not account or account.id_tenant != user.id_tenant: raise HTTPException(422, 'El CI debe existir en esta inmobiliaria.')
                result['data'] = main.create_cliente(schemas.ClienteCreate(**data), user, work)
            elif body.tipo == 'contrato.crear':
                result['data'] = contracts.crear_contrato(schemas.ContratoCreate(**data), user, work)
            elif body.tipo == 'pago.crear':
                result['data'] = contracts.registrar_pago(ident, schemas.PagoCreate(**data), user, work)
            elif body.tipo == 'contrato.eliminar':
                result['data'] = contracts.eliminar_contrato(ident, user, work)
            elif body.tipo == 'reporte.guardar':
                result['data'] = schemas.ReporteGuardadoResponse.model_validate(main.guardar_reporte(schemas.ReporteGuardadoCreate(**data), user, work)).model_dump(mode='json')
            elif body.tipo == 'propiedad.crear':
                prop = main.create_propiedad(schemas.PropiedadCreate(**data), user, work)
                label_tenants(db, [prop]); result['data'] = property_row(prop)
            elif body.tipo == 'propiedad.actualizar':
                prop = main.update_propiedad(ident, schemas.PropiedadCreate(**data), user, work)
                label_tenants(db, [prop]); result['data'] = property_row(prop)
            elif body.tipo == 'propiedad.estado':
                result['data'] = main.update_propiedad_estado(ident, schemas.PropiedadEstadoUpdate(**data), background_tasks, user, work)
            else:
                result['data'] = main.delete_propiedad(ident, user, work)
            db.flush()
            if body.tipo == 'contrato.crear':
                cid = result['data']['id_contrato']; result['huellas'][f'contrato:{cid}'] = fingerprint('contrato', result['data'])
            if target and not body.tipo.endswith('eliminar'):
                fresh = current_row(db, user, *target)
                result['huellas'][f'{target[0]}:{target[1]}'] = fingerprint(target[0], fresh)
            if body.tipo.startswith('propiedad.') and 'id_propiedad' in result['data']:
                result['huellas'][f"propiedad:{result['data']['id_propiedad']}"] = fingerprint('propiedad', result['data'])
    except HTTPException as error:
        result.update(estado='conflicto' if error.status_code == 409 else 'rechazada', motivo=str(error.detail), servidor=server)
    except (ValidationError, IntegrityError, ValueError):
        result.update(estado='rechazada', motivo='Datos inválidos o registro ya existente. Revisa el cambio local.', servidor=server)
    result = encoded(result)
    db.add(m.CambioReplica(uuid=str(body.uuid), id_tenant=user.id_tenant, ci_usuario=user.ci, payload_hash=digest, estado=result['estado'], resultado=result))
    db.commit()
    return result
