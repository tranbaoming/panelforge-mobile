import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/review_model.dart';
import '../../services/api_client.dart';
import '../../services/preview_service.dart';
import '../../theme/app_theme.dart';

class ReviewInvitePage extends StatefulWidget {
  final String token;

  const ReviewInvitePage({super.key, required this.token});

  @override
  State<ReviewInvitePage> createState() => _ReviewInvitePageState();
}

class _ReviewInvitePageState extends State<ReviewInvitePage> {
  ReviewManuscript? _manuscript;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDecrypting = false;

  @override
  void initState() {
    super.initState();
    _fetchLivePreview();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds > 0) {
        setState(() {
          _remaining = _remaining - const Duration(seconds: 1);
        });
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  Future<void> _fetchLivePreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dto = await PreviewService().openPreview(widget.token);
      if (dto.isExpired) {
        if (mounted) {
          context.pushReplacement('/review/expired/${widget.token}');
        }
        return;
      }
      if (mounted) {
        final ms = ReviewManuscript.fromPreviewDto(dto, widget.token);
        setState(() {
          _manuscript = ms;
          _remaining = ms.remainingTime;
          _isLoading = false;
        });
        _startTimer();
      }
    } on ApiException catch (e) {
      debugPrint('[ReviewInvite API Error] $e');
      if (mounted) {
        if (e.statusCode == 403 || e.statusCode == 404) {
          context.pushReplacement('/review/expired/${widget.token}');
          return;
        }
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      debugPrint('[ReviewInvite Error] $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể kết nối đến máy chủ để xác thực bản thảo. Vui lòng kiểm tra lại kết nối mạng.';
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '00:00:00 (Hết Hạn)';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _decodeManuscript() async {
    if (_manuscript == null) return;
    setState(() => _isDecrypting = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    if (_manuscript!.isExpired || _remaining.inSeconds <= 0) {
      context.pushReplacement('/review/expired/${_manuscript!.token}');
    } else {
      context.pushReplacement('/review/canvas/${_manuscript!.token}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
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
                'Đang xác thực lời mời review bản thảo...',
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
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
                const Icon(Icons.error_outline_rounded, color: Colors.grey, size: 54),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Không tìm thấy thông tin bản thảo hoặc mã token không tồn tại.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchLivePreview,
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

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Lời Mời Review Riêng',
          style: GoogleFonts.newsreader(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // XÁC THỰC PHIÊN LÀM VIỆC (Session Verification Badge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.mintSubtle,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.mint.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppColors.mint, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'PHIÊN LÀM VIỆC ĐÃ ĐƯỢC XÁC THỰC MẬT KHẨU',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mint,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Series Title & Chapter
              Text(
                manuscript.seriesTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                manuscript.chapterTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.darkTextSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // THÔNG TIN PRODUCER
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.business_center_rounded, color: AppColors.primary, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRODUCER / NHÀ XUẤT BẢN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            manuscript.producerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${manuscript.producerStudio} • ${manuscript.producerEmail}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // HIỂN THỊ ĐỊNH DANH ĐỘC QUYỀN NGƯỜI NHẬN (Recipient Watermark Identifier)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ĐỊNH DANH ĐỘC QUYỀN NGƯỜI NHẬN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkTextSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DRM WATERMARK',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  manuscript.recipientEmail,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Mã kiểm duyệt: ${manuscript.recipientId}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tất cả các khung tranh sẽ được đóng watermark chìm mang định danh này để chống sao chép và rò rỉ.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.darkTextSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ĐẾM NGƯỢC THỜI GIAN HẾT HẠN TOKEN
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _remaining.inSeconds > 0
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.rose.withValues(alpha: 0.15),
                      AppColors.darkSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _remaining.inSeconds > 0
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.rose.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: _remaining.inSeconds > 0 ? AppColors.primary : AppColors.rose,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'THỜI GIAN HIỆU LỰC TOKEN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: _remaining.inSeconds > 0 ? AppColors.primary : AppColors.rose,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_remaining),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _remaining.inSeconds > 0 ? Colors.white : AppColors.rose,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sau khi đếm ngược kết thúc, phiên truy cập sẽ tự động bị khóa.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // NÚT GIẢI MÃ BẢN THẢO
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDecrypting ? null : _decodeManuscript,
                  icon: _isDecrypting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.key_rounded, size: 20),
                  label: Text(
                    _isDecrypting
                        ? 'ĐANG GIẢI MÃ BẢN THẢO...'
                        : 'GIẢI MÃ BẢN THẢO & VÀO REVIEW',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
