"""Restaura el respaldo autorizado en una base NUEVA y gratuita; nunca vacía una base existente."""
import argparse
import base64
import hashlib
import ipaddress
import json
import os
import re
import time
from io import StringIO
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import psycopg2
from cryptography.fernet import Fernet
from deploy_render import api, discover

SNAPSHOT = 'backups/backup_raices_20261031_020000.sql'
DIGEST = '26ddc06ab188d70e92d4844ef365a5d0e2412b9ec8b2a1cae89c6dc27fa3c779'
DB_NAME = 'raices-recuperada-20261122'


def snapshot():
    headers = {'Accept': 'application/vnd.github+json'}
    if os.getenv('GITHUB_TOKEN'): headers['Authorization'] = 'Bearer ' + os.environ['GITHUB_TOKEN']
    request = Request('https://api.github.com/repos/bmateo637coder/SI2proy/contents/' + SNAPSHOT + '?ref=backups', headers=headers)
    with urlopen(request, timeout=30) as response: result = json.load(response)
    data = base64.b64decode(result['content'])
    if hashlib.sha256(data).hexdigest() != DIGEST: raise RuntimeError('El respaldo cambió: se requiere verificar nuevamente su contenido.')
    source = data.decode('utf-8').replace('\r\n', '\n')
    # pg_dump 18 añade metacomandos de psql y un SET que no existe en PostgreSQL 16.
    source = re.sub(r'^\\(?:un)?restrict [A-Za-z0-9]+\n', '', source, flags=re.M)
    source = re.sub(r'^SET transaction_timeout = 0;\n', '', source, flags=re.M)
    # Los objetos pertenecen al usuario de la nueva base; los roles del servidor anterior no existen aquí.
    source = re.sub(r'^ALTER DEFAULT PRIVILEGES [^\n]+;\n', '', source, flags=re.M)
    if re.search(r'^\\(?!\.$)|\b(?:CREATE DATABASE|ALTER SYSTEM|COPY\s+[^;]*\bPROGRAM)\b', source, re.M | re.I):
        # Los escapes de datos COPY se validan dentro de su bloque, no como comandos de psql.
        outside = re.sub(r'^COPY public\.[^\n]+ FROM stdin;\n.*?^\\\.\n', '', source, flags=re.M | re.S)
        if re.search(r'^\\|\bCREATE DATABASE\b|\bALTER SYSTEM\b|\bCOPY\b[^;]*\bPROGRAM\b', outside, re.M | re.I):
            raise RuntimeError('El respaldo contiene instrucciones ajenas a un volcado SQL de esta aplicación.')
    return source


def restore(dsn, source):
    with psycopg2.connect(dsn, connect_timeout=15) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='_recuperacion_sprint4')")
            if cursor.fetchone()[0]:
                cursor.execute('SELECT snapshot_sha FROM public._recuperacion_sprint4')
                if cursor.fetchone()[0] != DIGEST: raise RuntimeError('La base contiene otra recuperación. Se conserva sin cambios.')
                return
            cursor.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")
            if cursor.fetchone()[0] != 0: raise RuntimeError('La base destino contiene datos. No se sobrescribe.')
            position = 0
            pattern = re.compile(r'^COPY public\.[^\n]+ FROM stdin;\n', re.M)
            for match in pattern.finditer(source):
                prefix = source[position:match.start()]
                if re.sub(r'^--.*$', '', prefix, flags=re.M).strip(): cursor.execute(prefix)
                end = source.find('\n\\.\n', match.end())
                if source[match.end():].startswith('\\.\n'):
                    end = match.end() - 1
                if end < 0: raise RuntimeError('Bloque COPY incompleto.')
                content = source[match.end():end]
                cursor.copy_expert(match.group(0).strip(), StringIO(content + ('\n' if content else '')))
                position = end + len('\n\\.\n')
            cursor.execute(source[position:])
            cursor.execute('CREATE TABLE public._recuperacion_sprint4 (snapshot_sha TEXT PRIMARY KEY, restaurado_at TIMESTAMPTZ NOT NULL DEFAULT now())')
            cursor.execute('INSERT INTO public._recuperacion_sprint4(snapshot_sha) VALUES(%s)', (DIGEST,))


