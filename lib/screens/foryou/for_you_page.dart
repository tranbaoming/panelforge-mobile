import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../providers/api_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';
import '../explore/series_grid_page.dart';

/// Tab "Dành cho bạn": banner VIP, Phổ biến hôm nay, Đề xuất cho bạn, Đọc tất cả với VIP, Truyện mới.
/// Mỗi thẻ có thanh cam bên dưới ghi số chương thật ("13 chương") hoặc "Tất cả chương" (đọc hết bằng VIP).
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
              const SliverToBoxAdapter(child: _VipBanner()),
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
    final vipAll = [...s.all]..sort((a, b) => b.totalChapters.compareTo(a.totalChapters));
    final recommended = s.recommendedFor(PreferencesService.getReadingHistory());

    Widget block(String title, List<SeriesItem> list, {bool vip = false, bool twoRows = false}) => SliverToBoxAdapter(
      child: _Block(
        title: title,
        series: list,
        sections: s,
        vip: vip,
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
      block('Đọc tất cả với VIP', vipAll, vip: true, twoRows: true),
      block('Truyện mới', s.newest),
    ];
  }
}

class _Block extends StatelessWidget {
  final String title;
  final List<SeriesItem> series;
  final CatalogSections sections;
  final bool vip;
  final bool twoRows;
  final VoidCallback onMore;

  const _Block({
    required this.title,
    required this.series,
    required this.sections,
    required this.vip,
    required this.twoRows,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final rows = twoRows && series.length >= 4 ? 2 : 1;
    final list = series.take(rows == 2 ? 16 : 10).toList();
    return Container(
      color: vip ? ForgeColors.surface : null,
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
                    pillLabel: vip ? 'Tất cả chương' : '${s.totalChapters} chương',
                    pillIcon: vip ? Icons.workspace_premium_rounded : Icons.menu_book_rounded,
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

/// Banner VIP đầu trang. Đang có VIP → hiện hạn dùng; chưa có → mời xem gói ở tab Cửa hàng.
class _VipBanner extends ConsumerWidget {
  const _VipBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authStateProvider).isAuthenticated;
    final wallet = authed ? ref.watch(walletNotifierProvider).asData?.value : null;
    final isVip = wallet?.hasActiveVip ?? false;
    final expires = wallet?.vipExpiresAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/shop?tab=vip'),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ForgeColors.accent, AppColors.primaryDark],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVip ? 'Bạn đang là' : 'Đăng ký gói',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'VIP PANELFORGE',
                        style: GoogleFonts.bebasNeue(fontSize: 36, height: 1, color: Colors.white, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isVip
                                  ? (expires == null
                                        ? 'Đọc mọi chương trả phí'
                                        : 'Đọc mọi chương trả phí đến ${_date(expires)}')
                                  : 'Đọc mọi chương trả phí khi gói còn hạn',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isVip ? 'XEM\nGÓI' : 'XEM\nGÓI ›',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: ForgeColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
