from uuid import uuid4
from .conftest import headers


def opportunity(**extra):
    return {'titulo':'Compra casa centro','contacto':'Interesado de prueba','importe':'100000.25','id_cliente':1,'id_propiedad':1,'id_agente':1,**extra}


def test_pipeline_scope_validation_history_and_conflict(api):
    client,_=api
    for user,tid in [('client1',1),('super',None)]:
        h=headers(user,tid)
        if user=='super':h['X-Tenant-Scope']='all'
        assert client.post('/api/oportunidades',headers=h,json=opportunity()).status_code==403
    assert client.post('/api/oportunidades',headers=headers(),json=opportunity(id_propiedad=3)).status_code==422
    r=client.post('/api/oportunidades',headers=headers(),json=opportunity())
    assert r.status_code==200,r.text
    row=r.json();ident=row['id']
    assert row['version']==1 and row['inmobiliaria']=='Empresa 1'
    assert client.get('/api/oportunidades',headers=headers('admin2',2)).json()==[]
    opts=client.get('/api/oportunidades/opciones',headers=headers()).json()
    assert {r['id'] for r in opts['propiedades']}=={1,2}
    update=opportunity(etapa='Ganado',version=1)
    r=client.put(f'/api/oportunidades/{ident}',headers=headers(),json=update)
    assert r.status_code==200,r.text
    assert r.json()['probabilidad']==100 and len(r.json()['historial'])==2
    conflict=client.put(f'/api/oportunidades/{ident}',headers=headers(),json=update)
    assert conflict.status_code==409 and conflict.json()['detail']['servidor']['version']==2
    assert client.put(f'/api/oportunidades/{ident}',headers=headers('admin2',2),json=update).status_code==404
    all_h={**headers('super',None),'X-Tenant-Scope':'all'}
    assert len(client.get('/api/oportunidades',headers=all_h).json())==1
    assert client.delete(f'/api/oportunidades/{ident}?version=1',headers=headers()).status_code==409
    assert client.delete(f'/api/oportunidades/{ident}?version=2',headers=headers()).status_code==200
    assert client.get('/api/oportunidades',headers=headers()).json()==[]


def test_workflow_local_plan_review_and_tenant_isolation(api):
    client,_=api
    r=client.post('/api/workflow-ia',headers=headers(),json={'texto':'Quiero visitar la casa hoy, urgente'})
    assert r.status_code==200,r.text
    row=r.json();ident=row['id']
    assert (row['categoria'],row['urgencia'],row['modo'])==('Visita','Alta','local')
    assert len(row['tareas'])==3 and row['estado']=='Pendiente'
    for i in range(3):
        r=client.put(f'/api/workflow-ia/{ident}',headers=headers(),json={'version':i+1,'tarea':i,'completada':True})
        assert r.status_code==200,r.text
    assert r.json()['estado']=='Completado'
    assert client.put(f'/api/workflow-ia/{ident}',headers=headers(),json={'version':1,'tarea':0,'completada':False}).status_code==409
    assert client.get('/api/workflow-ia',headers=headers('admin2',2)).json()==[]
    assert client.post('/api/workflow-ia',headers=headers('admin2',2),json={'texto':'Compra de casa'}).status_code==403
    assert client.post('/api/workflow-ia',headers=headers(),json={'texto':'Compra de casa','id_oportunidad':999}).status_code==404


def test_sync_commercial_is_atomic_idempotent_and_rebaseable(api):
    client,factory=api
    command={'uuid':str(uuid4()),'metodo':'POST','ruta':'/api/oportunidades','datos':opportunity()}
    first=client.post('/api/servicios/sync',headers=headers(),json=command)
    assert first.status_code==200,first.text
    row=first.json();ident=row['id']
    assert client.post('/api/servicios/sync',headers=headers(),json=command).json()==row
    assert len(client.get('/api/oportunidades',headers=headers()).json())==1
    command['datos']['titulo']='Otro cliente'
    assert client.post('/api/servicios/sync',headers=headers(),json=command).status_code==409
    edit={'uuid':str(uuid4()),'metodo':'PUT','ruta':f'/api/oportunidades/{ident}','datos':opportunity(version=1,etapa='Visita'),'version':1}
    assert client.post('/api/servicios/sync',headers=headers(),json=edit).status_code==200
    edit['uuid']=str(uuid4())
    assert client.post('/api/servicios/sync',headers=headers(),json=edit).status_code==409
    edit['version']=2
    assert client.post('/api/servicios/sync',headers=headers(),json=edit).json()['version']==3
    flow={'uuid':str(uuid4()),'metodo':'POST','ruta':'/api/workflow-ia','datos':{'texto':'Deseo comprar una casa','id_oportunidad':ident}}
    r=client.post('/api/servicios/sync',headers=headers(),json=flow)
    assert r.status_code==200,r.text
    assert client.post('/api/servicios/sync',headers=headers(),json=flow).json()==r.json()
    task={'uuid':str(uuid4()),'metodo':'PUT','ruta':f"/api/workflow-ia/{r.json()['id']}",'datos':{'tarea':0,'completada':True},'version':1}
    assert client.post('/api/servicios/sync',headers=headers(),json=task).json()['tareas'][0]['completada']
    from database import models as m
    with factory() as db: assert db.query(m.Contrato).count()==0
