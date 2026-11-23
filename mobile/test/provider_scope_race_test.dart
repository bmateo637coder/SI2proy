import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobiliaria_mobile/data/models/cliente_model.dart';
import 'package:inmobiliaria_mobile/data/models/contrato_model.dart';
import 'package:inmobiliaria_mobile/data/repositories/clientes_repository.dart';
import 'package:inmobiliaria_mobile/data/repositories/contratos_repository.dart';
import 'package:inmobiliaria_mobile/data/services/clientes_service.dart';
import 'package:inmobiliaria_mobile/data/services/contratos_service.dart';
import 'package:inmobiliaria_mobile/presentation/providers/clientes_provider.dart';
import 'package:inmobiliaria_mobile/presentation/providers/contratos_provider.dart';

class Clients extends ClientesRepository {
  Clients() : super(ClientesService(Dio()));
  final created = Completer<ClienteModel>();
  final reads = <Completer<List<ClienteModel>>>[];
  @override
  Future<ClienteModel> createCliente(String ciUsuario) => created.future;
  @override
  Future<List<ClienteModel>> getClientes() {
    final result = Completer<List<ClienteModel>>();
    reads.add(result);
    return result.future;
  }
}

class Contracts extends ContratosRepository {
  Contracts() : super(ContratosService(Dio()));
  final payment = Completer<Map<String, dynamic>>();
  final details = <Completer<ContratoModel>>[];
  @override
  Future<Map<String, dynamic>> registrarPago({
    required int idContrato,
    required double monto,
    required String metodoPago,
  }) => payment.future;
  @override
  Future<ContratoModel> getContratoDetalle(int idContrato) {
    final result = Completer<ContratoModel>();
    details.add(result);
    return result.future;
  }
}

void main() {
  test(
    'client confirmation from previous company never appears in new company',
    () async {
      final repository = Clients();
      final provider = ClientesProvider(repository);
      addTearDown(provider.dispose);
      final pending = provider.createCliente('cliente');
      provider.reset();
      expect(provider.isCreating, isFalse);
      repository.created.complete(
        ClienteModel.fromJson({'id_cliente': 1, 'id_tenant': 1}),
      );
      expect(await pending, isFalse);
      expect(provider.clientes, isEmpty);
      expect(provider.errorMessage, isNull);
    },
  );
  test(
    'latest list refresh wins even when previous response arrives later',
    () async {
      final repository = Clients();
      final provider = ClientesProvider(repository);
      addTearDown(provider.dispose);
      final first = provider.fetchClientes();
      final second = provider.fetchClientes();
      repository.reads[1].complete([
        ClienteModel.fromJson({'id_cliente': 2}),
      ]);
      await second;
      repository.reads[0].complete([
        ClienteModel.fromJson({'id_cliente': 1}),
      ]);
      await first;
      expect(provider.clientes.single.idCliente, 2);
    },
  );
  test(
    'payment confirmation cannot trigger a read under a different company',
    () async {
      final repository = Contracts();
      final provider = ContratosProvider(repository);
      addTearDown(provider.dispose);
      final pending = provider.registrarPago(
        idContrato: 1,
        monto: 100,
        metodoPago: 'Efectivo',
      );
      provider.reset();
      repository.payment.complete({'numero_recibo': 'REC-1'});
      expect(await pending, isNull);
      expect(repository.details, isEmpty);
      expect(provider.successMessage, isNull);
      expect(provider.isSubmitting, isFalse);
    },
  );
  test(
    'opening another contract ignores the previous delayed detail',
    () async {
      final repository = Contracts();
      final provider = ContratosProvider(repository);
      addTearDown(provider.dispose);
      final first = provider.fetchDetalle(1);
      final second = provider.fetchDetalle(2);
      repository.details[1].complete(
        ContratoModel.fromJson({'id_contrato': 2}),
      );
      await second;
      repository.details[0].complete(
        ContratoModel.fromJson({'id_contrato': 1}),
      );
      await first;
      expect(provider.detalle!.idContrato, 2);
    },
  );
  test(
    'a completed request after disposal cannot notify a closed screen',
    () async {
      final repository = Clients();
      final provider = ClientesProvider(repository);
      final pending = provider.fetchClientes();
      provider.dispose();
      repository.reads.single.complete([]);
      await expectLater(pending, completes);
    },
  );
}
