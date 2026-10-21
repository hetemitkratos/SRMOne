// lib/features/auth/login_screen.dart
// Native login screen with auto-append NetID, the Student Portal password
// (the Academia one unless switched off; attendance comes from the portal)
// and terms of service check.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../scrapers/student_portal/sp_captcha_solver.dart';
import '../settings/legal_markdown_screen.dart';
import 'auth_controller.dart';
import 'student_portal_connector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _spPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureSpPassword = true;

  /// Whether the Student Portal password is the Academia one.
  bool _spSamePassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _spPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please accept the Terms of Service to continue.')),
      );
      return;
    }

    final spPassword =
        _spSamePassword ? _passwordController.text : _spPasswordController.text;
    // Captured before the await: a successful sign-in navigates away and
    // disposes this screen.
    final spConnector = ref.read(studentPortalConnectorProvider.notifier);
    // Load the CAPTCHA model while Academia signs in, so the Student Portal
    // connection doesn't wait for it afterwards.
    if (spPassword.isNotEmpty) unawaited(SpCaptchaSolver.init());
    final success = await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
          spPassword: spPassword.isEmpty ? null : spPassword,
        );
    if (!success) return;

    // The Student Portal connects in the background; the dashboard shows its
    // progress and offers the manual CAPTCHA sheet only if OCR fails.
    if (spPassword.isNotEmpty) unawaited(spConnector.connect());
    // Notification permission is requested once by the dashboard shell;
    // asking here too races it (permissionRequestInProgress).
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;
    final c = SrmColors.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mobile hero, as on the web: logo + wordmark, tagline,
                  // illustration.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 36, 32, 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(AssetPaths.logo, width: 40, height: 40),
                            const SizedBox(width: 12),
                            Text(
                              'SRM ONE',
                              style: TextStyle(
                                fontFamily: SrmFonts.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 28,
                                letterSpacing: -0.8,
                                color: c.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Attendance, marks\nand timetable, in one place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SvgPicture.asset(
                          AssetPaths.studying,
                          height: 150,
                          excludeFromSemantics: true,
                        ),
                      ],
                    ),
                  ),

                  // Form panel: a white sheet with a rounded top.
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: EdgeInsets.fromLTRB(
                        24, 28, 24, 28 + MediaQuery.paddingOf(context).bottom),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(SrmRadii.panel)),
                      boxShadow: [
                        BoxShadow(
                          color: SrmPalette.ink.withAlpha(15),
                          blurRadius: 40,
                          offset: const Offset(0, -12),
                        ),
                      ],
                    ),
                    child: _form(context, authState, isLoading),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, AuthState authState, bool isLoading) {
    final c = SrmColors.of(context);
    final label =
        TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600);
    final link = TextStyle(color: c.text, fontWeight: FontWeight.w700);

    Widget eye(bool obscured, VoidCallback toggle) => IconButton(
          tooltip: obscured ? 'Show password' : 'Hide password',
          icon: Icon(obscured ? Icons.visibility_off : Icons.visibility,
              color: c.faint),
          onPressed: toggle,
        );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            style: TextStyle(
              fontFamily: SrmFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 26,
              letterSpacing: -0.5,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in with your SRM student ID. Everything stays on this phone.',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: c.muted),
          ),
          const SizedBox(height: 24),

          if (authState is AuthError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.bad.withAlpha(20),
                borderRadius: BorderRadius.circular(SrmRadii.field),
                border: Border.all(color: c.bad.withAlpha(70)),
              ),
              child: Text(
                authState.message,
                style: TextStyle(color: c.bad, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // NetID only; the domain is fixed. A pasted full address keeps just
          // the part before the @.
          Text('NetID', style: label),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [_NetIdFormatter()],
            decoration: InputDecoration(
              hintText: 'ab1234',
              prefixIcon: Icon(Icons.person_outline, color: c.faint),
              suffixText: '@srmist.edu.in',
              suffixStyle: TextStyle(
                  color: c.muted, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'NetID is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Academia Password Input
          Text('Academia Password', style: label),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Your Academia portal password',
              prefixIcon: Icon(Icons.lock_outline, color: c.faint),
              suffixIcon: eye(_obscurePassword,
                  () => setState(() => _obscurePassword = !_obscurePassword)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Student Portal password: attendance comes from the portal,
          // so it always connects. Usually the same as Academia's.
          SwitchListTile.adaptive(
            key: const ValueKey('sp-same-password'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _spSamePassword,
            onChanged: (v) => setState(() => _spSamePassword = v),
            title: Text(
              'Student Portal uses the same password',
              style: TextStyle(
                  color: c.text, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),

          if (!_spSamePassword) ...[
            const SizedBox(height: 8),
            Text('Student Portal Password', style: label),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('sp-password'),
              controller: _spPasswordController,
              obscureText: _obscureSpPassword,
              decoration: InputDecoration(
                hintText: 'Your sp.srmist.edu.in password',
                prefixIcon: Icon(Icons.vpn_key_outlined, color: c.faint),
                suffixIcon: eye(
                    _obscureSpPassword,
                    () => setState(
                        () => _obscureSpPassword = !_obscureSpPassword)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Enter your Student Portal password';
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: 14),

          // Terms and Privacy Checkbox
          Row(
            children: [
              Checkbox(
                value: _acceptedTerms,
                activeColor: c.hero,
                checkColor: c.onHero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    style: TextStyle(color: c.muted, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Privacy Policy',
                        style: link,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LegalMarkdownScreen(
                                  title: 'Privacy Policy',
                                  isPrivacyPolicy: true,
                                ),
                              ),
                            );
                          },
                      ),
                      const TextSpan(text: ' & '),
                      TextSpan(
                        text: 'Terms',
                        style: link,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LegalMarkdownScreen(
                                  title: 'Terms of Service',
                                  isPrivacyPolicy: false,
                                ),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Submit Button, the web's black pill. The disabled colours match
          // the enabled ones so the spinner stays visible while signing in.
          ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.hero,
              foregroundColor: c.onHero,
              disabledBackgroundColor: c.hero,
              disabledForegroundColor: c.onHero,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: c.onHero),
                  )
                : const Text(
                    'Sign In to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
          if (authState is AuthLoading) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                authState.step.label,
                key: const ValueKey('login-progress'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Keeps only the NetID: drops anything from an "@" on and spaces.
class _NetIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final at = newValue.text.indexOf('@');
    final text = (at >= 0 ? newValue.text.substring(0, at) : newValue.text)
        .replaceAll(' ', '');
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
