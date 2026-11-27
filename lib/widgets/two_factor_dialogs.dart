import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/api_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Mở bottom sheet thiết lập 2FA (TOTP RFC 6238):
/// Bước 1: gọi POST /api/auth/enable-2fa, hiển thị QR, khóa thủ công + sao chép, nút mở ứng dụng Authenticator.
/// Bước 2: nhập mã 6 chữ số → POST /api/auth/verify-2fa → làm mới phiên & đóng sheet.
Future<void> showTwoFactorSetupSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ForgeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _TwoFactorSetupSheet(),
  );
}

class _TwoFactorSetupSheet extends ConsumerStatefulWidget {
  const _TwoFactorSetupSheet();

  @override
  ConsumerState<_TwoFactorSetupSheet> createState() => _TwoFactorSetupSheetState();
}

class _TwoFactorSetupSheetState extends ConsumerState<_TwoFactorSetupSheet> {
  final _codeController = TextEditingController();
  TwoFactorSetupModel? _setup;
  bool _loadingSetup = true;
  bool _submitting = false;
  bool _copied = false;
  String? _loadError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loadingSetup = true;
      _loadError = null;
    });
    try {
      final setup = await ref.read(authStateProvider.notifier).enableTwoFactor();
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _loadingSetup = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSetup = false;
        _loadError = e is ApiException ? e.message : 'Không thể khởi tạo thiết lập 2FA. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _copyKey() async {
    final setup = _setup;
    if (setup == null) return;
    final keyText = setup.formattedKey.isNotEmpty ? setup.formattedKey : setup.sharedKey;
    if (keyText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: keyText));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _openAuthenticatorApp() async {
    final uriStr = _setup?.authenticatorUri ?? '';
    if (uriStr.isEmpty) return;
    try {
      final uri = Uri.parse(uriStr);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Bỏ qua nhẹ nhàng nếu thiết bị không có ứng dụng hỗ trợ otpauth://
    }
  }

  Future<void> _confirmSetup() async {
    if (_submitting) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _submitError = 'Vui lòng nhập đủ 6 chữ số từ ứng dụng Authenticator.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final message = await ref.read(authStateProvider.notifier).confirmTwoFactorSetup(code);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e is ApiException ? e.message : 'Mã xác thực không hợp lệ. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ForgeColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.security_rounded, color: ForgeColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cài đặt 2FA Authenticator',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ForgeColors.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: ForgeColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingSetup) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator(color: ForgeColors.accent)),
              const SizedBox(height: 14),
              Text(
                'Đang khởi tạo mã bảo mật 2FA...',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.muted),
              ),
              const SizedBox(height: 28),
            ] else if (_loadError != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(_loadError!),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: ForgeColors.accent),
                      onPressed: _loadSetup,
                      child: const Text('Thử lại'),
                    ),
                  ),
                ],
              ),
            ] else if (_setup != null) ...[
              Text(
                'Bước 1: Quét mã QR bằng Google Authenticator, Authy hoặc ứng dụng TOTP tương thích.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.textSoft, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (_setup!.authenticatorUri.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ForgeColors.border),
                    ),
                    child: QrImageView(
                      data: _setup!.authenticatorUri,
                      version: QrVersions.auto,
                      size: 176,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                'Hoặc nhập khóa thủ công:',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: ForgeColors.muted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: ForgeColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ForgeColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _setup!.formattedKey.isNotEmpty ? _setup!.formattedKey : _setup!.sharedKey,
                        style: ForgeText.tabular(fontSize: 13.5, fontWeight: FontWeight.w700, color: ForgeColors.text),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _copyKey,
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 16,
                        color: _copied ? ForgeColors.green : ForgeColors.accent,
                      ),
                      label: Text(
                        _copied ? 'Đã chép' : 'Sao chép',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _copied ? ForgeColors.green : ForgeColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_setup!.authenticatorUri.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _openAuthenticatorApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ForgeColors.text,
                    side: BorderSide(color: ForgeColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(
                    'Mở ứng dụng Authenticator trên máy này',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Bước 2: Nhập mã 6 chữ số từ ứng dụng Authenticator để kích hoạt.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.textSoft, height: 1.4),
              ),
              const SizedBox(height: 10),
              if (_submitError != null) ...[
                _ErrorBanner(_submitError!),
                const SizedBox(height: 10),
              ],
              TextField(
                key: const ValueKey('2fa-setup-code'),
                controller: _codeController,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirmSetup(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: ForgeText.tabular(fontSize: 22, fontWeight: FontWeight.w800, color: ForgeColors.text)
                    .copyWith(letterSpacing: 6),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  filled: true,
                  fillColor: ForgeColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ForgeColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ForgeColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ForgeColors.accent, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const ValueKey('2fa-setup-confirm'),
                onPressed: _submitting ? null : _confirmSetup,
                style: FilledButton.styleFrom(
                  backgroundColor: ForgeColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Xác nhận & Bật 2FA',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại tắt 2FA (yêu cầu mã 6 chữ số TOTP + mật khẩu hiện tại; tài khoản Google có thể để trống mật khẩu).
Future<void> showDisableTwoFactorDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _DisableTwoFactorDialog(),
  );
}

class _DisableTwoFactorDialog extends ConsumerStatefulWidget {
  const _DisableTwoFactorDialog();

  @override
  ConsumerState<_DisableTwoFactorDialog> createState() => _DisableTwoFactorDialogState();
}

class _DisableTwoFactorDialogState extends ConsumerState<_DisableTwoFactorDialog> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số từ ứng dụng Authenticator.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final message = await ref.read(authStateProvider.notifier).disableTwoFactor(
            code,
            _passwordController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : 'Không thể tắt 2FA. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ForgeColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ForgeColors.border),
      ),
      title: Row(
        children: [
          const Icon(Icons.gpp_maybe_rounded, color: ForgeColors.danger, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tắt xác thực 2 bước (2FA)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ForgeColors.text,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nhập mã 6 chữ số từ ứng dụng Authenticator và mật khẩu hiện tại để tắt 2FA. Tài khoản đăng nhập Google không có mật khẩu có thể để trống ô mật khẩu.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _ErrorBanner(_error!),
              const SizedBox(height: 10),
            ],
            TextField(
              key: const ValueKey('2fa-disable-code'),
              controller: _codeController,
              enabled: !_submitting,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: ForgeText.tabular(fontSize: 15, fontWeight: FontWeight.w700, color: ForgeColors.text),
              decoration: InputDecoration(
                hintText: 'Mã 6 chữ số từ Authenticator',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: ForgeColors.bg,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('2fa-disable-password'),
              controller: _passwordController,
              enabled: !_submitting,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: ForgeColors.text),
              decoration: InputDecoration(
                hintText: 'Mật khẩu hiện tại',
                isDense: true,
                filled: true,
                fillColor: ForgeColors.bg,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: ForgeColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          key: const ValueKey('2fa-disable-confirm'),
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: ForgeColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Tắt 2FA'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ForgeColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ForgeColors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.danger, height: 1.35),
      ),
    );
  }
}
