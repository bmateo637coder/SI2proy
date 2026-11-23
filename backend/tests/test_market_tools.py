import json
from datetime import datetime, timezone
from decimal import Decimal
import pytest
import market_tools as tools
from database import models as m
from saas import today
from .conftest import headers


def snapshot():
    now = int(datetime.now(timezone.utc).timestamp())
    return {'base':'USD','tasas':{'USD':'1','BOB':'6.96','EUR':'.9','BRL':'5','CLP':'900','PEN':'3.7'},
            'actualizado_unix':now-60,'proxima_actualizacion_unix':now+86000,
            'actualizado_en':datetime.fromtimestamp(now-60,timezone.utc).isoformat(),
            'fuente':'Test provider','fuente_url':'https://example.test','aviso':'Referencia de prueba'}


@pytest.fixture(autouse=True)
def reset_retry(monkeypatch):
    monkeypatch.setattr(tools, '_retry_after', 0.)


def test_decimal_conversion_cross_rates_and_half_up():
    rates={'USD':'1','BOB':'6.96','EUR':'.9'}
    assert tools.convert_amount('100','USD','BOB',rates)==Decimal('696.00')
    assert tools.convert_amount('696','BOB','USD',rates)==Decimal('100.00')
    assert tools.convert_amount('90','EUR','BOB',rates)==Decimal('696.00')
    assert tools.convert_amount('.105','USD','USD',rates)==Decimal('.11')


def test_rates_are_persistent_cached_and_conversion_validated(api,monkeypatch):
    client,factory=api
    calls=[]
    monkeypatch.setattr(tools,'fetch_rates',lambda:(calls.append(1) or snapshot()))
    first=client.get('/api/moneda',headers=headers()).json()
    assert first['vencidas'] is False
    assert client.get('/api/moneda',headers=headers('client1',1)).status_code==200
    assert len(calls)==1
    response=client.post('/api/moneda/convertir',headers=headers(),json={'monto':100,'origen':'USD','destino':'BOB'})
    assert response.status_code==200,response.text
    assert response.json()['resultado']=='696.00'
    for body in [{'monto':-1},{'monto':'NaN'},{'monto':1,'destino':'ZZZ'},{'monto':10**13}]:
        assert client.post('/api/moneda/convertir',headers=headers(),json=body).status_code==422
    with factory() as db: assert db.get(tools.CurrencySnapshot,'USD') is not None


def test_provider_failure_keeps_stale_snapshot_and_backs_off(api,monkeypatch):
    client,factory=api
    old=snapshot();old['proxima_actualizacion_unix']=0
    with factory() as db:
        db.add(tools.CurrencySnapshot(base='USD',contenido=json.dumps(old)));db.commit()
    calls=[]
    def fail(): calls.append(1);raise TimeoutError()
    monkeypatch.setattr(tools,'fetch_rates',fail)
    for _ in range(2):
        result=client.get('/api/moneda',headers=headers())
        assert result.status_code==200
        assert result.json()['vencidas'] is True
        assert result.json()['actualizado_en']==old['actualizado_en']
    assert len(calls)==1


def test_provider_failure_without_cache_never_invents_rates(api,monkeypatch):
    client,_=api
    monkeypatch.setattr(tools,'fetch_rates',lambda: (_ for _ in ()).throw(TimeoutError()))
    assert client.get('/api/moneda',headers=headers()).status_code==503
    assert client.get('/api/moneda').status_code==401


def test_forecast_real_scope_and_insufficient_history(api):
    client,factory=api
    current=today().replace(day=1)
    with factory() as db:
        for tid,count in [(1,1),(2,2)]:
            for offset in range(1,7):
                day=tools.month_shift(current,-offset)
                for _ in range(count):
                    db.add(m.Contrato(id_tenant=tid,id_cliente=tid,id_propiedad=1 if tid==1 else 3,
                        id_agente=tid,tipo_contrato='Venta',monto_total=1000,fecha_inicio=day))
                    db.add(m.Visita(id_tenant=tid,id_cliente=tid,id_propiedad=1 if tid==1 else 3,
                        id_agente=tid,fecha_hora=datetime.combine(day,datetime.min.time()),estado='Realizada'))
        # Incomplete current month and future activity must not leak into training.
        db.add(m.Visita(id_tenant=1,id_cliente=1,id_propiedad=1,id_agente=1,fecha_hora=datetime.combine(current,datetime.min.time()),estado='Programada'))
        db.commit()
    result=client.get('/api/predicciones',headers=headers())
    assert result.status_code==200,result.text
    data=result.json()
    assert data['ventas']['eventos']==6 and data['demanda']['eventos']==6
    assert len(data['ventas']['proyeccion'])==6
    assert all(r['cantidad']>=0 for r in data['ventas']['proyeccion'])
    all_scope={**headers('super',None),'X-Tenant-Scope':'all'}
    assert client.get('/api/predicciones',headers=all_scope).json()['ventas']['eventos']==18
    assert client.get('/api/predicciones',headers=headers('client1',1)).status_code==403
    assert client.get('/api/predicciones',headers=headers('admin2',2)).status_code==403
    assert client.get('/api/predicciones?meses=7',headers=headers()).status_code==422


def test_demo_is_explicit_reproducible_and_does_not_modify_transactions(api):
    client,factory=api
    real=client.get('/api/predicciones',headers=headers()).json()
    assert real['ventas']['estado']=='historial_insuficiente'
    demo=client.get('/api/predicciones?modo=demo&meses=3',headers=headers()).json()
    assert demo['modo']=='demo' and 'sintético' in demo['advertencia']
    assert demo['ventas']['meses_entrenamiento']==24
    assert demo['ventas']['mae_modelo_ml'] is not None
    assert len(demo['demanda']['proyeccion'])==3
    assert demo['ventas']==client.get('/api/predicciones?modo=demo&meses=3',headers=headers()).json()['ventas']
    with factory() as db: assert db.query(m.Contrato).count()==0


def test_future_targets_do_not_change_earlier_forecasts():
    labels=[f'2025-{i:02}' for i in range(1,13)]
    values=list(range(3,15))
    first=tools.forecast(values,labels,3)
    second=tools.forecast(values,labels,6)
    assert first['proyeccion']==second['proyeccion'][:3]
    assert first['meses_validacion']==3
