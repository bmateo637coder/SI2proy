import os
from sqlalchemy import create_engine, text
from database.database import SQLALCHEMY_DATABASE_URL
from database import models

print("Conectando a la base de datos...")
engine = create_engine(SQLALCHEMY_DATABASE_URL)

print("Eliminando tablas existentes...")
models.Base.metadata.drop_all(bind=engine)

print("Creando tablas según models.py...")
models.Base.metadata.create_all(bind=engine)

print("Cargando datos semilla (schema.sql)...")
schema_path = os.path.join(os.path.dirname(__file__), "database", "schema.sql")

with engine.connect() as conn:
    with open(schema_path, "r", encoding="utf-8") as f:
        sql = f.read()
        
    # Split by semicolon to execute commands individually (SQLAlchemy text needs this sometimes)
    # But PostgreSQL usually allows executing the whole block if there's no complex procedure.
    try:
        conn.execute(text(sql))
        conn.commit()
        print("Datos semilla cargados correctamente.")
    except Exception as e:
        print(f"Error cargando el script SQL. Es posible que el script trate de crear tablas que ya existen. Ejecutando sin seed inicial. Error: {e}")

print("Base de datos lista.")
