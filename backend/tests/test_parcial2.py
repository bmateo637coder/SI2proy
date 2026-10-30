from datetime import datetime, timezone, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import func

from database import models as m
from tests.conftest import headers
from saas import today


def operation(**overrides):
    return {"uuid":str(uuid4()),"id_tenant":1,"id_sucursal":1,"ci_usuario":"admin1","id_cliente":1,
        "id_propiedad":1,"tipo":"venta_contado","registrado_en":datetime.now(timezone.utc).isoformat(),
        "version":1,"precio":"1000.00","total":"1000.00","forma_pago":"Efectivo",**overrides}


def test_sale_atomic_and_idempotent(api):
    client,factory=api
    body=operation()
    first=client.post('/api/offline/sincronizar',json=body,headers=headers())
    assert first.status_code==200,first.text
    assert first.json()['estado']=='confirmada'
    replay=client.post('/api/offline/sincronizar',json=body,headers=headers())
    assert replay.json()['duplicada'] is True
    with factory() as db:
        assert db.query(m.Contrato).count()==db.query(m.Pago).count()==db.query(m.Cuota).count()==1
        assert db.get(m.Propiedad,1).estado=='Vendida'
        assert db.get(m.Propiedad,1).version==2
        assert db.query(func.sum(m.Pago.monto)).scalar()==1000


def test_uuid_cannot_change_payload(api):
    client,_=api
    body=operation(tipo='reserva')
    assert client.post('/api/offline/sincronizar',json=body,headers=headers()).status_code==200
    body['tipo']='venta_contado'
    assert client.post('/api/offline/sincronizar',json=body,headers=headers()).status_code==409


def test_second_sale_is_durable_conflict(api):
    client,factory=api
    client.post('/api/offline/sincronizar',json=operation(),headers=headers())
    body=operation()
    response=client.post('/api/offline/sincronizar',json=body,headers=headers())
    assert response.json()['estado']=='conflicto'
    assert client.post('/api/offline/sincronizar',json=body,headers=headers()).json()['duplicada']
    with factory() as db:
        assert db.query(m.Contrato).count()==1
        assert db.query(m.OperacionOffline).count()==2


@pytest.mark.parametrize('changes,code',[
    ({'id_tenant':2},403),({'ci_usuario':'admin2'},403),({'id_sucursal':2},403),
    ({'id_cliente':2},404),({'id_propiedad':3},404),({'forma_pago':'QR'},422),
    ({'precio':'NaN'},422),({'registrado_en':'2026-10-01T12:00:00'},422)])
def test_sync_validates_scope_and_contract(api,changes,code):
    client,factory=api
    assert client.post('/api/offline/sincronizar',json=operation(**changes),headers=headers()).status_code==code
    with factory() as db:
        assert db.query(m.Contrato).count()==db.query(m.Pago).count()==0


@pytest.mark.parametrize('changes,state', [({'version':2},'conflicto'),({'precio':'999.00'},'conflicto'),({'total':'500.00'},'rechazada')])
def test_business_conflicts_are_recorded(api,changes,state):
    client,factory=api
    assert client.post('/api/offline/sincronizar',json=operation(**changes),headers=headers()).json()['estado']==state
    with factory() as db:
        assert db.get(m.Propiedad,1).estado=='Disponible'
        assert db.query(m.OperacionOffline).count()==1


def test_catalog_is_tenant_scoped(api):
    client,_=api
    data=client.get('/api/offline/catalogo',headers=headers()).json()
    assert {p['id_propiedad'] for p in data['propiedades']}=={1,2}
    assert [c['id_cliente'] for c in data['clientes']]==[1]
    assert client.get('/api/offline/catalogo',headers=headers('client1')).status_code==403
    assert client.get('/modulo_inmuebles/propiedades/catalogo',headers={**headers(),'X-Tenant-ID':'2'}).status_code==403


def test_branch_limit_and_plan_downgrade(api):
    client,_=api
    for i in range(2):
        assert client.post('/api/saas/sucursales',json={'nombre':f'Otra {i}'},headers=headers()).status_code==201
    body={'codigo_plan':'basico','inicio':str(today()),'vencimiento':str(today()+timedelta(days=30)),'estado':'activa'}
    assert client.put('/api/saas/suscripcion/1',json=body,headers=headers()).status_code==409
    h=headers('admin2',2)
    assert client.post('/api/saas/sucursales',json={'nombre':'Segunda'},headers=h).status_code==201
    assert client.post('/api/saas/sucursales',json={'nombre':'Tercera'},headers=h).status_code==409
    assert client.put('/api/saas/suscripcion/2',json=body,headers=headers()).status_code==403


