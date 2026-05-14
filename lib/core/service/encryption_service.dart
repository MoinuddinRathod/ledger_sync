import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class EncryptionService {
  EncryptionService._privateConstructor();
  static final EncryptionService instance =
      EncryptionService._privateConstructor();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  encrypt_pkg.Key? _encryptionKey;
  final encrypt_pkg.IV _iv = encrypt_pkg.IV.fromLength(16);

  Future<void> init() async {
    String? storedKey = await _secureStorage.read(key: 'aes_key');
    if (storedKey == null) {
      final key = encrypt_pkg.Key.fromSecureRandom(32);
      await _secureStorage.write(key: 'aes_key', value: key.base64);
      _encryptionKey = key;
    } else {
      _encryptionKey = encrypt_pkg.Key.fromBase64(storedKey);
    }
  }

  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    if (_encryptionKey == null)
      throw Exception("EncryptionService not initialized");

    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_encryptionKey!));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    if (_encryptionKey == null)
      throw Exception("EncryptionService not initialized");

    try {
      final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_encryptionKey!));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      // If decryption fails (e.g. data is unencrypted during migration),
      // return the raw text to gracefully fallback
      return encryptedText;
    }
  }

  String maskAccountNumber(String accountNumber) {
    if (accountNumber.isEmpty) return '';
    if (accountNumber.length <= 4) return '•••• $accountNumber';
    final lastFour = accountNumber.substring(accountNumber.length - 4);
    return '•••• •••• $lastFour';
  }

  String hashSha256(String data) {
    var bytes = utf8.encode(data);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
