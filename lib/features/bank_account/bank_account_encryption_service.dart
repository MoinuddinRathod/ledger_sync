// bank_account_encryption_service.dart

import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class BankAccountEncryptionService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Encrypter? _encrypter;
  bool _initialized = false;

  // Use a SEPARATE key from the password service key
  static const String _keyAlias = 'bank_account_aes_key';

  Future<void> init() async {
    if (_initialized) return;

    String? keyString = await _secureStorage.read(key: _keyAlias);
    if (keyString == null) {
      final key = Key.fromSecureRandom(32);
      await _secureStorage.write(key: _keyAlias, value: key.base64);
      _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    } else {
      final key = Key.fromBase64(keyString);
      _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    }
    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized || _encrypter == null) {
      throw StateError(
        'Call init() before using BankAccountEncryptionService.',
      );
    }
  }

  /// Encrypts the account number. Store this blob in SQLite.
  String encryptAccountNumber(String accountNumber) {
    _ensureInitialized();
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(accountNumber.trim(), iv: iv);
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64Encode(combined);
  }

  /// Decrypts the blob back to the plain account number.
  String decryptAccountNumber(String encryptedData) {
    _ensureInitialized();
    final combined = base64Decode(encryptedData);
    if (combined.length <= 16) throw ArgumentError('Invalid encrypted data.');
    final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
    final cipherBytes = Uint8List.fromList(combined.sublist(16));
    return _encrypter!.decrypt(Encrypted(cipherBytes), iv: iv);
  }

  /// Returns masked display string like ************1234
  /// Shows last [visibleDigits] digits, rest replaced with *
  String maskAccountNumber(String plainAccountNumber, {int visibleDigits = 4}) {
    final plain = plainAccountNumber.trim();
    if (plain.length <= visibleDigits) return plain;
    final masked = '*' * (plain.length - visibleDigits);
    final visible = plain.substring(plain.length - visibleDigits);
    return masked + visible;
  }
}