def test_expired_subscription_blocks_mutations_allows_renewal(api):
    client,factory=api
    with factory() as db:
        db.get(m.Suscripcion,1).vencimiento=today()-timedelta(days=1)
        db.commit()
    assert client.post('/api/offline/sincronizar',json=operation(),headers=headers()).status_code==402
    assert client.get('/api/saas/suscripcion',headers=headers()).json()['estado']=='vencida'
    assert client.put('/api/saas/suscripcion/1',json={'codigo_plan':'profesional','inicio':str(today()),'vencimiento':str(today()+timedelta(days=30)),'estado':'activa'},headers=headers()).status_code==200


def test_generated_reports_real_data_and_plan(api):
    client,_=api
    client.post('/api/offline/sincronizar',json=operation(),headers=headers())
    for text in ['ventas por sucursal','ingresos por semana','cartera por estado','ranking de agentes','reservas por sucursal']:
        result=client.post('/api/analitica/reporte',json={'texto':text},headers=headers())
        assert result.status_code==200,result.text
        assert result.json()['id_tenant']==1
    sales=client.post('/api/analitica/reporte',json={'texto':'ventas por sucursal'},headers=headers()).json()
    assert sales['filas']==[['Sucursal 1',1,1000.0]]
    assert client.post('/api/analitica/reporte',json={'texto':'ventas por sucursal'},headers=headers('admin2',2)).status_code==403
    assert client.post('/api/analitica/convencional',json={'tipo':'ventas_sucursal'},headers=headers('admin2',2)).json()['filas']==[]


def test_report_refuses_password_hash_and_other_tenant(api):
    client,_=api
    for column in ['password_hash','tenant','__dict__']:
        assert client.post('/reportes/generar',json={'entidad':'usuarios','columnas':[column]},headers=headers()).status_code==422
    assert client.post('/api/analitica/reporte',json={'texto':'ventas de sucursal 2'},headers=headers()).status_code==403
    assert client.post('/api/analitica/reporte',json={'texto':'haceme algo'},headers=headers()).status_code==422


def test_register_cannot_escalate_to_superadmin(api):
    client,factory=api
    response=client.post('/register',json={'ci':'new','id_tenant':1,'nombre':'Nuevo','correo':'new@example.com','id_rol':1,'password':'Test.123@'})
    assert response.status_code==201,response.text
    assert response.json()['id_rol']!=1
    with factory() as db:
        assert db.query(m.Cliente).filter_by(ci_usuario='new').one().id_tenant==1


def test_admin_cannot_assign_foreign_role_or_link_foreign_user(api):
    client,_=api
    body={'ci':'new','nombre':'Nuevo','correo':'new@example.com','id_rol':1,'password':'Test.123@'}
    assert client.post('/gestion_usuarios/usuarios',json=body,headers=headers()).status_code==403
    assert client.post('/modulo_inmuebles/clientes',json={'ci_usuario':'admin2'},headers=headers()).status_code==403
    assert client.put('/modulo_inmuebles/propiedades/3/estado',json={'estado':'Vendida'},headers=headers()).status_code==403


def test_login_same_email_requires_tenant_and_token_pins_identity(api):
    client,factory=api
    with factory() as db:
        db.get(m.Usuario,'admin2').correo='admin1@example.com'
        db.commit()
    body={'correo':'admin1@example.com','password':'Test.123@'}
    assert client.post('/login',json=body).status_code==409
    res=client.post('/login',json={**body,'id_tenant':2})
    assert res.status_code==200
    profile=client.get('/users/me',headers={'Authorization':'Bearer '+res.json()['access_token']}).json()
    assert profile['ci']=='admin2' and profile['id_tenant']==2


def test_ml_has_heldout_metrics(api):
    client,_=api
    result=client.get('/api/analitica/dashboard',headers=headers())
    assert result.status_code==200,result.text
    metrics=result.json()['metricas']
    assert metrics['entrenamiento']+metrics['validacion']==metrics['filas']
    assert metrics['validacion']>0 and metrics['mae_usd']>0
    assert -1<=metrics['silhouette_validacion']<=1


