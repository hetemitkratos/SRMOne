// lib/scrapers/student_portal/sp_captcha_solver.dart
// On-device CAPTCHA solver using onnxruntime with fallback trigger.
// Runs ddddocr_common.onnx offline with CTC decoding.
// Specification: architecture.md §7
//
// The bundled model is ddddocr's `common.onnx` (the "beta" model). It must be
// paired with ddddocr's CHARSET_BETA (assets/ml/ddddocr_charset.json); the
// CHARSET_OLD list belongs to `common_old.onnx` and maps every index to the
// wrong character. Pre/post-processing mirrors ddddocr's OcrEngine:
//   resize to height 64 (Lanczos in PIL) → grayscale → /255 → [1,1,64,W]
//   output float logits [T,1,C] → argmax per step → CTC collapse, drop blank 0

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../../core/constants/asset_paths.dart';

class SpCaptchaSolver {
  static OrtSession? _session;
  static List<String>? _charset;
  static Future<bool>? _init;

  /// The model's fixed input height.
  static const int inputHeight = 64;

  /// Loads the ONNX model and charset once. Safe to call repeatedly and
  /// concurrently; a failed load is not retried within the same app run.
  static Future<bool> init() => _init ??= _load();

  static Future<bool> _load() async {
    final sw = Stopwatch()..start();
    try {
      OrtEnv.instance.init();

      final charsetStr = await rootBundle.loadString(AssetPaths.ddddocrCharset);
      _charset = (jsonDecode(charsetStr) as List<dynamic>)
          .map((e) => e.toString())
          .toList();

      final modelData = await rootBundle.load(AssetPaths.ddddocrOnnx);
      final sessionOptions = OrtSessionOptions();
      _session =
          OrtSession.fromBuffer(modelData.buffer.asUint8List(), sessionOptions);
      _log('model loaded in ${sw.elapsedMilliseconds} ms');
      return true;
    } catch (e) {
      _log('model load failed: $e');
      return false;
    }
  }

  /// Solves the CAPTCHA from raw image bytes.
  /// Returns the predicted string, or null if inference failed or the answer
  /// does not look like an SRM CAPTCHA.
  static Future<String?> solve(Uint8List imageBytes) async {
    try {
      if (!await init()) return null;
      final session = _session!;
      final charset = _charset!;

      final sw = Stopwatch()..start();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;
      final (floatData, width) = preprocess(image);

      final runOptions = OrtRunOptions();
      final inputOrt = OrtValueTensor.createTensorWithDataList(
          floatData, [1, 1, inputHeight, width]);
      final inputName =
          session.inputNames.isNotEmpty ? session.inputNames.first : 'input1';
      final inputs = {inputName: inputOrt};
      // Off the UI isolate when available, so the spinner keeps turning.
      final outputs = await (session.runAsync(runOptions, inputs) ??
          Future.value(session.run(runOptions, inputs)));
      inputOrt.release();
      runOptions.release();

      if (outputs.isEmpty || outputs.first == null) return null;
      final outputTensor = outputs.first!;
      final raw = outputTensor.value;
      for (final o in outputs) {
        o?.release();
      }

      final predicted = decodeCtc(argmaxPerStep(raw), charset);
      _log('solved in ${sw.elapsedMilliseconds} ms '
          '(${predicted.length} chars)');
      return isPlausibleAnswer(predicted) ? predicted : null;
    } catch (e) {
      _log('solve failed: $e');
      return null;
    }
  }

  /// ddddocr preprocessing: scale to [inputHeight] keeping the aspect ratio,
  /// convert to luminance (ITU-R 601-2, as PIL's `convert('L')`) and scale
  /// to [0, 1]. Returns the row-major tensor data and its width.
  static (Float32List, int) preprocess(img.Image image) {
    final width =
        (image.width * (inputHeight / image.height)).floor().clamp(1, 4096);
    final resized = img.copyResize(image,
        width: width,
        height: inputHeight,
        interpolation: img.Interpolation.cubic);
    final data = Float32List(inputHeight * width);
    var i = 0;
    for (var y = 0; y < inputHeight; y++) {
      for (var x = 0; x < width; x++) {
        final p = resized.getPixel(x, y);
        final gray = (p.r * 299 + p.g * 587 + p.b * 114) / 1000;
        data[i++] = gray.roundToDouble() / 255.0;
      }
    }
    return (data, width);
  }

  /// Argmax over the class axis for every time step. Accepts the model's
  /// `[T, 1, C]` output, a `[1, T, C]` layout, `[T, C]`, or an already
  /// argmaxed `[1, T]` / `[T]` index list.
  static List<int> argmaxPerStep(Object? output) {
    if (output is! List || output.isEmpty) return const [];
    final first = output.first;
    if (first is num) {
      return [for (final v in output) (v as num).toInt()];
    }
    if (first is! List) return const [];

    List<List> steps;
    final inner = first.isNotEmpty ? first.first : null;
    if (inner is List) {
      // 3-D: [T][1][C] when the middle axis is the batch, else [1][T][C].
      steps = first.length == 1
          ? [for (final t in output) (t as List).first as List]
          : [for (final t in first) t as List];
    } else if (output.length == 1 && first.isNotEmpty && first.first is num) {
      // [1][T] already-argmaxed indices, or a lone [1][C] logit row.
      final row = first;
      final looksLikeIndices = row.every((v) => v is int);
      if (looksLikeIndices) return [for (final v in row) v as int];
      steps = [row];
    } else {
      steps = [for (final t in output) t as List];
    }

    return [
      for (final step in steps)
        () {
          var best = 0;
          var bestVal = double.negativeInfinity;
          for (var c = 0; c < step.length; c++) {
            final v = (step[c] as num).toDouble();
            if (v > bestVal) {
              bestVal = v;
              best = c;
            }
          }
          return best;
        }(),
    ];
  }

  /// CTC greedy decode: collapse repeated indices, then drop the blank (0).
  static String decodeCtc(List<int> indices, List<String> charset) {
    final buffer = StringBuffer();
    int? prev;
    for (final idx in indices) {
      if (idx != prev && idx != 0 && idx > 0 && idx < charset.length) {
        buffer.write(charset[idx]);
      }
      prev = idx;
    }
    return buffer.toString().trim();
  }

  /// SRM CAPTCHAs are 4–8 ASCII letters/digits. Anything else is a misread
  /// that would only burn a sign-in attempt.
  static bool isPlausibleAnswer(String s) =>
      RegExp(r'^[A-Za-z0-9]{4,8}$').hasMatch(s);

  static void _log(String message) {
    if (kDebugMode) debugPrint('[SP OCR] $message');
  }
}
