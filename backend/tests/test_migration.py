from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from database import models as m
import migrate_parcial2


def test_migration_is_additive_and_repeatable(tmp_path,monkeypatch):
    engine=create_engine('sqlite:///'+str(tmp_path/'migration.db'))
    with engine.begin() as conn:
        conn.execute(text('CREATE TABLE tenant (id_tenant INTEGER PRIMARY KEY, nombre VARCHAR(150) NOT NULL, slug VARCHAR(100) NOT NULL, plan VARCHAR(50), max_propiedades INTEGER, fecha_registro TIMESTAMP, estado BOOLEAN, fecha_vencimiento_pago DATE)'))
        conn.execute(text("INSERT INTO tenant(id_tenant,nombre,slug,plan,estado) VALUES(1,'Conservar','conservar','pro',true)"))
        conn.execute(text('CREATE TABLE propiedad (id_propiedad INTEGER PRIMARY KEY, id_tenant INTEGER NOT NULL, id_propietario INTEGER, id_agente INTEGER, titulo VARCHAR(150), descripcion VARCHAR(1000), direccion VARCHAR(255), precio NUMERIC(12,2), tipo_operacion VARCHAR(20), estado VARCHAR(20))'))
        conn.execute(text("INSERT INTO propiedad(id_propiedad,id_tenant,titulo) VALUES(99,1,'Conservar inmueble')"))
    monkeypatch.setattr(migrate_parcial2,'engine',engine)
    migrate_parcial2.migrate()
    migrate_parcial2.migrate()
    with Session(engine) as db:
        assert db.get(m.Propiedad,99).titulo=='Conservar inmueble'
        assert db.get(m.Propiedad,99).version==1
        assert db.get(m.Propiedad,99).id_sucursal is not None
        assert db.get(m.Suscripcion,1).codigo_plan=='profesional'
        assert db.query(m.Sucursal).count()==1
    engine.dispose()
