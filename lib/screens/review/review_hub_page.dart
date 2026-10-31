import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';
import '../../services/preferences_service.dart';
import '../../services/preview_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/qr_scanner_dialog.dart';

class ReviewHubPage extends StatefulWidget {
  const ReviewHubPage({super.key});

  @override
  State<ReviewHubPage> createState() => _ReviewHubPageState();
}

class _ReviewHubPageState extends State<ReviewHubPage> {
  final TextEditingController _linkController = TextEditingController();
  List<String> _recentTokens = [];
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _recentTokens = PreferencesService.getRecentReviewTokens();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _openReviewWithToken(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập hoặc quét mã token')),
      );
      return;
    }

    // Trích xuất token nếu người dùng dán link dạng http://.../preview/{token}
    String actualToken = clean;
    if (actualToken.contains('/preview/')) {
      actualToken = actualToken.split('/preview/').last.split('?').first;
    } else if (actualToken.contains('/review/')) {
      actualToken = actualToken.split('/review/').last.split('?').first;
    }

    setState(() => _isValidating = true);

    try {
      final preview = await PreviewService().openPreview(actualToken);
      if (!mounted) return;
      setState(() => _isValidating = false);
      if (preview.isExpired) {
        context.push('/review/expired/$actualToken');
      } else {
        await PreferencesService.addRecentReviewToken(actualToken);
        if (mounted) {
          setState(() {
            _recentTokens = PreferencesService.getRecentReviewTokens();
          });
          context.push('/review/invite/$actualToken');
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isValidating = false);
      if (e.statusCode == 403 || e.statusCode == 404) {
        context.push('/review/expired/$actualToken');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xác thực bản thảo: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.')),
      );
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _linkController.text = data.text!.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã dán liên kết từ bộ nhớ tạm!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bộ nhớ tạm trống hoặc không có văn bản')),
      );
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

  void _deleteRecentToken(String token) async {
    await PreferencesService.removeRecentReviewToken(token);
    if (mounted) {
      setState(() {
        _recentTokens = PreferencesService.getRecentReviewTokens();
      });
    }
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
                          onPressed: _isValidating
                              ? null
                              : () {
                                  final text = _linkController.text.trim();
                                  if (text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Vui lòng nhập hoặc dán mã token review')),
                                    );
                                    return;
                                  }
                                  _openReviewWithToken(text);
                                },
                          icon: _isValidating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.lock_open_rounded, size: 18),
                          label: Text(_isValidating ? 'ĐANG XÁC THỰC BẢN THẢO...' : 'XÁC THỰC & MỞ LỜI MỜI REVIEW'),
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
                      '${_recentTokens.length} mã token',
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

            // List of Recent Tokens or Empty State
            if (_recentTokens.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.history_toggle_off_rounded, size: 40, color: Colors.white30),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có bản thảo nào được mở gần đây',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hãy dán đường link hoặc quét mã QR do Producer gửi để bắt đầu thẩm định bản vẽ.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final token = _recentTokens[index];
                      return _buildRecentTokenCard(context, token);
                    },
                    childCount: _recentTokens.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTokenCard(BuildContext context, String token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 22),
        ),
        title: Text(
          token,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: Text(
          'Nhấn để kết nối và mở lại bản thảo',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.darkTextSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white38),
              tooltip: 'Xóa khỏi lịch sử',
              onPressed: () => _deleteRecentToken(token),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
          ],
        ),
        onTap: () {
          _linkController.text = token;
          _openReviewWithToken(token);
        },
      ),
    );
  }
}
