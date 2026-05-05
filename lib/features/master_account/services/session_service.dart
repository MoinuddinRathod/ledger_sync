import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static final SessionService instance = SessionService._internal();
  SessionService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'session_token';
  static const String _accountIdKey = 'session_account_id';
  static const String _accountNameKey = 'session_account_name';

  // ── Generate secure random token ──
  String generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // ── Save session after login ──
  Future<void> saveSession({
    required int accountId,
    required String accountName,
  }) async {
    final token = generateToken();
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _accountIdKey, value: accountId.toString());
    await _storage.write(key: _accountNameKey, value: accountName);
  }

  // ── Check if session exists ──
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<int?> getAccountId() async {
    final id = await _storage.read(key: _accountIdKey);
    return id != null ? int.tryParse(id) : null;
  }

  Future<String?> getAccountName() async {
    return await _storage.read(key: _accountNameKey);
  }

  // ── Clear session on logout ──
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _accountIdKey);
    await _storage.delete(key: _accountNameKey);
  }
}
