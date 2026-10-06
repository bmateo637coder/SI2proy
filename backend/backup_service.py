import base64
import json
import os
import shutil
import subprocess
import tempfile
import urllib.request
from datetime import datetime

from sqlalchemy.engine import make_url


def uri_conexion() -> str:
    """Devuelve la URI de conexión a PostgreSQL (incluyendo sslmode si no es local)."""
    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError("DATABASE_URL no está configurada.")
    parsed = make_url(url)
    if parsed.host not in (None, "localhost", "127.0.0.1"):
        sep = "&" if "?" in url else "?"
        if "sslmode" not in url:
            url = url + sep + "sslmode=require"
    return url


def pg_bin_tool(nombre: str) -> str:
    """Localiza pg_dump/psql en el PATH o en PG_BIN_PATH (Windows)."""
    encontrado = shutil.which(nombre)
    if encontrado:
        return nombre
    bin_dir = os.getenv("PG_BIN_PATH")
    if bin_dir:
        candidato = os.path.join(bin_dir, f"{nombre}.exe" if os.name == "nt" else nombre)
        if os.path.exists(candidato):
            return candidato
    return nombre


def _pg_env():
    env = os.environ.copy()
    parsed = make_url(os.getenv("DATABASE_URL", ""))
    if parsed.password:
        env["PGPASSWORD"] = parsed.password
    return env


def generar_backup_sql(dest_dir: str = None) -> str:
    """
    Genera un dump de PostgreSQL (formato texto, --clean) y devuelve la ruta.
    Si dest_dir se provee, guarda el archivo allí; de lo contrario usa un temporal.
    """
    if dest_dir:
        os.makedirs(dest_dir, exist_ok=True)
        filename = f"backup_raices_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql"
        filepath = os.path.join(dest_dir, filename)
    else:
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".sql", prefix="backup_raices_")
        filepath = tmp.name
        tmp.close()

    comando = [
        pg_bin_tool("pg_dump"),
        uri_conexion(),
        "-F", "p",
        "-f", filepath,
        "--clean",
        "--if-exists",
        "--no-owner",
    ]
    resultado = subprocess.run(
        comando, env=_pg_env(), check=True, capture_output=True, text=True, timeout=180
    )
    if resultado.returncode != 0:
        raise RuntimeError(f"pg_dump falló: {resultado.stderr}")
    return filepath


def publicar_backup_github(filepath: str) -> str | None:
    """
    Publica el backup en el repositorio indicado por BACKUP_GITHUB_REPO usando
    BACKUP_GITHUB_TOKEN. Devuelve la URL del archivo o None si no está configurado.
    """
    repo = os.getenv("BACKUP_GITHUB_REPO")
    token = os.getenv("BACKUP_GITHUB_TOKEN")
    if not repo or not token:
        return None

    branch = os.getenv("BACKUP_GITHUB_BRANCH", "backups")
    filename = os.path.basename(filepath)
    ruta = f"backups/{filename}"

    with open(filepath, "rb") as f:
        contenido = base64.b64encode(f.read()).decode()

    url = f"https://api.github.com/repos/{repo}/contents/{ruta}"
    datos = json.dumps({
        "message": f"Backup automático {filename}",
        "content": contenido,
        "branch": branch,
    }).encode()

    req = urllib.request.Request(url, data=datos, method="PUT")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload = json.loads(resp.read().decode())
            return payload.get("content", {}).get("html_url") or f"https://github.com/{repo}/blob/{branch}/{ruta}"
    except Exception as e:
        print(f"Error publicando backup en GitHub: {e}")
        return None


def listar_backups_dir(limit: int = 10) -> list[dict]:
    """Lista los backups automáticos locales (uploads/backups)."""
    dir_path = os.path.join(os.getcwd(), "uploads", "backups")
    if not os.path.isdir(dir_path):
        return []
    archivos = sorted((f for f in os.listdir(dir_path) if f.endswith(".sql")), reverse=True)
    return [
        {"archivo": f, "fecha": f.replace("backup_raices_", "").replace(".sql", "")}
        for f in archivos[:limit]
    ]


def backup_diario() -> dict:
    """Genera el backup diario, lo publica en GitHub si está configurado y poda los locales."""
    dir_path = os.path.join(os.getcwd(), "uploads", "backups")
    os.makedirs(dir_path, exist_ok=True)

    filepath = generar_backup_sql(dir_path)
    url = publicar_backup_github(filepath)

    archivos = sorted(f for f in os.listdir(dir_path) if f.endswith(".sql"))
    for antiguo in archivos[:-7]:
        try:
            os.remove(os.path.join(dir_path, antiguo))
        except OSError:
            pass

    return {
        "archivo": os.path.basename(filepath),
        "url": url,
        "backups_locales": len(archivos),
    }