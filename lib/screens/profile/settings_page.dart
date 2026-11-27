import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../navigation/back_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/api_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/library_sync_provider.dart';
import '../../services/api_client.dart';
import '../../services/app_info.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/reader_profile_sheet.dart';
import '../../widgets/two_factor_dialogs.dart';
import '../../widgets/wallet_topup_dialog.dart';

/// Ngôn ngữ giao diện duy nhất ứng dụng đang có.
const appLanguageLabel = 'Tiếng Việt';

/// Cài đặt (`/settings`, bánh răng ở tab Cá nhân): Tài khoản, Cài đặt ứng dụng, Trợ giúp, Khác.
/// Chỉ gồm những mục ứng dụng + Backend thực sự hỗ trợ.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _keepScreenOn = PreferencesService.getKeepScreenOn();
  DateTime? _lastSync = PreferencesService.getLastSyncAt();
  int _cacheBytes = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _measureCache();
  }

  // ─── Bộ nhớ đệm ảnh (CachedNetworkImage lưu ở thư mục tạm "libCachedImageData") ─────────
  Future<Directory?> _imageCacheDir() async {
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/libCachedImageData');
      return await dir.exists() ? dir : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _measureCache() async {
    var bytes = PaintingBinding.instance.imageCache.currentSizeBytes;
    final dir = await _imageCacheDir();
    if (dir != null) {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) bytes += await e.length();
      }
    }
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<void> _clearCache() async {
    final ok = await _confirm(
      'Xoá bộ nhớ đệm?',
      'Xoá ảnh đã lưu tạm để giải phóng dung lượng. Chương đã tải ngoại tuyến không bị xoá.',
    );
    if (ok != true) return;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    final dir = await _imageCacheDir();
    if (dir != null) await dir.delete(recursive: true);
    await _measureCache();
    _snack('Đã dọn sạch bộ nhớ đệm ảnh.');
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      if (ref.read(authStateProvider).isAuthenticated) {
        await ref.read(walletNotifierProvider.notifier).refresh();
        await ref.read(librarySyncProvider.notifier).syncNow();
        final error = ref.read(librarySyncProvider).error;
        if (error != null) throw Exception(error);
      }
      ref.invalidate(catalogSeriesProvider);
      await ref.read(catalogSeriesProvider.future);
      final now = DateTime.now();
      await PreferencesService.setLastSyncAt(now);
      if (mounted) setState(() => _lastSync = now);
      _snack(
        ref.read(authStateProvider).isAuthenticated
            ? 'Đã đồng bộ Ví, thư viện cá nhân và danh sách truyện.'
            : 'Đã cập nhật danh sách truyện. Đăng nhập để đồng bộ thư viện giữa các thiết bị.',
      );
    } catch (_) {
      _snack('Không đồng bộ được. Vui lòng kiểm tra kết nối.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _openUrl(String url, String missingLabel) async {
    if (url.isEmpty) {
      _snack('$missingLabel chưa được cấu hình (lib/services/app_info.dart).');
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) _snack('Không mở được liên kết.');
  }

  Future<void> _contactSupport({String subject = 'Hỗ trợ PanelForge'}) async {
    if (AppInfo.supportEmail.isEmpty) {
      _snack('Email hỗ trợ chưa được cấu hình (lib/services/app_info.dart).');
      return;
    }
    await _openUrl('mailto:${AppInfo.supportEmail}?subject=${Uri.encodeComponent(subject)}', 'Email hỗ trợ');
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Sáng',
    ThemeMode.dark => 'Tối',
    ThemeMode.system => 'Theo hệ thống',
  };

  Future<T?> _pick<T>(List<(T, String)> options, T current) => showModalBottomSheet<T>(
    context: context,
    backgroundColor: ForgeColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          for (final (value, label) in options)
            ListTile(
              title: Text(label, style: GoogleFonts.plusJakartaSans(color: ForgeColors.text)),
              trailing: value == current ? const Icon(Icons.check_rounded, color: ForgeColors.accent) : null,
              onTap: () => Navigator.of(ctx).pop(value),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Future<void> _pickTheme() async {
    final picked = await _pick([
      for (final m in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) (m, _themeLabel(m)),
    ], ref.read(appThemeModeProvider));
    if (picked != null) await ref.read(appThemeModeProvider.notifier).setMode(picked);
  }

  /// Ngôn ngữ giao diện của ứng dụng (hệ thống). Hiện ứng dụng chỉ có Tiếng Việt.
  /// Không liên quan tới bản ngôn ngữ của chương: chọn bản đọc vẫn làm trong màn đọc truyện.
  static const _textScales = [(1.0, 'Mặc định'), (1.15, 'Lớn'), (1.3, 'Rất lớn')];

  static String _textScaleLabel(double scale) =>
      _textScales.where((o) => o.$1 == scale).map((o) => o.$2).firstOrNull ?? 'Mặc định';

  Future<void> _pickTextScale() async {
    final picked = await _pick(_textScales, ref.read(textScaleProvider));
    if (picked != null) await ref.read(textScaleProvider.notifier).set(picked);
  }

  Future<void> _showCrashLog() async {
    final log = PreferencesService.getCrashLog();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ForgeColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  'Nhật ký lỗi',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: ForgeColors.text),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Chỉ lưu trên máy này. Sao chép rồi gửi cho bộ phận hỗ trợ khi cần.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.muted),
                ),
              ),
              Flexible(
                child: log.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Chưa ghi nhận lỗi nào.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(color: ForgeColors.muted),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        children: [
                          for (final e in log)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '${_formatTime(e.time)}\n${e.error}',
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.textSoft),
                              ),
                            ),
                        ],
                      ),
              ),
              if (log.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await PreferencesService.clearCrashLog();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) setState(() {});
                          },
                          child: const Text('Xoá nhật ký'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: ForgeColors.accent),
                          onPressed: () async {
                            final text = 'PanelForge ${AppInfo.version}\n\n${log.join('\n\n')}';
                            await Clipboard.setData(ClipboardData(text: text));
                            if (ctx.mounted) Navigator.pop(ctx);
                            _snack('Đã sao chép nhật ký lỗi.');
                          },
                          child: const Text('Sao chép'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAppLanguage() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: ForgeColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ListTile(
            title: Text(appLanguageLabel, style: GoogleFonts.plusJakartaSans(color: ForgeColors.text)),
            trailing: const Icon(Icons.check_rounded, color: ForgeColors.accent),
            onTap: () => Navigator.of(ctx).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Ứng dụng hiện chỉ có giao diện Tiếng Việt.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.muted),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmClearHistory(int count) async {
    final ok = await _confirm(
      'Xoá lịch sử đọc?',
      'Xoá $count tựa sách khỏi Lịch sử và Tiếp tục đọc. Không thể hoàn tác.',
    );
    if (ok != true) return;
    await PreferencesService.clearReadingHistory();
    if (mounted) setState(() {});
    _snack('Đã xoá lịch sử đọc.');
  }

  Future<void> _forgetDevice() async {
    final ok = await _confirm(
      'Xoá thiết bị tin cậy?',
      'Lần đăng nhập sau trên thiết bị này sẽ cần mã xác thực 2 lớp (nếu tài khoản bật 2FA).',
      confirmLabel: 'Xoá',
    );
    if (ok != true) return;
    try {
      final msg = await ref.read(authServiceProvider).forgetDevice();
      _snack(msg);
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Không thực hiện được. Vui lòng thử lại.');
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final ok = await _confirm(
      'Xoá tài khoản?',
      'Tài khoản ${user.email} sẽ bị vô hiệu hóa và không đăng nhập được nữa.\n\n'
          '• Số dư Ví còn lại và các chương đã mua không được hoàn lại.\n'
          '• Lịch sử giao dịch vẫn được lưu để đối soát.\n\nThao tác này không thể tự hoàn tác.',
      confirmLabel: 'Xoá tài khoản',
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(authServiceProvider).deleteMyAccount(user.id);
      await ref.read(monetizationServiceProvider).clearLocalCache();
      ref.read(authStateProvider.notifier).setUnauthenticated();
      if (!mounted) return;
      context.go('/');
      _snack('Tài khoản đã được xoá.');
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Không xoá được tài khoản. Vui lòng thử lại.');
    }
  }

  Future<bool?> _confirm(String title, String message, {String confirmLabel = 'Xoá'}) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ForgeColors.surface,
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(color: ForgeColors.text, fontWeight: FontWeight.w800),
      ),
      content: Text(message, style: GoogleFonts.plusJakartaSans(color: ForgeColors.textSoft, height: 1.45)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel, style: const TextStyle(color: ForgeColors.danger)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final authed = auth.isAuthenticated;
    final themeMode = ref.watch(appThemeModeProvider);
    final historyCount = PreferencesService.getReadingHistory().length;

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: AppBar(
        backgroundColor: ForgeColors.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: Icon(Icons.arrow_back_rounded, color: ForgeColors.text),
          onPressed: () => context.popOrGo('/profile'),
        ),
        title: Text(
          'Cài đặt',
          style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: ForgeColors.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Header('Tài khoản'),
          if (authed) ...[
            _Item('Hồ sơ của tôi', subtitle: auth.user?.email, onTap: () => ReaderProfileSheet.show(context)),
            _Item('Lịch sử giao dịch', onTap: () => WalletTopupDialog.show(context, initialTab: 1)),
            _Item('Xoá tài khoản', danger: true, onTap: _deleteAccount),
            const _Header('Bảo mật & phiên đăng nhập'),
            _TwoFactorSecurityCard(
              enabled: auth.user?.twoFactorEnabled == true,
              onSetup: () => showTwoFactorSetupSheet(context, ref),
              onDisable: () => showDisableTwoFactorDialog(context, ref),
            ),
            _Item('Đổi mật khẩu tài khoản', onTap: () => showChangePasswordDialog(context, ref)),
            _Item(
              'Thiết bị đang đăng nhập',
              subtitle: 'Quản lý tối đa 3 thiết bị & đăng xuất từ xa',
              onTap: () => context.push('/settings/devices'),
            ),
            _Item(
              'Thiết bị tin cậy',
              subtitle: 'Xoá thiết bị này khỏi danh sách bỏ qua xác thực 2 lớp',
              onTap: _forgetDevice,
            ),
            _Item('Đăng xuất khỏi thiết bị này', onTap: () => showLogoutConfirmDialog(context, ref)),
          ] else
            _Item('Đăng nhập / Đăng ký', onTap: () => context.push('/login')),
          const _Header('Cài đặt ứng dụng'),
          _Item(
            'Ngôn ngữ',
            subtitle: '$appLanguageLabel — ngôn ngữ giao diện ứng dụng',
            onTap: _showAppLanguage,
          ),
          _Item('Giao diện', subtitle: _themeLabel(themeMode), onTap: _pickTheme),
          _Item(
            'Cỡ chữ',
            subtitle: _textScaleLabel(ref.watch(textScaleProvider)),
            onTap: _pickTextScale,
          ),
          _Item(
            'Giữ màn hình sáng khi đọc',
            subtitle: 'Không tự tắt màn hình trong lúc đọc chương',
            trailing: Switch(
              value: _keepScreenOn,
              activeThumbColor: Colors.white,
              activeTrackColor: ForgeColors.accent,
              onChanged: (v) async {
                await PreferencesService.setKeepScreenOn(v);
                setState(() => _keepScreenOn = v);
              },
            ),
          ),
          _Item(
            'Thông báo',
            subtitle: 'Thông báo, chương mới của truyện theo dõi, giao dịch Ví',
            onTap: () => context.push('/activity'),
          ),
          _Item(
            'Truyện đã tải',
            subtitle: '${ref.watch(downloadedChaptersProvider).length} chương đọc offline',
            onTap: () => context.push('/downloads'),
          ),
          _Item(
            'Xoá lịch sử đọc',
            subtitle: '$historyCount tựa sách',
            onTap: historyCount == 0 ? null : () => _confirmClearHistory(historyCount),
          ),
          _Item(
            'Xoá bộ nhớ đệm',
            subtitle: 'Đang dùng ${(_cacheBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
            onTap: _clearCache,
          ),
          _Item(
            'Đồng bộ ngay',
            subtitle: _syncing
                ? 'Đang đồng bộ...'
                : (_lastSync == null ? 'Chưa đồng bộ' : 'Lần cuối: ${_formatTime(_lastSync!)}'),
            onTap: _syncing ? null : _syncNow,
          ),
          const _Header('Trợ giúp'),
          _Item('Câu hỏi thường gặp', onTap: () => context.push('/legal/faq')),
          _Item('Liên hệ hỗ trợ', onTap: _contactSupport),
          _Item(
            'Nhật ký lỗi',
            subtitle: '${PreferencesService.getCrashLog().length} lỗi được ghi trên máy',
            onTap: _showCrashLog,
          ),
          const _Header('Khác'),
          _Item('Điều khoản sử dụng', onTap: () => context.push('/legal/terms')),
          _Item('Chính sách bảo mật', onTap: () => context.push('/legal/privacy')),
          _Item('Bản quyền', onTap: () => context.push('/legal/copyright')),
          _Item(
            'Giấy phép mã nguồn mở',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'PanelForge',
              applicationVersion: AppInfo.version,
              applicationLegalese: 'Bản quyền thuộc về PanelForge Studio',
            ),
          ),
          const _Item('Phiên bản', subtitle: AppInfo.version),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}/${t.year}';
  }
}

