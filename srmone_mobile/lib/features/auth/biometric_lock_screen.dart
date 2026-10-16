// lib/features/auth/biometric_lock_screen.dart
// Biometric lock screen gate protecting dashboard when enabled in settings.

import 'package:flutter/material.dart';
import '../../core/security/biometric_auth_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget child;

  const BiometricLockScreen({super.key, required this.child});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final _biometrics = BiometricAuthService();
  bool _authenticated = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() => _isChecking = true);
    final available = await _biometrics.isAvailable();
    if (!available) {
      setState(() {
        _authenticated = true;
        _isChecking = false;
      });
      return;
    }

    final success = await _biometrics.authenticate(
      reason: 'Scan Face or Fingerprint to unlock SRM One',
    );

    setState(() {
      _authenticated = success;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBDE3D5), width: 2),
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 50,
                  color: Color(0xFFBDE3D5),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SRM One Locked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Biometric authentication is required to access your dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (_isChecking)
                const CircularProgressIndicator(color: Color(0xFFBDE3D5))
              else
                ElevatedButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock with Biometrics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBDE3D5),
                    foregroundColor: const Color(0xFF0F0F0F),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
