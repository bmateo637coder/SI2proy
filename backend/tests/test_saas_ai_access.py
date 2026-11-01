import pytest
from database import models as m
from .conftest import headers


@pytest.mark.parametrize('tenant', [1, 2])
def test_superadmin_ai_in_selected_company_ignores_tenant_plan(api, monkeypatch, tenant):
    client, _ = api
    auth = {**headers('super', None), 'X-Tenant-ID': str(tenant)}
    assert client.get('/api/ia/estado', headers=auth).json()['plan_habilitado'] is True
    response = client.post('/api/analitica/reporte', json={'texto': 'Cartera actual por estado'}, headers=auth)
    assert response.status_code == 200, response.text
    assert response.json()['id_tenant'] == tenant
    monkeypatch.setattr('ia_router.generate_text', lambda *args, **kwargs: 'OK')
    assert client.post('/api/ia/probar', json={}, headers=auth).status_code == 200
    result = client.post('/api/ia/generar-descripcion', json={
        'titulo': 'Casa de prueba', 'direccion': 'Centro', 'precio': 1000, 'tipo_operacion': 'Venta',
    }, headers=auth)
    assert result.status_code == 200, result.text


def test_basic_company_accounts_keep_plan_limits(api, monkeypatch):
    client, _ = api
    monkeypatch.setattr('ia_router.generate_text', lambda *args, **kwargs: 'OK')
    auth = headers('admin2', 2)
    assert client.get('/api/ia/estado', headers=auth).json()['plan_habilitado'] is False
    assert client.post('/api/ia/probar', json={}, headers=auth).status_code == 403
    assert client.post('/api/analitica/reporte', json={'texto': 'Cartera actual por estado'}, headers=auth).status_code == 403


def test_superadmin_can_audit_reports_in_suspended_company(api):
    client, factory = api
    with factory() as db:
        db.get(m.Suscripcion, 2).estado = 'suspendida'
        db.commit()
    auth = {**headers('super', None), 'X-Tenant-ID': '2'}
    assert client.post('/api/analitica/convencional', json={'tipo': 'cartera_estado'}, headers=auth).status_code == 200
    assert client.post('/api/analitica/reporte', json={'texto': 'Cartera actual por estado'}, headers=auth).status_code == 200
    assert client.post('/api/analitica/convencional', json={'tipo': 'cartera_estado'}, headers=headers('admin2', 2)).status_code == 402
