// lib/features/faculty/faculty_avatar.dart
// Circular faculty avatar with cached network image, fallback initials,
// and tap-to-open FacultyProfileSheet.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'faculty_profile_sheet.dart';

class FacultyAvatar extends StatelessWidget {
  final String facultyName;
  final String? photoUrl;
  final double radius;
  final VoidCallback? onTap;

  const FacultyAvatar({
    super.key,
    required this.facultyName,
    this.photoUrl,
    this.radius = 20,
    this.onTap,
  });

  String _getInitials(String name) {
    final clean = name
        .replaceAll(
            RegExp(r'\b(Dr|Mr|Mrs|Ms|Prof)\.?\s*', caseSensitive: false), '')
        .trim();
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getBackgroundColor(String name) {
    final colors = [
      const Color(0xFF2D6A4F),
      const Color(0xFF1D3557),
      const Color(0xFF457B9D),
      const Color(0xFFE76F51),
      const Color(0xFF6B705C),
      const Color(0xFF8338EC),
      const Color(0xFF3A86FF),
    ];
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasValidPhoto = photoUrl != null &&
        photoUrl!.isNotEmpty &&
        (photoUrl!.startsWith('http://') || photoUrl!.startsWith('https://'));

    return GestureDetector(
      onTap: onTap ??
          () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => FacultyProfileSheet(
                facultyName: facultyName,
                initialPhotoUrl: photoUrl,
              ),
            );
          },
      child: CircleAvatar(
        radius: radius,
        backgroundColor: _getBackgroundColor(facultyName),
        child: hasValidPhoto
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: photoUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildInitials(),
                  placeholder: (_, __) => _buildInitials(),
                ),
              )
            : _buildInitials(),
      ),
    );
  }

  Widget _buildInitials() {
    return Text(
      _getInitials(facultyName),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.8,
      ),
    );
  }
}
