// lib/scrapers/academia/academia_decoder.dart
// Port of Go's pageSanitizer byte-scanner and [zmlvalue] decoder from
// academia-backend/academia-scraper/cmd/loginprobe/parsers.go

import 'package:html/parser.dart' as html_parser;

class AcademiaDecoder {
  AcademiaDecoder._();

  /// Primary entry point: decodes an Academia Zoho HTML response fragment.
  /// Tries:
  /// 1. pageSanitizer.sanitize('...') byte-scanner
  /// 2. [zmlvalue] attribute unescaper
  /// 3. Returns raw HTML if it already contains <table
  static String decodeHTMLFragment(String raw) {
    if (raw.contains('pageSanitizer.sanitize(')) {
      try {
        final decoded = decodeSanitizedHTML(raw);
        if (decoded.isNotEmpty) return decoded;
      } catch (_) {}
    }

    if (raw.contains('zmlvalue')) {
      try {
        final decoded = decodeZMLValueHTML(raw);
        if (decoded.isNotEmpty) return decoded;
      } catch (_) {}
    }

    return raw;
  }

  /// Scans for `pageSanitizer.sanitize('` and consumes until unescaped `'`,
  /// then unescapes JS escape sequences (\x.., \u...., \n, \r, \t, etc.).
  static String decodeSanitizedHTML(String raw) {
    final payload = extractSanitizePayload(raw);
    return decodeJSString(payload);
  }

  /// Extracts the JS string literal inside `pageSanitizer.sanitize('...')`.
  static String extractSanitizePayload(String raw) {
    const marker = "pageSanitizer.sanitize('";
    final start = raw.indexOf(marker);
    if (start < 0) {
      throw const FormatException('pageSanitizer payload marker not found');
    }

    int i = start + marker.length;
    final buffer = StringBuffer();

    while (i < raw.length) {
      final ch = raw[i];
      if (ch == r'\') {
        if (i + 1 >= raw.length) {
          throw const FormatException(
              'unterminated escape sequence in sanitize payload');
        }
        buffer.write(raw[i]);
        buffer.write(raw[i + 1]);
        i += 2;
        continue;
      }
      if (ch == "'") {
        return buffer.toString();
      }
      buffer.write(ch);
      i++;
    }

    throw const FormatException('unterminated sanitize payload');
  }

  /// Decodes a JavaScript string literal with hex, unicode, and standard escapes.
  static String decodeJSString(String s) {
    final buffer = StringBuffer();
    int i = 0;

    while (i < s.length) {
      if (s[i] != r'\') {
        buffer.write(s[i]);
        i++;
        continue;
      }

      i++; // skip '\'
      if (i >= s.length) {
        throw const FormatException('unterminated escape');
      }

      final ch = s[i];
      switch (ch) {
        case 'x':
          if (i + 2 >= s.length) {
            throw const FormatException('short hex escape');
          }
          final hex = s.substring(i + 1, i + 3);
          buffer.writeCharCode(int.parse(hex, radix: 16));
          i += 3;
        case 'u':
          if (i + 4 >= s.length) {
            throw const FormatException('short unicode escape');
          }
          final hex = s.substring(i + 1, i + 5);
          buffer.writeCharCode(int.parse(hex, radix: 16));
          i += 5;
        case 'n':
          buffer.write('\n');
          i++;
        case 'r':
          buffer.write('\r');
          i++;
        case 't':
          buffer.write('\t');
          i++;
        case 'b':
          buffer.write('\b');
          i++;
        case 'f':
          buffer.write('\f');
          i++;
        case r'\':
        case "'":
        case '"':
        case '/':
          buffer.write(ch);
          i++;
        default:
          buffer.write(ch);
          i++;
      }
    }

    return buffer.toString();
  }

  /// Finds the `[zmlvalue]` attribute in [raw] and decodes its HTML entities.
  static String decodeZMLValueHTML(String raw) {
    final doc = html_parser.parse(raw);
    final elem = doc.querySelector('[zmlvalue]');
    if (elem == null) {
      throw const FormatException('zmlvalue attribute not found');
    }

    final val = elem.attributes['zmlvalue'] ?? '';
    if (val.trim().isEmpty) {
      throw const FormatException('zmlvalue attribute is empty');
    }

    // Unescape HTML entities
    return _unescapeHtml(val);
  }

  static String _unescapeHtml(String html) {
    return html
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
