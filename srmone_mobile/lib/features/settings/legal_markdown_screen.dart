// lib/features/settings/legal_markdown_screen.dart
// Legal information viewer for Privacy Policy and Terms of Service.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LegalMarkdownScreen extends StatelessWidget {
  final String title;
  final bool isPrivacyPolicy;

  const LegalMarkdownScreen({
    super.key,
    required this.title,
    required this.isPrivacyPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isPrivacyPolicy
            ? _buildPrivacyPolicy(theme)
            : _buildTermsOfService(theme),
      ),
    );
  }

  Widget _buildPrivacyPolicy(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy Policy',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last updated: October 2026',
          style:
              theme.textTheme.bodySmall?.copyWith(color: SrmPalette.slate500),
        ),
        const SizedBox(height: 24),
        _section(
          theme,
          '1. 100% Local-First Architecture',
          'SRMOne operates entirely on your device. We do not operate any middleman proxy, telemetry collector, or cloud backend. Your data is yours alone.',
        ),
        _section(
          theme,
          '2. Credential Security',
          'Your NetID and passwords never leave your physical device except when sent directly over TLS 1.3 encrypted HTTPS to official SRM Institute of Science and Technology servers (academia.srmist.edu.in and sp.srmist.edu.in).\n\nCredentials are encrypted on-device using platform hardware security (Android Keystore / iOS Keychain Secure Enclave).',
        ),
        _section(
          theme,
          '3. Offline Storage',
          'Your timetable, attendance, marks, and calendar are cached locally in an encrypted SQLite database on your device to enable instant offline access.',
        ),
        _section(
          theme,
          '4. Biometric Protection',
          'If enabled, the app uses your device\'s local biometric sensors (FaceID, TouchID, Fingerprint) to unlock. Biometric validation is handled entirely by the operating system.',
        ),
      ],
    );
  }

  Widget _buildTermsOfService(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terms of Service',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last updated: October 2026',
          style:
              theme.textTheme.bodySmall?.copyWith(color: SrmPalette.slate500),
        ),
        const SizedBox(height: 24),
        _section(
          theme,
          '1. Independent Student Utility',
          'SRMOne is an open-source, independent student client designed to improve the mobile user experience for accessing student portals. It is not officially affiliated with, endorsed by, or operated by SRM Institute of Science and Technology.',
        ),
        _section(
          theme,
          '2. Acceptable Use',
          'You agree to use this application solely for personal academic management and in compliance with your university\'s acceptable computer use policies. The app acts solely as an automated user agent browser on your behalf.',
        ),
        _section(
          theme,
          '3. Disclaimer of Warranty',
          'This software is provided "as is", without warranty of any kind. Official university records maintained on university servers always serve as the final authority on attendance, grades, and schedules.',
        ),
      ],
    );
  }

  Widget _section(ThemeData theme, String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
