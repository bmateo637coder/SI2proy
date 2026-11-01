import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/api_constants.dart';

class OfflineIdentity {
  OfflineIdentity({FlutterSecureStorage? storage, this.iterations = 600000})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  final FlutterSecureStorage storage;
  final int iterations;
  String key(String email) =>
      'offline_identity_${base64Url.encode(utf8.encode('${ApiConstants.baseUrl}|${email.trim().toLowerCase()}'))}';

  Future<void> remember(
    String email,
    String password,
    Map<String, dynamic> profile,
    String token,
    List<Map<String, dynamic>> companies,
  ) async {
    final salt = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final derived = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    await storage.write(
      key: key(email),
      value: jsonEncode({
        'salt': base64Encode(salt),
        'verifier': base64Encode(await derived.extractBytes()),
        'iterations': iterations,
        'profile': profile,
        'token': token,
        'companies': companies,
        'failures': 0,
        'locked_until': null,
      }),
    );
  }

  Future<Map<String, dynamic>?> unlock(String email, String password) async {
    final raw = await storage.read(key: key(email));
    if (raw == null) return null;
    final saved = Map<String, dynamic>.from(jsonDecode(raw));
    final locked = DateTime.tryParse(saved['locked_until']?.toString() ?? '');
    if (locked != null && locked.isAfter(DateTime.now().toUtc()))
      throw StateError(
        'Espera un minuto antes de volver a intentar el acceso local.',
      );
    final derived =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: saved['iterations'] as int,
          bits: 256,
        ).deriveKeyFromPassword(
          password: password,
          nonce: base64Decode(saved['salt']),
        );
    if (!constantTimeBytesEquality.equals(
      await derived.extractBytes(),
      base64Decode(saved['verifier']),
    )) {
      final failures = (saved['failures'] as int? ?? 0) + 1;
      saved['failures'] = failures;
      if (failures >= 5)
        saved['locked_until'] = DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 1))
            .toIso8601String();
      await storage.write(key: key(email), value: jsonEncode(saved));
      return null;
    }
    saved['failures'] = 0;
    saved['locked_until'] = null;
    await storage.write(key: key(email), value: jsonEncode(saved));
    return saved;
  }

  Future<void> revoke(String email) => storage.delete(key: key(email));
  Future<void> refreshProfile(
    String email,
    Map<String, dynamic> profile,
    List<Map<String, dynamic>> companies,
  ) async {
    final raw = await storage.read(key: key(email));
    if (raw == null) return;
    final saved = Map<String, dynamic>.from(jsonDecode(raw));
    saved['profile'] = profile;
    saved['companies'] = companies;
    await storage.write(key: key(email), value: jsonEncode(saved));
  }
}
