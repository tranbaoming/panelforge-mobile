import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/comic_model.dart';
import '../../providers/api_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';
import '../explore/series_grid_page.dart';

/// Tab "Dành cho bạn": Phổ biến hôm nay, Đề xuất cho bạn, Đọc nhiều chương, Truyện mới.
class ForYouPage extends ConsumerWidget {
  const ForYouPage({super.key});

  static const _cardWidth = 138.0;
  static const _cardHeight = 272.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogSeriesProvider);
    final items = catalog.asData?.value;

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: ForgeColors.accent,
          onRefresh: () async {
            ref.invalidate(catalogSeriesProvider);
            await ref.read(walletNotifierProvider.notifier).refresh(silent: true);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              if (items == null || items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: catalog.isLoading && items == null
                        ? const CircularProgressIndicator(color: ForgeColors.accent)
                        : catalog.hasError && items == null
                        ? ForgeEmptyState(
                            icon: Icons.cloud_off_rounded,
                            message: 'Không thể kết nối đến máy chủ',
                            actionLabel: 'Thử lại',
                            onAction: () => ref.invalidate(catalogSeriesProvider),
                          )
                        : const ForgeEmptyState(
                            icon: Icons.menu_book_outlined,
                            message: 'Chưa có bộ truyện nào được phát hành.',
                          ),
                  ),
                )
              else
                ..._sections(context, CatalogSections(items)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, CatalogSections s) {
    final today = s.popularToday;
    final manyChapters = [...s.all]..sort((a, b) => b.totalChapters.compareTo(a.totalChapters));
    final recommended = s.recommendedFor(PreferencesService.getReadingHistory());

    Widget block(String title, List<SeriesItem> list, {bool highlight = false, bool twoRows = false}) =>
        SliverToBoxAdapter(
          child: _Block(
            title: title,
            series: list,
            sections: s,
            highlight: highlight,
            twoRows: twoRows,
            onMore: () => SeriesGridPage.open(context, title: title, series: list),
          ),
        );

    return [
      // "Hôm nay" chỉ khi thật sự có lượt đọc trong 24h; nếu chưa có thì xếp theo tổng lượt đọc.
      if (today.isNotEmpty)
        block('Phổ biến hôm nay', today, twoRows: true)
      else
        block('Phổ biến', s.byViews, twoRows: true),
      block('Đề xuất cho bạn', recommended),
      block('Nhiều chương nhất', manyChapters, highlight: true, twoRows: true),
      block('Truyện mới', s.newest),
    ];
  }
}

class _Block extends StatelessWidget {
  final String title;
  final List<SeriesItem> series;
  final CatalogSections sections;
  final bool highlight;
  final bool twoRows;
  final VoidCallback onMore;

  const _Block({
    required this.title,
    required this.series,
    required this.sections,
    required this.highlight,
    required this.twoRows,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final rows = twoRows && series.length >= 4 ? 2 : 1;
    final list = series.take(rows == 2 ? 16 : 10).toList();
    return Container(
      color: highlight ? ForgeColors.surface : null,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ForgeBlockTitle(title: title, onMore: onMore),
          SizedBox(
            height: rows * ForYouPage._cardHeight + (rows - 1) * 14,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: rows,
                mainAxisSpacing: 10,
                crossAxisSpacing: 14,
                mainAxisExtent: ForYouPage._cardWidth,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                return Align(
                  alignment: Alignment.topCenter,
                  child: CoverTitleCard(
                    series: s,
                    width: ForYouPage._cardWidth,
                    isNew: sections.isNew(s),
                    isUpdated: sections.isUpdated(s),
                    pillLabel: '${s.totalChapters} chương',
                    pillIcon: Icons.menu_book_rounded,
                    onTap: () => context.push('/series/${s.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
