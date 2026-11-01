from .conftest import headers
from database import models as m


def test_global_summary_is_superadmin_only_and_keeps_empty_companies(api):
    client, factory = api
    for identity in (headers(), headers('agent1'), headers('client1')):
        assert client.get('/admin/vista-global/resumen', headers=identity).status_code == 403
        assert client.get('/admin/vista-global/propiedades', headers=identity).status_code == 403
    with factory() as db:
        db.add(m.Tenant(id_tenant=3, nombre='Empresa vacía', slug='empresa-vacia'))
        db.commit()
    response = client.get('/admin/vista-global/resumen', headers=headers('super', None))
    assert response.status_code == 200, response.text
    data = response.json()
    assert data['inmobiliarias'] == 3
    assert data['totales']['propiedades'] == 3
    assert data['totales']['clientes'] == 2
    assert data['totales']['usuarios'] == 7  # No cuenta la identidad global como usuario de una empresa.
    companies = {r['id_tenant']: r for r in data['empresas']}
    assert companies[1]['conteos']['propiedades'] == 2
    assert companies[2]['conteos']['propiedades'] == 1
    assert companies[3]['conteos']['propiedades'] == 0
    assert companies[3]['suscripcion'] == 'sin_suscripcion'


def test_global_records_filter_search_paginate_and_label_company(api):
    client, factory = api
    auth = headers('super', None)
    response = client.get('/admin/vista-global/propiedades?limite=1&offset=1', headers=auth)
    assert response.status_code == 200, response.text
    assert response.json()['total'] == 3
    assert response.json()['data'][0]['id_propiedad'] == 2
    assert response.json()['data'][0]['inmobiliaria'] == 'Empresa 1'
    response = client.get('/admin/vista-global/propiedades?id_tenant=2', headers=auth)
    assert [r['id_propiedad'] for r in response.json()['data']] == [3]
    assert client.get('/admin/vista-global/propiedades?buscar=Empresa%202', headers=auth).json()['total'] == 1
    assert client.get('/admin/vista-global/propiedades?buscar=%25', headers=auth).json()['total'] == 0
    assert client.get('/admin/vista-global/propiedades?limite=201', headers=auth).status_code == 422
    assert client.get('/admin/vista-global/propiedades?offset=-1', headers=auth).status_code == 422
    assert client.get('/admin/vista-global/propiedades?id_tenant=999', headers=auth).status_code == 404
    assert client.get('/admin/vista-global/password_hash', headers=auth).status_code == 422
    assert client.post('/admin/vista-global/propiedades', json={}, headers=auth).status_code == 405
    with factory() as db:
        assert db.get(m.Usuario, 'super').id_tenant is None
        assert db.query(m.Propiedad).count() == 3


def test_global_entities_only_serialize_public_fields_and_respect_relationships(api):
    client, factory = api
    auth = {**headers('super', None), 'X-Tenant-ID': '1'}
    with factory() as db:
        from saas import today
        db.add(m.Contrato(id_tenant=1, id_cliente=1, id_propiedad=1, id_agente=1,
                          tipo_contrato='Venta', monto_total=1000, fecha_inicio=today()))
        db.commit()
    for entity, expected in [('clientes', 2), ('agentes', 2), ('propietarios', 2), ('usuarios', 7), ('sucursales', 2), ('contratos', 1)]:
        response = client.get('/admin/vista-global/' + entity, headers=auth)
        assert response.status_code == 200, response.text
        data = response.json()
        assert data['total'] == expected
        assert all(r['inmobiliaria'] and r['id_tenant'] in (1, 2) for r in data['data'])
        assert 'password' not in response.text and 'permisos' not in response.text
    assert client.get('/admin/vista-global/contratos', headers=auth).json()['data'][0]['propiedad'] == 'Casa 1'
    # La consulta global no cambia el aislamiento de las rutas operativas.
    own = client.get('/modulo_inmuebles/propiedades', headers=headers()).json()
    assert {r['id_tenant'] for r in own} == {1}
