import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';

/// Màn hình "Xem tất cả" dạng lưới 2 cột (badge thời gian cập nhật, HOT, lượt xem).
class SeriesGridPage extends StatelessWidget {
  final String title;
  final List<SeriesItem> series;
  final Set<String> hotIds;
  final String emptyMessage;

  const SeriesGridPage({
    super.key,
    required this.title,
    required this.series,
    this.hotIds = const {},
    this.emptyMessage = 'Chưa có bộ truyện nào trong mục này.',
  });

  static Future<void> open(
    BuildContext context, {
    required String title,
    required List<SeriesItem> series,
    Set<String> hotIds = const {},
    String? emptyMessage,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeriesGridPage(
          title: title,
          series: series,
          hotIds: hotIds,
          emptyMessage: emptyMessage ?? 'Chưa có bộ truyện nào trong mục này.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: AppBar(
        backgroundColor: ForgeColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ForgeColors.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: ForgeColors.text),
        ),
      ),
      body: series.isEmpty
          ? Center(
              child: ForgeEmptyState(icon: Icons.menu_book_outlined, message: emptyMessage),
            )
          : ComicGrid(
              series: series,
              hotIds: hotIds,
              showTimeBadge: true,
              updatedAt: (s) => s.latestPublishedAt,
              onOpen: (s) => context.push('/series/${s.id}'),
            ),
    );
  }
}
