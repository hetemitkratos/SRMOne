// lib/scrapers/student_portal/sp_captcha_solver.dart
// On-device CAPTCHA solver using onnxruntime with fallback trigger.
// Runs ddddocr_common.onnx offline with CTC decoding.
// Specification: architecture.md §7

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../../core/constants/asset_paths.dart';

class SpCaptchaSolver {
  static OrtSession? _session;
  static List<String>? _charset;
  static bool _initAttempted = false;

  /// Initializes the ONNX runtime environment and loads the model + charset.
  static Future<bool> init() async {
    if (_session != null && _charset != null) return true;
    if (_initAttempted && _session == null) return false;

    _initAttempted = true;
    try {
      OrtEnv.instance.init();

      // Load charset JSON from Flutter assets
      final charsetStr = await rootBundle.loadString(AssetPaths.ddddocrCharset);
      final rawList = jsonDecode(charsetStr) as List<dynamic>;
      _charset = rawList.map((e) => e.toString()).toList();

      // Load ONNX model bytes from Flutter assets
      final modelData = await rootBundle.load(AssetPaths.ddddocrOnnx);
      final modelBytes = modelData.buffer.asUint8List();

      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Solves the CAPTCHA from raw image bytes.
  /// Returns the predicted string, or null if inference failed.
  static Future<String?> solve(Uint8List imageBytes) async {
    try {
      final initialized = await init();
      if (!initialized || _session == null || _charset == null) {
        return null;
      }

      // 1. Decode image using package:image
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // 2. Resize height to 64px preserving aspect ratio
      const targetHeight = 64;
      final targetWidth = (image.width * (targetHeight / image.height)).round();
      final resized =
          img.copyResize(image, width: targetWidth, height: targetHeight);

      // 3. Build normalized grayscale float tensor: [-1.0, 1.0]
      // Shape: [1, 1, 64, targetWidth]
      final floatData = Float32List(1 * 1 * targetHeight * targetWidth);
      int idx = 0;

      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final pixel = resized.getPixel(x, y);
          // Luminance formula (grayscale)
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          final gray = (0.299 * r + 0.587 * g + 0.114 * b);
          // Normalize to [-1.0, 1.0]: (pixel / 255.0 - 0.5) / 0.5
          floatData[idx++] = ((gray / 255.0) - 0.5) / 0.5;
        }
      }

      // 4. Run OrtSession
      final runOptions = OrtRunOptions();
      final inputShape = [1, 1, targetHeight, targetWidth];
      final inputOrt =
          OrtValueTensor.createTensorWithDataList(floatData, inputShape);

      final inputs = {'input1': inputOrt};
      final outputs = _session!.run(runOptions, inputs);
      inputOrt.release();

      if (outputs.isEmpty || outputs.first == null) return null;

      final outputTensor = outputs.first!;
      final outputList = outputTensor.value as List<dynamic>;
      outputTensor.release();

      // 5. CTC ArgMax decoding
      // Output shape: [batch=1, timeSteps, vocabSize] or flattened
      final predicted = _decodeCTC(outputList, _charset!);
      return predicted.isNotEmpty ? predicted : null;
    } catch (_) {
      return null;
    }
  }

  /// CTC ArgMax decoding with blank token (index 0) removal and adjacent collapse.
  static String _decodeCTC(dynamic outputData, List<String> charset) {
    // outputData is typically List<List<List<double>>> or List<dynamic>
    List<List<double>> timeSteps = [];

    if (outputData is List) {
      if (outputData.isNotEmpty && outputData.first is List) {
        final first = outputData.first as List;
        if (first.isNotEmpty && first.first is List) {
          // [batch][time][vocab]
          for (final t in first) {
            timeSteps
                .add((t as List).map((v) => (v as num).toDouble()).toList());
          }
        } else {
          // [time][vocab]
          for (final t in outputData) {
            timeSteps
                .add((t as List).map((v) => (v as num).toDouble()).toList());
          }
        }
      }
    }

    if (timeSteps.isEmpty) return '';

    final tokens = <int>[];
    for (final step in timeSteps) {
      int maxIdx = 0;
      double maxVal = double.negativeInfinity;
      for (int i = 0; i < step.length; i++) {
        if (step[i] > maxVal) {
          maxVal = step[i];
          maxIdx = i;
        }
      }
      tokens.add(maxIdx);
    }

    // Collapse adjacent duplicates and remove blank token (0)
    final buffer = StringBuffer();
    int prevToken = -1;

    for (final token in tokens) {
      if (token != prevToken) {
        if (token != 0 && token < charset.length) {
          buffer.write(charset[token]);
        }
        prevToken = token;
      }
    }

    return buffer.toString().trim();
  }
}
