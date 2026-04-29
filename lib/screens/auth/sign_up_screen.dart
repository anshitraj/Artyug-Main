import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth_error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_background.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _emailLoading = false;
  bool _googleLoading = false;
  String? _inlineError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _inlineError = null;
      _emailLoading = true;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.signUpWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      if (!auth.isAuthenticated) {
        const msg = 'Account created. Check your email to confirm, then sign in.';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      final msg = userFriendlyAuthMessage(e);
      if (!mounted) return;
      setState(() => _inlineError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _inlineError = null;
      _googleLoading = true;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ok = await auth.signInWithGoogle();
      if (!mounted) return;
      if (!ok) {
        const msg = 'Google sign-in was canceled or could not be started.';
        setState(() => _inlineError = msg);
      }
    } catch (e) {
      final msg = userFriendlyAuthMessage(e);
      if (!mounted) return;
      setState(() => _inlineError = msg);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080C),
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackground()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.7),
                  radius: 1.3,
                  colors: [const Color(0x33FF9C3D), Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xCC0F1218),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _AuthLogo(),
                              const SizedBox(height: 24),
                              const Text('Enter Artyug.', style: TextStyle(color: Color(0xFFEDEFF6), fontSize: 44, fontWeight: FontWeight.w800, height: 0.98, letterSpacing: -1.2)),
                              const SizedBox(height: 8),
                              const Text('Verify. Collect. Create.', style: TextStyle(color: Color(0xFF9EA5B7), fontSize: 16)),
                              const SizedBox(height: 24),
                              if (_inlineError != null) ...[
                                _InlineErrorBanner(message: _inlineError!),
                                const SizedBox(height: 14),
                              ],
                              _AuthField(
                                controller: _emailCtrl,
                                label: 'EMAIL',
                                icon: Icons.mail_outline_rounded,
                                hint: 'artist@studio.com',
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _AuthField(
                                controller: _passCtrl,
                                label: 'PASSWORD',
                                icon: Icons.lock_outline_rounded,
                                hint: 'At least 6 characters',
                                obscure: _obscurePass,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                  icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFFB6BDCD), size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Enter a password';
                                  if (v.length < 6) return 'At least 6 characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _AuthField(
                                controller: _confirmCtrl,
                                label: 'CONFIRM PASSWORD',
                                icon: Icons.lock_person_outlined,
                                obscure: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _signUp(),
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFFB6BDCD), size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Confirm your password';
                                  if (v != _passCtrl.text) return 'Passwords do not match';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              _PrimaryBtn(label: 'CREATE ACCOUNT', loading: _emailLoading, onPressed: (_emailLoading || _googleLoading) ? null : _signUp),
                              const SizedBox(height: 12),
                              const Center(child: Text('OR', style: TextStyle(color: Color(0xFF9EA5B7), fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w700))),
                              const SizedBox(height: 12),
                              _GoogleBtn(loading: _googleLoading, onPressed: (_emailLoading || _googleLoading) ? null : _googleSignIn),
                              const SizedBox(height: 24),
                              Center(
                                child: Wrap(
                                  children: [
                                    const Text('Already have an account? ', style: TextStyle(color: Color(0xFF9EA5B7), fontSize: 14)),
                                    GestureDetector(
                                      onTap: () => context.push('/sign-in'),
                                      child: const Text('Sign In', style: TextStyle(color: Color(0xFFFFB29A), fontSize: 14, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _TrustFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: 'ARTYUG', style: TextStyle(color: Color(0xFFEDEFF6), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          TextSpan(text: '.', style: TextStyle(color: Color(0xFFFF5A1F), fontSize: 28, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFFEDEFF6), fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(color: Color(0xFFEDEFF6), fontSize: 17, fontWeight: FontWeight.w500),
        cursorColor: const Color(0xFFFF5A1F),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFFB6BDCD), size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFF151A24),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2A3140))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 1.6)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5B5B), width: 1.4)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5B5B), width: 1.5)),
        ),
      ),
    ]);
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  const _InlineErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x44FF4D4D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FF6A6A)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, size: 17, color: Color(0xFFFFB9B9)),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFFFD6D6), fontSize: 13))),
      ]),
    );
  }
}

class _PrimaryBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const _PrimaryBtn({required this.label, this.onPressed, this.loading = false});

  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 130),
        child: SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(colors: [Color(0xFFFF6A2B), Color(0xFFE8470A)])
                  : const LinearGradient(colors: [Color(0xAAFF6A2B), Color(0x99E8470A)]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onPressed?.call();
                      }
                    : null,
                child: Center(
                  child: widget.loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(widget.label, style: const TextStyle(color: Colors.black, fontSize: 13.5, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleBtn extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  const _GoogleBtn({this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF384257))),
          alignment: Alignment.center,
          child: const Text('G', style: TextStyle(color: Color(0xFFEDEFF6), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        label: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEDEFF6)))
            : const Text('CONTINUE WITH GOOGLE', style: TextStyle(color: Color(0xFFEDEFF6), fontSize: 12.5, letterSpacing: 1, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF2A3140)),
          backgroundColor: const Color(0x22141A25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      Text('Secured authentication • Cross-platform artist identity', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9EA5B7), fontSize: 11.5)),
      SizedBox(height: 4),
      Text('Solana + NFC verification ready', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9EA5B7), fontSize: 11.5)),
    ]);
  }
}
