"""Actualizar el servicio existente desde Actions sin imprimir credenciales."""
import argparse
import ast
from pathlib import Path
import json
import os
import re
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit, unquote
from urllib.request import Request, urlopen


API = "https://api.render.com/v1/"
EXPECTED_REPO = "https://github.com/bmateo637coder/SI2proy"


def safe(value):
    value = str(value)
    value = re.sub(r"(?:postgres(?:ql)?|mysql|redis)://\S+", "[conexion oculta]", value)
    value = re.sub(r"rnd_[A-Za-z0-9_-]+", "[clave oculta]", value)
    token = os.environ.get("RENDER_API_KEY", "")
    return value.replace(token, "[clave oculta]") if token else value


def api(path, method="GET", body=None):
    token = os.environ.get("RENDER_API_KEY", "").strip()
    if not token:
        raise SystemExit("Falta el secreto RENDER_API_KEY en GitHub Actions.")
    request = Request(API + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + token, "Accept": "application/json",
                 "Content-Type": "application/json", "User-Agent": "SI2proy-deploy"})
    try:
        with urlopen(request, timeout=45) as response:
            content = response.read()
            return json.loads(content) if content else {}
    except HTTPError as error:
        try:
            message = json.loads(error.read()).get("message", "")
        except Exception:
            message = ""
        raise SystemExit(f"Render {method}: HTTP {error.code}. {safe(message)[:500]}") from None
    except URLError:
        raise SystemExit("No se pudo conectar con la API de Render.") from None


def discover(url):
    cursor = None
    found = []
    while True:
        query = {"limit": 100, "includePreviews": "false"}
        if cursor:
            query["cursor"] = cursor
        rows = api("services?" + urlencode(query))
        for row in rows:
            service = row["service"]
            if service.get("serviceDetails", {}).get("url", "").rstrip("/") == url:
                found.append(service)
        if len(rows) < 100 or not rows[-1].get("cursor"):
            break
        cursor = rows[-1]["cursor"]
    if len(found) != 1:
        raise SystemExit("No se encontro un unico servicio para PROD_API_URL. Revisar la cuenta y permisos de la clave.")
    service = found[0]
    if service["type"] != "web_service" or service.get("repo", "").removesuffix(".git") != EXPECTED_REPO:
        raise SystemExit("El servicio no corresponde al backend de este repositorio.")
    return service


def diagnose_database(rows):
    values = {r['envVar']['key']:r['envVar']['value'] for r in rows}
    dsn = values.get('DATABASE_URL','')
    if not dsn: return
    try:
        import psycopg2
        with psycopg2.connect(dsn, connect_timeout=8, options='-c statement_timeout=5000') as connection:
            with connection.cursor() as cursor: cursor.execute('SELECT 1'); cursor.fetchone()
        print('Diagnóstico BD: conexión y consulta de lectura correctas.', flush=True)
    except ImportError:
        print('Diagnóstico BD: controlador no disponible en este ejecutor.',flush=True)
    except Exception as error:
        parsed = urlsplit(dsn)
        message = str(error)
        hidden = [dsn, parsed.hostname, parsed.username, parsed.password, parsed.path.lstrip('/')]
        for value in sorted((unquote(v) for v in hidden if v),key=len,reverse=True): message=message.replace(value,'[oculto]')
        for value in values.values():
            if len(value)>8: message=message.replace(value,'[oculto]')
        print('Diagnóstico BD: ' + type(error).__name__ + ': ' + safe(message)[:1000],flush=True)


