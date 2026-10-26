import 'package:flutter/services.dart';

abstract class VaultStorage {
  Future<String?> read();
  Future<void> write(String encrypted);
  Future<bool> exportBackup(String encrypted);
  Future<String?> importBackup();
  Future<void> copySecret(String value);
  Future<void> clearClipboard();
}

class AndroidVaultStorage implements VaultStorage {
  static const _channel = MethodChannel('sesame/vault');
  @override
  Future<String?> read() => _channel.invokeMethod<String>('read');
  @override
  Future<void> write(String encrypted) =>
      _channel.invokeMethod<void>('write', encrypted);
  @override
  Future<bool> exportBackup(String encrypted) async =>
      await _channel.invokeMethod<bool>('export', encrypted) ?? false;
  @override
  Future<String?> importBackup() => _channel.invokeMethod<String>('import');
  @override
  Future<void> copySecret(String value) =>
      _channel.invokeMethod<void>('copy', value);
  @override
  Future<void> clearClipboard() =>
      _channel.invokeMethod<void>('clearClipboard');
}
