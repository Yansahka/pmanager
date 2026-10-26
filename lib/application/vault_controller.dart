import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/vault_storage.dart';
import '../domain/vault_entry.dart';
import '../security/vault_crypto.dart';

class VaultController extends ChangeNotifier {
  final VaultStorage storage;
  VaultController(this.storage);
  bool ready = false, exists = false, busy = false;
  bool readFailed = false;
  bool get unlocked => _key != null;
  String? error;
  Uint8List? _key;
  List<int>? _salt;
  List<VaultEntry> _entries = [];
  List<VaultEntry> get entries => List.unmodifiable(_entries);
  String? _encrypted;
  int _epoch = 0, _failures = 0;
  DateTime? _retryAt;
  Timer? _idle;
  int get retrySeconds {
    final ms = _retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return ms > 0 ? (ms / 1000).ceil() : 0;
  }

  Future<void> initialize() async {
    ready = false;
    error = null;
    notifyListeners();
    try {
      _encrypted = await storage.read();
      exists = _encrypted != null;
      readFailed = false;
    } catch (_) {
      readFailed = true;
      error = 'Lecture du coffre impossible. Réessayez sans effacer les données de l’application.';
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> open(
    String password, {
    String? confirmation,
    String? backup,
  }) async {
    if (busy || retrySeconds > 0 || !ready || readFailed) return false;
    final creating = !exists && backup == null;
    if (creating && masterPasswordError(password) != null) {
      error = masterPasswordError(password);
      notifyListeners();
      return false;
    }
    if (creating && password != confirmation) {
      error = 'Les phrases secrètes ne correspondent pas.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    final epoch = _epoch;
    Uint8List? key;
    try {
      final source = backup ?? _encrypted;
      final envelope = source == null ? null : VaultCrypto.envelope(source);
      final salt = envelope == null
          ? VaultCrypto.randomBytes(16)
          : base64Decode(envelope['salt'] as String);
      key = await VaultCrypto.derive(password, salt);
      final List<VaultEntry> loaded;
      if (envelope == null) {
        loaded = [];
      } else {
        final data = jsonDecode(
          await VaultCrypto.decrypt(envelope, key),
        ) as Map<String, dynamic>;
        if (data['version'] != 1) {
          throw const FormatException('Version invalide');
        }
        loaded = (data['entries'] as List)
            .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loaded.map((e) => e.id).toSet().length != loaded.length) {
          throw const FormatException('Identifiants dupliqués');
        }
      }
      if (epoch != _epoch) return false;
      if (creating || backup != null) {
        final encrypted =
            backup ?? await VaultCrypto.encrypt(_payload(loaded), key, salt);
        await storage.write(encrypted);
        _encrypted = encrypted;
        exists = true;
      }
      if (epoch != _epoch) return false;
      _key = key;
      key = null;
      _salt = salt;
      _entries = loaded;
      _failures = 0;
      _retryAt = null;
      touch();
      return true;
    } catch (_) {
      _failures++;
      if (_failures >= 3) {
        _retryAt = DateTime.now().add(
          Duration(seconds: (_failures * 5).clamp(15, 60)),
        );
      }
      error = 'Impossible d’ouvrir le coffre : phrase incorrecte, fichier endommagé ou stockage indisponible.';
      return false;
    } finally {
      key?.fillRange(0, key.length, 0);
      busy = false;
      notifyListeners();
    }
  }

  String _payload(List<VaultEntry> entries) => jsonEncode({
    'version': 1,
    'entries': entries.map((e) => e.toJson()).toList(),
  });

  Future<bool> saveEntries(List<VaultEntry> next) async {
    if (busy || !unlocked) return false;
    busy = true;
    error = null;
    notifyListeners();
    final epoch = _epoch;
    final key = Uint8List.fromList(_key!);
    try {
      final encrypted = await VaultCrypto.encrypt(_payload(next), key, _salt!);
      if (epoch != _epoch) return false;
      await storage.write(encrypted);
      _encrypted = encrypted;
      if (epoch != _epoch) return false;
      _entries = List.of(next);
      touch();
      return true;
    } catch (_) {
      error =
          'Enregistrement impossible. Vos données précédentes sont conservées.';
      return false;
    } finally {
      key.fillRange(0, key.length, 0);
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
    String current,
    String next,
    String confirmation,
  ) async {
    if (busy || !unlocked) return false;
    error = masterPasswordError(next);
    if (error != null || next != confirmation) {
      error ??= 'Les phrases secrètes ne correspondent pas.';
      notifyListeners();
      return false;
    }
    busy = true;
    notifyListeners();
    final epoch = _epoch;
    Uint8List? check, replacement;
    try {
      check = await VaultCrypto.derive(current, _salt!);
      await VaultCrypto.decrypt(VaultCrypto.envelope(_encrypted!), check);
      final salt = VaultCrypto.randomBytes(16);
      replacement = await VaultCrypto.derive(next, salt);
      if (epoch != _epoch) return false;
      final encrypted = await VaultCrypto.encrypt(
        _payload(_entries),
        replacement,
        salt,
      );
      if (epoch != _epoch) return false;
      await storage.write(encrypted);
      _encrypted = encrypted;
      if (epoch != _epoch) return false;
      _key!.fillRange(0, _key!.length, 0);
      _key = replacement;
      replacement = null;
      _salt = salt;
      touch();
      return true;
    } catch (_) {
      error = 'Modification impossible. Vérifiez la phrase actuelle et le stockage.';
      return false;
    } finally {
      check?.fillRange(0, check.length, 0);
      replacement?.fillRange(0, replacement.length, 0);
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> exportBackup() async {
    if (!unlocked || busy || _encrypted == null) return false;
    final encrypted = _encrypted!;
    // Lock before handing control to Android's document picker.
    lock();
    return storage.exportBackup(encrypted);
  }

  Future<String?> importBackup() async {
    if (busy || readFailed) return null;
    lock();
    final source = await storage.importBackup();
    if (source != null) VaultCrypto.envelope(source);
    return source;
  }

  void touch() {
    if (!unlocked) return;
    _idle?.cancel();
    _idle = Timer(const Duration(minutes: 2), lock);
  }

  void lock() {
    _epoch++;
    _idle?.cancel();
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
    _salt = null;
    _entries = [];
    error = null;
    unawaited(storage.clearClipboard().catchError((_) {}));
    notifyListeners();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _key?.fillRange(0, _key!.length, 0);
    super.dispose();
  }
}