def inspect_service(service):
    details = service.get("serviceDetails", {})
    specific = details.get("envSpecificDetails", {})
    summary = {key: service.get(key) for key in
        ("id", "name", "repo", "branch", "rootDir", "suspended", "autoDeploy", "autoDeployTrigger")}
    summary["configuration"] = {"runtime": details.get("runtime", details.get("env")),
        "healthCheckPath": details.get("healthCheckPath"), "url": details.get("url"),
        "buildCommand": specific.get("buildCommand"), "startCommand": specific.get("startCommand"),
        "detailKeys": sorted(details), "runtimeKeys": sorted(specific)}
    rows = api(f"services/{service['id']}/env-vars?limit=100")
    diagnose_database(rows)
    summary["environmentKeys"] = sorted(row["envVar"]["key"] for row in rows)
    for row in rows:
        if row["envVar"]["key"] == "PYTHON_VERSION":
            summary["pythonVersion"] = row["envVar"]["value"]
    recent = api(f"services/{service['id']}/deploys?limit=1")
    if recent:
        latest = recent[0]["deploy"]
        summary["latestDeploy"] = {key: latest.get(key) for key in ("id", "status", "createdAt", "finishedAt")}
        summary["latestDeploy"]["commit"] = latest.get("commit", {}).get("id")
    print(safe(json.dumps(summary, ensure_ascii=False, indent=2)), flush=True)
    try:
        logs = api('logs?' + urlencode({'ownerId':service['ownerId'], 'resource':service['id'], 'limit':100}))
        messages = [r.get('message','') for r in logs.get('logs',[])]
        # Los logs de Actions son públicos: publicar solo señales operativas, sin datos de solicitudes.
        patterns = {'memoria':r'out of memory|OOM|memory limit', 'base_de_datos':r'OperationalError|connection.*(failed|timed out|refused)|UndefinedColumn|UndefinedTable',
                    'inicio':r'Application startup complete|Uvicorn running|Your service is live',
                    'dependencia':r'ModuleNotFoundError|ImportError', 'health':r'health check.*(fail|timed out)', 'tarea_diaria':r'backup diario|registrando vencimientos'}
        print('Diagnóstico de logs: ' + json.dumps({'cantidad':len(messages), 'señales':{k:sum(bool(re.search(v,m,re.I)) for m in messages) for k,v in patterns.items()},
            'excepciones':sorted(set(t for msg in messages for t in re.findall(r'\b([A-Za-z_]+(?:Error|Exception)):',msg)))}), flush=True)
    except (SystemExit, KeyError, TypeError):
        print('Los logs no están disponibles con este acceso; se conserva el estado del servicio.',flush=True)


def verify_health(url, commit=None, attempts=12):
    for attempt in range(attempts):
        try:
            with urlopen(url + "/api/health", timeout=45) as response:
                health = json.load(response)
            valid = health.get("version") == "2.0.0" and {"saas", "offline", "analitica", "tenant_scope_all"}.issubset(health.get("features", []))
            deployed = health.get("commit", "")
            if valid and (not commit or (deployed and commit.startswith(deployed))):
                with urlopen(url + "/openapi.json", timeout=45) as response:
                    paths = json.load(response)["paths"]
                if {"/api/offline/sincronizar", "/api/saas/suscripcion", "/admin/vista-global/resumen", "/api/gerencia/dashboard", "/api/servicios/sync", "/api/visitas"}.issubset(paths):
                    print("API verificada: " + json.dumps(health), flush=True)
                    return
        except (HTTPError, URLError, TimeoutError, ValueError):
            pass
        if attempt < attempts - 1:
            time.sleep(10)
    raise SystemExit("La API publica aun no confirma la version y rutas requeridas.")


def audit_session(service, url):
    env = {r['envVar']['key']: r['envVar']['value'] for r in api(f"services/{service['id']}/env-vars?limit=100")}
    key = env.get('BITACORA_FERNET_KEY')
    if not key: raise SystemExit('No se encontro la clave para conservar la auditoria.')
    source = ast.parse(Path('backend/init_db.py').read_text(encoding='utf-8'))
    credentials = next(ast.literal_eval(n.value) for n in ast.walk(source) if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'usuarios' for t in n.targets))
    admin = next(row for row in credentials if row[2] == 1)
    payload = {'correo': admin[4], 'password': admin[6]}
    def call(path, body=None, token=None):
        headers = {'Content-Type':'application/json'}
        if token: headers['Authorization'] = 'Bearer ' + token
        request = Request(url+path, data=json.dumps(body).encode() if body is not None else None, headers=headers)
        for attempt in range(4):
            try:
                with urlopen(request, timeout=90) as response: return json.load(response)
            except (HTTPError, URLError, TimeoutError):
                if attempt == 3: raise SystemExit('No se pudo preservar o recuperar la auditoria. Se detiene la operacion sin imprimir credenciales.') from None
                time.sleep(10)
    token = call('/login', payload)['access_token']
    return key, lambda path, body=None: call(path, body, token)