/// Dải tiêu đề nhóm (nền tối hơn, chữ xám) như "Tài khoản", "Cài đặt ứng dụng".
class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ForgeColors.bg,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 15, color: ForgeColors.muted)),
    );
  }
}

/// Một dòng cài đặt trên nền thẻ #1E2330, phân cách 1px.
class _Item extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _Item(this.title, {this.subtitle, this.trailing, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ForgeColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: danger ? ForgeColors.danger : ForgeColors.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.muted)),
                    ],
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null && onTap != null) const Icon(Icons.chevron_right_rounded, color: ForgeColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ Xác Thực 2 Bước (2FA) trong mục "Bảo mật & phiên đăng nhập".
class _TwoFactorSecurityCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSetup;
  final VoidCallback onDisable;

  const _TwoFactorSecurityCard({
    required this.enabled,
    required this.onSetup,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = enabled ? ForgeColors.green : ForgeColors.muted;
    final badgeBg = enabled ? ForgeColors.green.withValues(alpha: 0.14) : ForgeColors.chip;
    final badgeBorder = enabled ? ForgeColors.green.withValues(alpha: 0.4) : ForgeColors.border;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ForgeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: enabled ? ForgeColors.green : ForgeColors.accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Xác Thực 2 Bước (2FA)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ForgeColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('2fa-status-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  enabled ? 'ĐÃ BẬT' : 'CHƯA BẬT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bảo vệ tài khoản bằng mã TOTP RFC 6238 từ ứng dụng Authenticator.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: ForgeColors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (enabled)
            OutlinedButton.icon(
              key: const ValueKey('2fa-action-button'),
              onPressed: onDisable,
              style: OutlinedButton.styleFrom(
                foregroundColor: ForgeColors.danger,
                side: BorderSide(color: ForgeColors.danger.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.gpp_maybe_rounded, size: 18),
              label: Text(
                'Tắt 2FA',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            )
          else
            FilledButton.icon(
              key: const ValueKey('2fa-action-button'),
              onPressed: onSetup,
              style: FilledButton.styleFrom(
                backgroundColor: ForgeColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: Text(
                'Cài đặt 2FA Authenticator',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
