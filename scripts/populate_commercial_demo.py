"""Datos académicos aditivos CRM, únicamente al ejecutar --apply. No crea ventas ni cobros."""
import argparse
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from populate_sprint4_demo import API

MARK = '[DEMO CRM]'


def populate(api, apply=False):
    assert api.call('/users/me')['id_rol'] == 1, 'Se requiere SaaS.'
    result = []
    for company in api.call('/admin/empresas'):
        tid = company['id_tenant']
        options = api.call('/api/oportunidades/opciones', tid=tid)
        old = api.call('/api/oportunidades', tid=tid)
        existing = {r['titulo']: r for r in old}
        created = 0
        for i, stage in enumerate(['Nuevo', 'Visita', 'Negociacion']):
            name = MARK + ' ' + ['Consulta de vivienda', 'Visita programada', 'Propuesta en revisión'][i]
            if name in existing or not apply: continue
            data = {'titulo': name, 'contacto': 'Interesado ficticio de demostración', 'etapa': stage,
                    'importe': [85000, 120000, 95000][i], 'probabilidad': [10, 40, 70][i],
                    'proximo_contacto': (datetime.now(ZoneInfo('America/La_Paz')).date() + timedelta(days=i+1)).isoformat(),
                    'notas': 'Caso académico para presentar el embudo. No representa una venta ni un cliente real.'}
            for field, key in [('id_cliente','clientes'),('id_agente','agentes'),('id_propiedad','propiedades')]:
                if options[key]: data[field] = options[key][i % len(options[key])]['id']
            existing[name] = api.call('/api/oportunidades', data, tid=tid)
            created += 1
        flows = api.call('/api/workflow-ia', tid=tid)
        text = MARK + ' El interesado ficticio solicita visitar la vivienda hoy y conocer las condiciones de compra.'
        if apply and not any(r['texto'] == text for r in flows):
            target = existing.get(MARK + ' Visita programada')
            api.call('/api/workflow-ia', {'texto':text,'id_oportunidad':target['id'] if target else None},tid=tid)
        result.append({'id_tenant':tid,'oportunidades_nuevas':created,'aplicado':apply})
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api-url',required=True)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    api=API(args.api_url).login(os.environ['DEMO_ADMIN_EMAIL'],os.environ['DEMO_ADMIN_PASSWORD'])
    print(populate(api,args.apply))
