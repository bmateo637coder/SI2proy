import base64
import os
import re
import sys
import tempfile
import unittest
import zlib
from datetime import date, datetime

BACKEND = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, BACKEND)

os.environ.setdefault("DATABASE_URL", "sqlite:///" + tempfile.gettempdir().replace("\\", "/") + "/test_comprobante.db")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret")
os.environ.setdefault("BITACORA_FERNET_KEY", "test-fernet")

from database.database import engine, Base, SessionLocal  # noqa: E402
from database import models  # noqa: E402
import contratos_router as cr  # noqa: E402
from auth import get_password_hash  # noqa: E402


class TestComprobantePDF(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.drop_all(engine)
        Base.metadata.create_all(engine)
        db = SessionLocal()
        db.add(models.Tenant(id_tenant=1, nombre="Inmobiliaria Test", slug="test"))
        db.flush()
        pw = get_password_hash("Test.123@")
        db.add_all([
            models.Usuario(ci="1000004", id_tenant=1, nombre="Cliente Test", correo="cli@test.com",
                           telefono="70000004", id_rol=3, password_hash=pw),
            models.Usuario(ci="1000002", id_tenant=1, nombre="Agente Test", correo="age@test.com",
                           telefono="70000002", id_rol=3, password_hash=pw),
            models.Usuario(ci="1000003", id_tenant=1, nombre="Propietario Test", correo="prop@test.com",
                           telefono="70000003", id_rol=3, password_hash=pw),
        ])
        db.flush()
        db.add_all([
            models.Cliente(id_cliente=1, ci_usuario="1000004", id_tenant=1),
            models.Agente(id_agente=1, ci_usuario="1000002", id_tenant=1),
            models.Propietario(id_propietario=1, ci_usuario="1000003", id_tenant=1),
        ])
        db.flush()
        db.add(models.Propiedad(id_propiedad=1, id_tenant=1, id_propietario=1, id_agente=1,
                                titulo="Departamento Centro", direccion="Av. Principal 123",
                                precio=1000.0, tipo_operacion="Alquiler"))
        db.flush()
        db.add(models.Contrato(id_contrato=1, id_tenant=1, id_cliente=1, id_propiedad=1, id_agente=1,
                               tipo_contrato="Alquiler", monto_total=1000.0,
                               fecha_inicio=date(2026, 10, 6)))
        db.flush()
        db.add(models.Cuota(id_contrato=1, numero_cuota=1, monto=1000.0,
                            fecha_vencimiento=date(2026, 11, 6), estado="Pagada",
                            fecha_pago=datetime.now()))
        db.add(models.Pago(id_pago=1, id_contrato=1, monto=1000.0, metodo_pago="Transferencia",
                           numero_recibo="REC-1-1"))
        db.commit()
        db.close()

    @classmethod
    def tearDownClass(cls):
        Base.metadata.drop_all(engine)

    def _pago(self):
        db = SessionLocal()
        pago = db.query(models.Pago).filter_by(id_pago=1).first()
        return db, pago

    def test_genera_pdf_valido(self):
        db, pago = self._pago()
        try:
            pdf = cr._generar_pdf_comprobante(pago.contrato, pago)
        finally:
            db.close()
        self.assertTrue(pdf.startswith(b"%PDF-"))
        self.assertGreater(len(pdf), 500)

    def test_comprobante_incluye_datos_clave(self):
        db, pago = self._pago()
        try:
            pdf = cr._generar_pdf_comprobante(pago.contrato, pago).decode("latin-1")
        finally:
            db.close()
        stream = re.search(r"stream\s+(.*?)endstream", pdf, re.S).group(1)
        contenido = zlib.decompress(base64.a85decode(stream, adobe=True)).decode("latin-1")
        self.assertIn("Comprobante de Pago", contenido)
        self.assertIn("REC-1-1", contenido)
        self.assertIn("Transferencia", contenido)


if __name__ == "__main__":
    unittest.main(verbosity=2)