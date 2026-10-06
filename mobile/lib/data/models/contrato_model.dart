class PagoModel {
  const PagoModel({
    required this.idPago,
    required this.monto,
    required this.fechaPago,
    required this.metodoPago,
    required this.numeroRecibo,
  });

  final int idPago;
  final double monto;
  final String? fechaPago;
  final String metodoPago;
  final String numeroRecibo;

  factory PagoModel.fromJson(Map<String, dynamic> json) => PagoModel(
        idPago: (json['id_pago'] as num?)?.toInt() ?? 0,
        monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
        fechaPago: json['fecha_pago'] as String?,
        metodoPago: json['metodo_pago'] as String? ?? '',
        numeroRecibo: json['numero_recibo'] as String? ?? '',
      );
}

class CuotaModel {
  const CuotaModel({
    required this.idCuota,
    required this.numeroCuota,
    required this.monto,
    required this.fechaVencimiento,
    required this.estado,
  });

  final int idCuota;
  final int numeroCuota;
  final double monto;
  final String fechaVencimiento;
  final String estado;

  factory CuotaModel.fromJson(Map<String, dynamic> json) => CuotaModel(
        idCuota: (json['id_cuota'] as num?)?.toInt() ?? 0,
        numeroCuota: (json['numero_cuota'] as num?)?.toInt() ?? 0,
        monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
        fechaVencimiento: json['fecha_vencimiento'] as String? ?? '',
        estado: json['estado'] as String? ?? 'Pendiente',
      );
}

class ContratoModel {
  const ContratoModel({
    required this.idContrato,
    required this.idTenant,
    required this.idCliente,
    required this.cliente,
    required this.idPropiedad,
    required this.propiedad,
    required this.idAgente,
    required this.agente,
    required this.tipoContrato,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.estado,
    required this.fechaInicio,
    required this.fechaFin,
    required this.cuotasTotales,
    required this.cuotasPagadas,
    required this.pagos,
    required this.cuotas,
  });

  final int idContrato;
  final int idTenant;
  final int idCliente;
  final String? cliente;
  final int idPropiedad;
  final String? propiedad;
  final int? idAgente;
  final String? agente;
  final String tipoContrato;
  final double montoTotal;
  final double saldoPendiente;
  final String estado;
  final String fechaInicio;
  final String? fechaFin;
  final int cuotasTotales;
  final int cuotasPagadas;
  final List<PagoModel> pagos;
  final List<CuotaModel> cuotas;

  factory ContratoModel.fromJson(Map<String, dynamic> json) => ContratoModel(
        idContrato: (json['id_contrato'] as num?)?.toInt() ?? 0,
        idTenant: (json['id_tenant'] as num?)?.toInt() ?? 0,
        idCliente: (json['id_cliente'] as num?)?.toInt() ?? 0,
        cliente: json['cliente'] as String?,
        idPropiedad: (json['id_propiedad'] as num?)?.toInt() ?? 0,
        propiedad: json['propiedad'] as String?,
        idAgente: (json['id_agente'] as num?)?.toInt(),
        agente: json['agente'] as String?,
        tipoContrato: json['tipo_contrato'] as String? ?? '',
        montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0.0,
        saldoPendiente: (json['saldo_pendiente'] as num?)?.toDouble() ?? 0.0,
        estado: json['estado'] as String? ?? 'Activo',
        fechaInicio: json['fecha_inicio'] as String? ?? '',
        fechaFin: json['fecha_fin'] as String?,
        cuotasTotales: (json['cuotas_totales'] as num?)?.toInt() ?? 0,
        cuotasPagadas: (json['cuotas_pagadas'] as num?)?.toInt() ?? 0,
        pagos: (json['pagos'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(PagoModel.fromJson)
            .toList(),
        cuotas: (json['cuotas'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CuotaModel.fromJson)
            .toList(),
      );
}