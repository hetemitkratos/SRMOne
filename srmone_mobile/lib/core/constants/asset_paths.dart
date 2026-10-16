// lib/core/constants/asset_paths.dart
// Typed asset path constants for the 13 pruned SVG illustrations, logo, and ML model.
// IMPORTANT: Only these 14 assets exist in assets/. Do NOT reference other SVG paths.

class AssetPaths {
  AssetPaths._();

  // ─── Images ───────────────────────────────────────────────────────────────────
  static const String logo = 'assets/images/logo.png';

  // ─── Illustrations (13 pruned unDraw SVGs) ───────────────────────────────────
  static const String aDayOff = 'assets/illustrations/a-day-off_uk4x.svg';
  static const String calendar = 'assets/illustrations/calendar_8r6s.svg';
  static const String chilling = 'assets/illustrations/chilling_o2zv.svg';
  static const String coffeeTime = 'assets/illustrations/coffee-time_98vi.svg';
  static const String eventsCalendar =
      'assets/illustrations/events-calendar_sudy.svg';
  static const String learning = 'assets/illustrations/learning_qt7d.svg';
  static const String onlineLearning =
      'assets/illustrations/online-learning.svg';
  static const String studying = 'assets/illustrations/studying.svg';
  static const String success = 'assets/illustrations/success_288d.svg';
  static const String target = 'assets/illustrations/target_d6hf.svg';
  static const String timeManagement =
      'assets/illustrations/time-management_4ss6.svg';
  static const String travelPlans =
      'assets/illustrations/travel-plans_l0fo.svg';
  static const String vacationSelfie =
      'assets/illustrations/vacation-selfie_q5bs.svg';

  // ─── ML Models ────────────────────────────────────────────────────────────────
  static const String ddddocrOnnx = 'assets/ml/ddddocr_common.onnx';
  static const String ddddocrCharset = 'assets/ml/ddddocr_charset.json';
}
