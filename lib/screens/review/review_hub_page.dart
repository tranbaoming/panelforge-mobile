import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/review_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/qr_scanner_dialog.dart';

class ReviewHubPage extends StatefulWidget {
  const ReviewHubPage({super.key});

  @override
  State<ReviewHubPage> createState() => _ReviewHubPageState();
}

class _ReviewHubPageState extends State<ReviewHubPage> {
  final TextEditingController _linkController = TextEditingController();
  final List<ReviewManuscript> _recentReviews = MockReviewRepository.getRecentManuscripts();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _openReviewWithToken(String token) {
    if (token.trim().isEmpty) return;
    final cleanToken = token.trim();
    if (cleanToken.toLowerCase().contains('expired') || cleanToken.contains('7712')) {
      context.push('/review/expired/$cleanToken');
    } else {
      context.push('/review/invite/$cleanToken');
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data?.text != null && data!.text!.isNotEmpty) {
      _linkController.text = data.text!;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã dán liên kết từ bộ nhớ tạm!')),
      );
    } else {
      _linkController.text = 'https://panelforge.studio/review/REV-8891-OBSIDIAN-AETHEL';
    }
  }

  void _openQRScanner() {
    QRScannerDialog.show(
      context: context,
      onCodeScanned: (scannedToken) {
        _linkController.text = scannedToken;
        _openReviewWithToken(scannedToken);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Header: Title & Collaborative Review Badge
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'BẢO MẬT & ĐỘC QUYỀN',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trung Tâm Review & Duyệt Bản Thảo',
                      style: GoogleFonts.newsreader(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhập link mời bí mật hoặc quét mã token để mở canvas bản thảo có watermark chìm.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // INPUT CARD: Dán link review riêng + Nút Quét mã QR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.darkBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIÊN KẾT DUYỆT BẢN THẢO RIÊNG TƯ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkTextSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Input with Paste & QR Button
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _linkController,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Dán liên kết hoặc mã token (REV-...)',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.darkTextSecondary.withValues(alpha: 0.6),
                                ),
                                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                                  tooltip: 'Dán link',
                                  color: AppColors.primary,
                                  onPressed: _pasteFromClipboard,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Nút Quét Mã QR
                          IconButton.filled(
                            onPressed: _openQRScanner,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            tooltip: 'Quét mã QR',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Nút Mở Bản Thảo
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_linkController.text.trim().isEmpty) {
                              _linkController.text = 'REV-8891-OBSIDIAN-AETHEL';
                            }
                            _openReviewWithToken(_linkController.text);
                          },
                          icon: const Icon(Icons.lock_open_rounded, size: 18),
                          label: const Text('XÁC THỰC & MỞ LỜI MỜI REVIEW'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Section Header: Danh Sách Các Bản Thảo Đã Mở Gần Đây
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bản Thảo Đã Mở Gần Đây',
                      style: GoogleFonts.newsreader(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_recentReviews.length} bản',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // List of Recent Reviews with Status Tags (Còn Hạn / Đã Hết Hạn)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final review = _recentReviews[index];
                    return _buildReviewManuscriptCard(context, review);
                  },
                  childCount: _recentReviews.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewManuscriptCard(BuildContext context, ReviewManuscript item) {
    final isExpired = item.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpired
              ? AppColors.rose.withValues(alpha: 0.3)
              : AppColors.mint.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (isExpired) {
            context.push('/review/expired/${item.token}');
          } else {
            context.push('/review/canvas/${item.token}');
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Status badge & Token
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Tag: Còn hạn (Mint) / Đã hết hạn (Rose)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired ? AppColors.roseSubtle : AppColors.mintSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isExpired ? AppColors.rose : AppColors.mint,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpired ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                          size: 12,
                          color: isExpired ? AppColors.rose : AppColors.mint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isExpired ? 'ĐÃ HẾT HẠN' : 'CÒN HẠN REVIEW',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isExpired ? AppColors.rose : AppColors.mint,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    item.token,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Series Title & Chapter
              Text(
                item.seriesTitle,
                style: GoogleFonts.newsreader(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.chapterTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.darkTextSecondary,
                ),
              ),

              const SizedBox(height: 12),

              // Producer Info & Expiry time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Producer: ${item.producerName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: isExpired ? AppColors.rose : AppColors.mint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired
                            ? 'Đã khóa'
                            : 'Còn ${item.remainingTime.inHours}h ${item.remainingTime.inMinutes % 60}m',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isExpired ? AppColors.rose : AppColors.mint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
