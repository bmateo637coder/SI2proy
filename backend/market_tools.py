"""Forecast of monthly activity and dated, persistent indicative exchange rates."""
import json
import math
import threading
from collections import Counter
from datetime import date, datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Literal
from urllib.request import Request, urlopen

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import Column, String, Text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from database.database import Base, get_db
from database import models as m
from auth import require_reader, get_current_user, scope_query
from saas import require_ai, today

router = APIRouter(prefix='/api', tags=['Predicciones y moneda'])
Currency = Literal['USD', 'BOB', 'EUR', 'BRL', 'CLP', 'PEN']
CURRENCIES = ('USD', 'BOB', 'EUR', 'BRL', 'CLP', 'PEN')
_rate_lock = threading.Lock()
_retry_after = 0.


class CurrencySnapshot(Base):
    __tablename__ = 'tipo_cambio_snapshot'
    base = Column(String(3), primary_key=True)
    contenido = Column(Text, nullable=False)


def month_shift(day, offset):
    number = day.year * 12 + day.month - 1 + offset
    return date(number // 12, number % 12 + 1, 1)


def forecast(values, labels, horizon):
    """Walk-forward validation uses only observations preceding each target."""
    history = [{'mes': label, 'cantidad': int(value)} for label, value in zip(labels, values)]
    result = {'historial': history, 'proyeccion': [], 'estado': 'historial_insuficiente',
              'modelo': None, 'mae_validacion': None, 'mae_base': None,
              'meses_entrenamiento': len(values), 'eventos': sum(values)}
    if len(values) < 6 or sum(values) < 6:
        return result
    import numpy as np
    from sklearn.linear_model import Ridge

    def features(index, previous):
        month = int(labels[0][5:7]) + index
        return [index / 12, math.sin(2 * math.pi * month / 12), math.cos(2 * math.pi * month / 12), previous]

    def estimate(past):
        x = [features(i, past[i - 1]) for i in range(1, len(past))]
        model = Ridge(alpha=2).fit(np.array(x), np.array(past[1:]))
        return max(0., float(model.predict([features(len(past), past[-1])])[0]))

    errors, base_errors = [], []
    for cut in range(max(4, len(values) - 3), len(values)):
        errors.append(abs(values[cut] - estimate(values[:cut])))
        base_errors.append(abs(values[cut] - sum(values[cut-3:cut]) / 3))
    mae, baseline = sum(errors) / len(errors), sum(base_errors) / len(base_errors)
    use_ml = mae <= baseline
    past = list(values)
    last = date.fromisoformat(labels[-1] + '-01')
    for step in range(horizon):
        point = estimate(past) if use_ml else sum(past[-3:]) / 3
        result['proyeccion'].append({'mes': month_shift(last, step + 1).strftime('%Y-%m'), 'cantidad': round(point, 2)})
        past.append(point)
    result.update(estado='calculado', modelo='Ridge' if use_ml else 'Promedio móvil (superó a Ridge en validación)',
                  mae_validacion=round(mae if use_ml else baseline, 3), mae_modelo_ml=round(mae, 3),
                  mae_base=round(baseline, 3), meses_validacion=len(errors))
    return result


@router.get('/predicciones')
def predictions(meses: int = Query(6, ge=1, le=6), modo: Literal['real', 'demo'] = 'real',
                db: Session = Depends(get_db), user=Depends(require_reader)):
    require_ai(db, user)
    current = today().replace(day=1)
    start = month_shift(current, -24)
    contracts = scope_query(db.query(m.Contrato), user, m.Contrato.id_tenant).filter(
        m.Contrato.tipo_contrato == 'Venta', m.Contrato.fecha_inicio >= start, m.Contrato.fecha_inicio < current).all()
    visits = scope_query(db.query(m.Visita), user, m.Visita.id_tenant).filter(
        m.Visita.estado != 'Cancelada', m.Visita.fecha_hora >= datetime.combine(start, datetime.min.time()),
        m.Visita.fecha_hora < datetime.combine(current, datetime.min.time())).all()
    sales = Counter(c.fecha_inicio.strftime('%Y-%m') for c in contracts)
    demand = Counter(v.fecha_hora.strftime('%Y-%m') for v in visits)
    if modo == 'demo':
        labels = [month_shift(start, i).strftime('%Y-%m') for i in range(24)]
        # Explicit academic scenario, never mixed with the user's transactions.
        sales = {label: max(1, round(4 + i * .35 + 2 * math.sin(i * math.pi / 6))) for i, label in enumerate(labels)}
        demand = {label: max(1, round(14 + i * .8 + 5 * math.sin(i * math.pi / 6))) for i, label in enumerate(labels)}
    else:
        first = min([*sales, *demand], default=current.strftime('%Y-%m'))
        labels = [month_shift(start, i).strftime('%Y-%m') for i in range(24) if month_shift(start, i).strftime('%Y-%m') >= first]
    return {'modo': modo, 'alcance': 'todas' if getattr(user, 'all_tenants', False) else 'empresa',
            'id_tenant': user.id_tenant, 'generado_en': datetime.now(timezone.utc).isoformat(),
            'hasta': month_shift(current, -1).strftime('%Y-%m'), 'horizonte': meses,
            'ventas': forecast([sales.get(k, 0) for k in labels], labels, meses),
            'demanda': forecast([demand.get(k, 0) for k in labels], labels, meses),
            'definiciones': {'ventas': 'Contratos de venta según fecha de inicio.',
                'demanda': 'Visitas no canceladas según fecha programada; indicador de interés, no demanda total del mercado.'},
            'advertencia': 'Escenario sintético académico; no representa ventas futuras reales.' if modo == 'demo' else
                'Se excluye el mes actual incompleto. Se necesitan al menos 6 meses y 6 eventos por serie. La validación temporal compara Ridge con un promedio móvil; las estimaciones no garantizan resultados.'}


def fetch_rates():
    request = Request('https://open.er-api.com/v6/latest/USD', headers={'User-Agent': 'Raices-currency/3.2'})
    with urlopen(request, timeout=8) as response:
        data = json.load(response)
    if data.get('result') != 'success' or data.get('base_code') != 'USD':
        raise ValueError('Invalid provider response')
    rates = {code: str(data['rates'][code]) for code in CURRENCIES}
    if any(not Decimal(rate).is_finite() or Decimal(rate) <= 0 for rate in rates.values()) or Decimal(rates['USD']) != 1:
        raise ValueError('Invalid rates')
    updated, next_update = int(data['time_last_update_unix']), int(data['time_next_update_unix'])
    now = datetime.now(timezone.utc).timestamp()
    if not 0 < updated <= now + 3600 or not updated < next_update <= updated + 172800:
        raise ValueError('Invalid timestamp')
    return {'base': 'USD', 'tasas': rates, 'actualizado_unix': updated, 'proxima_actualizacion_unix': next_update,
            'actualizado_en': datetime.fromtimestamp(updated, timezone.utc).isoformat(),
            'fuente': 'ExchangeRate-API', 'fuente_url': 'https://www.exchangerate-api.com',
            'aviso': 'Tasas indicativas de referencia. Los precios y registros contables del sistema permanecen en USD.'}


@router.get('/moneda')
def exchange_rates(db: Session = Depends(get_db), user=Depends(get_current_user)):
    global _retry_after
    with _rate_lock:
        saved = db.get(CurrencySnapshot, 'USD')
        cached = json.loads(saved.contenido) if saved else None
        now = datetime.now(timezone.utc).timestamp()
        if cached and now < cached['proxima_actualizacion_unix']:
            return {**cached, 'vencidas': False}
        if now < _retry_after:
            if cached:
                return {**cached, 'vencidas': True}
            raise HTTPException(503, 'El proveedor no está disponible. Reintenta dentro de unos minutos o usa una tasa manual.')
        try:
            snapshot = fetch_rates()
        except Exception:
            _retry_after = now + 300
            if cached:
                return {**cached, 'vencidas': True, 'aviso': 'No se pudo actualizar el proveedor. Se conserva la última tasa, con su fecha; los precios originales siguen en USD.'}
            raise HTTPException(503, 'No hay tasas guardadas y el proveedor no está disponible. Reintenta con conexión.') from None
        _retry_after = 0.
        if saved:
            saved.contenido = json.dumps(snapshot)
        else:
            db.add(CurrencySnapshot(base='USD', contenido=json.dumps(snapshot)))
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
        return {**snapshot, 'vencidas': now >= snapshot['proxima_actualizacion_unix']}


class Conversion(BaseModel):
    monto: Decimal = Field(ge=0, le=10**12, allow_inf_nan=False)
    origen: Currency = 'USD'
    destino: Currency = 'BOB'


def convert_amount(amount, origin, target, rates):
    return (Decimal(str(amount)) / Decimal(str(rates[origin])) * Decimal(str(rates[target]))).quantize(Decimal('.01'), rounding=ROUND_HALF_UP)


@router.post('/moneda/convertir')
def convert(body: Conversion, db: Session = Depends(get_db), user=Depends(get_current_user)):
    snapshot = exchange_rates(db, user)
    return {'monto': str(body.monto), 'origen': body.origen, 'destino': body.destino,
            'resultado': str(convert_amount(body.monto, body.origen, body.destino, snapshot['tasas'])),
            'actualizado_en': snapshot['actualizado_en'], 'vencidas': snapshot['vencidas'], 'fuente': snapshot['fuente']}
