"""Publica el APK firmado de Actions sin guardar credenciales locales en GitHub.

Uso: python scripts/publish_mobile_release.py ID_EJECUCION [--tag ETIQUETA]
Autenticación: RELEASE_TOKEN/GH_TOKEN, o la credencial Git existente para github.com.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import HTTPRedirectHandler, Request, build_opener
from zipfile import ZipFile

REPO = 'bmateo637coder/SI2proy'
API = 'https://api.github.com/repos/' + REPO + '/'


class SafeRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new and not newurl.startswith('https://api.github.com/'):
            new.remove_header('Authorization')
        return new


def credential():
    token = os.getenv('RELEASE_TOKEN') or os.getenv('GH_TOKEN')
    if token:
        return token
    result = subprocess.run(['git', 'credential', 'fill'],
        input='protocol=https\nhost=github.com\n\n', text=True, capture_output=True,
        env={**os.environ, 'GCM_INTERACTIVE': 'Never', 'GIT_TERMINAL_PROMPT': '0'}, timeout=45)
    values = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    if not values.get('password'):
        raise RuntimeError('Inicia sesión en Git para github.com o proporciona RELEASE_TOKEN con permisos Contents y Workflows de escritura.')
    return values['password']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run_id', type=int)
    parser.add_argument('--tag')
    parser.add_argument('--release-id', type=int)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--prepare-only', action='store_true', help='Crear el borrador sin cargar archivos.')
    mode.add_argument('--upload-only', action='store_true', help='Cargar archivos en un borrador existente sin publicarlo.')
    args = parser.parse_args()
    token = credential()
    opener = build_opener(SafeRedirect())

    def request(path, method='GET', body=None, raw=False, upload=False, content_type='application/json'):
        url = (('https://uploads.github.com/repos/' + REPO + '/' if upload else API) + path).rstrip('/')
        payload = body if raw else json.dumps(body).encode() if body is not None else None
        req = Request(url, method=method, data=payload, headers={
            'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'Raices-release', 'Content-Type': content_type,
        })
        with opener.open(req, timeout=900 if upload else 180) as response:
            if raw and not upload:
                return response.read()
            data = response.read()
            return json.loads(data) if data else {}

    def optional(path):
        try:
            return request(path)
        except HTTPError as error:
            if error.code == 404:
                return None
            raise

    run = request(f'actions/runs/{args.run_id}')
    if run['head_repository']['id'] != run['repository']['id'] or run['workflow_id'] != 374865708:
        raise RuntimeError('La ejecución no pertenece al workflow de distribución de este repositorio.')
    jobs = request(f'actions/runs/{args.run_id}/jobs?per_page=100')['jobs']
    native = next(j for j in jobs if j['name'] == 'android-test')
    build = next(j for j in jobs if j['name'] == 'build-apk')
    required = {'Compilar APK de producción firmado', 'Preparar descarga y verificar firma', 'Run actions/upload-artifact@v4'}
    successful = {s['name'] for s in build['steps'] if s['conclusion'] == 'success'}
    if native['conclusion'] != 'success' or not required <= successful:
        raise RuntimeError('Faltan pruebas Android o la verificación de firma. No se publicará el APK.')
    artifacts = request(f'actions/runs/{args.run_id}/artifacts')['artifacts']
    artifact = next(a for a in artifacts if a['name'] == 'Raices-Android-2.2.0' and not a['expired'])
    if artifact['workflow_run']['head_sha'] != run['head_sha']:
        raise RuntimeError('El artefacto no coincide con el código comprobado.')
    archive = request(f"actions/artifacts/{artifact['id']}/zip", raw=True)
    if artifact.get('digest') and 'sha256:' + hashlib.sha256(archive).hexdigest() != artifact['digest']:
        raise RuntimeError('El archivo descargado no coincide con el artefacto de Actions.')
    root = Path(__file__).resolve().parents[1]
    out = root / 'mobile/build/releases'
    out.mkdir(parents=True, exist_ok=True)
    archive_path = out / 'verified-actions-artifact.zip'
    archive_path.write_bytes(archive)
    names = ['Raices-2.2.0.apk', 'Raices-2.2.0.apk.sha256']
    with ZipFile(archive_path) as zip_file:
        for name in names:
            info = zip_file.getinfo(name)
            if info.file_size > 500 * 1024 * 1024:
                raise RuntimeError('Tamaño de artefacto inesperado.')
            (out / name).write_bytes(zip_file.read(name))
    expected = (out / names[1]).read_text().split()[0]
    apk = out / names[0]
    with apk.open('rb') as handle:
        if hashlib.file_digest(handle, 'sha256').hexdigest() != expected:
            raise RuntimeError('El SHA-256 del APK no coincide con el verificado por CI.')
    tag = args.tag or f"mobile-2.2.0-{run['run_number']}"
    existing_tag = optional('git/ref/tags/' + quote(tag, safe=''))
    if existing_tag and existing_tag['object']['sha'] != run['head_sha']:
        raise RuntimeError('La etiqueta ya corresponde a otro commit; se conserva sin modificarla.')
    release = request(f'releases/{args.release_id}') if args.release_id else optional('releases/tags/' + quote(tag, safe='')) or next(
        (r for r in request('releases?per_page=30') if r['tag_name'] == tag), None)
    if release and release['target_commitish'] != run['head_sha']:
        raise RuntimeError('La versión existente corresponde a otro commit; se conserva sin modificarla.')
    notes = f'''Raíces Android 2.2.0, conectada al backend de producción.

- SaaS: una o todas las inmobiliarias en catálogo, clientes, contratos y reportes.
- Reportes dinámicos con filtros, configuraciones y exportaciones PDF, Excel, CSV y HTML.
- IA: reportes por texto/voz, analítica, chat, descripciones, recomendaciones y predicciones académicas.
- Offline con SQLite: catálogo por cuenta/empresa, reservas y ventas en efectivo, recuperación tras reinicio y sincronización sin duplicados.

El superadministrador SaaS puede consultar la IA de cualquier inmobiliaria sin adoptar su plan. Las cuentas de las inmobiliarias mantienen los límites de su suscripción. La IA necesita conexión.

La copia autorizada se descarga automáticamente al iniciar sesión. Sin Internet puedes entrar con una cuenta previamente validada, consultar las pantallas habituales, calcular y exportar reportes, registrar contratos y pagos, guardar reportes y registrar reservas o ventas en efectivo. Al volver la conexión se sincronizan las propuestas con el mismo UUID. Los conflictos conservan los datos del servidor y se muestran para revisión. Las herramientas locales se identifican; Gemini requiere Internet.

Código del APK: {run['head_sha']}.
Pruebas Android y firma aprobadas: {run['html_url']}.
La publicación automática de esa ejecución fue rechazada por los permisos del token de Actions. Este APK se publicó desde su artefacto verificado usando el acceso autorizado al repositorio, sin recompilar ni cambiar el archivo.
'''
    if release is None:
        if args.upload_only:
            raise RuntimeError('Primero prepara un borrador con una credencial autorizada para Workflows.')
        release = request('releases', 'POST', {'tag_name': tag, 'target_commitish': run['head_sha'],
            'name': 'Raíces Android 2.2.0', 'body': notes, 'draft': True, 'prerelease': False})
    if args.prepare_only:
        print(json.dumps({'release_id':release['id'],'tag':tag,'sha256':expected}))
        return
    if args.upload_only and not release['draft']:
        raise RuntimeError('La carga de recuperación requiere un borrador, no una versión ya publicada.')
    current = {a['name']: a for a in release.get('assets', [])}
    for name in names:
        data = (out / name).read_bytes()
        if name in current:
            same_digest = current[name].get('digest') == 'sha256:' + hashlib.sha256(data).hexdigest()
            if same_digest:
                continue
            if release['draft'] and current[name]['state'] == 'starter' and current[name]['size'] == 0:
                request('releases/assets/' + str(current[name]['id']), 'DELETE')
            else:
                raise RuntimeError('Existe un archivo publicado con otro contenido; se conserva sin reemplazarlo.')
        print(f"Cargando {name}: {len(data) / (1024 * 1024):.1f} MiB", flush=True)
        request(f"releases/{release['id']}/assets?name={quote(name)}", 'POST', data,
            raw=True, upload=True, content_type='application/vnd.android.package-archive' if name.endswith('.apk') else 'text/plain')
    if args.upload_only:
        print(json.dumps({'release_id':release['id'],'uploaded':names,'sha256':expected}))
        return
    release = request('releases/' + str(release['id']), 'PATCH', {'draft': False, 'make_latest': 'true', 'body': notes})
    print(json.dumps({'release': release['html_url'], 'sha256': expected,
        'assets': [{'name': a['name'], 'url': a['browser_download_url'], 'bytes': a['size']} for a in release['assets']]}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except HTTPError as error:
        print(f'GitHub rechazó la operación: HTTP {error.code}. Comprueba los permisos de la credencial.', file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        print(f'No se publicó: {error}', file=sys.stderr)
        sys.exit(1)
