import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/api_providers.dart';
import '../../theme/app_theme.dart';

enum _LoginViewMode {
  /// Bước 1 (mặc định): nhập Email, hệ thống kiểm tra đã có tài khoản chưa.
  emailInput,
  /// Bước 2B: email đã có tài khoản → nhập mật khẩu.
  loginPassword,
  /// Bước 2A: email chưa có tài khoản → tạo tài khoản mới.
  registerNew,
  twoFactor,
  verifyEmail,
  forgotPassword,
  resetPassword,
}

/// Màn hình Đăng nhập & Đăng ký toàn màn hình (Standalone Auth Screen)
/// Theo chuẩn Dark Obsidian Theme (#07080D, #10121A, viền #282B3A, cam #F97316)
class LoginPage extends ConsumerStatefulWidget {
  /// Đường dẫn nội bộ cần mở lại sau khi đăng nhập (vd. `/reader/<series>?chapterId=...`).
  /// Đã được lọc bằng `safeLoginRedirect` ở router.
  final String? redirect;

  const LoginPage({super.key, this.redirect});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  _LoginViewMode _mode = _LoginViewMode.emailInput;

  // Login Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Register Controllers
  final _registerFullNameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Multi-step Controllers
  final _totpController = TextEditingController();
  final _verifyPinController = TextEditingController();
  final _forgotEmailController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // State flags
  bool _rememberDevice = true;
  bool _obscurePassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureNewPassword = true;
  bool _isLoading = false;
  bool _finished = false;
  String? _errorMessage;
  String? _successNotice;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _registerFullNameController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    _totpController.dispose();
    _verifyPinController.dispose();
    _forgotEmailController.dispose();
    _resetTokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _clearFeedback() {
    setState(() {
      _errorMessage = null;
      _successNotice = null;
    });
  }

