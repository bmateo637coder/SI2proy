"""Migración aditiva e idempotente. No elimina tablas ni registros existentes."""
from datetime import timedelta

from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from database.database import Base, engine
from database import models as m
from saas import today


def migrate():
    with engine.begin() as conn:
        if conn.dialect.name == "postgresql":
            # Serializa arranques/despliegues simultáneos sin dejar un bloqueo persistente.
            conn.execute(text("SELECT pg_advisory_xact_lock(20261030, 2)"))
        tables = inspect(conn).get_table_names()
        # create_all no agrega columnas a tablas existentes.
        if "propiedad" in tables:
            columns = {c["name"] for c in inspect(conn).get_columns("propiedad")}
            if "version" not in columns:
                conn.execute(text("ALTER TABLE propiedad ADD COLUMN version INTEGER NOT NULL DEFAULT 1"))
            if "id_sucursal" not in columns:
                # La FK se agrega después de crear sucursal, dentro de la misma transacción.
                m.Sucursal.__table__.create(conn, checkfirst=True)
                conn.execute(text("ALTER TABLE propiedad ADD COLUMN id_sucursal INTEGER REFERENCES sucursal(id_sucursal)"))
        Base.metadata.create_all(conn)
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_propiedad_id_sucursal ON propiedad (id_sucursal)"))
        with Session(conn) as db:
            for code, name, limit, ai in [("basico", "Básico", 2, False), ("profesional", "Profesional", 10, True)]:
                if not db.get(m.Plan, code):
                    db.add(m.Plan(codigo=code, nombre=name, max_sucursales=limit, reportes_ia=ai))
            db.flush()
            for tenant in db.query(m.Tenant).order_by(m.Tenant.id_tenant):
                if not db.get(m.Suscripcion, tenant.id_tenant):
                    code = "profesional" if tenant.plan in {"pro", "profesional", "premium"} else "basico"
                    db.add(m.Suscripcion(id_tenant=tenant.id_tenant, codigo_plan=code,
                        inicio=today(), vencimiento=tenant.fecha_vencimiento_pago or today() + timedelta(days=30),
                        estado="activa" if tenant.estado else "suspendida"))
                branch = db.query(m.Sucursal).filter_by(id_tenant=tenant.id_tenant).order_by(m.Sucursal.id_sucursal).first()
                if not branch:
                    branch = m.Sucursal(id_tenant=tenant.id_tenant, nombre="Casa matriz", direccion="")
                    db.add(branch)
                    db.flush()
                db.query(m.Propiedad).filter_by(id_tenant=tenant.id_tenant, id_sucursal=None).update({"id_sucursal": branch.id_sucursal})
                # En la migración se asigna la matriz a los agentes ya existentes.
                for agent in db.query(m.Agente).filter_by(id_tenant=tenant.id_tenant):
                    if not db.get(m.UsuarioSucursal, (agent.ci_usuario, branch.id_sucursal)):
                        db.add(m.UsuarioSucursal(ci_usuario=agent.ci_usuario, id_sucursal=branch.id_sucursal))
            db.flush()
    print("Migración parcial 2 completada. Datos existentes conservados.")


if __name__ == "__main__":
    migrate()
