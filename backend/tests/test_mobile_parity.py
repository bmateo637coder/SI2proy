from types import SimpleNamespace
from .conftest import headers


def test_property_photos_are_in_database_and_remain_readable(api):
    from property_media import FotoInmueble
    client, factory = api
    photo = b'\x89PNG\r\n\x1a\nDEMO'
    response = client.post('/upload', headers=headers(), files={'file': ('foto.png', photo, 'image/png')})
    assert response.status_code == 200, response.text
    url = response.json()['url']
    with factory() as db:
        assert db.get(FotoInmueble, url.rsplit('/', 1)[-1]).contenido == photo
    fetched = client.get(url)
    assert fetched.status_code == 200
    assert fetched.content == photo
    assert fetched.headers['content-type'] == 'image/png'
    assert client.post('/upload', headers=headers('client1', 1), files={'file': ('foto.png', photo, 'image/png')}).status_code == 403
    assert client.post('/upload', headers=headers(), files={'file': ('foto.png', b'no es imagen', 'image/png')}).status_code == 415


def test_restore_uses_dsn_auth_atomic_transaction_and_compatible_dump(api, monkeypatch):
    import main
    import backup_service
    client, _ = api
    captured = {}
    monkeypatch.delenv('POSTGRES_PASSWORD', raising=False)
    monkeypatch.setattr(backup_service, '_pg_env', lambda: {'PGPASSWORD': 'test-only'})
    monkeypatch.setattr(main, 'uri_conexion', lambda: 'postgresql://test-only@localhost/test')
    def run(command, **options):
        captured.update(command=command, options=options)
        with open(command[command.index('-f') + 1], 'rb') as file:
            captured['sql'] = file.read()
        return SimpleNamespace(returncode=0, stderr='')
    monkeypatch.setattr(main.subprocess, 'run', run)
    response = client.post('/admin/restore', headers=headers('super', None), files={'file': ('backup.sql', b'SET transaction_timeout = 0;\nSELECT 1;', 'text/plain')})
    assert response.status_code == 200, response.text
    assert '--single-transaction' in captured['command']
    assert '--set=ON_ERROR_STOP=1' in captured['command']
    assert captured['options']['env']['PGPASSWORD'] == 'test-only'
    assert b'transaction_timeout' not in captured['sql']


def test_restore_failure_is_not_reported_as_success(api, monkeypatch):
    import main
    client, _ = api
    monkeypatch.setattr(main, 'uri_conexion', lambda: 'postgresql://test-only@localhost/test')
    monkeypatch.setattr(main.subprocess, 'run', lambda *args, **kwargs: SimpleNamespace(returncode=1, stderr='private server details'))
    response = client.post('/admin/restore', headers=headers('super', None), files={'file': ('backup.sql', b'INVALID SQL;', 'text/plain')})
    assert response.status_code == 500
    assert 'revertida' in response.json()['detail']
    assert 'private server details' not in response.text


def test_legacy_agent_role_can_manage_its_maintenance(api):
    from database import models as m
    client, factory = api
    with factory() as db:
        db.get(m.Rol, 3).nombre = 'Agente Raices'
        db.commit()
    response = client.post('/api/mantenimiento', headers=headers('agent1', 1), json={
        'id_propiedad': 1, 'titulo': 'Reparar iluminación', 'descripcion': 'Falla en la luz de cocina.'})
    assert response.status_code == 201, response.text
    rows = client.get('/api/mantenimiento', headers=headers('agent1', 1))
    assert rows.status_code == 200
    assert any(r['id'] == response.json()['id'] for r in rows.json())


def test_people_delete_preserves_linked_property_and_visit_history(api):
    from datetime import datetime, timedelta
    client, _ = api
    assert client.delete('/modulo_inmuebles/propietarios/1', headers=headers()).status_code == 409
    visit = client.post('/api/visitas', headers=headers(), json={'id_propiedad': 1, 'id_cliente': 1,
        'fecha_hora': (datetime.utcnow() + timedelta(days=3)).isoformat()})
    assert visit.status_code == 201, visit.text
    deleted = client.delete('/modulo_inmuebles/clientes/1', headers=headers())
    assert deleted.status_code == 409, deleted.text
    assert any(c['id_cliente'] == 1 for c in client.get('/modulo_inmuebles/clientes', headers=headers()).json())


def test_property_form_exposes_branch_and_can_change_it(api):
    client, _ = api
    row = client.get('/modulo_inmuebles/propiedades', headers=headers()).json()[0]
    assert row['id_sucursal'] == 1
    branch = client.post('/api/saas/sucursales', headers=headers(), json={'nombre': 'Segunda sede', 'direccion': 'Prueba', 'activa': True})
    assert branch.status_code == 201, branch.text
    body = {k: row[k] for k in ('id_propietario', 'id_agente', 'titulo', 'descripcion', 'direccion', 'precio', 'tipo_operacion')}
    body['id_sucursal'] = branch.json()['id_sucursal']
    updated = client.put(f'/modulo_inmuebles/propiedades/{row["id_propiedad"]}', headers=headers(), json=body)
    assert updated.status_code == 200, updated.text
    assert updated.json()['id_sucursal'] == branch.json()['id_sucursal']


def test_property_delete_preserves_maintenance_and_contract_history(api):
    from database import models as m
    from saas import today
    client, factory = api
    incident = client.post('/api/mantenimiento', headers=headers(), json={'id_propiedad': 1,
        'titulo': 'Revisión de cocina', 'descripcion': 'Problema de iluminación.'})
    assert incident.status_code == 201, incident.text
    assert client.delete('/modulo_inmuebles/propiedades/1', headers=headers()).status_code == 409
    with factory() as db:
        db.add(m.Contrato(id_tenant=1, id_cliente=1, id_agente=1, id_propiedad=2,
            tipo_contrato='Alquiler', monto_total=500, fecha_inicio=today()))
        db.commit()
    assert client.delete('/modulo_inmuebles/propiedades/2', headers=headers()).status_code == 409
    with factory() as db:
        assert db.query(m.Contrato).count() == 1
        assert db.get(m.Propiedad, 1) is not None
        assert db.get(m.Propiedad, 2) is not None
