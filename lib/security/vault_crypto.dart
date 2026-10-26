import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class VaultCrypto {
  static const memory = 19456, iterations = 2;
  static const maxFileBytes = 8 * 1024 * 1024;
  static final _aad = utf8.encode('sesame:v1:argon2id:19456:2:1');

  static Uint8List randomBytes(int count) => Uint8List.fromList(
    List.generate(count, (_) => Random.secure().nextInt(256)),
  );

  static Future<Uint8List> derive(String password, List<int> salt) =>
      Isolate.run(() async {
        final key = await Argon2id(
          parallelism: 1,
          memory: memory,
          iterations: iterations,
          hashLength: 32,
        ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
        return Uint8List.fromList(await key.extractBytes());
      });

  static Map<String, dynamic> envelope(String source) {
    if (utf8.encode(source).length > maxFileBytes) {
      throw const FormatException('Fichier trop volumineux');
    }
    final e = jsonDecode(source) as Map<String, dynamic>;
    if (e['format'] != 'sesame' ||
        e['version'] != 1 ||
        e['kdf'] != 'argon2id' ||
        e['memory'] != memory ||
        e['iterations'] != iterations ||
        e['parallelism'] != 1) {
      throw const FormatException('Format de coffre non pris en charge');
    }
    if (base64Decode(e['salt'] as String).length != 16 ||
        base64Decode(e['nonce'] as String).length != 12 ||
        base64Decode(e['mac'] as String).length != 16) {
      throw const FormatException('En-tête invalide');
    }
    return e;
  }

  static Future<String> encrypt(
    String plaintext,
    List<int> key,
    List<int> salt,
  ) async {
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: randomBytes(12),
      aad: _aad,
    );
    final encoded = jsonEncode({
      'format': 'sesame',
      'version': 1,
      'kdf': 'argon2id',
      'memory': memory,
      'iterations': iterations,
      'parallelism': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
    });
    if (utf8.encode(encoded).length > maxFileBytes) {
      throw const FormatException('Le coffre dépasse la taille autorisée');
    }
    return encoded;
  }

  static Future<String> decrypt(Map<String, dynamic> e, List<int> key) async {
    final bytes = await AesGcm.with256bits().decrypt(
      SecretBox(
        base64Decode(e['ciphertext'] as String),
        nonce: base64Decode(e['nonce'] as String),
        mac: Mac(base64Decode(e['mac'] as String)),
      ),
      secretKey: SecretKey(key),
      aad: _aad,
    );
    try {
      return utf8.decode(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}
