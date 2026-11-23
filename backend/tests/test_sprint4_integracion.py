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


def test_visits_are_persisted_isolated_and_no_double_booking(api):
    from datetime import datetime
    client, _ = api
    data = {'id_propiedad': 1, 'fecha_hora': (datetime.utcnow()+timedelta(days=2)).isoformat()+'Z', 'comentario': 'Visitar patio'}
    first = client.post('/api/visitas', headers=headers('client1', 1), json=data)
    assert first.status_code == 201, first.text
    ident = first.json()['id_visita']
    assert client.get('/api/visitas', headers=headers('client1', 1)).json()[0]['id_visita'] == ident
    assert client.get('/api/visitas', headers=headers('client2', 2)).json() == []
    assert client.post('/api/visitas', headers=headers('client1', 1), json=data).status_code == 409
    assert client.put(f'/api/visitas/{ident}', headers=headers('client2', 2), json={'estado':'Cancelada'}).status_code == 404
    assert client.put(f'/api/visitas/{ident}', headers=headers('client1', 1), json={'estado':'Cancelada'}).status_code == 200
    assert client.get('/api/bandeja', headers=headers('client1', 1)).json()['no_leidas'] >= 1


def test_audit_history_is_encrypted_and_persistent(api, monkeypatch, tmp_path):
    import logger
    from sqlalchemy.orm import Session
    _, factory = api
    monkeypatch.setattr(logger, 'engine', factory.kw['bind'])
    monkeypatch.setattr(logger, 'LOG_FILE_PATH', str(tmp_path/'fallback.log'))
    logger.log_accion_segura('127.0.0.1', 'SaaS', 'Evento de prueba persistente')
    with Session(factory.kw['bind']) as db:
        encrypted = db.query(logger.RegistroAuditoria).one().contenido
        assert 'Evento de prueba' not in encrypted
    rows = logger.leer_bitacora_segura(logger.DEV_SECRET_KEY.decode())
    assert rows[0]['accion'] == 'Evento de prueba persistente'
    assert logger.importar_bitacora(logger.DEV_SECRET_KEY.decode(), rows) == 1
    assert logger.importar_bitacora(logger.DEV_SECRET_KEY.decode(), rows) == 0


def test_android_alert_credential_is_read_only_revocable_and_account_bound(api):
    client, factory = api
    from sprint4_notificaciones import notificar
    with factory() as db:
        notificar(db, 'client1', 'prueba', 'Mensaje privado uno')
        notificar(db, 'client2', 'prueba', 'Mensaje privado dos')
        db.commit()
    registered = client.put('/api/notificaciones/avisos/dispositivo', headers=headers('client1', 1), json={'dispositivo': 'telefono'})
    assert registered.status_code == 200, registered.text
    credential = {'X-Avisos-Token': registered.json()['token']}
    data = client.get('/api/notificaciones/avisos', headers=credential)
    assert [n['titulo'] for n in data.json()['notificaciones']] == ['Mensaje privado uno']
    assert client.get('/api/gerencia/dashboard', headers=credential).status_code == 401
    assert client.get('/api/notificaciones/avisos', headers={'X-Avisos-Token': 'inventado'}).status_code == 401
    second = client.put('/api/notificaciones/avisos/dispositivo', headers=headers('client2', 2), json={'dispositivo': 'telefono'})
    assert client.get('/api/notificaciones/avisos', headers=credential).status_code == 401
    credential = {'X-Avisos-Token': second.json()['token']}
    assert client.get('/api/notificaciones/avisos', headers=credential).json()['notificaciones'][0]['titulo'] == 'Mensaje privado dos'
    client.delete('/api/notificaciones/avisos/dispositivo/telefono', headers=headers('client2', 2))
    assert client.get('/api/notificaciones/avisos', headers=credential).status_code == 401


def test_webpush_generates_stable_keys_and_encrypts_real_payload(api, monkeypatch):
    import base64
    import requests
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives import serialization
    client, _ = api
    config = client.get('/api/notificaciones/webpush/config', headers=headers('client1', 1))
    assert config.status_code == 200, config.text
    assert len(config.json()['clave_publica']) == 87
    assert client.get('/api/notificaciones/webpush/config', headers=headers('client2', 2)).json() == config.json()
    encode = lambda b: base64.urlsafe_b64encode(b).decode().rstrip('=')
    key = ec.generate_private_key(ec.SECP256R1()).public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    body = {'dispositivo':'web-uno', 'endpoint':'https://fcm.googleapis.com/fcm/send/prueba', 'keys':{'p256dh':encode(key),'auth':encode(b'1234567890123456')}}
    bad = body | {'endpoint':'https://127.0.0.1/privado'}
    assert client.put('/api/notificaciones/webpush', headers=headers('client1', 1), json=bad).status_code == 422
    assert client.put('/api/notificaciones/webpush', headers=headers('client1', 1), json=body).status_code == 200
    deliveries = []
    def accept(url, data=None, headers=None, **kwargs):
        deliveries.append((url, data, headers))
        response = requests.Response(); response.status_code = 201; response._content = b''
        return response
    monkeypatch.setattr(requests, 'post', accept)
    result = client.post('/api/notificaciones/prueba', headers=headers('client1', 1))
    assert result.status_code == 200 and result.json()['push_enviado'], result.text
    assert len(deliveries) == 1
    assert 'authorization' in {k.lower() for k in deliveries[0][2]}
    assert b'notificaciones activadas' not in deliveries[0][1]
    assert client.post('/api/notificaciones/prueba', headers=headers('client2', 2)).json()['push_enviado'] is False


def test_daily_backup_does_not_block_api_event_loop(monkeypatch):
    import asyncio
    import threading
    import scheduler
    release = threading.Event()
    monkeypatch.setattr(scheduler, '_backup_diario', lambda: release.wait(2))
    monkeypatch.setattr(scheduler, '_registrar_vencimientos', lambda: None)
    async def scenario():
        work = asyncio.create_task(scheduler._ejecutar_tareas())
        try:
            await asyncio.sleep(0.05)
            assert not work.done(), 'La tarea diaria debe permitir que la API atienda otras solicitudes.'
        finally:
            release.set()
            await asyncio.wait_for(work, timeout=3)
    asyncio.run(scenario())
