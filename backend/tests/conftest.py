import os
import sys
import tempfile
import atexit
import base64
from uuid import uuid4
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
# Jamás usar el .env del proyecto ni una base del usuario para pruebas.
_test_dir = tempfile.TemporaryDirectory(prefix="raices-tests-")
os.environ["DATABASE_URL"] = "sqlite:///" + str(Path(_test_dir.name) / "legacy.db").replace("\\", "/")
os.environ["JWT_SECRET_KEY"] = "isolated-tests-secret"
os.environ["BITACORA_FERNET_KEY"] = base64.urlsafe_b64encode(os.urandom(32)).decode("ascii")
os.environ["GEMINI_API_KEY"] = ""

from datetime import timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from auth import create_access_token, get_password_hash
from database.database import Base, get_db, engine as legacy_engine
from database import models as m
from saas import today

atexit.register(legacy_engine.dispose)


@pytest.fixture
def api(monkeypatch):
    url = os.getenv("TEST_DATABASE_URL")
    root_engine = None
    schema = "test_" + uuid4().hex
    if url:
        root_engine = create_engine(url)
        with root_engine.begin() as conn:
            conn.execute(text(f'CREATE SCHEMA "{schema}"'))
        engine = root_engine.execution_options(schema_translate_map={None: schema})
    else:
        engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
        event.listen(engine, "connect", lambda conn, _: conn.execute("PRAGMA foreign_keys=ON"))
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    with factory() as db:
        db.add_all([m.Tenant(id_tenant=i, nombre=f"Empresa {i}", slug=f"empresa-{i}") for i in [1,2]])
        db.add_all([m.Rol(id_rol=i,nombre=name) for i,name in [(1,"Super Administrador"),(2,"Administrador"),(3,"Agente"),(4,"Cliente")]])
        db.add_all([m.Plan(codigo="basico",nombre="Básico",max_sucursales=2,reportes_ia=False),
                    m.Plan(codigo="profesional",nombre="Profesional",max_sucursales=10,reportes_ia=True)])
        db.flush()
        for i in [1,2]:
            db.add(m.Suscripcion(id_tenant=i,codigo_plan="profesional" if i==1 else "basico",inicio=today()-timedelta(days=1),vencimiento=today()+timedelta(days=30),estado="activa"))
            db.add(m.Sucursal(id_sucursal=i,id_tenant=i,nombre=f"Sucursal {i}",direccion="Centro"))
        password = get_password_hash("Test.123@")
        for ci,tid,role in [("admin1",1,2),("admin2",2,2),("agent1",1,3),("owner1",1,4),("client1",1,4),("owner2",2,4),("client2",2,4),("super",None,1)]:
            db.add(m.Usuario(ci=ci,id_tenant=tid,id_rol=role,nombre=ci,correo=f"{ci}@example.com",password_hash=password))
        db.flush()
        db.add_all([m.Agente(id_agente=i,id_tenant=i,ci_usuario="agent1" if i==1 else "admin2") for i in [1,2]])
        db.add_all([m.Propietario(id_propietario=i,id_tenant=i,ci_usuario=f"owner{i}") for i in [1,2]])
        db.add_all([m.Cliente(id_cliente=i,id_tenant=i,ci_usuario=f"client{i}") for i in [1,2]])
        db.add(m.UsuarioSucursal(ci_usuario="agent1",id_sucursal=1))
        db.flush()
        for pid,tid,price in [(1,1,1000),(2,1,2000),(3,2,3000)]:
            db.add(m.Propiedad(id_propiedad=pid,id_tenant=tid,id_propietario=tid,id_agente=tid,id_sucursal=tid,
                titulo=f"Casa {pid}",direccion="Centro",precio=price,tipo_operacion="Venta",estado="Disponible"))
        db.commit()
        if url:
            for table in Base.metadata.sorted_tables:
                pk = list(table.primary_key.columns)
                if len(pk) == 1 and pk[0].type.python_type is int:
                    name, col = table.name, pk[0].name
                    db.execute(text(f'''SELECT setval(pg_get_serial_sequence('{schema}.{name}', '{col}'),
                        COALESCE(MAX("{col}"), 1), MAX("{col}") IS NOT NULL) FROM "{schema}"."{name}"'''))
            db.commit()

    def override_db():
        with factory() as db:
            yield db
    main.app.dependency_overrides[get_db] = override_db
    monkeypatch.setattr(main,"log_accion_segura",lambda *args: None)
    # No activa el scheduler de respaldos: las pruebas no deben producir efectos externos.
    client = TestClient(main.app)
    yield client, factory
    main.app.dependency_overrides.clear()
    if root_engine:
        with root_engine.begin() as conn:
            conn.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        root_engine.dispose()
    else:
        engine.dispose()


def headers(ci="admin1", tid=1):
    return {"Authorization":"Bearer "+create_access_token({"sub":f"{ci}@example.com","ci":ci,"id_tenant":tid})}
