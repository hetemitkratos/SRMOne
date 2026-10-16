// lib/features/timetable/widgets/exportable_timetable_poster.dart
// High-DPI printable timetable poster rendered offscreen and exported via screenshot & share_plus.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ExportableTimetablePoster extends StatelessWidget {
  final String studentName;
  final String regNumber;
  final String batch;
  final Map<String, List<Map<String, String>>> dayOrderSchedule;

  const ExportableTimetablePoster({
    super.key,
    required this.studentName,
    required this.regNumber,
    required this.batch,
    required this.dayOrderSchedule,
  });

  /// Captures this widget as high-resolution PNG and opens native OS share sheet.
  static Future<void> exportAndShare(
    BuildContext context, {
    required String studentName,
    required String regNumber,
    required String batch,
    required Map<String, List<Map<String, String>>> schedule,
  }) async {
    final controller = ScreenshotController();

    final posterWidget = MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ExportableTimetablePoster(
          studentName: studentName,
          regNumber: regNumber,
          batch: batch,
          dayOrderSchedule: schedule,
        ),
      ),
    );

    try {
      final imageBytes = await controller.captureFromWidget(
        posterWidget,
        pixelRatio: 3.0,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/SRMOne_Timetable_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '$studentName - SRMOne Timetable',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export timetable: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SRM One',
                    style: TextStyle(
                      color: Color(0xFFBDE3D5),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$studentName • $regNumber • Batch $batch',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACADEMIC TIMETABLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24, thickness: 1.5),
          const SizedBox(height: 16),

          // Days 1 through 5 Grid
          ...['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5'].map((day) {
            final classes = dayOrderSchedule[day] ?? [];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      day,
                      style: const TextStyle(
                        color: Color(0xFFBDE3D5),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: classes.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161616),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'No classes scheduled',
                              style: TextStyle(
                                color: Colors.white38,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: classes.map((c) {
                              return Container(
                                width: 175,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['code'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c['title'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Room: ${c['room'] ?? '-'}',
                                      style: const TextStyle(
                                        color: Color(0xFFBDE3D5),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Generated with SRMOne Mobile — Zero-Server Local-First Client',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text(
                'srmone.in',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
