// lib/core/security/biometric_auth_service.dart
// Biometric authentication wrapper using local_auth package.
// Provides FaceID / TouchID (iOS) and Fingerprint (Android) app lock.

import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device supports biometric authentication and has
  /// enrolled biometrics (face, fingerprint, iris).
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Authenticates the user using biometrics.
  /// Returns true on success, false on failure or cancellation.
  ///
  /// [reason]: The reason string shown in the OS biometric prompt.
  Future<bool> authenticate({
    String reason = 'Authenticate to access your SRMOne dashboard',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow device PIN as fallback
          stickyAuth: true, // Re-show prompt if app goes background
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
