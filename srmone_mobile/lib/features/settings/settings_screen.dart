// lib/features/settings/settings_screen.dart
// Settings screen for managing Biometrics, Attendance Target Threshold,
// Data Export / Backup, Legal policies, and Account Logout.

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/diagnostics/error_log.dart';
import '../../core/security/biometric_auth_service.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';
import '../shared/cached_data_providers.dart';
import 'legal_markdown_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _biometrics = BiometricAuthService();
  final _packageInfo = PackageInfo.fromPlatform();
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometrics.isAvailable();
    if (mounted) {
      setState(() {
        _biometricSupported = available;
      });
    }
  }

  Future<void> _exportBackup(String email) async {
    final db = ref.read(appDatabaseProvider);
    final attendance = await (db.select(db.attendanceCache)
          ..where((t) => t.academiaEmail.equals(email)))
        .get();
    final profile = await db.getStudentProfile(email);
    final timetable = await db.getTimetable(email);
    final marks = await db.getMarks(email);

    final backup = {
      'exportedAt': DateTime.now().toIso8601String(),
      'academiaEmail': email,
      'profile': profile?.rawDataJson,
      'attendance': attendance
          .map((a) => {
                'code': a.courseCode,
                'title': a.courseTitle,
                'conducted': a.hoursConducted,
                'absent': a.hoursAbsent,
                'pct': a.attendancePct,
              })
          .toList(),
      'timetable': timetable?.coursesJson,
      'marks': marks
          .map((m) => {
                'code': m.courseCode,
                'title': m.courseTitle,
                'source': m.source,
                'tests': m.testsJson,
              })
          .toList(),
    };

    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/srmone_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonEncode(backup));

    if (mounted) {
      final xFile = XFile(file.path, mimeType: 'application/json');
      await Share.shareXFiles([xFile], text: 'SRMOne Data Backup');
    }
  }

  Future<void> _shareErrorLog() async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await ErrorLog.file();
    if (file == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No errors recorded so far.')));
      return;
    }
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/plain')],
        text: 'SRMOne error log');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: email.isEmpty
          ? const Center(child: Text('Not signed in'))
          : Consumer(
              builder: (context, ref, _) {
                final snapshot = ref.watch(userSettingsProvider);
                final settings = snapshot.valueOrNull;
                final biometricEnabled =
                    (settings?.biometricLockEnabled ?? 0) == 1;
                final threshold = settings?.attendanceThreshold ?? 75.0;

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    // Profile Header Card
                    Consumer(
                      builder: (context, ref, _) {
                        final profileSnap = ref.watch(studentProfileProvider);
                        final prof = profileSnap.valueOrNull;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFF2D6A4F),
                                  child: Text(
                                    prof?.name.isNotEmpty == true
                                        ? prof!.name[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prof?.name.isNotEmpty == true
                                            ? prof!.name
                                            : 'Student',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                      if (prof?.regNumber.isNotEmpty == true)
                                        Text(
                                          prof!.regNumber,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    _sectionHeader('Security & Biometrics'),

                    // Biometrics switch
                    ListTile(
                      leading: const Icon(LucideIcons.fingerprint),
                      title: const Text('Biometric Lock'),
                      subtitle: Text(_biometricSupported
                          ? 'Require FaceID / Fingerprint on launch'
                          : 'Biometrics unavailable on this device'),
                      trailing: Switch(
                        value: biometricEnabled,
                        onChanged: !_biometricSupported
                            ? null
                            : (val) async {
                                if (val) {
                                  final authenticated =
                                      await _biometrics.authenticate(
                                    reason:
                                        'Confirm biometrics to enable app lock',
                                  );
                                  if (!authenticated) return;
                                }
                                await db.upsertUserSettings(
                                  UserSettingsTableCompanion(
                                    academiaEmail: drift.Value(email),
                                    biometricLockEnabled:
                                        drift.Value(val ? 1 : 0),
                                  ),
                                );
                              },
                      ),
                    ),

                    const SizedBox(height: 16),
                    _sectionHeader('Attendance Preferences'),

                    // Attendance Threshold Slider
                    ListTile(
                      leading: const Icon(LucideIcons.target),
                      title: const Text('Attendance Target'),
                      subtitle: Text(
                        'Alert when attendance drops below ${threshold.toInt()}%',
                      ),
                    ),
                    Slider(
                      value: threshold,
                      min: 65,
                      max: 90,
                      divisions: 5,
                      label: '${threshold.toInt()}%',
                      onChanged: (val) async {
                        await db.upsertUserSettings(
                          UserSettingsTableCompanion(
                            academiaEmail: drift.Value(email),
                            attendanceThreshold: drift.Value(val),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    _sectionHeader('Data & Privacy'),

                    ListTile(
                      leading: const Icon(LucideIcons.download),
                      title: const Text('Export Local Data Backup'),
                      subtitle: const Text('Save JSON snapshot of your data'),
                      onTap: () => _exportBackup(email),
                    ),

                    ListTile(
                      leading: const Icon(LucideIcons.bug),
                      title: const Text('Share Error Log'),
                      subtitle: const Text(
                          'Errors this app hit, without your NetID or password'),
                      onTap: _shareErrorLog,
                    ),

                    ListTile(
                      leading: const Icon(LucideIcons.shieldCheck),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalMarkdownScreen(
                              title: 'Privacy Policy',
                              isPrivacyPolicy: true,
                            ),
                          ),
                        );
                      },
                    ),

                    ListTile(
                      leading: const Icon(LucideIcons.fileText),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalMarkdownScreen(
                              title: 'Terms of Service',
                              isPrivacyPolicy: false,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    _sectionHeader('Account'),

                    ListTile(
                      leading:
                          const Icon(LucideIcons.logOut, color: Colors.red),
                      title: const Text(
                        'Log Out',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text(
                        'Clears hardware keychain credentials from this device',
                      ),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Log Out?'),
                            content: const Text(
                              'Your credentials will be removed from hardware storage. You will need to log in again next time.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Log Out'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 32),
                    Center(
                      child: FutureBuilder<PackageInfo>(
                        future: _packageInfo,
                        builder: (context, snap) {
                          final info = snap.data;
                          final version = info == null
                              ? ''
                              : ' v${info.version} (${info.buildNumber})';
                          return Text(
                            'SRMOne Mobile$version\nLocal-First, built with Flutter & Drift',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Colors.grey,
        ),
      ),
    );
  }
}
