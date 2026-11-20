import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_model.dart';
import '../theme/app_theme.dart';

/// Thành phần giao diện dùng chung cho trang chủ / khám phá / chi tiết truyện (Dark Mode, nhấn cam).

String formatViews(int views) {
  if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
  if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
  return '$views';
}

String timeAgo(DateTime? time) {
  if (time == null) return 'Mới';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Vừa Xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} Phút Trước';
  if (diff.inHours < 24) return '${diff.inHours} Giờ Trước';
  if (diff.inDays < 30) return '${diff.inDays} Ngày Trước';
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
}

const _genreEmoji = <String, String>{
  'action': '⚔️',
  'hành động': '⚔️',
  'comedy': '😂',
  'hài': '😂',
  'drama': '🎭',
  'romance': '💕',
  'tình cảm': '💕',
  'fantasy': '🔮',
  'kỳ ảo': '🔮',
  'martial arts': '🥋',
  'võ thuật': '🥋',
  'horror': '👻',
  'kinh dị': '👻',
  'sci-fi': '🚀',
  'mystery': '🕵️',
  'slice of life': '☕',
  'sports': '⚽',
  'manga': '📕',
  'manhwa': '📗',
  'webtoon': '📱',
  'comic': '💥',
};

String genreLabel(String genre) {
  final emoji = _genreEmoji[genre.trim().toLowerCase()] ?? '🏷️';
  return '$emoji $genre';
}

