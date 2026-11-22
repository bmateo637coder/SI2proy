"""Carga aditiva por API; solo crea o completa registros propios [DEMO S4].

Requiere DEMO_ADMIN_EMAIL y DEMO_ADMIN_PASSWORD. Las contraseñas aleatorias de
las cuentas ficticias se conservan fuera de Git en --state-file para reintentos.
No restablece contraseñas, cambia planes ni edita propiedades ajenas a esta carga.
"""
import argparse
import hashlib
import json
import os
import secrets
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

MARK = '[DEMO S4]'
PHOTO = 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=600&q=75&fit=crop'


class API:
    def __init__(self, url, token=None):
        self.url, self.token = url.rstrip('/'), token

    def call(self, path, body=None, tid=None, method=None, raw=False, multipart=None):
        headers = {}
        if self.token: headers['Authorization'] = 'Bearer ' + self.token
        if tid: headers['X-Tenant-ID'] = str(tid)
        if tid == 'all':
            del headers['X-Tenant-ID']
            headers['X-Tenant-Scope'] = 'all'
        if multipart:
            payload, content_type = multipart
            headers['Content-Type'] = content_type
        else:
            headers['Content-Type'] = 'application/json'
            payload = json.dumps(body).encode() if body is not None else None
        request = Request(self.url + path, data=payload, headers=headers, method=method)
        try:
            with urlopen(request, timeout=120) as response:
                data = response.read()
                return data if raw else json.loads(data)
        except HTTPError as error:
            # Nunca imprimir cuerpos de respuesta, credenciales ni datos personales.
            raise RuntimeError(f'{request.get_method()} {path}: HTTP {error.code}') from None

    def login(self, email, password):
        self.token = self.call('/login', {'correo': email, 'password': password})['access_token']
        return self


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True).encode()).hexdigest()