  // ─── 1. Đăng nhập Email & Mật khẩu ───────────────────────────────────────
  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _successNotice = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Email tài khoản.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Mật khẩu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final resp = await authService.login(email: email, password: password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Nếu yêu cầu xác thực 2FA TOTP (cookie pf_2fa đã được lưu tự động)
      if (resp.requiresTwoFactor) {
        setState(() {
          _mode = _LoginViewMode.twoFactor;
          _successNotice = resp.message ?? 'Vui lòng nhập mã 6 số từ Google/Microsoft Authenticator.';
        });
        return;
      }

      // Kiểm tra trạng thái kích hoạt tài khoản
      if (resp.user != null && !resp.user!.isEmailConfirmed) {
        setState(() {
          _mode = _LoginViewMode.verifyEmail;
          _errorMessage = 'Tài khoản chưa được kích hoạt email. Vui lòng nhập mã PIN xác thực.';
        });
        return;
      }

      // Gán vững chắc trạng thái Reader vào authStateProvider
      if (resp.user != null) {
        ref.read(authStateProvider.notifier).updateState(AuthState(
          role: MobileAuthRole.reader,
          user: resp.user,
        ));
      }

      // Đăng nhập thành công -> mở tiếp chương / trang người dùng vừa bấm
      _finishLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── 2. Đăng ký tài khoản Độc giả mới ────────────────────────────────────
  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
      _successNotice = null;
    });

    final fullName = _registerFullNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _registerPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Biệt danh.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Vui lòng nhập địa chỉ Email hợp lệ.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự.');
      return;
    }
    if (confirm != password) {
      setState(() => _errorMessage = 'Mật khẩu nhập lại không khớp.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final resp = await authService.register(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (resp.token != null && resp.user != null) {
        _finishLogin();
        return;
      }

      // Backend yêu cầu nhập mã OTP kích hoạt gửi về Email
      setState(() {
        _mode = _LoginViewMode.verifyEmail;
        _successNotice = resp.message ??
            'Đăng ký tài khoản thành công! Vui lòng kiểm tra email để lấy mã PIN kích hoạt.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── 3. Đăng nhập với Google chính thức ──────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = ref.read(authServiceProvider);
      final resp = await authService.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (resp == null) {
        // Người dùng hủy chọn tài khoản Google (cancel)
        return;
      }

      if (resp.user != null || ref.read(authStateProvider).isAuthenticated) {
        if (resp.user != null) {
          ref.read(authStateProvider.notifier).updateState(AuthState(
            role: MobileAuthRole.reader,
            user: resp.user,
          ));
        }
        _finishLogin();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── 4. Xác thực 2 bước (2FA TOTP) ───────────────────────────────────────
  Future<void> _handleVerify2FA() async {
    final code = _totpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Vui lòng nhập đúng 6 chữ số mã Authenticator.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successNotice = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final resp = await authService.verifyTwoFactor(
        code: code,
        email: _emailController.text.trim().toLowerCase(),
        rememberDevice: _rememberDevice,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (resp.user != null) {
        ref.read(authStateProvider.notifier).updateState(AuthState(
          role: MobileAuthRole.reader,
          user: resp.user,
        ));
      }
      _finishLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── 5. Kích hoạt Email qua mã PIN ────────────────────────────────────────
  Future<void> _handleVerifyEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    final pin = _verifyPinController.text.trim();

    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã PIN kích hoạt.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyEmail(email: email, token: pin);

      if (!mounted) return;
      if (ref.read(authStateProvider).isAuthenticated) {
        setState(() => _isLoading = false);
        _finishLogin();
        return;
      }
      // Kích hoạt xong nhưng chưa có phiên đăng nhập → quay về form Đăng nhập (email đã điền sẵn).
      setState(() {
        _isLoading = false;
        _mode = _LoginViewMode.loginPassword;
        _successNotice = 'Kích hoạt tài khoản thành công! Vui lòng đăng nhập để tiếp tục.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── 6. Quên mật khẩu & Đặt lại mật khẩu ──────────────────────────────────
  Future<void> _handleForgotPassword() async {
    final email = _forgotEmailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email tài khoản của bạn.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final msg = await authService.forgotPassword(email: email);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _mode = _LoginViewMode.resetPassword;
        _successNotice = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _forgotEmailController.text.trim().toLowerCase();
    final token = _resetTokenController.text.trim();
    final newPass = _newPasswordController.text;

    if (token.isEmpty || newPass.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ mã OTP và mật khẩu mới.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final msg = await authService.resetPassword(
        email: email,
        token: token,
        newPassword: newPass,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _mode = _LoginViewMode.loginPassword;
        _successNotice = msg;
        _passwordController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── 7. Điều hướng sau khi đăng nhập / khi đóng màn hình ─────────────────
  /// Đăng nhập thành công:
  /// - Mở từ nút "Đọc" trong app (`ensureLoggedInForReading`) → đóng màn này và trả `true`; nút đó tự mở tiếp chương.
  /// - Có `redirect` (điều hướng thẳng tới /reader/...) → thay màn này bằng đúng trang đích.
  /// - Còn lại → về Trang chủ.
  void _finishLogin() {
    if (_finished || !mounted) return;
    _finished = true;
    final target = widget.redirect;
    final canPop = context.canPop();
    if (target != null) {
      if (canPop) {
        context.pushReplacement(target);
      } else {
        context.go('/');
        context.push(target);
      }
    } else if (canPop) {
      context.pop(true);
    } else {
      context.go('/');
    }
  }

  /// Đóng màn Đăng nhập để tiếp tục lướt kho truyện (không cần tài khoản).
  void _close() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && mounted) {
        _finishLogin();
      }
    });

    final onFirstStep = _mode == _LoginViewMode.emailInput;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar: ← (bước 1: đóng màn; bước sau: quay lại bước trước) + logo PANELFORGE
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                    tooltip: onFirstStep ? 'Đóng' : 'Quay lại',
                    onPressed: _isLoading ? null : _onBack,
                  ),
                  const SizedBox(width: 6),
                  const _AuthBrand(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      _banner(_errorMessage!, AppColors.rose, Icons.error_outline_rounded),
                      const SizedBox(height: 16),
                    ],
                    if (_successNotice != null) ...[
                      _banner(_successNotice!, AppColors.mint, Icons.check_circle_outline_rounded),
                      const SizedBox(height: 16),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(key: ValueKey(_mode), child: _buildFormContent()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút ←: ở bước nhập Email thì đóng màn; ở các bước sau thì lùi về bước trước.
  void _onBack() {
    switch (_mode) {
      case _LoginViewMode.emailInput:
        _close();
      case _LoginViewMode.loginPassword:
      case _LoginViewMode.registerNew:
        _goToStep(_LoginViewMode.emailInput);
      case _LoginViewMode.twoFactor:
      case _LoginViewMode.verifyEmail:
      case _LoginViewMode.forgotPassword:
      case _LoginViewMode.resetPassword:
        _goToStep(_LoginViewMode.loginPassword);
    }
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: color))),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    switch (_mode) {
      case _LoginViewMode.emailInput:
        return _buildEmailStep();
      case _LoginViewMode.loginPassword:
        return _buildLoginPasswordStep();
      case _LoginViewMode.registerNew:
        return _buildRegisterStep();
      case _LoginViewMode.twoFactor:
        return _buildTwoFactorForm();
      case _LoginViewMode.verifyEmail:
        return _buildVerifyEmailForm();
      case _LoginViewMode.forgotPassword:
        return _buildForgotPasswordForm();
      case _LoginViewMode.resetPassword:
        return _buildResetPasswordForm();
    }
  }

  // ─── Email-First: ô nhập & nút dùng chung ────────────────────────────────
  static const _inputBg = Color(0xFF050507);
  static const _accent = Color(0xFFFF6B00);

  bool _isValidEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  void _goToStep(_LoginViewMode mode) {
    _clearFeedback();
    setState(() => _mode = mode);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    Key? key,
    FocusNode? focusNode,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    bool autofocus = false,
    TextInputAction? action,
    ValueChanged<String>? onSubmitted,
  }) {
    // Ô viền trắng, nhãn nổi trên viền (cam khi đang nhập) — giống màn Email / Mật Khẩu.
    final focused = focusNode?.hasFocus ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
            key: key,
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: action,
            onSubmitted: onSubmitted,
            cursorColor: _accent,
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              floatingLabelBehavior: hint.isEmpty ? FloatingLabelBehavior.auto : FloatingLabelBehavior.always,
              labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 16),
              floatingLabelStyle:
                  GoogleFonts.plusJakartaSans(color: focused ? _accent : Colors.white70, fontSize: 15),
              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 15),
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.white70, size: 24),
                      onPressed: onToggleObscure,
                    ),
              filled: true,
              fillColor: Colors.black,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white70)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent, width: 2)),
            ),
          ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: _accent.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _stepText(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5, color: Colors.white.withValues(alpha: 0.85)),
      );

  /// Email đang dùng + nút đổi email (quay lại bước 1).
  Widget _emailChip() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: _accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _emailController.text.trim().toLowerCase(),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : () => _goToStep(_LoginViewMode.emailInput),
            child: Text('Đổi', style: GoogleFonts.plusJakartaSans(color: _accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String prefix, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: TextButton(
          onPressed: _isLoading ? null : onTap,
          child: Text.rich(
            TextSpan(
              text: '$prefix ',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
              children: [
                TextSpan(text: action, style: const TextStyle(color: _accent, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bước 1: Nhập Email ──────────────────────────────────────────────────
  Future<void> _handleCheckEmail() async {
    _clearFeedback();
    final email = _emailController.text.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Vui lòng nhập địa chỉ Email hợp lệ.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final exists = await ref.read(authServiceProvider).checkEmail(email);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _passwordController.clear();
        _registerPasswordController.clear();
        _confirmPasswordController.clear();
        _mode = exists ? _LoginViewMode.loginPassword : _LoginViewMode.registerNew;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nhập email của bạn để đăng nhập. Nếu bạn chưa có tài khoản, chúng tôi sẽ tạo một tài khoản mới cho bạn.',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, height: 1.6, color: Colors.white),
        ),
        const SizedBox(height: 20),
        _field(
          key: const ValueKey('auth-email'),
          controller: _emailController,
          focusNode: _emailFocusNode,
          label: 'Email',
          hint: '',
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          action: TextInputAction.next,
          onSubmitted: (_) => _handleCheckEmail(),
        ),
        const SizedBox(height: 16),
        _primaryButton('Tiếp Theo', _handleCheckEmail),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.darkBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('hoặc',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkTextSecondary)),
            ),
            const Expanded(child: Divider(color: AppColors.darkBorder)),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.darkBorder),
            backgroundColor: _inputBg,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 22),
          label: Text('Tiếp tục với Google',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ─── Bước 2B: Nhập mật khẩu đăng nhập ────────────────────────────────────
  Widget _buildLoginPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Chào mừng bạn quay lại.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.white)),
        const SizedBox(height: 40),
        // Email đang đăng nhập — chạm để đổi email (về bước 1).
        Tooltip(
          message: 'Đổi email',
          child: InkWell(
            onTap: _isLoading ? null : () => _goToStep(_LoginViewMode.emailInput),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _emailController.text.trim().toLowerCase(),
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _field(
          key: const ValueKey('auth-password'),
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          label: 'Mật Khẩu',
          hint: '',
          obscure: _obscurePassword,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          autofocus: true,
          action: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 40),
        _primaryButton('Đăng Nhập', _handleLogin),
        const SizedBox(height: 36),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _isLoading
                ? null
                : () {
                    _forgotEmailController.text = _emailController.text;
                    _goToStep(_LoginViewMode.forgotPassword);
                  },
            child: Text('Quên mật khẩu?', style: GoogleFonts.plusJakartaSans(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  // ─── Bước 2A: Tạo tài khoản mới ──────────────────────────────────────────
  Widget _buildRegisterStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepText('Có vẻ như bạn chưa có tài khoản. Hãy tạo một tài khoản mới với email này nhé.'),
        _emailChip(),
        _field(
          key: const ValueKey('auth-nickname'),
          controller: _registerFullNameController,
          label: 'Biệt danh',
          hint: 'Tên hiển thị của bạn',
          autofocus: true,
          action: TextInputAction.next,
        ),
        _field(
          key: const ValueKey('auth-register-password'),
          controller: _registerPasswordController,
          label: 'Mật khẩu',
          hint: 'Ít nhất 6 ký tự',
          obscure: _obscureRegisterPassword,
          onToggleObscure: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
          action: TextInputAction.next,
        ),
        _field(
          key: const ValueKey('auth-confirm-password'),
          controller: _confirmPasswordController,
          label: 'Nhập lại mật khẩu',
          hint: 'Nhập lại mật khẩu',
          obscure: _obscureConfirmPassword,
          onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          action: TextInputAction.done,
          onSubmitted: (_) => _handleRegister(),
        ),
        const SizedBox(height: 4),
        _primaryButton('Đăng ký', _handleRegister),
        _footerLink('Đã có tài khoản?', 'Đăng nhập', () => _goToStep(_LoginViewMode.emailInput)),
      ],
    );
  }


  // Form 2FA TOTP
  Widget _buildTwoFactorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Xác Thực 2 Bước (2FA)',
              style: GoogleFonts.newsreader(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Nhập mã 6 chữ số từ ứng dụng Authenticator của bạn:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _totpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 22,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
          decoration: const InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(letterSpacing: 8, color: Colors.white24),
            counterText: '',
            filled: true,
            fillColor: AppColors.darkCard,
          ),
        ),
        const SizedBox(height: 12),

        // Ghi nhớ thiết bị
        Row(
          children: [
            Checkbox(
              value: _rememberDevice,
              activeColor: AppColors.primary,
              checkColor: Colors.white,
              onChanged: (val) => setState(() => _rememberDevice = val ?? true),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _rememberDevice = !_rememberDevice),
                child: Text(
                  'Ghi nhớ thiết bị này trong 30 ngày',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleVerify2FA,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Xác Nhận Mã 2FA', style: TextStyle(fontWeight: FontWeight.w700)),
        ),

        const SizedBox(height: 8),

        TextButton(
          onPressed: () {
            _clearFeedback();
            setState(() => _mode = _LoginViewMode.loginPassword);
          },
          child: const Text('Quay lại Đăng nhập', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ),
      ],
    );
  }

  // Form Kích hoạt Email
  Widget _buildVerifyEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Kích Hoạt Tài Khoản',
              style: GoogleFonts.newsreader(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Nhập mã PIN xác thực đã gửi về email:',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _verifyPinController,
          textAlign: TextAlign.center,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 20,
            letterSpacing: 6,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          decoration: const InputDecoration(
            hintText: 'MÃ-PIN',
            filled: true,
            fillColor: AppColors.darkCard,
          ),
        ),
        const SizedBox(height: 14),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleVerifyEmail,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kích Hoạt Tài Khoản', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: () {
            _clearFeedback();
            setState(() => _mode = _LoginViewMode.loginPassword);
          },
          child: const Text('Quay lại Đăng nhập', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ),
      ],
    );
  }

  // Form Quên mật khẩu
  Widget _buildForgotPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Quên Mật Khẩu',
              style: GoogleFonts.newsreader(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Nhập email của bạn để nhận mã OTP đặt lại mật khẩu:',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _forgotEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'reader@panelforge.com',
            prefixIcon: Icon(Icons.email_outlined, color: Colors.white38, size: 18),
            filled: true,
            fillColor: AppColors.darkCard,
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleForgotPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Gửi Mã Xác Thực', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: () {
            _clearFeedback();
            setState(() => _mode = _LoginViewMode.loginPassword);
          },
          child: const Text('Quay lại Đăng nhập', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ),
      ],
    );
  }

  // Form Đặt lại mật khẩu
  Widget _buildResetPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.key_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Đặt Lại Mật Khẩu Mới',
              style: GoogleFonts.newsreader(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Nhập mã OTP từ email và thiết lập mật khẩu mới:',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _resetTokenController,
          textAlign: TextAlign.center,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 18,
            letterSpacing: 4,
            color: Colors.white,
          ),
          decoration: const InputDecoration(
            hintText: 'MÃ-OTP',
            filled: true,
            fillColor: AppColors.darkCard,
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Mật khẩu mới',
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white38,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            filled: true,
            fillColor: AppColors.darkCard,
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleResetPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Xác Nhận Đổi Mật Khẩu', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: () {
            _clearFeedback();
            setState(() => _mode = _LoginViewMode.loginPassword);
          },
          child: const Text('Quay lại Đăng nhập', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Logo trên thanh đầu màn Đăng nhập: ô biểu tượng + chữ PANEL (trắng) FORGE (cam).
/// Nền màn luôn đen nên không phụ thuộc chế độ Sáng/Tối.
class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5);
    return Semantics(
      label: 'PANELFORGE',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Color(0xFFFF6B00), size: 26),
          ),
          const SizedBox(width: 12),
          Text('PANEL', style: style.copyWith(color: Colors.white)),
          Text('FORGE', style: style.copyWith(color: const Color(0xFFFF6B00))),
        ],
      ),
    );
  }
}
