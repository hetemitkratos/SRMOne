// lib/features/auth/sp_captcha_bottom_sheet.dart
// Modal bottom sheet displayed when Student Portal CAPTCHA requires manual solving.

import 'dart:typed_data';
import 'package:flutter/material.dart';

class SpCaptchaBottomSheet extends StatefulWidget {
  final Uint8List captchaImage;
  final VoidCallback? onRefreshCaptcha;

  /// Called with the typed text before the sheet closes. The sheet also pops
  /// with the text as its result, so callers can simply await it.
  final ValueChanged<String>? onSubmitCaptcha;

  const SpCaptchaBottomSheet({
    super.key,
    required this.captchaImage,
    this.onRefreshCaptcha,
    this.onSubmitCaptcha,
  });

  @override
  State<SpCaptchaBottomSheet> createState() => _SpCaptchaBottomSheetState();
}

class _SpCaptchaBottomSheetState extends State<SpCaptchaBottomSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.of(context).pop(text);
      widget.onSubmitCaptcha?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Security Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Type the characters shown in the image to verify Student Portal access.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // CAPTCHA image with refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                // Fixed box: the CAPTCHA is ~175x45, so a 200x52 frame shows
                // it at native size. Without a width, an image that fails to
                // decode collapses to a hairline next to the border.
                child: Container(
                  width: 200,
                  height: 52,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Image.memory(
                    widget.captchaImage,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    semanticLabel: 'CAPTCHA image',
                    errorBuilder: (_, __, ___) => const Text(
                      "Couldn't load the image. Tap refresh.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                ),
              ),
              if (widget.onRefreshCaptcha != null) ...[
                const SizedBox(width: 12),
                IconButton.outlined(
                  icon: const Icon(Icons.refresh, color: Color(0xFFBDE3D5)),
                  onPressed: widget.onRefreshCaptcha,
                  tooltip: 'Get new CAPTCHA',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'Enter CAPTCHA text',
              hintStyle:
                  const TextStyle(color: Colors.white30, letterSpacing: 0),
              filled: true,
              fillColor: const Color(0xFF262626),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBDE3D5),
              foregroundColor: const Color(0xFF0F0F0F),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Verify & Continue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the CAPTCHA sheet and returns the typed text, or null if dismissed.
Future<String?> showSpCaptchaSheet(BuildContext context, Uint8List image) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SpCaptchaBottomSheet(captchaImage: image),
  );
}