def verify(dsn):
    expected = {'tenant': 3, 'usuario': 7, 'propiedad': 3, 'cliente': 3, 'contrato': 1,
                'bitacora': 0, 'pago': 1, 'cuota': 1, 'caracteristica': 6}
    with psycopg2.connect(dsn, connect_timeout=15) as connection:
        with connection.cursor() as cursor:
            counts = {}
            for table, count in expected.items():
                cursor.execute('SELECT count(*) FROM public.' + table)
                counts[table] = cursor.fetchone()[0]
                if counts[table] != count: raise RuntimeError('La verificación del respaldo no coincide en ' + table)
    print('Respaldo restaurado y validado: ' + json.dumps(counts), flush=True)


def recover(source):
    service = discover(os.environ['PROD_API_URL'].rstrip('/'))
    owner = service['ownerId']
    rows = api('postgres?' + urlencode({'ownerId': owner, 'limit': 100}))
    databases = [r.get('postgres', r) for r in rows]
    existing = next((p for p in databases if p.get('name') == DB_NAME), None)
    if existing is None:
        if databases: raise RuntimeError('Apareció otra base en el workspace; revisar antes de crear o conectar recursos.')
        with urlopen('https://api.ipify.org', timeout=15) as response: address = str(ipaddress.ip_address(response.read().decode().strip()))
        existing = api('postgres', 'POST', {'name': DB_NAME, 'ownerId': owner, 'region': 'oregon', 'version': '16',
            'plan': 'free', 'enableHighAvailability': False,
            'ipAllowList': [{'cidrBlock': address + '/32', 'description': 'Recuperacion temporal desde Actions'}]})
        existing = existing.get('postgres', existing)
    identifier = existing['id']
    if existing.get('plan') != 'free': raise RuntimeError('Solo se autoriza una base gratuita.')
    print('Base de recuperación gratuita: ' + identifier, flush=True)
    for _ in range(60):
        current = api('postgres/' + identifier)
        if current.get('status') == 'available': break
        if current.get('status') in ('creation_failed', 'suspended'): raise RuntimeError('La base de recuperación no está disponible.')
        time.sleep(10)
    else: raise RuntimeError('La base no alcanzó estado disponible.')
    connection = api('postgres/' + identifier + '/connection-info')
    external, internal = connection['externalConnectionString'], connection['internalConnectionString']
    restore(external, source)
    verify(external)
    rows = api('services/' + service['id'] + '/env-vars?limit=100')
    env = {r['envVar']['key']: r['envVar']['value'] for r in rows}
    before = {'service': service['id'], 'database_url_anterior': env['DATABASE_URL'], 'nueva_base': identifier, 'snapshot': SNAPSHOT, 'sha256': DIGEST}
    Path('database-before-recovery.fernet').write_bytes(Fernet(env['BITACORA_FERNET_KEY'].encode()).encrypt(json.dumps(before).encode()))
    api('services/' + service['id'] + '/env-vars/DATABASE_URL', 'PUT', {'value': internal})
    api('services/' + service['id'] + '/env-vars/DATABASE_RECOVERY_SNAPSHOT', 'PUT', {'value': SNAPSHOT})
    print('Conexión preparada para el próximo despliegue. Credenciales conservadas en Render; copia anterior cifrada.', flush=True)
    print('Vencimiento del plan gratuito: ' + str(current.get('expiresAt', '30 días después de la creación')), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['validate', 'restore'])
    args = parser.parse_args()
    source = snapshot()
    restore(os.environ['VALIDATE_DATABASE_URL'], source)
    verify(os.environ['VALIDATE_DATABASE_URL'])
    if args.operation == 'restore': recover(source)


if __name__ == '__main__':
    try: main()
    except Exception as error:
        # No exponer DSN, hashes ni filas de SQL en los logs públicos de Actions.
        print('Recuperación detenida: ' + type(error).__name__ + '. La conexión de producción solo cambia después de validar todos los registros.', flush=True)
        if isinstance(error, RuntimeError): print(str(error), flush=True)
        if isinstance(error, psycopg2.Error): print('SQLSTATE: ' + str(error.pgcode), flush=True)
        if isinstance(error, psycopg2.Error) and error.pgcode in ('42704', '42601', '42P01', '42703'):
            print('Compatibilidad del esquema: ' + str(error.diag.message_primary), flush=True)
        raise SystemExit(1) from None
