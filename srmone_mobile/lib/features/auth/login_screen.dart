// lib/features/auth/login_screen.dart
// Native login screen with auto-append NetID, optional SP credentials,
// and terms of service check.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/asset_paths.dart';
import '../settings/legal_markdown_screen.dart';
import 'auth_controller.dart';

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
  bool _showSpField = false;
  bool _acceptedTerms = true;

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

    final success = await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
          spPassword: _showSpField ? _spPasswordController.text : null,
        );

    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Brand Header
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Image.asset(AssetPaths.logo, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to SRM One',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Local-first, private academic companion',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  if (authState is AuthError) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(100)),
                      ),
                      child: Text(
                        authState.message,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // NetID / Email Input
                  const Text(
                    'NetID / Email',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. ab1234 or ab1234@srmist.edu.in',
                      hintStyle:
                          const TextStyle(color: Colors.white30, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      prefixIcon: const Icon(Icons.person_outline,
                          color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
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
                  const Text(
                    'Academia Password',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Your Academia portal password',
                      hintStyle:
                          const TextStyle(color: Colors.white30, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Student Portal Optional Toggle
                  GestureDetector(
                    onTap: () => setState(() => _showSpField = !_showSpField),
                    child: Row(
                      children: [
                        Icon(
                          _showSpField
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFFBDE3D5),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Add Student Portal (Optional for dual sync)',
                          style: TextStyle(
                              color: Color(0xFFBDE3D5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                  if (_showSpField) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _spPasswordController,
                      obscureText: _obscureSpPassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Student Portal Password (sp.srmist.edu.in)',
                        hintStyle: const TextStyle(
                            color: Colors.white30, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        prefixIcon: const Icon(Icons.vpn_key_outlined,
                            color: Colors.white54),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSpPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                          ),
                          onPressed: () => setState(
                              () => _obscureSpPassword = !_obscureSpPassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Terms and Privacy Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        activeColor: const Color(0xFFBDE3D5),
                        checkColor: const Color(0xFF0F0F0F),
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            children: [
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                    color: Color(0xFFBDE3D5),
                                    fontWeight: FontWeight.bold),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const LegalMarkdownScreen(
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
                                style: const TextStyle(
                                    color: Color(0xFFBDE3D5),
                                    fontWeight: FontWeight.bold),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const LegalMarkdownScreen(
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
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBDE3D5),
                      foregroundColor: const Color(0xFF0F0F0F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Color(0xFF0F0F0F)),
                          )
                        : const Text(
                            'Sign In to Dashboard',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
