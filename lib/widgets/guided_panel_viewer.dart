import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_package_models.dart';
import '../theme/app_theme.dart';

class GuidedPanelViewer extends StatefulWidget {
  final Widget child;
  final List<PanelInfo> panels;
  final int currentPanelIndex;
  final ValueChanged<int> onPanelChanged;
  final VoidCallback onNextPage;
  final VoidCallback onPrevPage;
  final VoidCallback onTapScreen;

  const GuidedPanelViewer({
    super.key,
    required this.child,
    required this.panels,
    required this.currentPanelIndex,
    required this.onPanelChanged,
    required this.onNextPage,
    required this.onPrevPage,
    required this.onTapScreen,
  });

  @override
  State<GuidedPanelViewer> createState() => _GuidedPanelViewerState();
}

class _GuidedPanelViewerState extends State<GuidedPanelViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.panels.isNotEmpty) {
        _animateToPanel(widget.currentPanelIndex);
      }
    });
  }

  @override
  void didUpdateWidget(covariant GuidedPanelViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPanelIndex != widget.currentPanelIndex ||
        oldWidget.panels != widget.panels) {
      _animateToPanel(widget.currentPanelIndex);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _animateToPanel(int panelIndex) {
    if (_lastSize == Size.zero) return;

    final targetMatrix = _calculateTargetMatrix(panelIndex, _lastSize);

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _animationController.forward(from: 0);
  }

  Matrix4 _calculateTargetMatrix(int index, Size size) {
    if (index < 0 || index >= widget.panels.length) {
      // Chế độ toàn trang (Overview)
      return Matrix4.identity();
    }

    final panel = widget.panels[index];
    final b = panel.bounds;

    final W = size.width;
    final H = size.height;

    final px = b.x * W;
    final py = b.y * H;
    final pw = (b.w * W).clamp(10.0, W);
    final ph = (b.h * H).clamp(10.0, H);

    // Tính tỷ lệ zoom tối ưu với viền đệm 10%
    final scaleX = (W * 0.90) / pw;
    final scaleY = (H * 0.90) / ph;
    final scale = min(scaleX, scaleY).clamp(1.0, 3.8);

    // Tọa độ tâm khung tranh
    final cx = px + (pw / 2);
    final cy = py + (ph / 2);

    // Tọa độ dịch chuyển để đưa tâm khung tranh vào giữa màn hình
    final tx = (W / 2) - (cx * scale);
    final ty = (H / 2) - (cy * scale);

    return Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  void _onNext() {
    if (widget.panels.isEmpty) {
      widget.onNextPage();
      return;
    }

    if (widget.currentPanelIndex < widget.panels.length - 1) {
      widget.onPanelChanged(widget.currentPanelIndex + 1);
    } else {
      // Đã tới khung tranh cuối của trang hiện tại -> Chuyển sang trang tiếp theo
      widget.onNextPage();
    }
  }

  void _onPrev() {
    if (widget.panels.isEmpty) {
      widget.onPrevPage();
      return;
    }

    if (widget.currentPanelIndex > 0) {
      widget.onPanelChanged(widget.currentPanelIndex - 1);
    } else if (widget.currentPanelIndex == 0) {
      // Lùi về toàn trang (Overview) hoặc trang trước
      widget.onPanelChanged(-1);
    } else {
      widget.onPrevPage();
    }
  }

  void _onDoubleTap() {
    if (widget.panels.isEmpty) return;
    // Bấm đúp để chuyển đổi giữa xem toàn cảnh trang và zoom vào khung tranh hiện tại
    if (widget.currentPanelIndex == -1) {
      widget.onPanelChanged(0);
    } else {
      widget.onPanelChanged(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastSize != currentSize) {
          _lastSize = currentSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _animateToPanel(widget.currentPanelIndex);
          });
        }

        return Stack(
          children: [
            // InteractiveViewer với AnimationController
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.8,
              maxScale: 5.0,
              panEnabled: true,
              scaleEnabled: true,
              child: Center(
                child: widget.child,
              ),
            ),

            // Tap detector regions: Trái 30% lùi, Phải 30% tiến, Giữa 40% bật tắt HUD
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _onDoubleTap,
                onTapUp: (details) {
                  final x = details.localPosition.dx;
                  final width = constraints.maxWidth;
                  if (x < width * 0.28) {
                    _onPrev();
                  } else if (x > width * 0.72) {
                    _onNext();
                  } else {
                    widget.onTapScreen();
                  }
                },
              ),
            ),

            // Floating Panel Indicator Pill (VD: Khung 2 / 5 hoặc Toàn cảnh)
            if (widget.panels.isNotEmpty)
              Positioned(
                top: 14,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.crop_free_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.currentPanelIndex >= 0
                              ? 'Khung ${widget.currentPanelIndex + 1} / ${widget.panels.length}'
                              : 'Toàn cảnh trang',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

