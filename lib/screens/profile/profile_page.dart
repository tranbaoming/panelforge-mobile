import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_model.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../services/app_info.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/reader_profile_sheet.dart';
import '../../widgets/vip_purchase_sheet.dart';
import '../../widgets/wallet_topup_dialog.dart';
import '../explore/series_grid_page.dart';

/// Tab Cá nhân: hồ sơ, Ví & VIP, Danh sách của tôi, Tiếp tục đọc, Cài đặt cá nhân, Liên hệ, Đăng xuất.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  List<SeriesItem> _catalog = [];
  bool _keepScreenOn = PreferencesService.getKeepScreenOn();
  DateTime? _lastSync = PreferencesService.getLastSyncAt();
  int _cacheBytes = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _measureCache();
  }

  Future<void> _loadCatalog() async {
    try {
      final res = await CatalogService().getSeries(pageSize: 50);
      if (mounted) setState(() => _catalog = res.items.map(SeriesItem.fromPublicDto).toList());
    } catch (_) {
      // Ngoại tuyến: các danh sách vẫn hiển thị số lượng từ bộ nhớ máy.
    }
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
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    final dir = await _imageCacheDir();
    if (dir != null) await dir.delete(recursive: true);
    await _measureCache();
    _snack('Đã dọn sạch bộ nhớ đệm ảnh.');
  }

  // ─── Đồng bộ ─────────────────────────────────────────────────────────────
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      if (ref.read(authStateProvider).isAuthenticated) {
        await ref.read(walletNotifierProvider.notifier).refresh();
      }
      await _loadCatalog();
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

  Future<void> _contactAdmin({String subject = 'Hỗ trợ PanelForge'}) async {
    if (AppInfo.supportEmail.isEmpty) {
      _snack('Email Admin chưa được cấu hình (lib/services/app_info.dart).');
      return;
    }
    await _openUrl('mailto:${AppInfo.supportEmail}?subject=${Uri.encodeComponent(subject)}', 'Email Admin');
  }

  Future<void> _shareApp() async {
    final text = AppInfo.shareUrl.isEmpty
        ? 'Đọc truyện tranh bản quyền trên ứng dụng PanelForge!'
        : 'Đọc truyện tranh bản quyền trên ứng dụng PanelForge: ${AppInfo.shareUrl}';
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Đã sao chép lời giới thiệu, hãy dán để chia sẻ.');
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Sáng',
    ThemeMode.dark => 'Tối',
    ThemeMode.system => 'Theo hệ thống',
  };

  Future<void> _pickTheme() async {
    final current = ref.read(appThemeModeProvider);
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: ForgeColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system])
              ListTile(
                title: Text(_themeLabel(mode), style: GoogleFonts.plusJakartaSans(color: ForgeColors.text)),
                trailing: mode == current ? const Icon(Icons.check_rounded, color: ForgeColors.accent) : null,
                onTap: () => Navigator.of(ctx).pop(mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await ref.read(appThemeModeProvider.notifier).setMode(picked);
  }

  Future<void> _confirmClearHistory(int count) async {
    final ok = await _confirm('Xoá lịch sử đọc?', 'Xoá $count tựa sách khỏi mục Tiếp tục đọc. Không thể hoàn tác.');
    if (ok != true) return;
    await PreferencesService.clearReadingHistory();
    if (mounted) setState(() {});
    _snack('Đã xoá lịch sử đọc.');
  }

  Future<void> _deleteAccount() async {
    // Backend chưa có API tự xoá tài khoản → gửi yêu cầu cho Admin xử lý.
    final ok = await _confirm(
      'Xoá tài khoản',
      'Việc xoá tài khoản được Admin xử lý để bảo toàn giao dịch và quyền đọc đã mua. '
          'Gửi yêu cầu xoá tài khoản tới Admin?',
      confirmLabel: 'Gửi yêu cầu',
    );
    if (ok == true) await _contactAdmin(subject: 'Yêu cầu xoá tài khoản PanelForge');
  }

  Future<bool?> _confirm(String title, String message, {String confirmLabel = 'Xoá'}) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ForgeColors.card,
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(color: ForgeColors.text, fontWeight: FontWeight.w800),
      ),
      content: Text(message, style: GoogleFonts.plusJakartaSans(color: ForgeColors.textSoft)),
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
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    final history = PreferencesService.getReadingHistory();
    final bookmarks = PreferencesService.getBookmarks();
    final follows = PreferencesService.getFollows();
    final unlocked = {...?wallet?.unlockedChapterIds, ...PreferencesService.getUnlockedChapterIds()};
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: const ForgeTopBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildHeader(auth),
          if (auth.isAuthenticated) _buildWalletCard(wallet),
          const ForgeSectionHeader(title: 'DANH SÁCH CỦA TÔI'),
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _listCard(
                  Icons.bookmark_rounded,
                  ForgeColors.accent,
                  'ĐỌC SAU',
                  '${bookmarks.length} Tựa Sách',
                  () => _openSeriesList('Đọc Sau', bookmarks),
                ),
                _listCard(
                  Icons.notifications_rounded,
                  ForgeColors.blue,
                  'THEO DÕI',
                  '${follows.length} Tựa Sách',
                  () => _openSeriesList('Theo Dõi', follows),
                ),
                _listCard(
                  Icons.lock_open_rounded,
                  ForgeColors.green,
                  'ĐÃ MỞ KHÓA',
                  '${unlocked.length} Chương',
                  auth.isAuthenticated ? () => WalletTopupDialog.show(context, initialTab: 1) : null,
                ),
              ],
            ),
          ),
          ForgeSectionHeader(title: 'TIẾP TỤC ĐỌC', onMore: history.isEmpty ? null : () => context.go('/activity')),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Bạn chưa đọc truyện nào.',
                style: GoogleFonts.plusJakartaSans(color: ForgeColors.muted, fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _historyCard(history[i]),
              ),
            ),
          const ForgeSectionHeader(title: 'CÁ NHÂN'),
          _group([
            _row(Icons.contrast_rounded, 'Giao diện', trailing: _themeLabel(themeMode), onTap: _pickTheme),
            _row(
              Icons.light_mode_outlined,
              'Giữ màn hình sáng khi đọc',
              trailingWidget: Switch(
                value: _keepScreenOn,
                activeThumbColor: Colors.white,
                activeTrackColor: ForgeColors.accent,
                onChanged: (v) async {
                  await PreferencesService.setKeepScreenOn(v);
                  setState(() => _keepScreenOn = v);
                },
              ),
            ),
            _row(
              Icons.history_rounded,
              'Xoá lịch sử đọc',
              trailing: '${history.length} Tựa Sách',
              onTap: history.isEmpty ? null : () => _confirmClearHistory(history.length),
            ),
            _row(
              Icons.delete_outline_rounded,
              'Xoá bộ nhớ đệm',
              trailing: '${(_cacheBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
              onTap: _clearCache,
            ),
            _row(
              Icons.sync_rounded,
              'Đồng bộ ngay',
              trailing: _syncing ? 'Đang đồng bộ...' : (_lastSync == null ? 'Chưa đồng bộ' : _formatTime(_lastSync!)),
              onTap: _syncing ? null : _syncNow,
            ),
            _row(
              Icons.verified_user_outlined,
              'Trung tâm Review bản thảo',
              trailing: 'Nhập mã REV',
              onTap: () => context.push('/review'),
            ),
            if (auth.isAuthenticated) ...[
              _row(Icons.lock_outline_rounded, 'Đổi mật khẩu', onTap: () => showChangePasswordDialog(context, ref)),
              _row(Icons.person_remove_outlined, 'Xoá tài khoản', danger: true, onTap: _deleteAccount),
            ],
            _row(
              Icons.info_outline_rounded,
              'Phiên bản',
              trailing: AppInfo.version,
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'PanelForge',
                applicationVersion: AppInfo.version,
                applicationLegalese: 'Ứng dụng đọc truyện tranh bản quyền PanelForge.',
              ),
            ),
          ]),
          const ForgeSectionHeader(title: 'LIÊN HỆ'),
          _group([
            _row(Icons.mail_outline_rounded, 'Liên Hệ Admin', onTap: _contactAdmin),
            _row(
              Icons.shield_outlined,
              'Chính Sách Bảo Mật',
              onTap: () => _openUrl(AppInfo.privacyPolicyUrl, 'Trang Chính sách bảo mật'),
            ),
            _row(
              Icons.star_outline_rounded,
              'Đánh Giá Ứng Dụng',
              onTap: () => _openUrl(AppInfo.storeUrl, 'Liên kết cửa hàng ứng dụng'),
            ),
            _row(Icons.share_outlined, 'Chia Sẻ Ứng Dụng', onTap: _shareApp),
          ]),
          if (auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showLogoutConfirmDialog(context, ref),
                  icon: Icon(Icons.logout_rounded, color: ForgeColors.text),
                  label: Text(
                    'ĐĂNG XUẤT',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: ForgeColors.text,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}/${t.year}';
  }

  void _openSeriesList(String title, Set<String> ids) {
    SeriesGridPage.open(
      context,
      title: title,
      series: _catalog.where((s) => ids.contains(s.id)).toList(),
      emptyMessage: 'Danh sách trống.',
    );
  }

  Widget _buildHeader(AuthState auth) {
    final user = auth.user;
    if (!auth.isAuthenticated || user == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: ForgeColors.card, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bạn đang ở chế độ Khách',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ForgeColors.text, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Đăng nhập để mua chương, nạp Ví, mua VIP và đồng bộ tủ truyện.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Đăng nhập / Đăng ký'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ForgeColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final name = user.fullName.isNotEmpty ? user.fullName : user.email.split('@').first;
    final hasAvatar = user.avatarUrl?.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: ForgeColors.accent,
            backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl!) : null,
            child: hasAvatar
                ? null
                : Text(
                    name.isEmpty ? 'R' : name.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 20),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ForgeColors.text,
                  ),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chỉnh sửa hồ sơ',
            icon: Icon(Icons.edit_outlined, color: ForgeColors.text),
            onPressed: () => ReaderProfileSheet.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(UserWalletDto? wallet) {
    final hasVip = wallet?.hasActiveVip ?? false;
    final expires = wallet?.vipExpiresAt;
    final vipText = !hasVip
        ? 'Chưa có VIP'
        : expires == null
        ? 'VIP đang hoạt động'
        : 'VIP đến ${expires.day.toString().padLeft(2, '0')}/${expires.month.toString().padLeft(2, '0')}/${expires.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ForgeColors.card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: ForgeColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ví PanelForge',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.text),
                ),
                const Spacer(),
                Icon(Icons.workspace_premium_rounded, size: 16, color: hasVip ? ForgeColors.accent : ForgeColors.muted),
                const SizedBox(width: 4),
                Text(vipText, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              wallet == null ? '—' : formatVnd(wallet.balanceVnd),
              style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: ForgeColors.text),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => WalletTopupDialog.show(context),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Nạp Ví VietQR'),
                    style: ElevatedButton.styleFrom(backgroundColor: ForgeColors.accent, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => VipPurchaseSheet.show(context),
                    icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                    label: const Text('Mua VIP'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ForgeColors.text,
                      side: BorderSide(color: ForgeColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _listCard(IconData icon, Color color, String title, String subtitle, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: ForgeColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ForgeColors.text),
                      ),
                      Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyCard(ReadingHistoryEntry h) {
    final series =
        _catalog.where((s) => s.id == h.seriesId).firstOrNull ??
        SeriesItem(
          id: h.seriesId,
          title: h.seriesTitle,
          author: '',
          artist: '',
          format: ComicFormat.manga,
          coverGradientStart: '',
          coverGradientEnd: '',
          synopsisQuote: '',
          fullSynopsis: '',
          views: 0,
          readProgressChapter: 0,
          totalChapters: 0,
          genres: const [],
          chapters: const [],
          editorialNote: '',
        );
    return Container(
      width: 270,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: ForgeColors.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(width: 78, height: 108, child: SeriesCover(series: series, radius: 8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  h.seriesTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ForgeColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  '📖 Chương ${h.chapterNumber}  🕒 ${timeAgo(h.readAt)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ForgeColors.muted),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => openReaderGuarded(context, ref, h.seriesId, h.chapterId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ForgeColors.text,
                    side: BorderSide(color: ForgeColors.border),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Đọc Tiếp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(List<Widget> rows) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      decoration: BoxDecoration(color: ForgeColors.card, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 0.8, color: ForgeColors.divider),
              rows[i],
            ],
          ],
        ),
      ),
    ),
  );

  Widget _row(
    IconData icon,
    String label, {
    String? trailing,
    Widget? trailingWidget,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? ForgeColors.danger : ForgeColors.text;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? ForgeColors.danger : ForgeColors.muted),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(color: color, fontWeight: FontWeight.w600),
      ),
      trailing:
          trailingWidget ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Text(trailing, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted)),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: ForgeColors.muted),
            ],
          ),
    );
  }
}