def seed_reports(api):
    for tid in (1, 2, 3):
        saved = {r['nombre'] for r in api.call('/reportes/guardados', tid=tid)}
        for name, entity, columns in [('Cartera y precios', 'propiedades', ['titulo', 'precio', 'estado', 'tipo_operacion']),
                                      ('Clientes', 'clientes', ['nombre', 'correo'])]:
            name = MARK + ' ' + name + (f' (inmobiliaria {tid})' if tid != 1 else '')
            if name not in saved:
                api.call('/reportes/guardados', {'nombre': name,
                    'configuracion': json.dumps({'entidad': entity, 'columnas': columns})}, tid=tid)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api-url', required=True)
    parser.add_argument('--state-file', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    state_path = args.state_file.resolve()
    # Solo permitir estado privado dentro del directorio ignorado de herramientas.
    if not state_path.is_relative_to((repo / 'backend/.venv').resolve()):
        raise RuntimeError('Guarde el estado privado en backend/.venv, fuera de Git.')
    api = API(args.api_url).login(os.environ['DEMO_ADMIN_EMAIL'], os.environ['DEMO_ADMIN_PASSWORD'])
    companies = api.call('/admin/empresas')
    assert {c['id_tenant'] for c in companies} == {1, 2, 3}, 'Revisar las inmobiliarias destino.'
    assert api.call('/users/me')['id_rol'] == 1, 'Se requiere superadministrador.'
    original = {}
    for tid in (1, 2, 3):
        props = api.call('/modulo_inmuebles/propiedades', tid=tid)
        original[tid] = {p['id_propiedad']: fingerprint(p) for p in props if not p['titulo'].startswith(MARK)}
        company = next(c for c in companies if c['id_tenant'] == tid)
        wanted = 8 if tid == 1 else 5
        present = sum(p['titulo'].startswith(MARK) for p in props)
        assert len(props) + wanted - present <= company['max_propiedades'], 'Se conserva el límite del plan.'
        print(json.dumps({'tenant': tid, 'actuales': len(props), 'nuevas': wanted - present}), flush=True)
    if not args.apply:
        print('Vista previa. --apply crea datos ficticios de contratos, pagos y servicios.')
        return
    state = json.loads(state_path.read_text(encoding='utf-8')) if state_path.exists() else {
        'users': {}, 'anchor': datetime.now(ZoneInfo('America/La_Paz')).date().isoformat()}
    anchor = date.fromisoformat(state['anchor'])

    def save():
        state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')

    roles = api.call('/roles')
    role_ids = {}
    for name in ('Agente', 'Propietario', 'Cliente'):
        role = next((r for r in roles if r['nombre'] == name and r['id_tenant'] is None), None)
        role_ids[name] = (role or api.call('/roles', {'nombre': name}))['id_rol']

    def user(tid, kind, index=1):
        ci = f'S4D{tid}{kind[:2].upper()}{index}'
        users = api.call('/gestion_usuarios/usuarios', tid=tid)
        existing = next((u for u in users if u['ci'] == ci), None)
        if ci not in state['users']:
            if existing: raise RuntimeError('Falta el estado privado de una cuenta demo existente; no se cambia su contraseña.')
            state['users'][ci] = {'email': f's4demo.{tid}.{kind.lower()}.{index}@example.com', 'password': secrets.token_urlsafe(24) + 'Aa1@'}
            save()
        identity = state['users'][ci]
        if not existing:
            existing = api.call('/gestion_usuarios/usuarios', {'ci': ci, 'nombre': f'{MARK} {kind} {tid}-{index}',
                'correo': identity['email'], 'password': identity['password'], 'telefono': None,
                'id_tenant': tid, 'id_rol': role_ids[kind]}, tid=tid)
        assert existing['id_tenant'] == tid and existing['id_rol'] == role_ids[kind]
        return ci, identity

    def person(tid, endpoint, ci):
        rows = api.call('/modulo_inmuebles/' + endpoint, tid=tid)
        return next((r for r in rows if r['ci_usuario'] == ci), None) or api.call('/modulo_inmuebles/' + endpoint, {'ci_usuario': ci}, tid=tid)

    # Fotografía ilustrativa de un inmueble, no evidencia de un daño real.
    with urlopen(PHOTO, timeout=40) as response: photo = response.read()
    assert photo.startswith(b'\xff\xd8\xff')
    boundary = 's4demo' + secrets.token_hex(12)
    multipart = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="demostracion.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'.encode()
                 + photo + f'\r\n--{boundary}--\r\n'.encode(), 'multipart/form-data; boundary=' + boundary)
    root_alerts = {a['nombre'] for a in api.call('/api/alertas')}
    for name, criteria in [('Ventas accesibles', {'tipo_operacion': 'Venta', 'precio_max': 150000}),
                           ('Alquiler amoblado', {'tipo_operacion': 'Alquiler', 'amueblado': True})]:
        if MARK + ' ' + name not in root_alerts:
            api.call('/api/alertas', {'nombre': MARK + ' ' + name, 'criterios': criteria}, tid=1)

    for tid in (1, 2, 3):
        agent = person(tid, 'agentes', user(tid, 'Agente')[0])
        owner = person(tid, 'propietarios', user(tid, 'Propietario')[0])
        clients, identities = [], []
        for index in (1, 2, 3):
            ci, identity = user(tid, 'Cliente', index)
            clients.append(person(tid, 'clientes', ci))
            identities.append(identity)
        branch = next(b for b in api.call('/api/saas/sucursales', tid=tid) if b['activa'])
        existing_props = api.call('/modulo_inmuebles/propiedades', tid=tid)
        props = []
        specs = [('Casa norte vendida', 'Venta', 145000, 210, 3, 0),
                 ('Departamento norte financiado', 'Venta', 92000, 94, 2, 0),
                 ('Residencia Equipetrol', 'Venta', 225000, 310, 4, 1),
                 ('Departamento sur alquilado', 'Alquiler', 550, 85, 2, 2),
                 ('Casa en anticrético', 'Anticretico', 48000, 150, 3, 2)]
        specs += [('Casa con jardín disponible', 'Venta', 132000, 180, 3, 0),
                  ('Suite amoblada disponible', 'Alquiler', 420, 58, 1, 1),
                  ('Departamento para anticrético', 'Anticretico', 32000, 88, 2, 2)]
        zones = [('Zona Norte', -17.731, -63.174), ('Equipetrol', -17.759, -63.198), ('Zona Sur', -17.817, -63.180)]
        for index, (label, operation, price, area, rooms, zone) in enumerate(specs):
            title = f'{MARK} {tid}-{index+1} {label}'
            p = next((p for p in existing_props if p['titulo'] == title), None)
            if not p:
                name, lat, lng = zones[zone]
                attributes = {'Metros Cuadrados': str(area), 'Cuartos': str(rooms), 'Baños': '2', 'Zona': 'Estándar',
                    'Zona geográfica': '[DEMO] ' + name, 'Latitud': str(lat + tid * .001 + index * .0002),
                    'Longitud': str(lng - tid * .001), 'Amueblado': 'Sí' if operation == 'Alquiler' else 'No',
                    'Tipo inmueble': 'Departamento' if 'Departamento' in label or 'Suite' in label else 'Casa',
                    'Tipo de registro': 'Demostración Sprint 4'}
                p = api.call('/modulo_inmuebles/propiedades', {'id_propietario': owner['id_propietario'],
                    'id_agente': agent['id_agente'], 'id_sucursal': branch['id_sucursal'], 'titulo': title,
                    'descripcion': 'DATOS FICTICIOS de demostración para reportes e IA. Coordenadas aproximadas e imagen ilustrativa; no es una oferta real.',
                    'direccion': f'Dirección ficticia S4-{tid}-{index+1}, {name}, Santa Cruz', 'precio': price,
                    'tipo_operacion': operation, 'imagenes': [PHOTO],
                    'caracteristicas': [{'nombre': k, 'valor': v} for k, v in attributes.items()]}, tid=tid)
            props.append(p)
        print(f'Tenant {tid}: inmuebles demo preparados', flush=True)

        # Solo se contratan los cinco inmuebles nuevos destinados a escenarios financieros.
        contracts = api.call('/gestion_contractual/contratos', tid=tid)
        for index, p in enumerate(props[:5]):
            c = next((c for c in contracts if c['id_propiedad'] == p['id_propiedad']), None)
            if not c:
                total = float(p['precio']) * (12 if p['tipo_operacion'] == 'Alquiler' else 1)
                start = anchor - timedelta(days=[120, 150, 10, 100, 45][index] + tid)
                c = api.call('/gestion_contractual/contratos', {'id_cliente': clients[index % 3]['id_cliente'],
                    'id_propiedad': p['id_propiedad'], 'tipo_contrato': p['tipo_operacion'], 'monto_total': total,
                    'fecha_inicio': start.isoformat(), 'fecha_fin': (start + timedelta(days=365)).isoformat(),
                    'num_cuotas': [1, 8, 4, 12, 1][index], 'observacion': MARK + ' contrato ficticio'}, tid=tid)
            detail = api.call(f'/gestion_contractual/contratos/{c["id_contrato"]}', tid=tid)
            if index != 2 and not detail['pagos']:
                fraction = [1, .25, 0, 1/12, 1][index]
                api.call(f'/gestion_contractual/contratos/{c["id_contrato"]}/pagos',
                    {'monto': round(float(c['monto_total']) * fraction, 2), 'metodo_pago': ['Transferencia', 'QR', 'Efectivo'][index % 3],
                     'observacion': MARK + ' pago ficticio para pruebas'}, tid=tid)
            desired = 'Vendida' if p['tipo_operacion'] == 'Venta' else 'Alquilada'
            current = next(x for x in api.call('/modulo_inmuebles/propiedades', tid=tid) if x['id_propiedad'] == p['id_propiedad'])
            if current['estado'] != desired:
                api.call(f'/modulo_inmuebles/propiedades/{p["id_propiedad"]}/estado', {'estado': desired}, tid=tid, method='PUT')
        commissions = api.call('/api/comisiones', tid=tid)['comisiones']
        sale = next(c for c in commissions if c['id_contrato'] == next(c['id_contrato'] for c in api.call('/gestion_contractual/contratos', tid=tid) if c['id_propiedad'] == props[0]['id_propiedad']))
        if sale['estado'] != 'Liquidada': api.call(f'/api/comisiones/{sale["id"]}/liquidar', {}, tid=tid)

        available = [p for p in api.call('/modulo_inmuebles/propiedades', tid=tid) if p['estado'] == 'Disponible']
        assert len(available) >= 2
        promo_title = f'{MARK} Campaña inmobiliaria {tid}'
        if not any(p['titulo'] == promo_title for p in api.call('/api/promociones', tid=tid)):
            api.call('/api/promociones', {'id_propiedad': available[0]['id_propiedad'], 'titulo': promo_title,
                'descuento_pct': 5 + tid, 'inicio': anchor.isoformat(), 'fin': (anchor + timedelta(days=25)).isoformat()}, tid=tid)

        incidents = api.call('/api/mantenimiento', tid=tid)
        scenarios = [('Fuga de agua en cocina', 'Plomeria', 'Alta', 'En progreso'),
                     ('Revisión de iluminación', 'Electricidad', 'Media', 'Asignada'),
                     ('Mantenimiento de cerradura', 'Seguridad', 'Baja', 'Resuelta'),
                     ('Limpieza preventiva', 'Limpieza y plagas', 'Baja', 'Cerrada')]
        for index, (label, category, urgency, target) in enumerate(scenarios):
            title = f'{MARK} {tid}-{index+1} {label}'
            s = next((s for s in incidents if s['titulo'] == title), None)
            if not s:
                s = api.call('/api/mantenimiento', {'id_propiedad': props[index]['id_propiedad'], 'titulo': title,
                    'descripcion': 'Caso FICTICIO de demostración: ' + label + '. La fotografía adjunta es ilustrativa, no evidencia de un daño real.'}, tid=tid)
            detail = api.call(f'/api/mantenimiento/{s["id"]}', tid=tid)
            if not detail['fotos']: api.call(f'/api/mantenimiento/{s["id"]}/fotos', tid=tid, method='POST', multipart=multipart)
            for label_cost, amount in [('Materiales DEMO', 80 + index * 35 + tid * 10), ('Mano de obra DEMO', 120 + index * 50)]:
                detail = api.call(f'/api/mantenimiento/{s["id"]}', tid=tid)
                if not any(c['concepto'] == label_cost for c in detail['costos']):
                    api.call(f'/api/mantenimiento/{s["id"]}/costos', {'concepto': label_cost, 'monto': amount}, tid=tid)
            detail = api.call(f'/api/mantenimiento/{s["id"]}', tid=tid)
            if not detail.get('contratista'):
                api.call(f'/api/mantenimiento/{s["id"]}', {'contratista': f'{MARK} Servicios técnicos {tid}',
                    'categoria': category, 'urgencia': urgency, 'id_responsable': agent['ci_usuario']}, tid=tid, method='PUT')
            path = ['Asignada', 'En progreso', 'Resuelta', 'Cerrada']
            detail = api.call(f'/api/mantenimiento/{s["id"]}', tid=tid)
            if detail['estado'] == 'Recibida':
                api.call(f'/api/mantenimiento/{s["id"]}', {'estado': 'Asignada'}, tid=tid, method='PUT')
                detail['estado'] = 'Asignada'
            for step in path[path.index(detail['estado'])+1:path.index(target)+1]:
                api.call(f'/api/mantenimiento/{s["id"]}', {'estado': step, 'comentario': MARK + ' avance ficticio'}, tid=tid, method='PUT')

        visits = api.call('/api/visitas', tid=tid)
        for index, p in enumerate(available[:2]):
            comment = f'{MARK} visita {tid}-{index+1}'
            v = next((v for v in visits if v['comentario'] == comment), None)
            if not v:
                moment = datetime.combine(anchor + timedelta(days=3 + tid), datetime.min.time(), tzinfo=timezone.utc) + timedelta(hours=15 + index)
                v = api.call('/api/visitas', {'id_propiedad': p['id_propiedad'], 'id_cliente': clients[index]['id_cliente'],
                    'fecha_hora': moment.isoformat(), 'comentario': comment}, tid=tid)
            if index == 0 and v['estado'] == 'Programada':
                api.call(f'/api/visitas/{v["id"]}', {'estado': 'Confirmada'}, tid=tid, method='PUT')

        for account in [api, API(args.api_url).login(identities[0]['email'], identities[0]['password'])]:
            favorites = {f['id_propiedad'] for f in account.call('/api/favoritos', tid=tid)}
            feedback = {f['id_propiedad'] for f in account.call('/api/recomendaciones/feedback', tid=tid)}
            for index, p in enumerate(available[:2]):
                if p['id_propiedad'] not in favorites: account.call('/api/favoritos/' + str(p['id_propiedad']), {}, tid=tid)
                if p['id_propiedad'] not in feedback:
                    account.call('/api/recomendaciones/feedback', {'id_propiedad': p['id_propiedad'], 'valoracion': 5 - index,
                        'comentario': MARK + ' valoración ficticia para probar preferencias'}, tid=tid)
            if account is not api:
                name = MARK + ' Mi búsqueda de compra'
                if not any(a['nombre'] == name for a in account.call('/api/alertas', tid=tid)):
                    account.call('/api/alertas', {'nombre': name, 'criterios': {'tipo_operacion': 'Venta', 'precio_max': 180000}}, tid=tid)
        print(f'Tenant {tid}: contratos, pagos, comisiones, promociones, mantenimiento, visitas y preferencias listos', flush=True)

    seed_reports(api)

    summary = {}
    for tid in (1, 2, 3):
        props = api.call('/modulo_inmuebles/propiedades', tid=tid)
        current = {p['id_propiedad']: fingerprint(p) for p in props if p['id_propiedad'] in original[tid]}
        assert current == original[tid], 'Una propiedad anterior cambió; revisar.'
        zones = api.call('/api/analitica/zonas', tid=tid)
        assert sum(z['cierres'] for z in zones['zonas']) >= 3
        assert len([z for z in zones['zonas'] if z['cierres'] and z['latitud'] is not None]) >= 2
        dashboard = api.call('/api/gerencia/dashboard', tid=tid)
        assert dashboard['cartera']['total'] == len(props)
        assert api.call('/api/reportes/ejecutivo?formato=pdf', tid=tid, raw=True).startswith(b'%PDF')
        summary[tid] = {'propiedades': len(props), 'clientes': len(api.call('/modulo_inmuebles/clientes', tid=tid)),
            'contratos': len(api.call('/gestion_contractual/contratos', tid=tid)),
            'incidencias': len(api.call('/api/mantenimiento', tid=tid)), 'visitas': len(api.call('/api/visitas', tid=tid)),
            'ventas_mapa': sum(z['cierres'] for z in zones['zonas'])}
    assert len(api.call('/modulo_inmuebles/propiedades', tid='all')) == sum(s['propiedades'] for s in summary.values())
    state['verified'] = summary; save()
    print(json.dumps({'verificado': summary, 'originales': 'conservados'}, ensure_ascii=True), flush=True)


if __name__ == '__main__':
    main()
