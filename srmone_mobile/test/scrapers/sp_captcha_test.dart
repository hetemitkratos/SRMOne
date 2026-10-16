// test/scrapers/sp_captcha_test.dart
// Student Portal CAPTCHA plumbing: where the image comes from, how a failed
// sign-in is recognised, and the ddddocr post-processing. The ONNX model
// itself needs the native runtime and is exercised on a device.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:srmone_mobile/scrapers/student_portal/sp_captcha_solver.dart';
import 'package:srmone_mobile/scrapers/student_portal/sp_client.dart';
import 'package:srmone_mobile/scrapers/student_portal/sp_parsers.dart';

const _loginUrl =
    'https://sp.srmist.edu.in/srmiststudentportal/students/loginManager/youLogin.jsp';

void main() {
  group('extractCaptchaImageUrl', () {
    test('uses the one-time data-src URL, resolved against the portal', () {
      const html = '<div><img id="secure_captcha" '
          'data-src="/srmiststudentportal/SCaptchaServlet?ts=1792177604093&amp;token=41c0-ab" '
          'alt="Captcha"></div>';
      expect(
        SPParsers.extractCaptchaImageUrl(html, _loginUrl),
        'https://sp.srmist.edu.in/srmiststudentportal/SCaptchaServlet'
        '?ts=1792177604093&token=41c0-ab',
      );
    });

    test('returns empty when the page has no CAPTCHA image', () {
      expect(SPParsers.extractCaptchaImageUrl('<html></html>', _loginUrl), '');
    });
  });

  group('isLoginFailed', () {
    test('landing on the HRDSystem dashboard is success', () {
      expect(
          SPParsers.isLoginFailed(
              'https://sp.srmist.edu.in/srmiststudentportal/students/template/HRDSystem.jsp',
              '<html>alert-danger invalid captcha</html>'),
          isFalse);
    });

    test('bouncing back to the login page is failure even without an alert',
        () {
      expect(SPParsers.isLoginFailed(_loginUrl, '<html></html>'), isTrue);
      expect(
          SPParsers.isLoginFailed(
              'https://sp.srmist.edu.in/srmiststudentportal/LoginServlet', ''),
          isTrue);
    });

    test('alert text tells CAPTCHA mistakes from password mistakes', () {
      const page = '<div class="alert alert-danger">  Invalid\n Captcha </div>';
      expect(SPParsers.extractAlertText(page), 'Invalid Captcha');
      expect(SPClient.isCredentialRejection('Invalid Captcha'), isFalse);
      expect(SPClient.isCredentialRejection('Invalid credentials'), isTrue);
      expect(SPClient.isCredentialRejection('Incorrect password'), isTrue);
      expect(SPClient.isCredentialRejection(''), isFalse);
    });
  });

  group('looksLikeRasterImage', () {
    test('accepts the real portal PNG, rejects an empty 403 body and HTML', () {
      final png = File('test/fixtures/sp_captcha_sample.png').readAsBytesSync();
      expect(SPClient.looksLikeRasterImage(png), isTrue);
      expect(SPClient.looksLikeRasterImage(Uint8List(0)), isFalse);
      expect(
          SPClient.looksLikeRasterImage(
              Uint8List.fromList(utf8.encode('<html>Forbidden</html>'))),
          isFalse);
    });
  });

  group('SpCaptchaSolver post-processing', () {
    // Index 0 is the CTC blank.
    const charset = ['', 'a', 'b', 'c'];

    List<double> logits(int best) =>
        [for (var c = 0; c < charset.length; c++) c == best ? 9.0 : 0.0];

    test('decodes the model\'s [T, 1, C] layout over every time step', () {
      // a a _ a b _ c  →  "aabc"
      final steps = [1, 1, 0, 1, 2, 0, 3];
      final output = [
        for (final s in steps) [logits(s)]
      ];
      expect(
          SpCaptchaSolver.decodeCtc(
              SpCaptchaSolver.argmaxPerStep(output), charset),
          'aabc');
    });

    test('also accepts [1, T, C] and already-argmaxed [1, T]', () {
      final steps = [2, 2, 0, 3];
      expect(
          SpCaptchaSolver.argmaxPerStep([
            [for (final s in steps) logits(s)]
          ]),
          steps);
      expect(
          SpCaptchaSolver.argmaxPerStep([
            [2, 2, 0, 3]
          ]),
          steps);
    });

    test('rejects answers that cannot be an SRM CAPTCHA', () {
      expect(SpCaptchaSolver.isPlausibleAnswer('wHGDtu'), isTrue);
      expect(SpCaptchaSolver.isPlausibleAnswer('ab'), isFalse);
      expect(SpCaptchaSolver.isPlausibleAnswer('考旆绉Ｖ'), isFalse);
    });

    test('preprocess scales to height 64 and normalises to [0, 1]', () {
      final png = File('test/fixtures/sp_captcha_sample.png').readAsBytesSync();
      final image = img.decodeImage(png)!;
      final (data, width) = SpCaptchaSolver.preprocess(image);
      expect(width, (image.width * 64 / image.height).floor());
      expect(data.length, 64 * width);
      expect(data.every((v) => v >= 0 && v <= 1), isTrue);
    });
  });

  test('bundled charset is ddddocr CHARSET_BETA, matching common.onnx', () {
    // CHARSET_OLD (for common_old.onnx) starts '', '掀', '袜'; pairing it with
    // the beta model turns every answer into random CJK characters.
    final charset =
        (jsonDecode(File('assets/ml/ddddocr_charset.json').readAsStringSync())
                as List)
            .cast<String>();
    expect(charset.length, 8210);
    expect(charset.take(4).toList(), ['', '笤', '谴', '膀']);
    final model = File('assets/ml/ddddocr_common.onnx');
    // A git-lfs pointer file is ~130 bytes; the real model is ~54 MB.
    expect(model.lengthSync(), greaterThan(50 * 1024 * 1024));
  });
}
