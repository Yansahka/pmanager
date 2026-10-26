import 'package:pmanager/data/vault_storage.dart';

class MemoryStorage implements VaultStorage {
  String? value;
  bool failWrite = false, failRead = false;
  int writes = 0, clears = 0;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failure');
    return value;
  }

  @override
  Future<void> write(String encrypted) async {
    if (failWrite) throw StateError('write failure');
    value = encrypted;
    writes++;
  }

  @override
  Future<bool> exportBackup(String encrypted) async => true;
  @override
  Future<String?> importBackup() async => value;
  @override
  Future<void> copySecret(String value) async {}
  @override
  Future<void> clearClipboard() async {
    clears++;
  }
}
