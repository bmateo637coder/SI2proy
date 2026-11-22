from datetime import timedelta
from .conftest import headers
from database import models as m
from saas import today


def test_favorites_search_feedback_and_tenant_isolation(api):
    client, _ = api
    assert client.post('/api/favoritos/1', headers=headers('client1', 1)).status_code == 201
    assert client.post('/api/favoritos/3', headers=headers('client1', 1)).status_code == 404
    rows = client.get('/api/favoritos', headers=headers('client1', 1)).json()
    assert [r['id_propiedad'] for r in rows] == [1]
    assert client.get('/api/favoritos', headers=headers('client2', 2)).json() == []
    result = client.post('/api/busqueda-semantica', headers=headers('client1', 1), json={'texto': 'casa en venta hasta 1500'}).json()
    assert [r['id_propiedad'] for r in result['resultados']] == [1]
    response = client.post('/api/recomendaciones/feedback', headers=headers('client1', 1), json={'id_propiedad': 2, 'valoracion': 1, 'comentario': 'No me interesa'})
    assert response.status_code == 200, response.text
    assert all(r['propiedad']['id_propiedad'] != 2 for r in client.get('/api/recomendaciones', headers=headers('client1', 1)).json()['recomendaciones'])


def test_alert_and_inbox_belong_to_account(api):
    client, factory = api
    a = client.post('/api/alertas', headers=headers('client1', 1), json={'nombre': 'Presupuesto', 'criterios': {'precio_max': 1500}})
    assert a.status_code == 201, a.text
    assert client.put(f'/api/alertas/{a.json()["id"]}', headers=headers('client2', 2), json={'activa': False}).status_code == 404
    from sprint4_fidelizacion import procesar_alertas
    with factory() as db:
        assert procesar_alertas(db, db.get(m.Propiedad, 3)) == 0
        assert procesar_alertas(db, db.get(m.Propiedad, 1)) == 1
        assert procesar_alertas(db, db.get(m.Propiedad, 1)) == 0
    inbox = client.get('/api/bandeja', headers=headers('client1', 1))
    assert inbox.status_code == 200, inbox.text
    assert inbox.json()['no_leidas'] == 1
    assert client.get('/api/bandeja', headers=headers('client2', 2)).json()['no_leidas'] == 0


def test_maintenance_workflow_photos_costs_and_contractors(api):
    client, _ = api
    data = {'id_propiedad': 1, 'titulo': 'Fuga de agua', 'descripcion': 'El baño tiene una fuga urgente'}
    created = client.post('/api/mantenimiento', json=data, headers=headers())
    assert created.status_code == 201, created.text
    sid = created.json()['id']
    assert created.json()['estado'] == 'Asignada'
    assert client.get(f'/api/mantenimiento/{sid}', headers=headers('admin2', 2)).status_code == 404
    photo = client.post(f'/api/mantenimiento/{sid}/fotos', headers=headers(), files={'file': ('foto.png', b'\x89PNG\r\n\x1a\nTEST', 'image/png')})
    assert photo.status_code == 201, photo.text
    changed = client.put(f'/api/mantenimiento/{sid}', headers=headers(), json={'estado': 'En progreso', 'contratista': 'Plomero de prueba'})
    assert changed.status_code == 200, changed.text
    cost = client.post(f'/api/mantenimiento/{sid}/costos', headers=headers(), json={'concepto': 'Reparación', 'monto': '120.50'})
    assert cost.status_code == 201, cost.text
    assert float(cost.json()['costo_total']) == 120.50
    reopened = client.get(f'/api/mantenimiento/{sid}', headers=headers()).json()
    assert reopened['contratista'] == 'Plomero de prueba'
    assert reopened['fotos'][0]['url'].startswith('data:image/png;base64,')


def test_heatmap_counts_sales_not_other_contracts_and_global_scope(api):
    client, factory = api
    with factory() as db:
        for pid, tid, kind in [(1, 1, 'Venta'), (2, 1, 'Alquiler'), (3, 2, 'Venta')]:
            db.add(m.Contrato(id_tenant=tid, id_cliente=tid, id_propiedad=pid, id_agente=tid,
                             tipo_contrato=kind, monto_total=100, fecha_inicio=today()))
        db.commit()
    assert sum(r['cierres'] for r in client.get('/api/analitica/zonas', headers=headers()).json()['zonas']) == 1
    global_headers = headers('super', None) | {'X-Tenant-Scope': 'all'}
    response = client.get('/api/analitica/zonas', headers=global_headers)
    assert response.status_code == 200, response.text
    assert sum(r['cierres'] for r in response.json()['zonas']) == 2
    assert len(response.json()['zonas']) == 2
    report = client.get('/api/reportes/ejecutivo?formato=pdf', headers=global_headers)
    assert report.status_code == 200 and report.content.startswith(b'%PDF')


def test_promo_dates_scope_and_notifications_configuration(api):
    client, _ = api
    data = {'id_propiedad': 1, 'titulo': 'Oferta', 'descuento_pct': '10.50', 'inicio': str(today()), 'fin': str(today() + timedelta(days=2))}
    result = client.post('/api/promociones', headers=headers(), json=data)
    assert result.status_code == 201, result.text
    assert float(result.json()['precio_promocional']) == 895
    assert client.delete(f'/api/promociones/{result.json()["id"]}', headers=headers('admin2', 2)).status_code == 404
    data['fin'] = str(today() - timedelta(days=1))
    assert client.post('/api/promociones', headers=headers(), json=data).status_code == 422
    config = client.get('/api/notificaciones/config', headers=headers()).json()
    assert 'smtp_configurado' in config and 'firebase' in config


def test_sync_idempotency_and_optimistic_conflict(api):
    from uuid import uuid4
    client, _ = api
    command = {'uuid': str(uuid4()), 'metodo': 'POST', 'ruta': '/api/mantenimiento',
               'datos': {'id_propiedad': 1, 'titulo': 'Incidencia de prueba', 'descripcion': 'Una fuga de agua en el baño'}}
    first = client.post('/api/servicios/sync', headers=headers(), json=command)
    assert first.status_code == 200, first.text
    assert client.post('/api/servicios/sync', headers=headers(), json=command).json() == first.json()
    assert len(client.get('/api/mantenimiento', headers=headers()).json()) == 1
    sid = first.json()['id']
    client.put(f'/api/mantenimiento/{sid}', headers=headers(), json={'contratista': 'Actualizado desde la web'})
    stale = {'uuid': str(uuid4()), 'metodo': 'PUT', 'ruta': f'/api/mantenimiento/{sid}', 'version': first.json()['version'], 'datos': {'estado': 'En progreso'}}
    conflict = client.post('/api/servicios/sync', headers=headers(), json=stale)
    assert conflict.status_code == 409, conflict.text
    assert conflict.json()['detail']['servidor']['contratista'] == 'Actualizado desde la web'
    assert client.get(f'/api/mantenimiento/{sid}', headers=headers()).json()['estado'] == first.json()['estado']
    bad = {'uuid': str(uuid4()), 'metodo': 'POST', 'ruta': '/api/alertas', 'datos': {}}
    assert client.post('/api/servicios/sync', headers=headers(), json=bad).status_code == 422
