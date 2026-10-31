"""Actualizar el servicio existente desde Actions sin imprimir credenciales."""
import argparse
import json
import os
import re
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
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


def verify_health(url, commit=None, attempts=12):
    for attempt in range(attempts):
        try:
            with urlopen(url + "/api/health", timeout=45) as response:
                health = json.load(response)
            valid = health.get("version") == "2.0.0" and {"saas", "offline", "analitica"}.issubset(health.get("features", []))
            deployed = health.get("commit", "")
            if valid and (not commit or (deployed and commit.startswith(deployed))):
                with urlopen(url + "/openapi.json", timeout=45) as response:
                    paths = json.load(response)["paths"]
                if {"/api/offline/sincronizar", "/api/saas/suscripcion", "/admin/vista-global/resumen"}.issubset(paths):
                    print("API verificada: " + json.dumps(health), flush=True)
                    return
        except (HTTPError, URLError, TimeoutError, ValueError):
            pass
        if attempt < attempts - 1:
            time.sleep(10)
    raise SystemExit("La API publica aun no confirma la version y rutas requeridas.")


def deploy(service, url):
    branch = os.environ["GITHUB_REF_NAME"]
    commit = os.environ["GITHUB_SHA"]
    if branch not in {"feat/parcial2-saas-offline-analitica", "main"}:
        raise SystemExit("Seleccionar la rama del parcial 2 o main para actualizar produccion.")
    service_id = service["id"]
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