/// Logo chữ PANEL (trắng) + FORGE (cam, gạch chân).
class ForgeBrandLogo extends StatelessWidget {
  final double fontSize;
  const ForgeBrandLogo({super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.bebasNeue(fontSize: fontSize, letterSpacing: 1.2, height: 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: fontSize + 8,
          height: fontSize + 8,
          decoration: BoxDecoration(color: ForgeColors.accent, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: fontSize * 0.8),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'PANELFORGE',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PANEL', style: style.copyWith(color: ForgeColors.text)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('FORGE', style: style.copyWith(color: ForgeColors.accent)),
                  CustomPaint(size: Size(fontSize * 2.6, fontSize * 0.28), painter: _SwooshPainter()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Top AppBar cố định nền đen: logo PANELFORGE bên trái, các nút tuỳ chọn bên phải.
/// Dùng chung cho các tab Khám phá / Tìm kiếm / Cá nhân / Thông báo.
class ForgeTopBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;
  const ForgeTopBar({super.key, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    // Màn được push (Thông báo, Thể loại) có nút ←; màn gốc của tab thì không.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return AppBar(
      backgroundColor: ForgeColors.navBar,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              tooltip: 'Quay lại',
              icon: Icon(Icons.arrow_back_rounded, color: ForgeColors.text),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      toolbarHeight: 58,
      titleSpacing: canPop ? 0 : 16,
      title: const ForgeBrandLogo(),
      actions: [...actions, const SizedBox(width: 4)],
    );
  }
}

/// Ảnh bìa: Backend chưa có ảnh bìa bộ truyện → dùng ảnh bìa chương nếu có, ngược lại khối màu kèm chữ cái đầu.
class SeriesCover extends StatelessWidget {
  final SeriesItem series;
  final String? imageUrl;
  final double radius;

  const SeriesCover({super.key, required this.series, this.imageUrl, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final placeholder = _GradientCover(series: series);
    final url = imageUrl ?? series.coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url.isEmpty
          ? placeholder
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
    );
  }
}

class _GradientCover extends StatelessWidget {
  final SeriesItem series;
  const _GradientCover({required this.series});

  // Ảnh bìa dự phòng: gradient slate trầm (#1E2330 → #13161F) với sắc độ rất nhẹ để các bìa vẫn phân biệt được.
  static const _palettes = [
    [Color(0xFF1E2330), Color(0xFF13161F)],
    [Color(0xFF222A36), Color(0xFF13171F)],
    [Color(0xFF262435), Color(0xFF14141D)],
    [Color(0xFF1D2A2E), Color(0xFF12181C)],
    [Color(0xFF2A2530), Color(0xFF16141B)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[series.id.hashCode.abs() % _palettes.length];
    final initials = series.title.trim().isEmpty ? '?' : series.title.trim().characters.first.toUpperCase();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.bebasNeue(fontSize: 48, color: ForgeColors.muted.withValues(alpha: 0.55)),
      ),
    );
  }
}

/// Tiêu đề section in hoa + mũi tên `>` (bấm để xem tất cả).
class ForgeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const ForgeSectionHeader({super.key, required this.title, this.onMore});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onMore,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ForgeColors.text,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (onMore != null) Icon(Icons.chevron_right_rounded, color: ForgeColors.text, size: 24),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Badge({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: Colors.white), const SizedBox(width: 3)],
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Thẻ truyện: bìa 3:4 bo 10px, badge HOT (trên phải), lượt xem (dưới trái), badge thời gian (trên trái, tuỳ chọn),
/// tên truyện tối đa 2 dòng và "Chapter X".
class ComicCard extends StatelessWidget {
  final SeriesItem series;
  final bool isHot;
  final String? timeBadge;
  final double? width;
  final VoidCallback onTap;

  const ComicCard({
    super.key,
    required this.series,
    required this.onTap,
    this.isHot = false,
    this.timeBadge,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SeriesCover(series: series),
                  if (timeBadge != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _Badge(text: timeBadge!, color: Colors.black.withValues(alpha: 0.65)),
                    ),
                  if (isHot)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(text: 'HOT', color: ForgeColors.hot),
                    ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _Badge(
                      text: formatViews(series.views),
                      color: Colors.black.withValues(alpha: 0.6),
                      icon: Icons.visibility_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              series.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ForgeColors.text,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Chapter ${series.totalChapters}',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ForgeColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lưới 2 cột các thẻ truyện (dùng cho Xem tất cả / Khám phá / Tìm kiếm).
class ComicGrid extends StatelessWidget {
  final List<SeriesItem> series;
  final Set<String> hotIds;
  final bool showTimeBadge;
  final DateTime? Function(SeriesItem)? updatedAt;
  final void Function(SeriesItem) onOpen;
  final bool shrinkWrap;

  const ComicGrid({
    super.key,
    required this.series,
    required this.onOpen,
    this.hotIds = const {},
    this.showTimeBadge = false,
    this.updatedAt,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.56,
      ),
      itemCount: series.length,
      itemBuilder: (context, i) {
        final s = series[i];
        return ComicCard(
          series: s,
          isHot: hotIds.contains(s.id),
          timeBadge: showTimeBadge ? timeAgo(updatedAt?.call(s)) : null,
          onTap: () => onOpen(s),
        );
      },
    );
  }
}

/// Trạng thái trống / lỗi gọn gàng.
class ForgeEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ForgeEmptyState({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: ForgeColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.muted),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(backgroundColor: ForgeColors.accent, foregroundColor: Colors.white),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nút nhanh đổi Sáng ↔ Tối (dùng trên thanh trên cùng của Trang chủ).
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Chuyển sang chế độ Sáng' : 'Chuyển sang chế độ Tối',
      onPressed: () => ref.read(appThemeModeProvider.notifier).setMode(isDark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: ForgeColors.muted, size: 20),
    );
  }
}

/// Chọn chế độ hiển thị: Sáng / Tối / Theo hệ thống (tab Tài khoản).
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Sáng')),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Tối')),
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Hệ thống')),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (s) => ref.read(appThemeModeProvider.notifier).setMode(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: ForgeColors.accent,
        selectedForegroundColor: Colors.white,
        foregroundColor: ForgeColors.text,
        side: BorderSide(color: ForgeColors.border),
      ),
    );
  }
}

/// Nét gạch chân cong (swoosh) dưới chữ FORGE.
class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ForgeColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.55
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.5, size.height * 1.15, size.width * 0.98, size.height * 0.1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Bố cục mobile mới (Trang chủ / Dành cho bạn / Tìm kiếm) ────────────────

/// Huy hiệu tròn nhỏ cạnh tên truyện — tính từ ngày tạo / ngày phát hành thật:
/// MỚI (nền cam) và UP (nền xanh da trời).
class SeriesBadge extends StatelessWidget {
  final String text;
  final Color color;
  const SeriesBadge({super.key, required this.text, required this.color});

