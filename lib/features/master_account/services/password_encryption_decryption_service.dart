import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasswordEncryptionDecryptionService {
  static final PasswordEncryptionDecryptionService instance = PasswordEncryptionDecryptionService._internal();
  PasswordEncryptionDecryptionService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Encrypter? _encrypter;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    String? keyString = await _secureStorage.read(key: 'aes_encryption_key');

    if (keyString == null) {
      final key = Key.fromSecureRandom(32);
      await _secureStorage.write(key: 'aes_encryption_key', value: key.base64);
      _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    } else {
      final key = Key.fromBase64(keyString);
      _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    }

    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized || _encrypter == null) {
      throw StateError('Call init() before using the service.');
    }
  }

  // ── SHA-256 hash — for PIN comparison in SQLite ──
  String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  // ── AES Encrypt — for sensitive data ──
  String encryptData(String data) {
    _ensureInitialized();
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(data, iv: iv);
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64Encode(combined);
  }

  // ── AES Decrypt ──
  String decryptData(String encryptedData) {
    _ensureInitialized();
    final combined = base64Decode(encryptedData);
    if (combined.length <= 16) throw ArgumentError('Invalid encrypted data.');
    final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
    final cipherBytes = Uint8List.fromList(combined.sublist(16));
    return _encrypter!.decrypt(Encrypted(cipherBytes), iv: iv);
  }
}
