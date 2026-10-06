from datetime import date, datetime, timedelta
from io import BytesIO
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy.orm import Session

import schemas
from auth import get_current_user
from database import models
from database.database import get_db

router = APIRouter(prefix="/gestion_contractual", tags=["Gestión Contractual"])

ROLES_OPERATIVOS = (1, 2, 3)
METODOS_PAGO = ("Transferencia", "Efectivo", "QR")


def _es_operativo(user: models.Usuario) -> bool:
    return user.id_rol in ROLES_OPERATIVOS


def _serializar_cuota(cuota: models.Cuota) -> dict:
    return {
        "id_cuota": cuota.id_cuota,
        "numero_cuota": cuota.numero_cuota,
        "monto": float(cuota.monto),
        "fecha_vencimiento": cuota.fecha_vencimiento.isoformat(),
        "estado": cuota.estado,
        "fecha_pago": cuota.fecha_pago.isoformat() if cuota.fecha_pago else None,
    }


def _nombre_usuario(entidad) -> str | None:
    if entidad and entidad.usuario:
        return entidad.usuario.nombre
    return entidad.ci_usuario if entidad else None


def _serializar_contrato(contrato: models.Contrato, detalle: bool = False) -> dict:
    cuotas = list(contrato.cuotas)
    total = float(contrato.monto_total)
    pagado = sum(float(p.monto) for p in contrato.pagos)
    saldo = round(total - pagado, 2)

    vencidas = [
        q for q in cuotas
        if q.estado == "Vencida"
        or (q.estado == "Pendiente" and q.fecha_vencimiento < date.today())
    ]
    if saldo <= 0:
        estado = "Pagado"
    elif vencidas:
        estado = "En Mora"
    else:
        estado = "Activo"

    data = {
        "id_contrato": contrato.id_contrato,
        "id_tenant": contrato.id_tenant,
        "id_cliente": contrato.id_cliente,
        "cliente": _nombre_usuario(contrato.cliente),
        "id_propiedad": contrato.id_propiedad,
        "propiedad": contrato.propiedad.titulo if contrato.propiedad else "",
        "id_agente": contrato.id_agente,
        "agente": _nombre_usuario(contrato.agente),
        "tipo_contrato": contrato.tipo_contrato,
        "monto_total": total,
        "saldo_pendiente": saldo,
        "estado": estado,
        "fecha_inicio": contrato.fecha_inicio.isoformat(),
        "fecha_fin": contrato.fecha_fin.isoformat() if contrato.fecha_fin else None,
        "cuotas_totales": len(cuotas),
        "cuotas_pagadas": len([q for q in cuotas if q.estado == "Pagada"]),
        "pagos": [
            {
                "id_pago": p.id_pago,
                "monto": float(p.monto),
                "fecha_pago": p.fecha_pago.isoformat() if p.fecha_pago else None,
                "metodo_pago": p.metodo_pago,
                "numero_recibo": p.numero_recibo,
            }
            for p in contrato.pagos
        ],
    }
    if detalle:
        data["cuotas"] = [_serializar_cuota(q) for q in sorted(cuotas, key=lambda q: q.numero_cuota)]
    return data


