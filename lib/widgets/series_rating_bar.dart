import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_model.dart';
import '../navigation/read_guard.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

/// Đánh giá 1–5 sao cho bộ truyện: hiện điểm trung bình + số lượt, chạm sao để đánh giá (cần đăng nhập).
/// Mỗi độc giả một đánh giá, chạm lại để sửa. Publisher thấy điểm này trên dashboard (lọc theo ngôn ngữ đọc).
class SeriesRatingBar extends ConsumerStatefulWidget {
  final SeriesItem series;
  final double average;
  final int count;
  final int? myRating;
  final CatalogService? catalogService;

  const SeriesRatingBar({
    super.key,
    required this.series,
    required this.average,
    required this.count,
    this.myRating,
    this.catalogService,
  });

  @override
  ConsumerState<SeriesRatingBar> createState() => _SeriesRatingBarState();
}

class _SeriesRatingBarState extends ConsumerState<SeriesRatingBar> {
  late double _average = widget.average;
  late int _count = widget.count;
  late int? _mine = widget.myRating;
  bool _saving = false;

  Future<void> _rate(int stars) async {
    if (_saving) return;
    if (!await ensureLoggedInForReading(context, ref, series: widget.series)) return;
    setState(() => _saving = true);
    try {
      final result = await (widget.catalogService ?? CatalogService()).rateSeries(
        widget.series.id,
        stars,
        lang: PreferencesService.getContentLanguage(),
      );
      if (!mounted) return;
      setState(() {
        _average = result.average;
        _count = result.count;
        _mine = stars;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Không gửi được đánh giá. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 4),
          Text(
            _count > 0 ? _average.toStringAsFixed(1) : '—',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: ForgeColors.text),
          ),
          const SizedBox(width: 4),
          Text('($_count đánh giá)', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.textSoft)),
          const Spacer(),
          Semantics(
            label: 'Đánh giá của bạn',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final stars = i + 1;
                final filled = (_mine ?? 0) >= stars;
                return IconButton(
                  key: ValueKey('rate-$stars'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: '$stars sao',
                  onPressed: _saving ? null : () => _rate(stars),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.primary : ForgeColors.textSoft,
                    size: 24,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
