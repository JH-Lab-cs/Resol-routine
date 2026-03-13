import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class DeviceIdentityStore {
  Future<String> getOrCreateDeviceId();
}

class SecureDeviceIdentityStore implements DeviceIdentityStore {
  SecureDeviceIdentityStore({required FlutterSecureStorage secureStorage})
    : _secureStorage = secureStorage;

  static const String _storageKey = 'sync_device_id';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await _secureStorage.read(key: _storageKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final generated = _generateDeviceId();
    await _secureStorage.write(key: _storageKey, value: generated);
    return generated;
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'device-$hex';
  }
}