  const SeriesBadge.newSeries({super.key}) : text = 'MỚI', color = ForgeColors.accent;
  const SeriesBadge.updated({super.key}) : text = 'UP', color = ForgeColors.up;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Dải nhãn Studio mảnh màu #282E3E ngay dưới bìa (tên Studio phát hành, in hoa).
class StudioStrip extends StatelessWidget {
  final String studio;
  final double fontSize;
  const StudioStrip({super.key, required this.studio, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ForgeColors.chip,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      alignment: Alignment.center,
      child: Text(
        (studio.isEmpty ? 'PanelForge Studio' : studio).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: ForgeColors.textSoft,
        ),
      ),
    );
  }
}

/// Thanh vàng full-width dưới thẻ: số chương ("13 chương") hoặc nhãn bộ sưu tập.
class ChapterCountBar extends StatelessWidget {
  final String label;
  final IconData icon;
  const ChapterCountBar({super.key, required this.label, this.icon = Icons.menu_book_rounded});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF13161F);
    return Container(
      height: 26,
      decoration: BoxDecoration(color: ForgeColors.gold, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ForgeText.tabular(fontSize: 12.5, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ bìa cho hàng cuộn ngang: bìa 3:4 → dải Studio → tên 1 dòng kèm huy hiệu MỚI/UP
/// → (tuỳ chọn) thanh vàng số chương.
class CoverTitleCard extends StatelessWidget {
  final SeriesItem series;
  final double width;
  final bool isNew;
  final bool isUpdated;
  final String? pillLabel;
  final IconData pillIcon;
  final bool showStudio;
  final VoidCallback onTap;

  const CoverTitleCard({
    super.key,
    required this.series,
    required this.onTap,
    this.width = 138,
    this.isNew = false,
    this.isUpdated = false,
    this.pillLabel,
    this.pillIcon = Icons.menu_book_rounded,
    this.showStudio = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: SeriesCover(series: series, radius: 0),
                  ),
                  if (showStudio) StudioStrip(studio: series.author, fontSize: 9),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (isNew) ...[const SeriesBadge.newSeries(), const SizedBox(width: 4)],
                if (isUpdated) ...[const SeriesBadge.updated(), const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    series.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ForgeColors.text,
                    ),
                  ),
                ),
              ],
            ),
            if (pillLabel != null) ...[const SizedBox(height: 6), ChapterCountBar(label: pillLabel!, icon: pillIcon)],
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề khối lớn kiểu mobile ("Phổ biến hôm nay") + liên kết "Xem thêm ›" tuỳ chọn.
class ForgeBlockTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  final Color? color;
  const ForgeBlockTitle({super.key, required this.title, this.onMore, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? ForgeColors.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(fontSize: 21, fontWeight: FontWeight.w800, color: c),
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(foregroundColor: c),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Xem thêm', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right_rounded, size: 22),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ảnh đại diện tròn của một thể loại (bìa bộ tiêu biểu) + tên thể loại.
class GenreAvatar extends StatelessWidget {
  final String genre;
  final SeriesItem? cover;
  final VoidCallback onTap;
  const GenreAvatar({super.key, required this.genre, required this.cover, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ForgeColors.border, width: 2),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: cover == null
                    ? Container(
                        color: ForgeColors.chip,
                        child: Icon(Icons.local_offer_rounded, color: ForgeColors.muted),
                      )
                    : SeriesCover(series: cover!, radius: 0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              genre,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: ForgeColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ảnh nhỏ đại diện cho một chương. Backend chưa có ảnh riêng từng chương → dùng bìa bộ truyện
/// phủ tối + số chương lớn để các dòng vẫn phân biệt được.
class ChapterThumbnail extends StatelessWidget {
  final SeriesItem series;
  final String number;
  final double width;
  final double height;
  const ChapterThumbnail({super.key, required this.series, required this.number, this.width = 124, this.height = 88});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SeriesCover(series: series, radius: 0),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.7)],
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 2,
              child: Text(
                number,
                style: GoogleFonts.bebasNeue(fontSize: height * 0.5, color: Colors.white, height: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tên riêng của chương để làm phụ đề: bỏ tiền tố "Chương N:" mà Backend ghép sẵn ("Chương 2: Huyết Chiến" → "Huyết Chiến").
/// Trả chuỗi rỗng khi chương không có tên riêng.
String chapterSubtitle(String title) {
  final stripped = title.replaceFirst(RegExp(r'^\s*Chương\s*[\d.]+\s*[:\-–.]?\s*', caseSensitive: false), '');
  return stripped.trim();
}
