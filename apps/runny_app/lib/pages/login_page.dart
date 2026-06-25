import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ui_components.dart';
import '../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  final bool initialIsSignUp;

  const LoginPage({super.key, this.initialIsSignUp = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  late bool _isSignUp = widget.initialIsSignUp;

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (res.session != null) {
          // Confirm email TẮT: đã đăng nhập ngay. LoginPage được push đè lên
          // AuthGate, nên phải pop về gốc để AuthGate điều hướng vào onboarding.
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else if (res.user != null &&
            (res.user!.identities == null || res.user!.identities!.isEmpty)) {
          // Supabase trả về user "giả" khi email đã tồn tại (chống dò email).
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.translate('email_already_registered')),
                backgroundColor: Colors.redAccent,
              ),
            );
            setState(() => _isSignUp = false);
          }
        } else if (mounted) {
          // Confirm email BẬT: cần xác thực qua email trước khi đăng nhập.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.translate('signup_success'))),
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Đăng nhập thành công: pop LoginPage để AuthGate (gốc) vào dashboard.
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        // Email chưa xác thực: cho phép gửi lại email xác thực ngay từ snackbar.
        final notConfirmed = e.message.toLowerCase().contains('not confirmed') ||
            e.message.toLowerCase().contains('not been confirmed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            action: notConfirmed
                ? SnackBarAction(
                    label: context.translate('resend_confirmation'),
                    textColor: Colors.white,
                    onPressed: _resendConfirmation,
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('error_occurred')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.translate('feature_coming_soon_title')),
        content: Text(dialogContext.translate('feature_coming_soon_body')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.translate('ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _resendConfirmation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('enter_email_first'))),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('confirmation_resent'))),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.translate('reset_password_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogContext.translate('reset_password_hint')),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: themedInputDecoration(
                  dialogContext,
                  dialogContext.translate('email'),
                  icon: Icons.email,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.translate('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(dialogContext.translate('send')),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty || !mounted) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('reset_email_sent'))),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: sportPlatformGradient(context))),
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                const LanguageSwitcher(),
                const ThemeToggle(),
              ],
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFFFA6B27).withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: glassCard(
                context: context,
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RunnyLogo(fontSize: 32),
                    const SizedBox(height: 28),
                    Text(
                      _isSignUp ? context.translate('signup') : context.translate('login'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      decoration: themedInputDecoration(context, context.translate('email'), icon: Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: themedInputDecoration(context, context.translate('password'), icon: Icons.lock),
                      obscureText: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      onPressed: _isLoading ? null : _handleAuth,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isSignUp ? context.translate('signup') : context.translate('login')),
                    ),
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleForgotPassword,
                          child: Text(
                            context.translate('forgot_password'),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      runSpacing: 12,
                      spacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _showComingSoon,
                          icon: const Icon(Icons.g_mobiledata, color: Colors.redAccent, size: 24),
                          label: Text(context.translate('google_login')),
                          style: secondaryActionButton(context),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _showComingSoon,
                          icon: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 24),
                          label: Text(context.translate('facebook_login')),
                          style: secondaryActionButton(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp ? context.translate('already_have_account') : context.translate('no_account_signup'),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54, 
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ],
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
