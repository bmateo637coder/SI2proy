"""Modelos reproducibles entrenados exclusivamente con datos sintéticos declarados."""
from functools import lru_cache
import json
from pathlib import Path

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session, selectinload

from auth import require_reader, is_all_tenants, scope_query, label_tenants
from database import models as m
from database.database import get_db
from saas import require_ai

router = APIRouter(prefix="/api/analitica", tags=["Machine Learning"])


@lru_cache(maxsize=1)
def train_models():
    import numpy as np
    from sklearn.cluster import KMeans
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.metrics import mean_absolute_error, r2_score, silhouette_score
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import StandardScaler

    rng = np.random.default_rng(42)
    n = 1800
    area = rng.uniform(35, 500, n)
    rooms = rng.integers(1, 7, n)
    zone = rng.integers(0, 3, n)
    # Precio de venta sintético en USD. Ninguna fila corresponde a una tasación real.
    price = np.maximum(10000, (area * (550 + zone * 350) + rooms * 3000) * rng.normal(1, .08, n))
    x = np.column_stack([area, rooms, zone])
    x_train, x_test, y_train, y_test = train_test_split(x, price, test_size=.25, random_state=42)
    reg = RandomForestRegressor(n_estimators=80, max_depth=14, random_state=42, n_jobs=1)
    reg.fit(x_train, y_train)
    prediction = reg.predict(x_test)
    # Escalador ajustado exclusivamente al entrenamiento; validación sobre muestra separada.
    scaler = StandardScaler().fit(x_train)
    cluster = KMeans(n_clusters=3, random_state=42, n_init=10).fit(scaler.transform(x_train))
    test_scaled = scaler.transform(x_test)
    labels = cluster.predict(test_scaled)
    metrics = {"origen": "datos_sinteticos", "semilla": 42, "filas": n,
        "entrenamiento": len(x_train), "validacion": len(x_test),
        "variables": ["metros_cuadrados", "habitaciones", "zona_codigo"],
        "objetivo": "precio_venta_usd", "supervisado": "RandomForestRegressor",
        "mae_usd": round(mean_absolute_error(y_test, prediction), 2), "r2": round(r2_score(y_test, prediction), 4),
        "no_supervisado": "KMeans (k=3)", "silhouette_validacion": round(silhouette_score(test_scaled, labels), 4),
        "advertencia": "Validación sobre datos sintéticos. No demuestra precisión de mercado ni sustituye una tasación profesional."}
    return reg, scaler, cluster, metrics, np.column_stack([x, price])


def property_features(prop):
    from reportes_generativos import normalized
    attrs = {normalized(c.nombre): c.valor for c in prop.caracteristicas}
    area = attrs.get("metros cuadrados") or attrs.get("superficie") or attrs.get("m2") or attrs.get("area") or attrs.get("metros_cuadrados")
    rooms = attrs.get("cuartos") or attrs.get("habitaciones") or attrs.get("dormitorios")
    zone = normalized(attrs.get("zona", ""))
    try:
        area, rooms = float(str(area).replace(',', '.')), float(rooms)
        if not rooms.is_integer():
            return None
        if not 35 <= area <= 500 or not 1 <= rooms <= 6:
            return None
    except (TypeError, ValueError):
        return None
    zones = {"economica": 0, "estandar": 1, "premium": 2}
    if zone not in zones or prop.tipo_operacion != "Venta":
        return None
    return [area, rooms, zones[zone]]


@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db), user=Depends(require_reader)):
    require_ai(db, user)
    reg, scaler, cluster, metrics, _ = train_models()
    props = scope_query(db.query(m.Propiedad), user, m.Propiedad.id_tenant).options(
        selectinload(m.Propiedad.caracteristicas)).order_by(m.Propiedad.id_propiedad).limit(500).all()
    label_tenants(db, props)
    rows = []
    valid = [(prop, features) for prop in props if (features := property_features(prop)) is not None]
    omitted = len(props) - len(valid)
    features = [item[1] for item in valid]
    predictions = reg.predict(features) if valid else []
    groups = cluster.predict(scaler.transform(features)) if valid else []
    for (prop, _), prediction, group in zip(valid, predictions, groups):
        predicted = float(prediction)
        rows.append({"id_tenant": prop.id_tenant, "inmobiliaria": prop.inmobiliaria, "id_propiedad": prop.id_propiedad, "titulo": prop.titulo, "precio_publicado": float(prop.precio),
            "precio_estimado_sintetico": round(predicted, 2),
            "grupo": int(group),
            "diferencia_porcentaje": round((float(prop.precio) - predicted) / predicted * 100, 1)})
    return {"metricas": metrics, "propiedades": rows, "omitidas": omitted, "limite": 500,
        "criterio": "Propiedades en venta: 35–500 m², 1–6 habitaciones y Zona Económica, Estándar o Premium. Los grupos no tienen orden de calidad."}


def export_training():
    import numpy as np
    _, _, _, metrics, data = train_models()
    out = Path(__file__).parent / "ml_artifacts"
    out.mkdir(exist_ok=True)
    np.savetxt(out / "inmuebles_sinteticos.csv", data, delimiter=",", comments="",
        header="metros_cuadrados,habitaciones,zona_codigo,precio_venta_usd", fmt="%.2f")
    (out / "metricas.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(metrics, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    export_training()
