import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ui_components.dart';
import '../widgets/password_requirements_checklist.dart';
import '../l10n/app_localizations.dart';
import '../utils/unsigned_text_input_formatter.dart';

class LoginPage extends StatefulWidget {
  final bool initialIsSignUp;

  const LoginPage({super.key, this.initialIsSignUp = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  late bool _isSignUp = widget.initialIsSignUp;
  String? _pendingConfirmationEmail;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(_onPasswordFocusChanged);
  }

  void _onPasswordFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        if (!PasswordRequirementsChecklist.isValid(_passwordController.text)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('password_requirements_error')),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        final email = _emailController.text.trim();

        // Pre-check phía server: chặn email sai định dạng / dùng-một-lần trước khi
        // gọi signUp (chốt chặn thật vẫn là trigger trg_guard_auth_signup ở DB).
        final check =
            await Supabase.instance.client.rpc(
                  'check_signup_email',
                  params: {'p_email': email},
                )
                as Map;
        if (check['allowed'] != true) {
          if (mounted) {
            final reason = check['reason'];
            final msgKey = reason == 'disposable'
                ? 'disposable_email_not_allowed'
                : 'invalid_email';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.translate(msgKey)),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        final res = await Supabase.instance.client.auth.signUp(
          email: email,
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
          setState(() => _pendingConfirmationEmail = email);
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
        final notConfirmed =
            e.message.toLowerCase().contains('not confirmed') ||
            e.message.toLowerCase().contains('not been confirmed');
        final message = notConfirmed
            ? context.translate('email_not_confirmed')
            : !_isSignUp
            ? context.translate('invalid_login_credentials')
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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
          SnackBar(
            content: Text(context.translate('error_occurred')),
            backgroundColor: Colors.redAccent,
          ),
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
    final email = _pendingConfirmationEmail ?? _emailController.text.trim();
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

  @override
  void dispose() {
    _passwordFocusNode
      ..removeListener(_onPasswordFocusChanged)
      ..dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
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
                  isRequired: true,
                ),
                inputFormatters: [UnsignedTextInputFormatter()],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.translate('cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
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
    final hasPassword = _passwordController.text.isNotEmpty;
    final canSubmit =
        hasPassword &&
        (!_isSignUp ||
            PasswordRequirementsChecklist.isValid(_passwordController.text));

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [const LanguageSwitcher(), const ThemeToggle()],
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
                  colors: [
                    const Color(0xFFFA6B27).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
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
                      if (_pendingConfirmationEmail != null)
                        _ConfirmationPendingContent(
                          email: _pendingConfirmationEmail!,
                          isLoading: _isLoading,
                          onResend: _resendConfirmation,
                          onBackToLogin: () => setState(() {
                            _isSignUp = false;
                            _passwordController.clear();
                            _pendingConfirmationEmail = null;
                          }),
                        )
                      else ...[
                        Text(
                          _isSignUp
                              ? context.translate('signup')
                              : context.translate('login'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          decoration: themedInputDecoration(
                            context,
                            context.translate('email'),
                            icon: Icons.email,
                            isRequired: true,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          inputFormatters: [UnsignedTextInputFormatter()],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          decoration: themedInputDecoration(
                            context,
                            context.translate('password'),
                            icon: Icons.lock,
                            isRequired: true,
                          ),
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          inputFormatters: [UnsignedTextInputFormatter()],
                          onChanged: (_) => setState(() {}),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child:
                              _isSignUp &&
                                  (_passwordFocusNode.hasFocus || hasPassword)
                              ? PasswordRequirementsChecklist(
                                  password: _passwordController.text,
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          onPressed: _isLoading || !canSubmit
                              ? null
                              : _handleAuth,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isSignUp
                                      ? context.translate('signup')
                                      : context.translate('login'),
                                ),
                        ),
                        if (!_isSignUp)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleForgotPassword,
                              child: Text(
                                context.translate('forgot_password'),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SocialLoginButton(
                                onPressed: _isLoading ? null : _showComingSoon,
                                icon: const Icon(
                                  Icons.g_mobiledata,
                                  color: Colors.redAccent,
                                  size: 28,
                                ),
                                label: context.translate('google_login'),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SocialLoginButton(
                                onPressed: _isLoading ? null : _showComingSoon,
                                icon: const Icon(
                                  Icons.facebook,
                                  color: Color(0xFF1877F2),
                                  size: 24,
                                ),
                                label: context.translate('facebook_login'),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              setState(() => _isSignUp = !_isSignUp),
                          child: Text(
                            _isSignUp
                                ? context.translate('already_have_account')
                                : context.translate('no_account_signup'),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

class _ConfirmationPendingContent extends StatelessWidget {
  final String email;
  final bool isLoading;
  final VoidCallback onResend;
  final VoidCallback onBackToLogin;

  const _ConfirmationPendingContent({
    required this.email,
    required this.isLoading,
    required this.onResend,
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          context.translate('confirm_email_title'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.translate('confirm_email_desc', [email]),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: isLoading ? null : onResend,
          child: Text(context.translate('resend_confirmation')),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: isLoading ? null : onBackToLogin,
          child: Text(
            context.translate('back_to_login'),
            style: TextStyle(color: secondaryText, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final bool isDark;

  const _SocialLoginButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.065)
              : Colors.black.withValues(alpha: 0.025),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.08),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SizedBox(width: 30, child: Center(child: icon)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
