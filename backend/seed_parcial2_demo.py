"""Dos empresas independientes. Ejecutar solo sobre una base de demostración."""
import os
from datetime import datetime, timedelta
from decimal import Decimal

from database.database import engine
from sqlalchemy.orm import Session
from database import models as m
from auth import get_password_hash
from migrate_parcial2 import migrate
from saas import today


def seed():
    password = os.getenv("DEMO_PASSWORD")
    if not password or len(password) < 8:
        raise RuntimeError("Defina DEMO_PASSWORD (mínimo 8 caracteres) para las cuentas de demostración.")
    migrate()
    with Session(engine) as db:
        for rid, name in [(1, "Super Administrador"), (2, "Administrador de Empresa")]:
            if not db.get(m.Rol, rid):
                db.add(m.Rol(id_rol=rid, nombre=name))
        db.flush()
        if engine.dialect.name == "postgresql":
            from sqlalchemy import text
            db.execute(text("SELECT setval(pg_get_serial_sequence('rol', 'id_rol'), (SELECT MAX(id_rol) FROM rol))"))
        for slug, name, code in [("demo-raices", "Raíces Demo", "profesional"), ("demo-horizonte", "Horizonte Demo", "basico")]:
            if db.query(m.Tenant).filter_by(slug=slug).first():
                continue
            tenant = m.Tenant(nombre=name, slug=slug, plan=code, estado=True)
            db.add(tenant)
            db.flush()
            tid = tenant.id_tenant
            db.add(m.Suscripcion(id_tenant=tid, codigo_plan=code, inicio=today(), vencimiento=today()+timedelta(days=90), estado="activa"))
            branch = m.Sucursal(id_tenant=tid, nombre="Casa matriz", direccion="Santa Cruz")
            db.add(branch)
            role = m.Rol(id_tenant=tid, nombre="Cliente demo")
            db.add(role)
            db.flush()
            users = {}
            for suffix, rid in [("admin", 2), ("cliente", role.id_rol), ("propietario", role.id_rol)]:
                user = m.Usuario(ci=f"{slug}-{suffix}"[:20], id_tenant=tid, id_rol=rid, nombre=f"{suffix.title()} {name}",
                    correo=f"{suffix}@{slug}.com", password_hash=get_password_hash(password))
                db.add(user)
                users[suffix] = user
            db.flush()
            agent = m.Agente(id_tenant=tid, ci_usuario=users["admin"].ci)
            owner = m.Propietario(id_tenant=tid, ci_usuario=users["propietario"].ci)
            client = m.Cliente(id_tenant=tid, ci_usuario=users["cliente"].ci)
            db.add_all([agent, owner, client])
            db.flush()
            for i in range(18):
                price = Decimal(60000 + i * 12000)
                prop = m.Propiedad(id_tenant=tid, id_sucursal=branch.id_sucursal, id_agente=agent.id_agente,
                    id_propietario=owner.id_propietario, titulo=f"Inmueble demo {i+1}", direccion=f"Calle Demo {i+1}",
                    precio=price, tipo_operacion="Venta", estado="Vendida" if i<12 else "Disponible")
                db.add(prop)
                db.flush()
                for key,value in [("Metros Cuadrados", str(60+i*15)), ("Cuartos", str(1+i%5)), ("Zona", ["Económica","Estándar","Premium"][i%3])]:
                    db.add(m.Caracteristica(id_propiedad=prop.id_propiedad, nombre=key, valor=value))
                if i<12:
                    start = today()-timedelta(days=7*i)
                    contract = m.Contrato(id_tenant=tid, id_propiedad=prop.id_propiedad, id_cliente=client.id_cliente,
                        id_agente=agent.id_agente, monto_total=price, tipo_contrato="Venta", fecha_inicio=start)
                    db.add(contract)
                    db.flush()
                    db.add(m.Pago(id_contrato=contract.id_contrato, monto=price, metodo_pago="Efectivo",
                        numero_recibo=f"DEMO-{contract.id_contrato}", fecha_pago=datetime.combine(start, datetime.min.time())))
            print(f"Empresa demo: {name}; ID {tid}; administrador admin@{slug}.com")
        # Los roles base usan IDs fijos heredados. Asegura la secuencia en PostgreSQL.
        if engine.dialect.name == "postgresql":
            from sqlalchemy import text
            db.execute(text("SELECT setval(pg_get_serial_sequence('rol', 'id_rol'), (SELECT MAX(id_rol) FROM rol))"))
        db.commit()
    print("Demostración preparada. La contraseña es el valor de DEMO_PASSWORD.")


if __name__ == "__main__":
    seed()
