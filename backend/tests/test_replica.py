from uuid import uuid4
from .conftest import headers
from database import models as m


def test_snapshot_complete_authorized_and_no_secrets(api):
    client, _ = api
    data = client.get('/api/replica/datos', headers=headers()).json()
    assert data['completo'] is True
    assert data['ci_usuario'] == 'admin1'
    assert data['datos']['propiedades']
    assert all(p['id_tenant'] == 1 for p in data['datos']['propiedades'])
    assert 'password' not in str(data).lower()
    assert 'propiedad:1' in data['huellas']
    assert client.get('/api/replica/datos', headers=headers('client1')).status_code == 403
    all_data = client.get('/api/replica/datos', headers={**headers('super', None), 'X-Tenant-Scope': 'all'}).json()
    assert {p['id_tenant'] for p in all_data['datos']['propiedades']} == {1, 2}


def change(**kwargs):
    return {'uuid': str(uuid4()), 'id_tenant': 1, 'ci_usuario': 'admin1', **kwargs}


def test_offline_contract_conflict_no_overwrite_and_retries_idempotent(api):
    client, factory = api
    data = client.get('/api/replica/datos', headers=headers()).json()
    op = change(tipo='contrato.crear', base=data['huellas']['propiedad:1'], datos={
        'id_cliente': 1, 'id_propiedad': 1, 'tipo_contrato': 'Venta', 'monto_total': 1000, 'fecha_inicio': '2026-11-01'})
    first = client.post('/api/replica/cambios', json=op, headers=headers())
    assert first.status_code == 200, first.text
    assert first.json()['estado'] == 'confirmada', first.text
    again = client.post('/api/replica/cambios', json=op, headers=headers()).json()
    assert again['duplicada'] is True
    other = client.post('/api/replica/cambios', json={**op, 'uuid': str(uuid4())}, headers=headers()).json()
    assert other['estado'] == 'conflicto'
    with factory() as db:
        assert db.query(m.Contrato).count() == 1
        assert db.query(m.CambioReplica).count() == 2


def test_contract_payment_dependency_atomic_receipt_and_changed_balance(api):
    client, factory = api
    initial = client.get('/api/replica/datos', headers=headers()).json()
    contract = change(tipo='contrato.crear', base=initial['huellas']['propiedad:1'], datos={
        'id_cliente': 1, 'id_propiedad': 1, 'tipo_contrato': 'Venta', 'monto_total': 1000, 'fecha_inicio': '2026-11-01'})
    assert client.post('/api/replica/cambios', json=contract, headers=headers()).json()['estado'] == 'confirmada'
    payment = change(tipo='pago.crear', id=-1, datos={'monto': 250, 'metodo_pago': 'Efectivo'}, dependencias={'id': contract['uuid']})
    result = client.post('/api/replica/cambios', json=payment, headers=headers())
    assert result.json()['estado'] == 'confirmada', result.text
    assert client.post('/api/replica/cambios', json=payment, headers=headers()).json()['duplicada'] is True
    next_payment = change(tipo='pago.crear', id=-1, datos={'monto': 250, 'metodo_pago': 'Efectivo'}, dependencias={'id': contract['uuid'], 'base': payment['uuid']})
    result = client.post('/api/replica/cambios', json=next_payment, headers=headers())
    assert result.json()['estado'] == 'confirmada', result.text
    with factory() as db:
        assert db.query(m.Pago).count() == 2
        assert sum(p.monto for p in db.query(m.Pago)) == 500


def test_replica_does_not_cross_account_company_or_accept_reused_uuid(api):
    client, _ = api
    op = change(tipo='reporte.guardar', datos={'nombre': 'Prueba', 'configuracion': '{"entidad":"propiedades","columnas":["titulo"]}'})
    assert client.post('/api/replica/cambios', json=op, headers=headers('admin2', 2)).status_code == 403
    assert client.post('/api/replica/cambios', json=op, headers=headers()).json()['estado'] == 'confirmada'
    assert client.post('/api/replica/cambios', json={**op, 'datos': {**op['datos'], 'nombre': 'Otro'}}, headers=headers()).status_code == 409


def test_snapshot_change_detects_price_edit(api):
    client, factory = api
    before = client.get('/api/replica/datos', headers=headers()).json()
    with factory() as db:
        db.get(m.Propiedad, 1).precio = 1500
        db.commit()
    op = change(tipo='contrato.crear', base=before['huellas']['propiedad:1'], datos={
        'id_cliente': 1, 'id_propiedad': 1, 'tipo_contrato': 'Venta', 'monto_total': 1000, 'fecha_inicio': '2026-11-01'})
    result = client.post('/api/replica/cambios', json=op, headers=headers()).json()
    assert result['estado'] == 'conflicto'
    assert result['servidor']['precio'] == 1500


def test_new_property_dependency_can_be_contracted_without_an_intermediate_download(api):
    client, factory = api
    prop = change(tipo='propiedad.crear', datos={'id_propietario': 1, 'id_agente': 1, 'id_sucursal': 1,
        'titulo': 'Creada sin conexión', 'direccion': 'Centro', 'precio': 1200, 'tipo_operacion': 'Venta'})
    saved = client.post('/api/replica/cambios', json=prop, headers=headers()).json()
    assert saved['estado'] == 'confirmada', saved
    contract = change(tipo='contrato.crear', datos={'id_cliente': 1, 'id_propiedad': -1,
        'tipo_contrato': 'Venta', 'monto_total': 1200, 'fecha_inicio': '2026-11-01'}, dependencias={'id_propiedad': prop['uuid']})
    saved_contract = client.post('/api/replica/cambios', json=contract, headers=headers()).json()
    assert saved_contract['estado'] == 'confirmada', saved_contract
    with factory() as db:
        assert db.get(m.Contrato, saved_contract['data']['id_contrato']).id_propiedad == saved['data']['id_propiedad']


def test_installments_are_positive_and_add_up_in_cents(api):
    client, factory = api
    snapshot = client.get('/api/replica/datos', headers=headers()).json()
    op = change(tipo='contrato.crear', base=snapshot['huellas']['propiedad:1'], datos={
        'id_cliente': 1, 'id_propiedad': 1, 'tipo_contrato': 'Venta', 'monto_total': 1,
        'fecha_inicio': '2026-11-01', 'num_cuotas': 99})
    saved = client.post('/api/replica/cambios', json=op, headers=headers()).json()
    assert saved['estado'] == 'confirmada', saved
    with factory() as db:
        amounts = [q.monto for q in db.query(m.Cuota).all()]
        assert min(amounts) > 0 and sum(amounts) == 1
    op = change(tipo='contrato.crear', base=snapshot['huellas']['propiedad:2'], datos={
        'id_cliente': 1, 'id_propiedad': 2, 'tipo_contrato': 'Venta', 'monto_total': 0.01,
        'fecha_inicio': '2026-11-01', 'num_cuotas': 2})
    assert client.post('/api/replica/cambios', json=op, headers=headers()).json()['estado'] == 'rechazada'
    with factory() as db:
        assert db.query(m.Contrato).count() == 1
    invalid = change(tipo='contrato.crear', base=snapshot['huellas']['propiedad:2'], datos={
        'id_cliente': 1, 'id_propiedad': 2, 'tipo_contrato': 'Venta', 'monto_total': 0.001,
        'fecha_inicio': '2026-11-01'})
    assert client.post('/api/replica/cambios', json=invalid, headers=headers()).json()['estado'] == 'rechazada'
