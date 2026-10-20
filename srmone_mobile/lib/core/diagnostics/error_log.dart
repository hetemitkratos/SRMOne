// lib/core/diagnostics/error_log.dart
// On-device log of uncaught errors, so a tester can share what went wrong.
// Nothing leaves the phone unless the student shares the file from Settings.
// Emails, registration numbers and cookie values are masked before writing.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ErrorLog {
  ErrorLog._();

  /// The log is trimmed to its newest half once it grows past this.
  static const maxBytes = 64 * 1024;

  static const _fileName = 'error_log.txt';

  /// Set by [init]; null until then (and in tests), when entries are only
  /// printed in debug builds.
  static File? _file;

  /// Serialises writes so concurrent errors don't interleave.
  static Future<void> _pending = Future.value();

  /// Opens the log in the app's private support directory.
  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _file = File(p.join(dir.path, _fileName));
  }

  /// The log file, if anything has been written to it.
  static Future<File?> file() async {
    final f = _file;
    return f != null && await f.exists() ? f : null;
  }

  /// Appends [error] with its [stack] and the [context] it happened in.
  /// Never throws.
  static Future<void> record(Object error, StackTrace? stack,
      {String context = ''}) {
    final entry = StringBuffer()
      ..writeln('--- ${DateTime.now().toIso8601String()} $context')
      ..writeln(redact('${error.runtimeType}: $error'));
    if (stack != null) entry.writeln(redact(stack.toString()));
    if (kDebugMode) debugPrint(entry.toString());

    final f = _file;
    if (f == null) return Future.value();
    return _pending = _pending.then((_) async {
      try {
        await f.writeAsString(entry.toString(),
            mode: FileMode.append, flush: true);
        if (await f.length() > maxBytes) {
          final text = await f.readAsString();
          await f.writeAsString(text.substring(text.length ~/ 2));
        }
      } catch (_) {
        // Logging must never cause another error.
      }
    });
  }

  /// Masks emails, SRM registration numbers and cookie/token values.
  @visibleForTesting
  static String redact(String text) => text
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+'), '<email>')
      .replaceAll(RegExp(r'\bRA\d{6,}\b', caseSensitive: false), '<reg-no>')
      .replaceAllMapped(
          RegExp(
              r'((?:cookie|token|session|password|csrf)[\w-]*\s*[=:]\s*)'
              r'[^\s;,&]+',
              caseSensitive: false),
          (m) => '${m[1]}<hidden>');
}
