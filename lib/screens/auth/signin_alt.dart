import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth_error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/premium_action_sheet.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _emailLoading = false;
  bool _googleLoading = false;
  String? _inlineError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _inlineError = null;
      _emailLoading = true;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      final msg = userFriendlyAuthMessage(e);
      if (!mounted) return;
      setState(() => _inlineError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFBD3B18),
          behavior: SnackBarBehavior.floating,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
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
          backgroundColor: const Color(0xFFBD3B18),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: PremiumActionSheet(
          title: 'Reset password',
          subtitle: 'Enter your account email and we will send a reset link.',
          child: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Color(0xFF151515)),
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: const TextStyle(color: Color(0xFF818187)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8E2D8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8E2D8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 1.4),
              ),
            ),
          ),
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2DBD1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext, ctrl.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A1F),
                  foregroundColor: const Color(0xFF151515),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Send link',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await context.read<AuthProvider>().resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent. Check your email.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      final msg = userFriendlyAuthMessage(e);
      if (!mounted) return;
      setState(() => _inlineError = msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    if (auth.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF7F2),
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFFFF5A1F),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDesktop ? const Color(0xFF0D0908) : const Color(0xFFFAF7F2),
      body: Stack(
        children: [
          if (!isDesktop) const Positioned.fill(child: AuthBackground()),
          if (isDesktop) const Positioned.fill(child: _DesktopAuthBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isDesktop ? 30 : 34),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: isDesktop ? 2 : 8, sigmaY: isDesktop ? 2 : 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDesktop ? const Color(0xF2181215) : const Color(0xEEFFFFFF),
                          borderRadius: BorderRadius.circular(isDesktop ? 30 : 34),
                          border: Border.all(
                            color: isDesktop ? const Color(0x33FFFFFF) : const Color(0xFFE8E2D8),
                          ),
                          boxShadow: isDesktop
                              ? const [
                                  BoxShadow(
                                    color: Color(0x50000000),
                                    blurRadius: 48,
                                    offset: Offset(0, 18),
                                  ),
                                ]
                              : const [
                                  BoxShadow(
                                    color: Color(0x14121212),
                                    blurRadius: 40,
                                    offset: Offset(0, 14),
                                  ),
                                  BoxShadow(
                                    color: Color(0x0F121212),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                        ),
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 30 : 24,
                          isDesktop ? 30 : 26,
                          isDesktop ? 30 : 24,
                          isDesktop ? 26 : 24,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AuthLogo(desktop: isDesktop),
                              const SizedBox(height: 24),
                              Text(
                                'Welcome back.',
                                style: TextStyle(
                                  color: isDesktop ? const Color(0xFFF2EEF0) : const Color(0xFF151515),
                                  fontSize: isDesktop ? 62 : 52,
                                  fontWeight: FontWeight.w800,
                                  height: 0.94,
                                  letterSpacing: -1.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Your art world is waiting.',
                                style: TextStyle(
                                  color: isDesktop ? const Color(0xFFA9A2A6) : const Color(0xFF6F6F76),
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_inlineError != null) ...[
                                _InlineErrorBanner(message: _inlineError!, desktop: isDesktop),
                                const SizedBox(height: 14),
                              ],
                              _AuthField(
                                controller: _emailCtrl,
                                label: 'EMAIL',
                                icon: Icons.mail_outline_rounded,
                                hint: 'artist@studio.com',
                                desktop: isDesktop,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter your email';
                                  }
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _AuthField(
                                controller: _passCtrl,
                                label: 'PASSWORD',
                                icon: Icons.lock_outline_rounded,
                                hint: 'Your password',
                                desktop: isDesktop,
                                obscure: _obscure,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _signIn(),
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF8D8D93),
                                    size: 20,
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Enter your password'
                                    : null,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgotPassword,
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDesktop
                                        ? const Color(0xFFFF8C61)
                                        : const Color(0xFFFF5A1F),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _PrimaryBtn(
                                label: 'SIGN IN',
                                loading: _emailLoading,
                                onPressed: (_emailLoading || _googleLoading)
                                    ? null
                                    : _signIn,
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: isDesktop
                                        ? const Color(0xFF8F858A)
                                        : const Color(0xFF8F8F96),
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _GoogleBtn(
                                desktop: isDesktop,
                                loading: _googleLoading,
                                onPressed: (_emailLoading || _googleLoading)
                                    ? null
                                    : _googleSignIn,
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: Wrap(
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        color: isDesktop
                                            ? Color(0xFFA9A2A6)
                                            : Color(0xFF6F6F76),
                                        fontSize: 14,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push('/sign-up'),
                                      child: const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          color: Color(0xFFFF5A1F),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _TrustFooter(desktop: isDesktop),
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
  final bool desktop;
  const _AuthLogo({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'ARTYUG',
              style: TextStyle(
                color: desktop ? Color(0xFFF2EEF0) : Color(0xFF202020),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            TextSpan(
              text: '.',
              style: TextStyle(
                color: Color(0xFFFF5A1F),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
  final bool desktop;

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
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: desktop ? const Color(0xFFD3CED1) : const Color(0xFF535359),
            fontSize: 12,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(
            color: desktop ? const Color(0xFFF2EEF0) : const Color(0xFF151515),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: const Color(0xFFFF5A1F),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: desktop ? const Color(0xFF8F878C) : const Color(0xFF8D8D93),
            ),
            prefixIcon: Icon(
              icon,
              color: desktop ? const Color(0xFF8F878C) : const Color(0xFF8D8D93),
              size: 20,
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: desktop ? const Color(0xFFEFEFF2) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE8E2D8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE5644C), width: 1.3),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE5644C), width: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  final bool desktop;
  const _InlineErrorBanner({required this.message, this.desktop = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: desktop ? const Color(0x28E5644C) : const Color(0x1AE5644C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66E5644C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 17, color: Color(0xFFBD3B18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8E3D2A), fontSize: 13),
            ),
          ),
        ],
      ),
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
        scale: _pressed ? 0.987 : 1,
        duration: const Duration(milliseconds: 130),
        child: SizedBox(
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      colors: [Color(0xFFFF7A2F), Color(0xFFFF4D00)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xAAFF7A2F), Color(0x99FF4D00)],
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26121212),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onPressed?.call();
                      }
                    : null,
                child: Center(
                  child: widget.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF202020),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.label,
                              style: const TextStyle(
                                color: Color(0xFF202020),
                                fontSize: 13.5,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF202020),
                              size: 18,
                            ),
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
  final bool desktop;

  const _GoogleBtn({this.onPressed, this.loading = false, this.desktop = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: desktop ? const Color(0xFFF2EFF0) : const Color(0xFFF7F4EE),
            border: Border.all(
              color: desktop ? const Color(0x44FFFFFF) : const Color(0xFFE1DACF),
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF35353A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        label: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4B4B50),
                ),
              )
            : Text(
                'CONTINUE WITH GOOGLE',
                style: TextStyle(
                  color: desktop ? Color(0xFFE8E4E7) : Color(0xFF2A2A2F),
                  fontSize: 12.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: desktop ? const Color(0x33FFFFFF) : const Color(0xFFE8E2D8),
          ),
          backgroundColor: desktop ? const Color(0x1AFFFFFF) : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          shadowColor: const Color(0x14121212),
          elevation: 1,
        ),
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  final bool desktop;
  const _TrustFooter({this.desktop = false});

  @override
  Widget build(BuildContext context) {
    final color = desktop ? const Color(0xFF948B90) : const Color(0xFF7F7F86);
    return Column(
      children: [
        Text(
          'Secured authentication • Cross-platform artist identity',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 11.5),
        ),
        SizedBox(height: 4),
        Text(
          'Solana + NFC verification ready',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _DesktopAuthBackdrop extends StatelessWidget {
  const _DesktopAuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.1),
          radius: 1.15,
          colors: [Color(0xFF3A0D00), Color(0xFF190B0A), Color(0xFF0D0908)],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x22FF5A1F),
              ),
            ),
          ),
          Positioned(
            right: -140,
            bottom: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1FFF5A1F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