def test_failure_rolls_back_contract_payment_and_availability(api, monkeypatch):
    import main
    from fastapi.testclient import TestClient
    from sqlalchemy import event
    client,factory=api
    def fail_on_payment(session, context, instances):
        if any(isinstance(obj,m.Pago) for obj in session.new):
            raise RuntimeError('injected transaction failure')
    event.listen(factory,'before_flush',fail_on_payment)
    body=operation()
    response=TestClient(main.app,raise_server_exceptions=False).post('/api/offline/sincronizar',json=body,headers=headers())
    assert response.status_code==500
    event.remove(factory,'before_flush',fail_on_payment)
    with factory() as db:
        assert db.query(m.Contrato).count()==db.query(m.Pago).count()==db.query(m.OperacionOffline).count()==0
        assert db.get(m.Propiedad,1).estado=='Disponible'
    assert client.post('/api/offline/sincronizar',json=body,headers=headers()).json()['estado']=='confirmada'


def test_concurrent_same_uuid_has_one_sale(api):
    import os
    from concurrent.futures import ThreadPoolExecutor
    if not os.getenv('TEST_DATABASE_URL'):
        pytest.skip('Los bloqueos de filas se verifican en PostgreSQL, no en SQLite.')
    client,factory=api
    body=operation()
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses=list(pool.map(lambda _: client.post('/api/offline/sincronizar',json=body,headers=headers()),range(2)))
    assert all(r.status_code==200 for r in responses)
    assert sorted(r.json()['duplicada'] for r in responses)==[False,True]
    with factory() as db:
        assert db.query(m.Pago).count()==db.query(m.Contrato).count()==db.query(m.OperacionOffline).count()==1


def test_two_concurrent_sales_compete_for_property(api):
    import os
    from concurrent.futures import ThreadPoolExecutor
    if not os.getenv('TEST_DATABASE_URL'):
        pytest.skip('Requiere PostgreSQL.')
    client,factory=api
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses=list(pool.map(lambda _: client.post('/api/offline/sincronizar',json=operation(),headers=headers()),range(2)))
    assert sorted(r.json()['estado'] for r in responses)==['confirmada','conflicto']
    with factory() as db:
        assert db.query(m.Contrato).count()==1


def test_cancel_reservation_is_idempotent_and_releases_property(api):
    client,factory=api
    body=operation(tipo='reserva')
    assert client.post('/api/offline/sincronizar',json=body,headers=headers()).json()['estado']=='confirmada'
    path=f"/api/offline/reservas/{body['uuid']}/cancelar"
    assert client.put(path,headers=headers()).json()['estado']=='cancelada'
    assert client.put(path,headers=headers()).json()['duplicada'] is True
    with factory() as db:
        prop=db.get(m.Propiedad,1)
        assert prop.estado=='Disponible' and prop.version==3


def test_cannot_cancel_after_window(api):
    client,factory=api
    body=operation(tipo='reserva')
    client.post('/api/offline/sincronizar',json=body,headers=headers())
    with factory() as db:
        row=db.query(m.OperacionOffline).one()
        row.procesado_en=datetime.now(timezone.utc)-timedelta(hours=49)
        db.commit()
    assert client.put(f"/api/offline/reservas/{body['uuid']}/cancelar",headers=headers()).status_code==409
    with factory() as db:
        assert db.get(m.Propiedad,1).estado=='Reservada'


def test_partial_payments_accumulate_and_close_sale(api):
    client,factory=api
    response=client.post('/gestion_contractual/contratos',headers=headers(),json={
        'id_cliente':1,'id_propiedad':1,'tipo_contrato':'Venta','monto_total':1000,
        'fecha_inicio':str(today()),'num_cuotas':2})
    assert response.status_code==201,response.text
    cid=response.json()['id_contrato']
    path=f'/gestion_contractual/contratos/{cid}/pagos'
    for amount in [100,400]:
        res=client.post(path,json={'monto':amount,'metodo_pago':'Efectivo'},headers=headers())
        assert res.status_code==201,res.text
    with factory() as db:
        quotas=db.query(m.Cuota).order_by(m.Cuota.numero_cuota).all()
        assert [q.estado for q in quotas]==['Pagada','Pendiente']
    assert client.post(path,json={'monto':500,'metodo_pago':'Efectivo'},headers=headers()).status_code==201
    with factory() as db:
        assert db.get(m.Propiedad,1).estado=='Vendida'
        assert all(q.estado=='Pagada' for q in db.query(m.Cuota))
