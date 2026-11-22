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
