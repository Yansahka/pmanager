import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pmanager/application/vault_controller.dart';
import 'package:pmanager/domain/vault_entry.dart';
import 'package:pmanager/security/vault_crypto.dart';

import 'support/memory_storage.dart';

const phrase = 'vergers nuages cuivre lanternes 47';
const replacement = 'prairies etoiles velours baleines 83';
VaultEntry entry(String id, String password) => VaultEntry(
  id: id,
  title: 'Banque privée',
  username: 'alice@exemple.fr',
  password: password,
  notes: 'Une note confidentielle',
  updatedAt: DateTime.utc(2026, 10, 26),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Generator enforces options, length and character groups', () {
    final seen = <String>{};
    for (var i = 0; i < 100; i++) {
      final p = generatePassword(length: 24);
      expect(p.length, 24);
      expect(RegExp('[a-z]').hasMatch(p), isTrue);
      expect(RegExp('[A-Z]').hasMatch(p), isTrue);
      expect(RegExp('[2-9]').hasMatch(p), isTrue);
      expect(RegExp(r'[^a-zA-Z0-9]').hasMatch(p), isTrue);
      seen.add(p);
    }
    expect(seen.length, 100);
    expect(
      RegExp(r'^[a-zA-Z]+$')
          .hasMatch(generatePassword(digits: false, symbols: false)),
      isTrue,
    );
    expect(() => generatePassword(length: 3), throwsArgumentError);
    expect(masterPasswordError('azerty'), isNotNull);
    expect(masterPasswordError(phrase), isNull);
  });

  test('AES authenticates ciphertext, nonce, tag and format', () async {
    final key = VaultCrypto.randomBytes(32), salt = VaultCrypto.randomBytes(16);
    final one = await VaultCrypto.encrypt('secret', key, salt);
    final two = await VaultCrypto.encrypt('secret', key, salt);
    expect(one, isNot(two));
    expect(await VaultCrypto.decrypt(VaultCrypto.envelope(one), key), 'secret');
    for (final field in ['nonce', 'mac', 'ciphertext']) {
      final tampered = VaultCrypto.envelope(one);
      final bytes = base64Decode(tampered[field] as String);
      bytes[0] ^= 1;
      tampered[field] = base64Encode(bytes);
      await expectLater(VaultCrypto.decrypt(tampered, key), throwsA(anything));
    }
    final badHeader = jsonDecode(one) as Map<String, dynamic>;
    badHeader['iterations'] = 1;
    expect(
      () => VaultCrypto.envelope(jsonEncode(badHeader)),
      throwsFormatException,
    );
  });

  test('Create, save, restart, reject wrong key, rotate and restore', () async {
    final storage = MemoryStorage();
    final vault = VaultController(storage);
    addTearDown(vault.dispose);
    await vault.initialize();
    expect(await vault.open(phrase, confirmation: phrase), isTrue);
    expect(
      await vault.saveEntries([entry('first', 'UneCleTresLongueEtUnique!8')]),
      isTrue,
    );
    for (final plain in [
      'Banque privée',
      'alice@exemple.fr',
      'confidentielle',
      phrase,
    ]) {
      expect(storage.value, isNot(contains(plain)));
    }
    final oldBackup = storage.value!;
    vault.lock();
    expect(vault.entries, isEmpty);
    expect(vault.unlocked, isFalse);
    expect(await vault.open('phrase incorrecte'), isFalse);
    expect(vault.entries, isEmpty);
    expect(await vault.open(phrase), isTrue);
    expect(vault.entries.single.username, 'alice@exemple.fr');

    storage.failWrite = true;
    expect(await vault.saveEntries([]), isFalse);
    expect(storage.value, oldBackup);
    expect(vault.entries, hasLength(1));
    storage.failWrite = false;
    expect(
      await vault.changePassword(phrase, replacement, replacement),
      isTrue,
    );
    final rotated = storage.value!;
    vault.lock();
    expect(await vault.open(phrase), isFalse);
    expect(await vault.open(replacement), isTrue);
    vault.lock();
    expect(await vault.open('incorrect', backup: oldBackup), isFalse);
    expect(storage.value, rotated);
    expect(await vault.open(phrase, backup: oldBackup), isTrue);
    expect(storage.value, oldBackup);

    final restarted = VaultController(storage);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.exists, isTrue);
    expect(restarted.unlocked, isFalse);
    expect(await restarted.open(phrase), isTrue);
    expect(restarted.entries.single.notes, 'Une note confidentielle');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('Lock cancels an in-flight unlock', () async {
    final storage = MemoryStorage();
    final vault = VaultController(storage);
    addTearDown(vault.dispose);
    await vault.initialize();
    final opening = vault.open(phrase, confirmation: phrase);
    vault.lock();
    expect(await opening, isFalse);
    expect(vault.unlocked, isFalse);
    expect(storage.writes, 0);
  });

  test('Read failure blocks creating a new vault', () async {
    final storage = MemoryStorage()..failRead = true;
    final vault = VaultController(storage);
    addTearDown(vault.dispose);
    await vault.initialize();
    expect(await vault.open(phrase, confirmation: phrase), isFalse);
    expect(storage.writes, 0);
  });
}
