import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_package_models.dart';
import '../../models/review_model.dart';
import '../../services/preview_service.dart';
import '../../services/screen_security_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/annotation_sheet.dart';
import '../../widgets/no_print_security_overlay.dart';
import '../../widgets/panel_selection_detector.dart';
import '../../widgets/security_blur_shield.dart';
import '../../widgets/watermark_overlay.dart';

class ReviewCanvasPage extends StatefulWidget {
  final String token;

  const ReviewCanvasPage({super.key, required this.token});

  @override
  State<ReviewCanvasPage> createState() => _ReviewCanvasPageState();
}

class _ReviewCanvasPageState extends State<ReviewCanvasPage> with WidgetsBindingObserver {
  ReviewManuscript? _manuscript;
  String? _selectedPanelId;
  int _totalAnnotationCount = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPrivacyShieldActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenSecurityService.keepScreenAwake(true);
    _fetchLiveManuscript();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ScreenSecurityService.keepScreenAwake(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (mounted && !_isPrivacyShieldActive) {
        setState(() => _isPrivacyShieldActive = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (mounted && _isPrivacyShieldActive) {
        setState(() => _isPrivacyShieldActive = false);
      }
    }
  }

  Future<void> _fetchLiveManuscript() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dto = await PreviewService().openPreview(widget.token);
      if (mounted) {
        final ms = ReviewManuscript.fromPreviewDto(dto, widget.token);
        setState(() {
          _manuscript = ms;
          _isLoading = false;
          _recalculateAnnotations();
          if (ms.panels.isNotEmpty) {
            _selectedPanelId = ms.panels.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('[ReviewCanvas live load error] $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải dữ liệu bản thảo. Vui lòng kiểm tra lại kết nối mạng.';
        });
      }
    }
  }

  void _recalculateAnnotations() {
    if (_manuscript == null) return;
    int count = 0;
    for (final p in _manuscript!.panels) {
      count += p.annotations.length;
    }
    _totalAnnotationCount = count;
  }

  void _openAnnotationSheet(
    ReviewPanel panel, {
    TextRegion? selectedTextRegion,
    Offset? point,
  }) {
    if (_manuscript == null) return;
    AnnotationBottomSheet.show(
      context: context,
      panel: panel,
      selectedTextRegion: selectedTextRegion,
      initialPoint: point,
      onSubmitAnnotation: (newAnnotation) async {
        setState(() {
          final updatedPanels = _manuscript!.panels.map((p) {
            if (p.id == panel.id) {
              return p.copyWith(
                annotations: [...p.annotations, newAnnotation],
              );
            }
            return p;
          }).toList();

          _manuscript = _manuscript!.copyWith(panels: updatedPanels);
          _recalculateAnnotations();
        });

        // Đồng bộ lên Backend API Preview: POST /api/preview/feedback qua PreviewFeedbackRequest
        try {
          final request = PreviewFeedbackRequest(
            token: widget.token,
            message: '[${newAnnotation.category.label}] ${newAnnotation.note}'
                '${newAnnotation.textRegionId != null ? " [Vùng thoại: #${newAnnotation.textRegionId}]" : ""}'
                ' [Tọa độ: (${(newAnnotation.normalizedPoint.dx * 100).toStringAsFixed(1)}%, ${(newAnnotation.normalizedPoint.dy * 100).toStringAsFixed(1)}%)]',
            pageId: panel.pageId,
            panelId: panel.id.startsWith('rev-') ? null : panel.id,
            textRegionId: newAnnotation.textRegionId,
            bounds: NormalizedBounds(
              x: newAnnotation.normalizedPoint.dx,
              y: newAnnotation.normalizedPoint.dy,
              w: 0.1,
              h: 0.1,
            ),
          );
          await PreviewService().submitFeedback(request);
        } catch (e) {
          debugPrint('[Sync Feedback API Error] $e');
        }

        if (mounted) {
          final targetDesc = newAnnotation.textRegionId != null
              ? 'Vùng Thoại #${newAnnotation.textRegionId}'
              : 'Khung Tranh #${panel.panelNumber}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 18),
                  const SizedBox(width: 8),
                  Text('Đã lưu góp ý cho $targetDesc!'),
                ],
              ),
              backgroundColor: AppColors.darkSurface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Đang tải khung tranh và áp dụng watermark chìm...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_manuscript == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 54),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Không tìm thấy dữ liệu bản vẽ bản thảo.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchLiveManuscript,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final manuscript = _manuscript!;
    final cleanToken = widget.token.length > 14 ? widget.token.substring(0, 14) : widget.token;
    final watermarkText = 'BẢN THẢO NỘI BỘ - CẤM IN ẤN • $cleanToken';

    return NoPrintSecurityOverlay(
      token: widget.token,
      onSecurityTriggered: () {
        setState(() => _isPrivacyShieldActive = true);
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg.withValues(alpha: 0.9),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                manuscript.seriesTitle,
                style: GoogleFonts.newsreader(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                manuscript.chapterTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
          actions: [
            // Huy hiệu CẤM IN & SAO CHÉP (NO-PRINT DRM)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.rose.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block_rounded, size: 12, color: AppColors.rose),
                  const SizedBox(width: 4),
                  Text(
                    '🚫 CẤM IN & SAO CHÉP (NO-PRINT DRM)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.rose,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mintSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment_rounded, size: 12, color: AppColors.mint),
                  const SizedBox(width: 4),
                  Text(
                    '$_totalAnnotationCount GÓP Ý',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Top DRM Watermark warning ribbon
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppColors.primary.withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Watermark đang nhúng: ${manuscript.recipientEmail}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                            ),
                          ),
                        ),
                        Text(
                          '${manuscript.panels.length} Khung Tranh',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // MAIN SCROLLABLE CANVAS WITH WATERMARK OVERLAY (30 độ nghiêng)
                  Expanded(
                    child: WatermarkOverlay(
                      text: watermarkText,
                      angle: -30 * 3.1415926535 / 180,
                      spacingX: 200,
                      spacingY: 90,
                      opacity: 0.14,
                      child: manuscript.panels.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.panorama_outlined, size: 48, color: Colors.white24),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Bản thảo chưa có khung tranh nào',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: manuscript.panels.length,
                              itemBuilder: (context, index) {
                                final panel = manuscript.panels[index];
                                final isSelected = panel.id == _selectedPanelId;

                                return PanelSelectionDetector(
                                  panel: panel,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedPanelId = panel.id;
                                    });
                                  },
                                  onAnnotatePressed: () {
                                    _openAnnotationSheet(panel);
                                  },
                                  onTextRegionTap: (region) {
                                    setState(() {
                                      _selectedPanelId = panel.id;
                                    });
                                    _openAnnotationSheet(panel, selectedTextRegion: region);
                                  },
                                  onCanvasPointTap: (point) {
                                    setState(() {
                                      _selectedPanelId = panel.id;
                                    });
                                    _openAnnotationSheet(panel, point: point);
                                  },
                                );
                              },
                            ),
                    ),
                  ),

                  // BOTTOM CONTROL BAR
                  if (manuscript.panels.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AppColors.darkSurface,
                        border: Border(
                          top: BorderSide(color: AppColors.darkBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Khung đang chọn:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: AppColors.darkTextSecondary,
                                  ),
                                ),
                                Text(
                                  _selectedPanelId != null
                                      ? 'PANEL #${manuscript.panels.firstWhere((p) => p.id == _selectedPanelId, orElse: () => manuscript.panels.first).panelNumber}'
                                      : 'Chưa chọn',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              final currentPanel = manuscript.panels.firstWhere(
                                (p) => p.id == _selectedPanelId,
                                orElse: () => manuscript.panels.first,
                              );
                              _openAnnotationSheet(currentPanel);
                            },
                            icon: const Icon(Icons.add_comment_rounded, size: 16),
                            label: const Text('GÓP Ý PANEL NÀY'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Lớp màn chắn bảo mật khi ứng dụng mất tiêu điểm hoặc khi bấm phím chụp màn hình
            if (_isPrivacyShieldActive)
              Positioned.fill(
                child: SecurityBlurShield(
                  title: '🔒 BẢN THẢO NỘI BỘ ĐANG ĐƯỢC BẢO VỆ',
                  message: 'Màn hình tạm thời bị ẩn khi chuyển ứng dụng hoặc khi kích hoạt công cụ chụp màn hình theo chính sách bản quyền Studio.',
                  onDismiss: () {
                    setState(() => _isPrivacyShieldActive = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
