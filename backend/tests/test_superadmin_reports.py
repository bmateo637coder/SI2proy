import json
from urllib.error import HTTPError

from .conftest import headers
from database import models as m


def test_superadmin_selected_company_is_request_scoped(api):
    client, factory = api
    original = headers('super', None)
    selected = {**original, 'X-Tenant-ID': '1'}
    report = {'entidad': 'propiedades', 'columnas': ['id_propiedad', 'precio']}
    assert client.post('/reportes/generar', json=report, headers=original).status_code == 403
    response = client.post('/reportes/generar', json=report, headers=selected)
    assert response.status_code == 200, response.text
    assert [r['id_propiedad'] for r in response.json()['data']] == [1, 2]
    assert client.get('/gestion_contractual/contratos', headers=selected).status_code == 200
    assert client.get('/api/saas/sucursales', headers=selected).json()[0]['id_sucursal'] == 1
    assert len(client.get('/modulo_inmuebles/clientes', headers=selected).json()) == 1
    assert client.get('/users/me', headers=selected).json()['id_tenant'] is None
    with factory() as db:
        assert db.get(m.Usuario, 'super').id_tenant is None
    assert client.get('/api/saas/sucursales', headers={**original, 'X-Tenant-ID': '9999'}).status_code == 404
    assert client.get('/modulo_inmuebles/clientes', headers={**headers(), 'X-Tenant-ID': '2'}).status_code == 403


def test_reports_validate_filters_and_list_actual_clients(api):
    client, _ = api
    report = {'entidad': 'propiedades', 'columnas': ['titulo', 'precio']}
    for operator, value in [('like', '100'), ('lt', 'text'), ('eq', None), ('eq', True), ('lt', 'NaN')]:
        response = client.post('/reportes/generar', headers=headers(), json={**report,
            'filtros': [{'columna': 'precio', 'operador': operator, 'valor': value}]})
        assert response.status_code == 422, response.text
    response = client.post('/reportes/generar', headers=headers(), json={**report,
        'filtros': [{'columna': 'precio', 'operador': 'gte', 'valor': '1500'}]})
    assert [r['precio'] for r in response.json()['data']] == [2000]
    result = client.post('/reportes/generar', headers=headers(), json={**report, 'limite': 1}).json()
    assert result['truncado'] and len(result['data']) == 1
    result = client.post('/reportes/generar', headers=headers(), json={'entidad': 'clientes', 'columnas': ['ci']})
    assert result.json()['data'] == [{'ci': 'client1'}]


def test_saved_reports_isolate_company_and_validate_json(api):
    client, _ = api
    a = {**headers('super', None), 'X-Tenant-ID': '1'}
    b = {**headers('super', None), 'X-Tenant-ID': '2'}
    body = {'nombre': 'Mi cartera', 'configuracion': json.dumps({
        'entidad': 'propiedades', 'columnas': ['titulo'], 'ordenColumna': 'titulo', 'ordenDireccion': 'asc'})}
    assert client.post('/reportes/guardados', json=body, headers=a).status_code == 200
    assert len(client.get('/reportes/guardados', headers=a).json()) == 1
    assert client.get('/reportes/guardados', headers=b).json() == []
    for value in ['invalid', 'null', '[]', '{"entidad":"usuarios","columnas":["password_hash"]}']:
        assert client.post('/reportes/guardados', json={**body, 'configuracion': value}, headers=a).status_code == 422


def test_gemini_configuration_failure_and_validated_results(api, monkeypatch):
    import ia_router
    client, _ = api
    assert client.get('/api/ia/estado', headers=headers()).json()['configurada'] is False
    description = {'titulo': 'Casa', 'direccion': 'Centro', 'precio': 150000, 'tipo_operacion': 'Venta'}
    response = client.post('/api/ia/generar-descripcion', json=description, headers=headers())
    assert response.status_code == 503 and 'GEMINI_API_KEY' in response.json()['detail']
    monkeypatch.setenv('GEMINI_API_KEY', 'private-test-key')
    monkeypatch.setattr(ia_router, 'generate_text', lambda *a, **k: json.dumps({
        'entidad': 'clientes', 'columnas': ['nombre'], 'filtros': [], 'ordenColumna': 'nombre', 'ordenDireccion': 'asc'}))
    response = client.post('/api/ia/reporte-voz', json={'texto': 'Mostrar clientes'}, headers=headers())
    assert response.status_code == 200 and response.json()['modo'] == 'gemini'
    monkeypatch.setattr(ia_router, 'generate_text', lambda *a, **k: '{"entidad":"usuarios","columnas":["password_hash"]}')
    assert client.post('/api/ia/reporte-voz', json={'texto': 'Mostrar usuarios'}, headers=headers()).status_code == 422


def test_gemini_errors_do_not_leak_key(monkeypatch):
    import generative_client as g
    monkeypatch.setenv('GEMINI_API_KEY', 'private-test-key')
    def fail(*args, **kwargs):
        raise HTTPError('https://provider/?key=private-test-key', 429, 'quota', {}, None)
    monkeypatch.setattr(g, 'urlopen', fail)
    try:
        g.generate_text('Hola')
        assert False, 'Expected provider error'
    except g.GeminiError as error:
        assert 'cuota' in str(error)
        assert 'private-test-key' not in str(error)


def test_invalid_local_report_dates_return_validation_error(api):
    client, _ = api
    for request in ['Ventas de 2026-13-99', 'Ventas top 99999', 'Ventas de 2026-10-30 a 2026-01-01']:
        assert client.post('/api/analitica/reporte', json={'texto': request}, headers=headers()).status_code == 422


def test_property_edits_preserve_and_enable_analytics_and_numeric_filters(api):
    from analitica_ml import property_features
    client, factory = api
    with factory() as db:
        db.get(m.Propiedad, 1).descripcion = 'Descripción que se debe conservar'
        db.add(m.Caracteristica(id_propiedad=1, nombre='Cuartos', valor='sin datos'))
        db.commit()
    result = client.get('/modulo_inmuebles/propiedades/catalogo?cuartos=2', headers=headers())
    assert result.status_code == 200 and result.json() == []
    selected = {**headers('super', None), 'X-Tenant-ID': '1'}
    body = {'id_propietario': 1, 'id_agente': 1, 'titulo': 'Casa actualizada', 'direccion': 'Centro',
            'precio': 150000, 'tipo_operacion': 'Venta', 'caracteristicas': [
                {'nombre': 'Cuartos', 'valor': '3'}, {'nombre': 'Superficie', 'valor': '120'}, {'nombre': 'Zona', 'valor': 'Premium'}]}
    result = client.put('/modulo_inmuebles/propiedades/1', json=body, headers=selected)
    assert result.status_code == 200, result.text
    assert result.json()['descripcion'] == 'Descripción que se debe conservar'
    with factory() as db:
        assert property_features(db.get(m.Propiedad, 1)) == [120, 3, 2]
    result = client.get('/modulo_inmuebles/propiedades/catalogo?cuartos=2&metros_min=100', headers=selected)
    assert [p['id_propiedad'] for p in result.json()] == [1]
