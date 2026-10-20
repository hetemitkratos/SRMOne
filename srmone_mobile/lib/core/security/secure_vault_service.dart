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
      // Data that can't be decrypted (its Keystore key is gone, e.g. after a
      // restore onto another phone) is wiped instead of throwing on every
      // read, so the student just signs in again.
      resetOnError: true,
    ),
  );

  /// Values already read or written in this isolate. Each secure-storage
  /// call is a platform round trip with a decryption, so credentials are
  /// read once per app run and unchanged values are not rewritten.
  /// Shared by all instances: they all front the same storage.
  static final Map<String, String?> _cache = {};

  /// Keys the background sync (another isolate) may rewrite, so they are
  /// always read from storage rather than from [_cache].
  static const _sharedKeys = {
    VaultKey.academiaCookiesJson,
    VaultKey.academiaSavedAt,
    VaultKey.spCookiesJson,
  };

  Future<String?> _read(String key) async {
    if (!_sharedKeys.contains(key) && _cache.containsKey(key)) {
      return _cache[key];
    }
    final value = await _storage.read(key: key);
    _cache[key] = value;
    return value;
  }

  /// Skips the write when [value] is what this isolate last read or wrote.
  Future<void> _write(String key, String value) async {
    if (_cache.containsKey(key) && _cache[key] == value) return;
    _cache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      _cache.remove(key);
      rethrow;
    }
  }

  Future<void> _delete(String key) async {
    _cache[key] = null;
    await _storage.delete(key: key);
  }

  // ─── Academia Credentials ─────────────────────────────────────────────────────

  Future<void> saveAcademiaCredentials({
    required String email,
    required String password,
  }) async {
    await Future.wait([
      _write(VaultKey.academiaEmail, email),
      _write(VaultKey.academiaPassword, password),
    ]);
  }

  Future<String?> getAcademiaEmail() => _read(VaultKey.academiaEmail);

  Future<String?> getAcademiaPassword() => _read(VaultKey.academiaPassword);

  // ─── Student Portal Credentials ───────────────────────────────────────────────

  Future<void> saveSpPassword(String password) =>
      _write(VaultKey.spPassword, password);

  Future<String?> getSpPassword() => _read(VaultKey.spPassword);

  // ─── Academia Cookies ─────────────────────────────────────────────────────────

  /// Saves the Academia cookie jar. Does nothing when it is what this
  /// isolate last read or saved, so a sync that changed no cookies writes
  /// nothing and the saved-at time records when the session last changed.
  Future<void> saveAcademiaCookies(String cookiesJson) async {
    if (_cache[VaultKey.academiaCookiesJson] == cookiesJson) return;
    await Future.wait([
      _write(VaultKey.academiaCookiesJson, cookiesJson),
      _write(VaultKey.academiaSavedAt, DateTime.now().toIso8601String()),
    ]);
  }

  Future<String?> getAcademiaCookiesJson() =>
      _read(VaultKey.academiaCookiesJson);

  Future<DateTime?> getAcademiaCookiesSavedAt() async {
    final raw = await _read(VaultKey.academiaSavedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ─── Student Portal Cookies ───────────────────────────────────────────────────

  Future<void> saveSpCookies(String cookiesJson) =>
      _write(VaultKey.spCookiesJson, cookiesJson);

  Future<String?> getSpCookiesJson() => _read(VaultKey.spCookiesJson);

  // ─── Biometric Lock ───────────────────────────────────────────────────────────

  Future<void> setBiometricLockEnabled(bool enabled) =>
      _write(VaultKey.biometricLockEnabled, enabled.toString());

  Future<bool> isBiometricLockEnabled() async {
    final raw = await _read(VaultKey.biometricLockEnabled);
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
  Future<void> clearAll() async {
    _cache.clear();
    await _storage.deleteAll();
    // Everything is gone now; remember that instead of re-reading.
    for (final key in _allKeys) {
      _cache[key] = null;
    }
  }

  static const _allKeys = [
    VaultKey.academiaEmail,
    VaultKey.academiaPassword,
    VaultKey.spPassword,
    VaultKey.academiaCookiesJson,
    VaultKey.academiaSavedAt,
    VaultKey.spCookiesJson,
    VaultKey.biometricLockEnabled,
  ];

  /// Clears only cookies (forces re-login on next scrape without removing credentials).
  Future<void> clearCookies() async {
    await Future.wait([
      _delete(VaultKey.academiaCookiesJson),
      _delete(VaultKey.academiaSavedAt),
      _delete(VaultKey.spCookiesJson),
    ]);
  }
}