@router.get("/contratos")
def listar_contratos(
    estado: Optional[str] = Query(None, description="Activo, En Mora, Pagado"),
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _es_operativo(current_user):
        raise HTTPException(status_code=403, detail="Sin permisos para operar la gestión contractual.")

    contratos = db.query(models.Contrato).filter(
        models.Contrato.id_tenant == current_user.id_tenant
    ).order_by(models.Contrato.id_contrato.desc()).all()

    resultados = [_serializar_contrato(c) for c in contratos]
    if estado:
        resultados = [r for r in resultados if r["estado"] == estado]
    return resultados


@router.post("/contratos", status_code=201)
def crear_contrato(
    body: schemas.ContratoCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _es_operativo(current_user):
        raise HTTPException(status_code=403, detail="Sin permisos para operar la gestión contractual.")

    if body.tipo_contrato not in ("Venta", "Alquiler", "Anticretico"):
        raise HTTPException(status_code=400, detail="tipo_contrato debe ser Venta, Alquiler o Anticretico.")

    cliente = db.query(models.Cliente).filter(
        models.Cliente.id_cliente == body.id_cliente,
        models.Cliente.id_tenant == current_user.id_tenant,
    ).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado en esta empresa.")

    propiedad = db.query(models.Propiedad).filter(
        models.Propiedad.id_propiedad == body.id_propiedad,
        models.Propiedad.id_tenant == current_user.id_tenant,
    ).first()
    if not propiedad:
        raise HTTPException(status_code=404, detail="Propiedad no encontrada en esta empresa.")

    if body.monto_total <= 0:
        raise HTTPException(status_code=400, detail="El monto total debe ser mayor a 0.")

    if body.num_cuotas and body.num_cuotas > 0:
        num_cuotas = body.num_cuotas
    elif body.tipo_contrato == "Alquiler" and body.fecha_fin and body.fecha_fin > body.fecha_inicio:
        num_cuotas = max(1, (body.fecha_fin.year - body.fecha_inicio.year) * 12
                         + (body.fecha_fin.month - body.fecha_inicio.month))
    else:
        num_cuotas = 1

    contrato = models.Contrato(
        id_tenant=current_user.id_tenant,
        id_cliente=cliente.id_cliente,
        id_propiedad=propiedad.id_propiedad,
        id_agente=propiedad.id_agente,
        tipo_contrato=body.tipo_contrato,
        monto_total=body.monto_total,
        fecha_inicio=body.fecha_inicio,
        fecha_fin=body.fecha_fin,
    )
    db.add(contrato)
    db.flush()

    base_cuota = round(body.monto_total / num_cuotas, 2)
    for i in range(1, num_cuotas + 1):
        monto = base_cuota
        if i == num_cuotas:
            monto = round(body.monto_total - base_cuota * (num_cuotas - 1), 2)
        db.add(models.Cuota(
            id_contrato=contrato.id_contrato,
            numero_cuota=i,
            monto=monto,
            fecha_vencimiento=body.fecha_inicio + timedelta(days=30 * i),
            estado="Pendiente",
        ))

    if propiedad.estado == "Disponible":
        propiedad.estado = "Reservada"

    db.commit()
    db.refresh(contrato)
    return _serializar_contrato(contrato, detalle=True)


@router.get("/contratos/{id_contrato}")
def detalle_contrato(
    id_contrato: int,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _es_operativo(current_user):
        raise HTTPException(status_code=403, detail="Sin permisos para operar la gestión contractual.")

    contrato = db.query(models.Contrato).filter(
        models.Contrato.id_contrato == id_contrato,
        models.Contrato.id_tenant == current_user.id_tenant,
    ).first()
    if not contrato:
        raise HTTPException(status_code=404, detail="Contrato no encontrado.")
    return _serializar_contrato(contrato, detalle=True)


@router.post("/contratos/{id_contrato}/pagos", status_code=201)
def registrar_pago(
    id_contrato: int,
    body: schemas.PagoCreate,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _es_operativo(current_user):
        raise HTTPException(status_code=403, detail="Sin permisos para operar la gestión contractual.")

    if body.monto <= 0:
        raise HTTPException(status_code=400, detail="El monto del pago debe ser mayor a 0.")
    if body.metodo_pago not in METODOS_PAGO:
        raise HTTPException(status_code=400, detail=f"metodo_pago debe ser uno de: {', '.join(METODOS_PAGO)}.")

    contrato = db.query(models.Contrato).filter(
        models.Contrato.id_contrato == id_contrato,
        models.Contrato.id_tenant == current_user.id_tenant,
    ).first()
    if not contrato:
        raise HTTPException(status_code=404, detail="Contrato no encontrado.")

    saldo = _serializar_contrato(contrato)["saldo_pendiente"]
    if body.monto > saldo + 0.001:
        raise HTTPException(status_code=400, detail=f"El monto excede el saldo pendiente ({saldo}).")

    numero_recibo = f"REC-{contrato.id_contrato}-{len(contrato.pagos) + 1}"
    pago = models.Pago(
        id_contrato=contrato.id_contrato,
        monto=body.monto,
        metodo_pago=body.metodo_pago,
        numero_recibo=numero_recibo,
    )
    db.add(pago)
    db.flush()

    cuotas = sorted(
        (q for q in contrato.cuotas if q.estado in ("Pendiente", "Vencida")),
        key=lambda q: q.numero_cuota,
    )
    cubiertas: list[int] = []
    restante = round(body.monto, 2)
    for cuota in cuotas:
        if restante <= 0.001:
            break
        monto_cuota = float(cuota.monto)
        if monto_cuota <= restante + 0.001:
            cuota.estado = "Pagada"
            cuota.fecha_pago = datetime.utcnow()
            restante = round(restante - monto_cuota, 2)
            cubiertas.append(cuota.id_cuota)

    db.commit()
    db.refresh(contrato)

    if _serializar_contrato(contrato)["estado"] == "Pagado" and contrato.tipo_contrato == "Venta":
        if contrato.propiedad.estado != "Vendida":
            contrato.propiedad.estado = "Vendida"
            db.commit()

    return {
        "id_pago": pago.id_pago,
        "numero_recibo": numero_recibo,
        "monto": body.monto,
        "metodo_pago": body.metodo_pago,
        "fecha_pago": pago.fecha_pago.isoformat() if pago.fecha_pago else None,
        "cuotas_cubiertas": cubiertas,
        "comprobante_url": f"/gestion_contractual/pagos/{pago.id_pago}/comprobante",
        "saldo_pendiente": _serializar_contrato(contrato)["saldo_pendiente"],
    }


def _generar_pdf_comprobante(contrato: models.Contrato, pago: models.Pago) -> bytes:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

    buf = BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4, topMargin=18 * mm, bottomMargin=18 * mm)

    estilos = getSampleStyleSheet()
    titulo = ParagraphStyle("Titulo", parent=estilos["Title"], fontSize=20, alignment=1)
    subtitulo = ParagraphStyle("Subtitulo", parent=estilos["Normal"], fontSize=12, alignment=1,
                               textColor=colors.HexColor("#444444"), spaceAfter=18)
    encabezado = ParagraphStyle("Encabezado", parent=estilos["Normal"], fontSize=10, leading=14)
    texto_pequeno = ParagraphStyle("TextoPequeno", parent=estilos["BodyText"], fontSize=8,
                                   textColor=colors.HexColor("#666666"), spaceBefore=2)

    nombre_empresa = contrato.tenant.nombre if contrato.tenant else "Raíces Inmobiliaria"
    cliente_nombre = _nombre_usuario(contrato.cliente) or f"Cliente #{contrato.id_cliente}"
    agente_nombre = _nombre_usuario(contrato.agente) or f"Agente #{contrato.id_agente}"
    fecha_pago = pago.fecha_pago.strftime("%d/%m/%Y %H:%M") if pago.fecha_pago else "—"

    elementos = [
        Paragraph(f"Comprobante de Pago", titulo),
        Paragraph(f"{nombre_empresa}", subtitulo),
        Paragraph(f"<b>N° Recibo:</b> {pago.numero_recibo}", encabezado),
        Paragraph(f"<b>Fecha de pago:</b> {fecha_pago}", encabezado),
        Paragraph(f"<b>Método de pago:</b> {pago.metodo_pago}", encabezado),
        Spacer(1, 8 * mm),
    ]

    encabezados = ["Referencia", "Contrato", "Propiedad", "Tipo"]
    filas = [[
        f"Contrato #{contrato.id_contrato}",
        f"{contrato.tipo_contrato}",
        contrato.propiedad.titulo if contrato.propiedad else "",
        fecha_pago,
    ]]
    tabla_contrato = Table([encabezados] + filas, colWidths=[40 * mm, 40 * mm, 60 * mm, 30 * mm])
    tabla_contrato.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0e7490")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    elementos.append(tabla_contrato)
    elementos.append(Spacer(1, 6 * mm))

    datos = [
        ["Cliente", cliente_nombre],
        ["Agente responsable", agente_nombre],
        ["Monto pagado", f"$us {float(pago.monto):,.2f}"],
        ["Saldo pendiente", f"$us {_serializar_contrato(contrato)['saldo_pendiente']:,.2f}"],
    ]
    tabla_datos = Table(datos, colWidths=[45 * mm, 130 * mm])
    tabla_datos.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#f1f5fd")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    elementos.append(tabla_datos)
    elementos.append(Spacer(1, 8 * mm))

    cuotas = sorted(contrato.cuotas, key=lambda q: q.numero_cuota)
    filas_cuotas = [["N°", "Vencimiento", "Monto", "Estado"]]
    for q in cuotas:
        filas_cuotas.append([
            str(q.numero_cuota),
            q.fecha_vencimiento.strftime("%d/%m/%Y"),
            f"$us {float(q.monto):,.2f}",
            q.estado,
        ])
    tabla_cuotas = Table(filas_cuotas, colWidths=[15 * mm, 50 * mm, 60 * mm, 50 * mm])
    tabla_cuotas.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#333333")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    elementos.extend([
        Paragraph("<b>Plan de cuotas del contrato</b>", encabezado),
        Spacer(1, 3 * mm),
        tabla_cuotas,
        Spacer(1, 10 * mm),
        Paragraph("Este documento es un comprobante digital de pago, válido como respaldo del contrato.",
                  texto_pequeno),
    ])

    doc.build(elementos)
    return buf.getvalue()


@router.get("/pagos/{id_pago}/comprobante")
def comprobante_pago(
    id_pago: int,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _es_operativo(current_user):
        raise HTTPException(status_code=403, detail="Sin permisos para operar la gestión contractual.")

    pago = db.query(models.Pago).join(models.Contrato).filter(
        models.Pago.id_pago == id_pago,
        models.Contrato.id_tenant == current_user.id_tenant,
    ).first()
    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado.")

    pdf = _generar_pdf_comprobante(pago.contrato, pago)
    filename = f"comprobante_{pago.numero_recibo}.pdf"
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )


@router.delete("/contratos/{id_contrato}")
def eliminar_contrato(
    id_contrato: int,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.id_rol not in (1, 2):
        raise HTTPException(status_code=403, detail="Solo Super Admin o Administrador pueden eliminar contratos.")

    contrato = db.query(models.Contrato).filter(
        models.Contrato.id_contrato == id_contrato,
        models.Contrato.id_tenant == current_user.id_tenant,
    ).first()
    if not contrato:
        raise HTTPException(status_code=404, detail="Contrato no encontrado.")
    if contrato.pagos:
        raise HTTPException(status_code=400, detail="No se puede eliminar un contrato con pagos registrados.")

    db.delete(contrato)
    db.commit()
    return {"mensaje": "Contrato eliminado exitosamente."}