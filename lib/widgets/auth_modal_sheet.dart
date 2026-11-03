import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/api_providers.dart';
import '../theme/app_theme.dart';

enum AuthSheetStep {
  login,
  twoFactor,
  verifyEmail,
  forgotPassword,
  resetPassword,
}

/// Bảng BottomSheet Đăng nhập & Xác thực Độc giả (Reader & Guest) theo chuẩn Dark Obsidian
class AuthModalSheet extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const AuthModalSheet({
    super.key,
    this.onLoginSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onLoginSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AuthModalSheet(onLoginSuccess: onLoginSuccess),
      ),
    );
  }

  @override
  ConsumerState<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends ConsumerState<AuthModalSheet> {
  AuthSheetStep _step = AuthSheetStep.login;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFactorController = TextEditingController();
  final _pinController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberDevice = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Lưu email tạm cho các bước 2FA / Verify
  String _pendingEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _twoFactorController.dispose();
    _pinController.dispose();
    _resetTokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _clearFeedback() {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
  }

  // ─── 1. Xử lý Đăng nhập ───────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập địa chỉ email.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mật khẩu.');
      return;
    }

    _clearFeedback();
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Bước 2: Kiểm tra yêu cầu 2FA TOTP
      if (response.requiresTwoFactor) {
        setState(() {
          _pendingEmail = response.twoFactorEmail ?? email;
          _step = AuthSheetStep.twoFactor;
          _isLoading = false;
          _successMessage = 'Đã gửi yêu cầu xác thực 2 bước.';
        });
        return;
      }

      // Đăng nhập thành công
      await _onSuccessAuthenticated();
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      setState(() {
        _isLoading = false;
        // Kiểm tra nếu tài khoản chưa kích hoạt email -> gợi ý sang bước PIN
        if (errorStr.toLowerCase().contains('chưa được kích hoạt') ||
            errorStr.toLowerCase().contains('mã pin')) {
          _pendingEmail = email;
          _errorMessage = 'Tài khoản chưa kích hoạt. Vui lòng nhập mã PIN xác thực.';
          _step = AuthSheetStep.verifyEmail;
        } else {
          _errorMessage = errorStr.replaceAll('ApiException: ', '').replaceAll(RegExp(r'\(code: \d+\)'), '').trim();
        }
      });
    }
  }

  // ─── 2. Xử lý Xác thực 2FA TOTP ───────────────────────────────────────────
  Future<void> _handleVerify2FA() async {
    final code = _twoFactorController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ mã OTP 6 chữ số.');
      return;
    }

    _clearFeedback();
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyTwoFactor(
        code: code,
        email: _pendingEmail.isNotEmpty ? _pendingEmail : null,
        rememberDevice: _rememberDevice,
      );

      if (!mounted) return;
      await _onSuccessAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '').replaceAll(RegExp(r'\(code: \d+\)'), '').trim();
      });
    }
  }

  // ─── 3. Đăng nhập Google OAuth ───────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    _clearFeedback();
    setState(() => _isLoading = true);

    try {
      // Mock Google idToken cho môi trường thử nghiệm / mobile reader
      final authService = ref.read(authServiceProvider);
      // Gửi idToken giả lập hoặc thông báo tới Backend
      await authService.externalLogin(idToken: 'demo-google-oauth-token');

      if (!mounted) return;
      await _onSuccessAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Đăng nhập Google thất bại: ${e.toString().replaceAll('ApiException: ', '')}';
      });
    }
  }

  // ─── 4. Kích hoạt Email qua mã PIN ───────────────────────────────────────
  Future<void> _handleVerifyEmail() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã PIN xác thực.');
      return;
    }

    _clearFeedback();
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyEmail(email: _pendingEmail, token: pin);

      if (!mounted) return;
      await _onSuccessAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  Future<void> _handleResendVerification() async {
    if (_pendingEmail.isEmpty) return;
    _clearFeedback();
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final msg = await authService.resendVerification(email: _pendingEmail);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── 5. Quên & Đặt lại mật khẩu ───────────────────────────────────────────
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email để nhận mã OTP đặt lại mật khẩu.');
      return;
    }

    _clearFeedback();
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final msg = await authService.forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _pendingEmail = email;
        _step = AuthSheetStep.resetPassword;
        _isLoading = false;
        _successMessage = msg;
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
    final token = _resetTokenController.text.trim();
    final newPassword = _newPasswordController.text;

    if (token.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã xác thực OTP.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu mới phải có tối thiểu 6 ký tự.');
      return;
    }

    _clearFeedback();
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final msg = await authService.resetPassword(
        email: _pendingEmail,
        token: token,
        newPassword: newPassword,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = AuthSheetStep.login;
        _successMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  // ─── Hoàn tất xác thực thành công ─────────────────────────────────────────
  Future<void> _onSuccessAuthenticated() async {
    setState(() => _isLoading = false);
    Navigator.of(context).pop();
    widget.onLoginSuccess?.call();

    final authState = ref.read(authStateProvider);
    final userName = authState.user?.fullName ?? 'Độc giả';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.mint, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chào mừng $userName đã quay trở lại!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.darkBorder, width: 1.5),
          left: BorderSide(color: AppColors.darkBorder, width: 1),
          right: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh kéo nhỏ trên đầu
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Thông báo lỗi / thành công nếu có
            if (_errorMessage != null) ...[
              _buildFeedbackCard(
                message: _errorMessage!,
                icon: Icons.error_outline_rounded,
                color: AppColors.rose,
              ),
              const SizedBox(height: 14),
            ],
            if (_successMessage != null) ...[
              _buildFeedbackCard(
                message: _successMessage!,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.mint,
              ),
              const SizedBox(height: 14),
            ],

            // Nội dung theo từng bước
            switch (_step) {
              AuthSheetStep.login => _buildLoginStep(),
              AuthSheetStep.twoFactor => _buildTwoFactorStep(),
              AuthSheetStep.verifyEmail => _buildVerifyEmailStep(),
              AuthSheetStep.forgotPassword => _buildForgotPasswordStep(),
              AuthSheetStep.resetPassword => _buildResetPasswordStep(),
            },
          ],
        ),
      ),
    );
  }

  // ─── UI BƯỚC 1: ĐĂNG NHẬP ─────────────────────────────────────────────────
  Widget _buildLoginStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đăng Nhập Độc Giả',
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Mở khóa truyện & đồng bộ ForgeCoins',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Email input
        Text(
          'Email tài khoản:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'reader@example.com',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.darkTextSecondary, size: 20),
            filled: true,
            fillColor: AppColors.darkCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        // Password input
        Text(
          'Mật khẩu:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.darkTextSecondary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.darkTextSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: AppColors.darkCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),

        // Quên mật khẩu link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _clearFeedback();
              setState(() => _step = AuthSheetStep.forgotPassword);
            },
            child: Text(
              'Quên mật khẩu?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Nút Đăng nhập
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Đăng Nhập',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 12),

        // Divider Hoặc
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.darkBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'HOẶC',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.darkBorder)),
          ],
        ),
        const SizedBox(height: 12),

        // Nút Đăng nhập với Google
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.darkBorder),
            backgroundColor: AppColors.darkCard,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.redAccent, size: 24),
          label: Text(
            'Đăng nhập với Google',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),

        // Nút Tiếp tục với tư cách Khách (Guest)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Tiếp tục với tư cách Khách (Guest)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── UI BƯỚC 2: XÁC THỰC 2 BƯỚC (2FA TOTP) ────────────────────────────────
  Widget _buildTwoFactorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xác Thực 2 Bước (2FA)',
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Mã bảo mật Authenticator 6 số',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Vui lòng mở ứng dụng Google hoặc Microsoft Authenticator và nhập mã xác thực OTP 6 số để tiếp tục:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.darkTextSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // 6-digit OTP input field
        TextField(
          controller: _twoFactorController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: AppColors.darkCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Checkbox Remember Device 30 days
        InkWell(
          onTap: () => setState(() => _rememberDevice = !_rememberDevice),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: _rememberDevice,
                  onChanged: (val) => setState(() => _rememberDevice = val ?? true),
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                  side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
                ),
                Expanded(
                  child: Text(
                    'Ghi nhớ thiết bị này trong 30 ngày (Bỏ qua 2FA các lần sau)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerify2FA,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Xác Nhận & Hoàn Tất Đăng Nhập',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: () {
            _clearFeedback();
            setState(() => _step = AuthSheetStep.login);
          },
          child: Text(
            'Quay lại Đăng nhập',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.darkTextSecondary),
          ),
        ),
      ],
    );
  }

  // ─── UI BƯỚC 3: KÍCH HOẠT EMAIL PIN ───────────────────────────────────────
  Widget _buildVerifyEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kích Hoạt Tài Khoản',
          style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'Mã PIN kích hoạt đã được gửi tới email $_pendingEmail. Vui lòng nhập mã để kích hoạt tài khoản:',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _pinController,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 6, color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nhập mã PIN',
            filled: true,
            fillColor: AppColors.darkCard,
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifyEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Kích Hoạt & Đăng Nhập'),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isLoading ? null : _handleResendVerification,
              child: const Text('Gửi lại mã PIN', style: TextStyle(color: AppColors.primary)),
            ),
            TextButton(
              onPressed: () => setState(() => _step = AuthSheetStep.login),
              child: const Text('Quay lại', style: TextStyle(color: AppColors.darkTextSecondary)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── UI BƯỚC 4: QUÊN MẬT KHẨU ─────────────────────────────────────────────
  Widget _buildForgotPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quên Mật Khẩu',
          style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'Nhập địa chỉ email của bạn để nhận mã xác thực đặt lại mật khẩu:',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'reader@example.com',
            prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.darkTextSecondary),
            filled: true,
            fillColor: AppColors.darkCard,
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleForgotPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Gửi Mã Xác Thực OTP'),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: () => setState(() => _step = AuthSheetStep.login),
          child: const Text('Quay lại Đăng nhập', style: TextStyle(color: AppColors.darkTextSecondary)),
        ),
      ],
    );
  }

  // ─── UI BƯỚC 5: ĐẶT LẠI MẬT KHẨU MỚI ─────────────────────────────────────
  Widget _buildResetPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Đặt Lại Mật Khẩu',
          style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'Mã xác thực đã được gửi về email $_pendingEmail. Vui lòng nhập mã và mật khẩu mới:',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _resetTokenController,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 4, color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nhập mã OTP đặt lại',
            filled: true,
            fillColor: AppColors.darkCard,
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.darkTextSecondary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: AppColors.darkCard,
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleResetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Lưu Mật Khẩu & Đăng Nhập'),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: () => setState(() => _step = AuthSheetStep.login),
          child: const Text('Quay lại', style: TextStyle(color: AppColors.darkTextSecondary)),
        ),
      ],
    );
  }

  // ─── THẺ THÔNG BÁO PHẢN HỒI ──────────────────────────────────────────────
  Widget _buildFeedbackCard({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
