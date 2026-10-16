// lib/core/security/secure_vault_service.dart
// Hardware-backed secure storage wrapper using flutter_secure_storage.
// Replaces backend/utils/crypto.js + Supabase credential storage.
//
// iOS:  Keychain with kSecAttrAccessibleAfterFirstUnlock (allows WorkManager
//       background refreshes while device is locked after first boot unlock).
// Android: EncryptedSharedPreferences backed by Android Keystore.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Typed keys for all secure vault entries.
class VaultKey {
  VaultKey._();
  static const String academiaEmail = 'vault.academia_email';
  static const String academiaPassword = 'vault.academia_password';
  static const String spPassword = 'vault.sp_password';
  static const String academiaCookiesJson = 'vault.academia_cookies_json';
  static const String academiaSavedAt = 'vault.academia_saved_at';
  static const String spCookiesJson = 'vault.sp_cookies_json';
  static const String biometricLockEnabled = 'vault.biometric_lock_enabled';
}

class SecureVaultService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // ─── Academia Credentials ─────────────────────────────────────────────────────

  Future<void> saveAcademiaCredentials({
    required String email,
    required String password,
  }) async {
    await Future.wait([
      _storage.write(key: VaultKey.academiaEmail, value: email),
      _storage.write(key: VaultKey.academiaPassword, value: password),
    ]);
  }

  Future<String?> getAcademiaEmail() =>
      _storage.read(key: VaultKey.academiaEmail);

  Future<String?> getAcademiaPassword() =>
      _storage.read(key: VaultKey.academiaPassword);

  // ─── Student Portal Credentials ───────────────────────────────────────────────

  Future<void> saveSpPassword(String password) =>
      _storage.write(key: VaultKey.spPassword, value: password);

  Future<String?> getSpPassword() => _storage.read(key: VaultKey.spPassword);

  // ─── Academia Cookies ─────────────────────────────────────────────────────────

  Future<void> saveAcademiaCookies(String cookiesJson) async {
    await Future.wait([
      _storage.write(key: VaultKey.academiaCookiesJson, value: cookiesJson),
      _storage.write(
        key: VaultKey.academiaSavedAt,
        value: DateTime.now().toIso8601String(),
      ),
    ]);
  }

  Future<String?> getAcademiaCookiesJson() =>
      _storage.read(key: VaultKey.academiaCookiesJson);

  Future<DateTime?> getAcademiaCookiesSavedAt() async {
    final raw = await _storage.read(key: VaultKey.academiaSavedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ─── Student Portal Cookies ───────────────────────────────────────────────────

  Future<void> saveSpCookies(String cookiesJson) =>
      _storage.write(key: VaultKey.spCookiesJson, value: cookiesJson);

  Future<String?> getSpCookiesJson() =>
      _storage.read(key: VaultKey.spCookiesJson);

  // ─── Biometric Lock ───────────────────────────────────────────────────────────

  Future<void> setBiometricLockEnabled(bool enabled) => _storage.write(
        key: VaultKey.biometricLockEnabled,
        value: enabled.toString(),
      );

  Future<bool> isBiometricLockEnabled() async {
    final raw = await _storage.read(key: VaultKey.biometricLockEnabled);
    return raw == 'true';
  }

  // ─── Session Helpers ──────────────────────────────────────────────────────────

  /// Returns true if the user has saved credentials (email + password stored).
  Future<bool> hasStoredCredentials() async {
    final email = await getAcademiaEmail();
    final password = await getAcademiaPassword();
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  /// Clears all vault entries (full logout / account removal).
  Future<void> clearAll() => _storage.deleteAll();

  /// Clears only cookies (forces re-login on next scrape without removing credentials).
  Future<void> clearCookies() async {
    await Future.wait([
      _storage.delete(key: VaultKey.academiaCookiesJson),
      _storage.delete(key: VaultKey.academiaSavedAt),
      _storage.delete(key: VaultKey.spCookiesJson),
    ]);
  }
}
