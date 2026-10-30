import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/preview_service.dart';
import '../../theme/app_theme.dart';

class ReviewExpiredPage extends StatefulWidget {
  final String token;

  const ReviewExpiredPage({super.key, required this.token});

  @override
  State<ReviewExpiredPage> createState() => _ReviewExpiredPageState();
}

class _ReviewExpiredPageState extends State<ReviewExpiredPage> {
  final TextEditingController _replacementTokenController = TextEditingController();
  final String _producerName = 'Ban Biên Tập & Producer';
  final String _producerEmail = 'producer@panelforge.studio';
  String _seriesTitle = 'Bản Thảo Truyện';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final dto = await PreviewService().openPreview(widget.token);
      if (mounted) {
        setState(() {
          if (dto.seriesTitle.isNotEmpty) {
            _seriesTitle = dto.seriesTitle;
          }
        });
      }
    } catch (_) {
      // Ignored for expired tokens
    }
  }

  @override
  void dispose() {
    _replacementTokenController.dispose();
    super.dispose();
  }

  void _validateReplacementToken() {
    final token = _replacementTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập token thay thế hợp lệ!')),
      );
      return;
    }

    context.pushReplacement('/review/invite/$token');
  }

  @override
  Widget build(BuildContext context) {
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
          'Thông Báo Hết Hạn',
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // TRẠNG THÁI KHÓA BẢN THẢO (Lock Graphic with Rose #EF4444)
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.roseSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.rose, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.rose.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_clock_rounded,
                    color: AppColors.rose,
                    size: 46,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Bản Thảo Đã Bị Khóa',
                style: GoogleFonts.newsreader(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Thời hạn hiệu lực của token bảo mật đã kết thúc. Để đảm bảo tính bảo mật và chống rò rỉ hình ảnh, nội dung bản thảo đã bị mã hóa trở lại.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.darkTextSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // EXPIRED TOKEN DETAILS CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MÃ TOKEN HẾT HIỆU LỰC',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.rose,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.roseSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'EXPIRED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.rose,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.token,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tác phẩm: $_seriesTitle',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // THÔNG TIN LIÊN HỆ PRODUCER QUA EMAIL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIÊN HỆ PRODUCER ĐỂ XIN GIA HẠN',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _producerName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _producerEmail,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đang mở ứng dụng email gửi tới $_producerEmail...'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: const Text('GỬI EMAIL XIN GIA HẠN TOKEN'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.darkBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Ô NHẬP TOKEN THAY THẾ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOẶC NHẬP TOKEN THAY THẾ (GIA HẠN MỚI)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkTextSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _replacementTokenController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập token mới',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.darkTextSecondary.withValues(alpha: 0.6),
                        ),
                        prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _validateReplacementToken,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('XÁC THỰC LẠI TOKEN MỚI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
