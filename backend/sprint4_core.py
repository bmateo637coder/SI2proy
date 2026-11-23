"""Adaptación de los módulos Sprint 4 al esquema CI y al alcance SaaS existente."""
from types import SimpleNamespace
from sqlalchemy.orm import synonym
from fastapi import HTTPException
from auth import get_current_user, require_admin, require_staff, require_reader, is_all_tenants, scope_query
from database import models as m

# Alias ORM: no se cambian claves primarias ni se duplican identidades en producción.
m.Usuario.id = synonym('ci')
for model in (m.Cliente, m.Agente, m.Propietario):
    model.id_usuario = synonym('ci_usuario')


def is_admin(user):
    return user.id_rol in (1, 2)


def role_name(user):
    return 'agente' if user.agente else 'administrador' if is_admin(user) else 'cliente'


def in_scope(user, tid):
    return is_all_tenants(user) or user.id_tenant == tid


def scoped(query, user, column):
    return scope_query(query, user, column)


def property_visible(db, user, pid):
    return scoped(db.query(m.Propiedad), user, m.Propiedad.id_tenant).filter(m.Propiedad.id_propiedad == pid).first()


def attr(p, *keys, default=None):
    from sprint4_ia import normalizar
    values = {normalizar(c.nombre): c.valor for c in p.caracteristicas}
    return next((values[normalizar(k)] for k in keys if normalizar(k) in values), default)


def numeric(p, *keys):
    try:
        value = float(str(attr(p, *keys)).replace(',', '.'))
        import math
        return value if math.isfinite(value) else None
    except (TypeError, ValueError):
        return None


def flag(p, key):
    return str(attr(p, key, default='')).lower() in ('si', 'sí', 'true', '1', 'yes')


# Los atributos de las entregas nuevas se leen de las características ya persistidas.
m.Propiedad.zona = property(lambda p: SimpleNamespace(nombre=attr(p, 'Zona geográfica', 'Zona', default='Sin zona')))
m.Propiedad.id_zona = property(lambda p: p.zona.nombre)
def property_type(p):
    value = attr(p, 'Tipo inmueble', 'Tipo')
    if not value:
        value = next((k for k in ['Casa', 'Departamento', 'Local', 'Terreno', 'Oficina'] if k.lower() in p.titulo.lower()), 'Otro')
    return SimpleNamespace(nombre=value)


m.Propiedad.tipo_inmueble = property(property_type)
m.Propiedad.id_tipo_inmueble = property(lambda p: p.tipo_inmueble.nombre)
m.Propiedad.habitaciones = property(lambda p: numeric(p, 'Habitaciones', 'Cuartos', 'Dormitorios'))
m.Propiedad.banos = property(lambda p: numeric(p, 'Baños', 'Banos'))
m.Propiedad.superficie_m2 = property(lambda p: numeric(p, 'Metros Cuadrados', 'Superficie', 'm2', 'Área'))
m.Propiedad.latitud = property(lambda p: numeric(p, 'Latitud'))
m.Propiedad.longitud = property(lambda p: numeric(p, 'Longitud'))
m.Propiedad.amueblado = property(lambda p: flag(p, 'Amueblado'))
m.Propiedad.garaje = property(lambda p: flag(p, 'Garaje'))


def promotion(p):
    from sqlalchemy.orm import object_session
    from sprint4_api import promo_price
    db = object_session(p)
    return promo_price(db, p) if db is not None else None


m.Propiedad.promocion = property(promotion)
