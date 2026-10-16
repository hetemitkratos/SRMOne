// lib/features/faculty/faculty_profile_sheet.dart
// Modal bottom sheet displaying detailed faculty profile information,
// fetching live profile details from SRMIST directory if available.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../scrapers/faculty/faculty_client.dart';
import '../../scrapers/faculty/faculty_parser.dart';

class FacultyProfileSheet extends StatefulWidget {
  final String facultyName;
  final String? initialPhotoUrl;
  final String? subjectName;

  const FacultyProfileSheet({
    super.key,
    required this.facultyName,
    this.initialPhotoUrl,
    this.subjectName,
  });

  @override
  State<FacultyProfileSheet> createState() => _FacultyProfileSheetState();
}

class _FacultyProfileSheetState extends State<FacultyProfileSheet> {
  late final FacultyClient _client;
  FacultyParsedProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _client = FacultyClient();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prof = await _client.lookup(widget.facultyName);
    if (mounted) {
      setState(() {
        _profile = prof;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = _profile?.photoUrl ?? widget.initialPhotoUrl;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Avatar
            CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF2D6A4F),
              child: photo != null && photo.startsWith('http')
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photo,
                        httpHeaders: FacultyClient.photoHeaders,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildFallbackInitials(),
                      ),
                    )
                  : _buildFallbackInitials(),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              _profile?.name.isNotEmpty == true
                  ? _profile!.name
                  : widget.facultyName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Designation
            if (_profile?.designation.isNotEmpty == true)
              Text(
                _profile!.designation,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

            // Department & Campus
            if (_profile?.department.isNotEmpty == true ||
                _profile?.campus.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [_profile!.department, _profile!.campus]
                      .where((t) => t.isNotEmpty)
                      .join(' · '),
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),

            if (widget.subjectName != null && widget.subjectName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.subjectName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )
            else ...[
              if (_profile?.email.isNotEmpty == true)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.mail, size: 20),
                  title: Text(_profile!.email),
                  subtitle: const Text('Tap to copy email'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _profile!.email));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${_profile!.email} to clipboard'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              if (_profile != null) ...[
                _detail(theme, 'Specialization', _profile!.specialization),
                _detail(
                    theme, 'Research Interests', _profile!.researchInterest),
                _detail(theme, 'Experience', _profile!.experience),
                _detail(theme, 'Courses', _profile!.courses),
              ],
              if (_profile == null && !_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No extended directory profile found on SRMIST portal.',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(ThemeData theme, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackInitials() {
    final initials = widget.facultyName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Text(
      initials.isEmpty ? 'F' : initials,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 28,
      ),
    );
  }
}
