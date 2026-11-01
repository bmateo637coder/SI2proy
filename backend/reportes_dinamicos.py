"""Configuración compartida por reportes manuales y Gemini; sin SQL generado."""
import math
from auth import is_all_tenants, scope_query, label_tenants
from fastapi import HTTPException
from database import models as m

COLUMNS = {
    'propiedades': {'id_propiedad', 'titulo', 'direccion', 'precio', 'tipo_operacion', 'estado'},
    'usuarios': {'ci', 'nombre', 'correo', 'telefono', 'id_rol'},
    'clientes': {'ci', 'nombre', 'correo', 'telefono'},
}
NUMERIC = {'id_propiedad', 'precio', 'id_rol'}


def validate_config(spec):
    columns = COLUMNS.get(spec.entidad, set())
    if not spec.columnas or not set(spec.columnas) <= columns:
        raise HTTPException(422, 'Columnas de reporte no autorizadas.')
    if len(set(spec.columnas)) != len(spec.columnas):
        raise HTTPException(422, 'No repita columnas en el reporte.')
    for f in spec.filtros:
        if f.columna not in columns or f.operador not in {'eq', 'gt', 'lt', 'gte', 'lte', 'like'}:
            raise HTTPException(422, 'Filtros no autorizados.')
        if f.columna in NUMERIC:
            try:
                if isinstance(f.valor, bool) or f.operador == 'like':
                    raise ValueError()
                number = float(f.valor)
                if not math.isfinite(number) or abs(number) > 999999999999:
                    raise ValueError()
                if f.columna != 'precio' and not number.is_integer():
                    raise ValueError()
                f.valor = number if f.columna == 'precio' else int(number)
            except (TypeError, ValueError, OverflowError):
                raise HTTPException(422, f'El filtro {f.columna} necesita un número válido y un operador numérico.')
        elif not isinstance(f.valor, str) or len(f.valor) > 300:
            raise HTTPException(422, f'El filtro {f.columna} necesita un texto de hasta 300 caracteres.')
    if spec.orden and (spec.orden.columna not in columns or spec.orden.direccion not in {'asc', 'desc'}):
        raise HTTPException(422, 'Orden no autorizado.')
    return spec


def execute_report(db, user, spec):
    validate_config(spec)
    model = m.Propiedad if spec.entidad == 'propiedades' else m.Usuario
    query = scope_query(db.query(model), user, model.id_tenant)
    if spec.entidad == 'clientes':
        query = query.join(m.Cliente, (m.Cliente.ci_usuario == m.Usuario.ci) & (m.Cliente.id_tenant == m.Usuario.id_tenant))
    for f in spec.filtros:
        attr = getattr(model, f.columna)
        if f.operador == 'like':
            query = query.filter(attr.icontains(f.valor, autoescape=True))
        else:
            compare = {'eq': '__eq__', 'gt': '__gt__', 'lt': '__lt__', 'gte': '__ge__', 'lte': '__le__'}[f.operador]
            query = query.filter(getattr(attr, compare)(f.valor))
    if spec.orden:
        attr = getattr(model, spec.orden.columna)
        query = query.order_by(attr.desc() if spec.orden.direccion == 'desc' else attr.asc())
    query = query.order_by(model.id_propiedad if model == m.Propiedad else model.ci)
    rows = query.limit(spec.limite + 1).all()
    data = [{**{c: getattr(row, c) for c in spec.columnas}, **({'id_tenant': row.id_tenant} if is_all_tenants(user) else {})} for row in rows[:spec.limite]]
    if is_all_tenants(user):
        label_tenants(db, data)
    return {'data': data, 'columnas': (['inmobiliaria'] if is_all_tenants(user) else []) + spec.columnas,
            'id_tenant': user.id_tenant, 'limite': spec.limite, 'truncado': len(rows) > spec.limite}