def backup_audit(service, url):
    from cryptography.fernet import Fernet
    key, call = audit_session(service, url)
    rows = call('/admin/bitacora?' + urlencode({'dev_key':key}))
    if not isinstance(rows, list): raise SystemExit('Respuesta de bitacora inesperada.')
    encrypted = Fernet(key.encode()).encrypt(json.dumps(rows, ensure_ascii=False).encode())
    Path('audit-pre-deploy.fernet').write_bytes(encrypted)
    print(f'Bitacora respaldada y cifrada: {len(rows)} registros.', flush=True)
    return [{k:r[k] for k in ('ip','usuario','accion','fecha_hora')} for r in rows if all(k in r for k in ('ip','usuario','accion','fecha_hora'))]


def deploy(service, url):
    branch = os.environ["GITHUB_REF_NAME"]
    commit = os.environ["GITHUB_SHA"]
    if branch not in {"feat/parcial2-saas-offline-analitica", "feat/sprint4-integracion-web-movil", "main"}:
        raise SystemExit("Seleccionar la rama del parcial 2 o main para actualizar produccion.")
    service_id = service["id"]
    audit = backup_audit(service, url)
    # Solo se actualiza Python: las credenciales y DATABASE_URL se conservan.
    api(f"services/{service_id}/env-vars/PYTHON_VERSION", "PUT", {"value": "3.12.10"})
    api(f"services/{service_id}", "PATCH", {
        "branch": branch, "rootDir": "backend", "autoDeployTrigger": "off",
        "serviceDetails": {"healthCheckPath": "/api/health", "envSpecificDetails": {
            "buildCommand": "pip install -r requirements.txt", "startCommand": "python start_render.py"}}})
    result = api(f"services/{service_id}/deploys", "POST", {"commitId": commit})
    deploy_id = result["id"]
    print(f"Deploy iniciado: {deploy_id}; commit {commit[:12]}", flush=True)
    deadline = time.monotonic() + 1800
    previous = None
    while time.monotonic() < deadline:
        data = api(f"services/{service_id}/deploys/{deploy_id}")
        status = data["status"]
        if status != previous:
            print(f"Estado Render: {status}", flush=True)
            previous = status
        if status == "live":
            verify_health(url, commit)
            if audit:
                key, call = audit_session(service, url)
                result = call('/admin/bitacora/importar', {'dev_key':key, 'registros':audit})
                print('Auditoria recuperada: ' + str(result['importados']) + ' registros.', flush=True)
            summary = os.environ.get("GITHUB_STEP_SUMMARY")
            if summary:
                with open(summary, "a", encoding="utf8") as file:
                    file.write(f"Backend actualizado: {url}\n\nCommit: `{commit}`\n\nDeploy: `{deploy_id}`\n")
            return
        if status in {"build_failed", "update_failed", "pre_deploy_failed", "canceled", "deactivated"}:
            raise SystemExit(f"El despliegue {deploy_id} termino con estado {status}. Revisar los logs de Render.")
        time.sleep(20)
    raise SystemExit(f"Tiempo de espera agotado para {deploy_id}; comprobar Render antes de reintentar.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=["inspect", "deploy", "verify"])
    args = parser.parse_args()
    url = os.environ.get("PROD_API_URL", "").rstrip("/")
    if url != "https://raices-backend-n1yy.onrender.com":
        raise SystemExit("PROD_API_URL no corresponde al servicio existente.")
    if args.operation == "verify":
        verify_health(url)
        return
    service = discover(url)
    inspect_service(service)
    if args.operation == "deploy":
        deploy(service, url)


if __name__ == "__main__":
    main()
