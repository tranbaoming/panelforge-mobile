import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/api_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/server_config_dialog.dart';

enum _LoginViewMode {
  login,
  register,
  twoFactor,
  verifyEmail,
  forgotPassword,
  resetPassword,
}

/// Màn hình Đăng nhập & Đăng ký toàn màn hình (Standalone Auth Screen)
/// Theo chuẩn Dark Obsidian Theme (#07080D, #10121A, viền #282B3A, cam #F97316)
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  _LoginViewMode _mode = _LoginViewMode.login;

  // Login Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Register Controllers
  final _registerFullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerPhoneController = TextEditingController();

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
  bool _obscureNewPassword = true;
  bool _isLoading = false;
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
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerPhoneController.dispose();
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

      // Đăng nhập thành công -> điều hướng vào trang chủ
      context.go('/');
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
    final email = _registerEmailController.text.trim().toLowerCase();
    final password = _registerPasswordController.text;
    final phone = _registerPhoneController.text.trim();

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Họ và tên.');
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

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final resp = await authService.register(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phone.isNotEmpty ? phone : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (resp.token != null && resp.user != null) {
        context.go('/');
        return;
      }

      // Backend yêu cầu nhập mã OTP kích hoạt gửi về Email
      _emailController.text = email;
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

      if (resp.user != null) {
        context.go('/');
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
      await authService.verifyTwoFactor(
        code: code,
        email: _emailController.text.trim().toLowerCase(),
        rememberDevice: _rememberDevice,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go('/');
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
      setState(() => _isLoading = false);
      context.go('/');
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
        _mode = _LoginViewMode.login;
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

  // ─── 7. Tiếp tục với tư cách Khách (Guest) ───────────────────────────────
  void _continueAsGuest() {
    ref.read(authStateProvider.notifier).continueAsGuest();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Back button if canPop
              if (canPop)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Quay lại',
                  ),
                )
              else
                const SizedBox(height: 16),

              const SizedBox(height: 8),

              // Brand Logo & Tiêu đề (Nhấn giữ Logo để cấu hình máy chủ cho Developer)
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onLongPress: () => ServerConfigDialog.show(context),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'PANELFORGE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nền Tảng Đọc Truyện & Review Bản Quyền',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Thông báo lỗi hoặc thành công (nếu có)
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.rose),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_successNotice != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.mint, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successNotice!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.mint),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Card Chứa Form Xác Thực (Đăng nhập / Đăng ký)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.darkBorder, width: 1.2),
                ),
                padding: const EdgeInsets.all(20),
                child: _buildFormContent(),
              ),

              const SizedBox(height: 24),

              // Nút phụ: Tiếp tục với tư cách Khách (Guest)
              InkWell(
                onTap: _continueAsGuest,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tiếp tục với tư cách Khách (Guest)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đọc truyện miễn phí và quét QR Review không cần tài khoản',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    switch (_mode) {
      case _LoginViewMode.login:
        return _buildLoginForm();
      case _LoginViewMode.register:
        return _buildRegisterForm();
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

  // ─── Tab Chuyển Đổi Đăng Nhập / Đăng Ký ──────────────────────────────────
  Widget _buildAuthTabSwitcher() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                _clearFeedback();
                setState(() => _mode = _LoginViewMode.login);
              },
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _mode == _LoginViewMode.login
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng Nhập',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _mode == _LoginViewMode.login
                        ? Colors.white
                        : AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                _clearFeedback();
                setState(() => _mode = _LoginViewMode.register);
              },
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _mode == _LoginViewMode.register
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng Ký Độc Giả',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _mode == _LoginViewMode.register
                        ? Colors.white
                        : AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Form Đăng nhập Độc giả
  Widget _buildLoginForm() {
    final isEmailFocused = _emailFocusNode.hasFocus;
    final isPasswordFocused = _passwordFocusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAuthTabSwitcher(),

        Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Đăng Nhập Độc Giả',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Mở khóa chương trả phí & đồng bộ Ví ForgeCoins',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 18),

        // 1. Email Label
        Text(
          'Email',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEmailFocused ? const Color(0xFFF97316) : const Color(0xFF282B3A),
              width: isEmailFocused ? 1.5 : 1.0,
            ),
            boxShadow: isEmailFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.18),
                      blurRadius: 0,
                      spreadRadius: 3.5,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            cursorColor: const Color(0xFFF97316),
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13.5,
            ),
            decoration: InputDecoration(
              hintText: 'reader@panelforge.com',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: isEmailFocused ? const Color(0xFFF97316) : const Color(0xFF94A3B8),
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Password Label & "Quên mật khẩu?" Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () {
                _clearFeedback();
                _forgotEmailController.text = _emailController.text;
                setState(() => _mode = _LoginViewMode.forgotPassword);
              },
              child: Text(
                'Quên mật khẩu?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPasswordFocused ? const Color(0xFFF97316) : const Color(0xFF282B3A),
              width: isPasswordFocused ? 1.5 : 1.0,
            ),
            boxShadow: isPasswordFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.18),
                      blurRadius: 0,
                      spreadRadius: 3.5,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            cursorColor: const Color(0xFFF97316),
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13.5,
            ),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 13.5,
                letterSpacing: 2.0,
              ),
              prefixIcon: Icon(
                Icons.key_rounded,
                color: isPasswordFocused ? const Color(0xFFF97316) : const Color(0xFF94A3B8),
                size: 20,
              ),
              suffixIcon: IconButton(
                splashRadius: 20,
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Nút Đăng nhập
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Đăng Nhập',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),

        const SizedBox(height: 14),

        // Divider Hoặc
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.darkBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'hoặc',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkTextSecondary),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.darkBorder)),
          ],
        ),

        const SizedBox(height: 14),

        // Đăng nhập Google (OAuth thật)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.darkBorder),
            backgroundColor: AppColors.darkCard,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 22),
          label: Text(
            'Đăng nhập với Google',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Form Đăng ký tài khoản Độc giả
  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAuthTabSwitcher(),

        Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Đăng Ký Độc Giả Mới',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tạo tài khoản để nạp ForgeCoins, đánh giá & mở khóa chương',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 18),

        // Họ và tên
        Text(
          'Họ và tên:',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _registerFullNameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Nhập họ và tên hiển thị',
            prefixIcon: Icon(Icons.badge_outlined, color: Colors.white38, size: 18),
            filled: true,
            fillColor: AppColors.darkCard,
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        // Email field
        Text(
          'Email tài khoản:',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _registerEmailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Nhập email (ví dụ: reader@gmail.com)',
            prefixIcon: Icon(Icons.email_outlined, color: Colors.white38, size: 18),
            filled: true,
            fillColor: AppColors.darkCard,
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        // Password field
        Text(
          'Mật khẩu:',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _registerPasswordController,
          obscureText: _obscureRegisterPassword,
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tối thiểu 6 ký tự, 1 hoa, 1 ký tự đặc biệt',
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegisterPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white38,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
            ),
            filled: true,
            fillColor: AppColors.darkCard,
            isDense: true,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gợi ý: Mật khẩu có chữ hoa và ký tự đặc biệt (ví dụ: Reader@123)',
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 14),

        // Phone field (tùy chọn)
        Text(
          'Số điện thoại (tùy chọn):',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _registerPhoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Nhập số điện thoại (nếu có)',
            prefixIcon: Icon(Icons.phone_outlined, color: Colors.white38, size: 18),
            filled: true,
            fillColor: AppColors.darkCard,
            isDense: true,
          ),
        ),
        const SizedBox(height: 18),

        // Nút Tạo Tài Khoản
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleRegister,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Tạo Tài Khoản Độc Giả',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
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
            setState(() => _mode = _LoginViewMode.login);
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
            setState(() => _mode = _LoginViewMode.login);
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
            setState(() => _mode = _LoginViewMode.login);
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
            setState(() => _mode = _LoginViewMode.login);
          },
          child: const Text('Quay lại Đăng nhập', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ),
      ],
    );
  }
}
