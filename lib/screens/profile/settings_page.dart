import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/api_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../services/api_client.dart';
import '../../services/app_info.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/reader_profile_sheet.dart';
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
      }
      ref.invalidate(catalogSeriesProvider);
      await ref.read(catalogSeriesProvider.future);
      final now = DateTime.now();
      await PreferencesService.setLastSyncAt(now);
      if (mounted) setState(() => _lastSync = now);
      _snack('Đã đồng bộ Ví và danh sách truyện.');
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
          onPressed: () => context.pop(),
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
            _Item('Đổi mật khẩu', onTap: () => showChangePasswordDialog(context, ref)),
            _Item(
              'Thiết bị tin cậy',
              subtitle: 'Xoá thiết bị này khỏi danh sách bỏ qua xác thực 2 lớp',
              onTap: _forgetDevice,
            ),
            _Item('Lịch sử giao dịch', onTap: () => WalletTopupDialog.show(context, initialTab: 1)),
          ] else
            _Item('Đăng nhập / Đăng ký', onTap: () => context.push('/login')),
          _Item(
            'Nhập mã Review',
            subtitle: 'Mã REV-... do Studio gửi để xem & góp ý bản thảo',
            onTap: () => context.push('/review'),
          ),
          if (authed) ...[
            _Item('Đăng xuất', onTap: () => showLogoutConfirmDialog(context, ref)),
            _Item('Xoá tài khoản', danger: true, onTap: _deleteAccount),
          ],
          const _Header('Cài đặt ứng dụng'),
          _Item(
            'Ngôn ngữ',
            subtitle: '$appLanguageLabel — ngôn ngữ giao diện ứng dụng',
            onTap: _showAppLanguage,
          ),
          _Item('Giao diện', subtitle: _themeLabel(themeMode), onTap: _pickTheme),
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
