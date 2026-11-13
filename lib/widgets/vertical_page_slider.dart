import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Thanh trượt trang dọc ẩn ở mép phải trình đọc.
///
/// Bình thường không hiện gì và không chặn thao tác: lướt / chạm / lật trang vẫn như cũ (kể cả ở mép phải).
/// Bấm đè (giữ yên ~0,4 giây) ở mép phải [edgeWidth] → hiện thanh trượt (rãnh mờ, phần đã đọc màu cam, nút tròn cam)
/// và bong bóng "trang / tổng"; giữ nguyên ngón tay kéo lên/xuống để nhảy trang; nhấc tay → thanh ẩn đi.
/// Nếu ngón tay di chuyển trước khi đủ thời gian giữ thì đó là thao tác lướt bình thường.
class VerticalPageScrubber extends StatefulWidget {
  final Widget child;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;
  final bool enabled;

  /// Bề rộng vùng mép phải nhận bấm đè.
  final double edgeWidth;

  /// Khoảng chừa trên / dưới cho rãnh trượt (tránh tai thỏ, thanh điều hướng).
  final EdgeInsets trackMargin;

  const VerticalPageScrubber({
    super.key,
    required this.child,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
    this.enabled = true,
    this.edgeWidth = 48,
    this.trackMargin = const EdgeInsets.only(top: 90, bottom: 110),
  });

  @override
  State<VerticalPageScrubber> createState() => _VerticalPageScrubberState();
}

class _VerticalPageScrubberState extends State<VerticalPageScrubber> {
  static const double _thumb = 22;
  static const double _trackWidth = 6;

  final _trackKey = GlobalKey();

  /// Đang bấm đè để tua trang.
  bool _scrubbing = false;

  /// Trang đang tua tới.
  int? _dragPage;

  int get _total => widget.totalPages < 1 ? 1 : widget.totalPages;

  void _updateFromGlobal(Offset global) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dy = box.globalToLocal(global).dy;
    final usable = (box.size.height - _thumb).clamp(1.0, double.infinity);
    final t = ((dy - _thumb / 2) / usable).clamp(0.0, 1.0);
    final page = 1 + (t * (_total - 1)).round();
    if (page == _dragPage) return;
    setState(() => _dragPage = page);
    widget.onPageSelected(page);
  }

  void _start(LongPressStartDetails d) {
    setState(() {
      _scrubbing = true;
      _dragPage = widget.currentPage.clamp(1, _total);
    });
    // Rãnh vừa hiện: đợi layout xong rồi mới tính trang theo vị trí ngón tay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrubbing) _updateFromGlobal(d.globalPosition);
    });
  }

  /// Ngón tay đặt trong dải [VerticalPageScrubber.edgeWidth] sát mép phải vùng đọc.
  bool _isAtEdge(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    return box.globalToLocal(global).dx >= box.size.width - widget.edgeWidth;
  }

  void _onMove(LongPressMoveUpdateDetails d) => _updateFromGlobal(d.globalPosition);

  void _onEnd(LongPressEndDetails _) => _end();

  void _end() => setState(() {
    _scrubbing = false;
    _dragPage = null;
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              if (widget.enabled)
                _EdgeLongPressRecognizer: GestureRecognizerFactoryWithHandlers<_EdgeLongPressRecognizer>(
                  () => _EdgeLongPressRecognizer(acceptsAt: _isAtEdge, debugOwner: this),
                  (r) {
                    r
                      ..acceptsAt = _isAtEdge
                      ..onLongPressStart = _start
                      ..onLongPressMoveUpdate = _onMove
                      ..onLongPressEnd = _onEnd
                      ..onLongPressCancel = _end;
                  },
                ),
            },
            child: widget.child,
          ),
        ),
        Positioned(
          top: widget.trackMargin.top,
          bottom: widget.trackMargin.bottom,
          right: 6,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _scrubbing ? 1 : 0,
              child: _buildTrack(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrack() {
    final page = (_dragPage ?? widget.currentPage).clamp(1, _total);
    final fraction = _total <= 1 ? 1.0 : (page - 1) / (_total - 1);
    return LayoutBuilder(
      key: _trackKey,
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final thumbTop = fraction * (height - _thumb);
        return Semantics(
          slider: true,
          label: 'Thanh trượt trang',
          value: 'Trang $page / $_total',
          child: SizedBox(
            key: const ValueKey('vertical-page-slider'),
            width: 44,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Rãnh mờ.
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: _trackWidth + 10,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Phần đã đọc (cam) từ đầu rãnh tới nút.
                Positioned(
                  top: _thumb / 2,
                  child: Container(
                    width: _trackWidth / 2,
                    height: thumbTop,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // Nút kéo.
                Positioned(
                  top: thumbTop,
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6)],
                    ),
                  ),
                ),
                // Bong bóng số trang.
                if (_scrubbing)
                  Positioned(
                    top: thumbTop - 4,
                    right: 46,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$page / $_total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bấm đè chỉ nhận khi ngón tay đặt ở mép phải màn hình; nơi khác (và khi ngón tay di chuyển trước thời hạn)
/// nhường cho thao tác lướt / chạm của trình đọc.
class _EdgeLongPressRecognizer extends LongPressGestureRecognizer {
  bool Function(Offset global) acceptsAt;

  _EdgeLongPressRecognizer({required this.acceptsAt, super.debugOwner})
    : super(duration: const Duration(milliseconds: 400));

  @override
  bool isPointerAllowed(PointerDownEvent event) => acceptsAt(event.position) && super.isPointerAllowed(event);
}
