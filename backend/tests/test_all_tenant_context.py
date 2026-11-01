import pytest
from starlette.websockets import WebSocketDisconnect
from .conftest import headers
from database import models as m


def all_headers():
    return {**headers('super', None), 'X-Tenant-Scope': 'all'}


def test_all_scope_applies_to_existing_catalog_lists_and_reports(api):
    client, factory = api
    auth = all_headers()
    for path, count in [('propiedades/catalogo', 3), ('propiedades', 3), ('clientes', 2), ('propietarios', 2), ('agentes', 2)]:
        response = client.get('/modulo_inmuebles/' + path, headers=auth)
        assert response.status_code == 200, response.text
        assert len(response.json()) == count
        assert {r['id_tenant'] for r in response.json()} == {1, 2}
        assert all(r['inmobiliaria'] for r in response.json())
    spec = {'entidad': 'propiedades', 'columnas': ['titulo', 'precio']}
    response = client.post('/reportes/generar', json=spec, headers=auth)
    assert response.status_code == 200, response.text
    assert response.json()['columnas'] == ['inmobiliaria', 'titulo', 'precio']
    assert len(response.json()['data']) == 3
    assert {r['inmobiliaria'] for r in response.json()['data']} == {'Empresa 1', 'Empresa 2'}
    response = client.post('/reportes/generar', json={'entidad': 'clientes', 'columnas': ['nombre']}, headers=auth)
    assert len(response.json()['data']) == 2
    response = client.post('/reportes/generar', json={**spec, 'filtros': [{'columna': 'precio', 'operador': 'gt', 'valor': 1500}]}, headers=auth)
    assert len(response.json()['data']) == 2
    assert client.get('/modulo_inmuebles/propiedades/catalogo?tipo_operacion=Alquiler', headers=auth).json() == []
    single = client.post('/reportes/generar', json=spec, headers={**headers('super', None), 'X-Tenant-ID': '2'}).json()
    assert len(single['data']) == 1 and single['columnas'] == spec['columnas']
    with factory() as db:
        assert db.get(m.Usuario, 'super').id_tenant is None


def test_all_scope_is_explicit_superadmin_read_access_and_blocks_ambiguous_writes(api):
    client, factory = api
    for identity in (headers(), headers('agent1'), headers('client1')):
        auth = {**identity, 'X-Tenant-Scope': 'all'}
        assert client.get('/modulo_inmuebles/propiedades/catalogo', headers=auth).status_code == 403
        assert client.post('/reportes/generar', json={'entidad': 'propiedades', 'columnas': ['titulo']}, headers=auth).status_code == 403
    assert client.get('/modulo_inmuebles/propiedades/catalogo', headers={**all_headers(), 'X-Tenant-ID': '1'}).status_code == 422
    assert client.get('/modulo_inmuebles/propiedades/catalogo', headers={**headers('super', None), 'X-Tenant-Scope': 'invalid'}).status_code == 422
    assert client.get('/modulo_inmuebles/propiedades/catalogo', headers=headers('super', None)).json() == []
    for method, path in [('post', '/modulo_inmuebles/propiedades'), ('delete', '/modulo_inmuebles/propiedades/1'),
                         ('put', '/modulo_inmuebles/propiedades/1/estado'), ('post', '/gestion_contractual/contratos'),
                         ('post', '/api/offline/sincronizar'), ('post', '/reportes/guardados')]:
        response = getattr(client, method)(path, headers=all_headers(), **({'json': {}} if method != 'delete' else {}))
        assert response.status_code == 403, (path, response.text)
    with factory() as db:
        assert db.query(m.Propiedad).count() == 3
    assert {r['id_tenant'] for r in client.get('/modulo_inmuebles/propiedades/catalogo', headers=headers()).json()} == {1}


def test_all_scope_contracts_plans_and_aggregate_reports(api):
    from saas import today
    client, factory = api
    with factory() as db:
        for tid, pid in [(1, 1), (2, 3)]:
            db.add(m.Contrato(id_tenant=tid, id_propiedad=pid, id_cliente=tid, id_agente=tid,
                              tipo_contrato='Venta', monto_total=1000 * tid, fecha_inicio=today()))
        db.commit()
    auth = all_headers()
    response = client.get('/gestion_contractual/contratos', headers=auth)
    assert response.status_code == 200, response.text
    assert len(response.json()) == 2 and all(r['inmobiliaria'] for r in response.json())
    assert client.get('/gestion_contractual/contratos/' + str(response.json()[0]['id_contrato']), headers=auth).status_code == 200
    response = client.get('/api/saas/sucursales', headers=auth)
    assert len(response.json()) == 2 and all(r['inmobiliaria'] for r in response.json())
    for route in ('convencional', 'reporte'):
        body = {'tipo': 'cartera_estado'} if route == 'convencional' else {'texto': 'Cartera actual por estado'}
        response = client.post('/api/analitica/' + route, json=body, headers=auth)
        assert response.status_code == 200, response.text
        report = response.json()
        assert report['alcance'] == 'todas' and report['columnas'][0] == 'Inmobiliaria'
        assert {r[0] for r in report['filas']} == {'Empresa 1', 'Empresa 2'}
        assert sum(r[2] for r in report['filas']) == 3
    report = client.post('/api/analitica/convencional', json={'tipo': 'ventas_sucursal', 'id_sucursal': 2}, headers=auth).json()
    assert {r[0] for r in report['filas']} == {'Empresa 2'}
    assert client.get('/api/ia/estado', headers=auth).json()['plan_habilitado'] is True


def test_all_scope_machine_learning_labels_both_companies(api, monkeypatch):
    import analitica_ml
    client, factory = api
    with factory() as db:
        for pid in (1, 3):
            db.add_all([m.Caracteristica(id_propiedad=pid, nombre=k, valor=v) for k, v in
                        [('Metros Cuadrados', '100'), ('Cuartos', '2'), ('Zona', 'Estándar')]])
        db.commit()
    class Regressor:
        def predict(self, data): return [150000] * len(data)
    class Scaler:
        def transform(self, data): return data
    class Cluster:
        def predict(self, data): return [0] * len(data)
    monkeypatch.setattr(analitica_ml, 'train_models', lambda: (Regressor(), Scaler(), Cluster(), {}, None))
    response = client.get('/api/analitica/dashboard', headers=all_headers())
    assert response.status_code == 200, response.text
    assert {r['inmobiliaria'] for r in response.json()['propiedades']} == {'Empresa 1', 'Empresa 2'}
    assert response.json()['omitidas'] == 1


def test_websocket_all_scope_is_superadmin_only(api, monkeypatch):
    from database import database
    from ws_manager import manager
    client, factory = api
    monkeypatch.setattr(database, 'SessionLocal', factory)
    super_token = headers('super', None)['Authorization'].split(' ', 1)[1]
    normal_token = headers()['Authorization'].split(' ', 1)[1]
    with client.websocket_connect('/ws/propiedades?scope=all', subprotocols=['raices', super_token]):
        assert None in manager.active_connections.values()
    with client.websocket_connect('/ws/propiedades?id_tenant=2', subprotocols=['raices', super_token]):
        assert 2 in manager.active_connections.values()
    for url in ('/ws/propiedades?scope=all', '/ws/propiedades?id_tenant=2'):
        with pytest.raises(WebSocketDisconnect) as exc:
            with client.websocket_connect(url, subprotocols=['raices', normal_token]):
                pass
        assert exc.value.code == 1008
