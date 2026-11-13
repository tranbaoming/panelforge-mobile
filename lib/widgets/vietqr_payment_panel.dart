import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

SnackBar _paymentSnackBar(String message, {required IconData icon, required Color color}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.darkSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: color),
    ),
    content: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

/// SnackBar yêu cầu đăng nhập khi Guest bấm mua chương / nạp Ví.
void showLoginRequiredSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(_paymentSnackBar(message, icon: Icons.lock_person_rounded, color: AppColors.primary));
}

void showPaymentErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(_paymentSnackBar(message, icon: Icons.cloud_off_rounded, color: AppColors.rose));
}

void showPaymentSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(_paymentSnackBar(message, icon: Icons.check_circle_rounded, color: AppColors.mint));
}

/// Hiển thị đơn VietQR do Backend sinh (ảnh QR + tài khoản thụ hưởng thật của Studio + nội dung CK bắt buộc)
/// và chờ Producer xác nhận trên Web bằng polling `GET /api/wallet/transactions/{orderCode}/status` mỗi 3 giây.
///
/// Đơn đã ở trạng thái Pending trên Backend ngay khi được tạo (hiện ngay ở màn hình Thanh toán của Producer);
/// nút "Tôi đã chuyển khoản" chỉ chuyển giao diện sang chế độ chờ xác nhận.
class VietQrPaymentPanel extends ConsumerStatefulWidget {
  final TopupResponse order;
  final String title;

  /// Gọi đúng 1 lần khi Producer duyệt đơn (status = Approved).
  final Future<void> Function(TransactionStatusDto status) onApproved;

  /// Huỷ / chọn lại (đơn Pending cũ sẽ được Producer từ chối hoặc hết hạn).
  final VoidCallback onCancel;

  const VietQrPaymentPanel({
    super.key,
    required this.order,
    required this.title,
    required this.onApproved,
    required this.onCancel,
  });

  @override
  ConsumerState<VietQrPaymentPanel> createState() => _VietQrPaymentPanelState();
}

class _VietQrPaymentPanelState extends ConsumerState<VietQrPaymentPanel> {
  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollingDuration = Duration(minutes: 15);

  Timer? _timer;
  DateTime? _pollingStartedAt;
  bool _isWaitingConfirmation = false;
  bool _isChecking = false;
  bool _connectionIssue = false;
  bool _handledFinalStatus = false;
  TransactionStatusDto? _status;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _pollingStartedAt = DateTime.now();
    _timer = Timer.periodic(_pollInterval, (_) => _checkStatus());
  }

  bool get _pollingTimedOut =>
      _pollingStartedAt != null && DateTime.now().difference(_pollingStartedAt!) > _maxPollingDuration;

  Future<void> _checkStatus({bool manual = false}) async {
    if (_isChecking || _handledFinalStatus) return;
    if (!manual && _pollingTimedOut) {
      _timer?.cancel();
      if (mounted) setState(() {});
      return;
    }
    if (manual && mounted) setState(() => _isChecking = true);

    try {
      final status = await ref.read(monetizationServiceProvider).getTransactionStatus(widget.order.orderId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _connectionIssue = false;
      });

      if (status.isApproved) {
        _handledFinalStatus = true;
        _timer?.cancel();
        await widget.onApproved(status);
      } else if (status.isRejected || status.isExpired) {
        _handledFinalStatus = true;
        _timer?.cancel();
        _showSnack(
          status.isRejected
              ? 'Giao dịch bị từ chối'
                    '${status.rejectionReason?.isNotEmpty == true ? ': ${status.rejectionReason}' : '.'}'
              : 'Đơn thanh toán đã hết hạn. Vui lòng tạo đơn mới.',
        );
      } else if (manual) {
        _showSnack('Đơn ${widget.order.orderId} vẫn đang chờ Studio xác nhận.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _connectionIssue = true);
      if (manual) {
        _showSnack(e is ApiException ? e.message : 'Không kiểm tra được trạng thái đơn. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && manual) setState(() => _isChecking = false);
    }
  }

  void _onTransferred() {
    setState(() => _isWaitingConfirmation = true);
    if (_timer == null || !_timer!.isActive) _startPolling();
    _checkStatus();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurface,
        content: Text(message, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12.5)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    _showSnack('Đã sao chép $label');
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = _status;
    final rejected = status?.isRejected ?? false;
    final expired = status?.isExpired ?? false;
    final approved = status?.isApproved ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: order.qrCodeUrl!,
                  width: 190,
                  height: 190,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    width: 190,
                    height: 190,
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    width: 190,
                    height: 190,
                    child: Center(child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _infoRow('Ngân hàng', order.bankName ?? '—', copyable: false),
              _infoRow('Chủ tài khoản', order.accountName ?? '—'),
              _infoRow('Số tài khoản', order.accountNumber ?? '—', copyable: order.accountNumber != null),
              _infoRow('Số tiền', formatVnd(order.amountVnd), copyValue: order.amountVnd.toString(), highlight: true),
              _infoRow('Nội dung CK', order.requiredTransferContent, highlight: true),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bắt buộc ghi đúng nội dung "${order.requiredTransferContent}" để Studio đối soát đơn của bạn.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (rejected || expired)
          _resultBanner(
            icon: Icons.cancel_rounded,
            color: AppColors.rose,
            title: rejected ? 'Studio đã từ chối giao dịch' : 'Đơn thanh toán đã hết hạn',
            message: rejected
                ? (status?.rejectionReason?.isNotEmpty == true
                      ? 'Lý do: ${status!.rejectionReason}'
                      : 'Vui lòng kiểm tra lại giao dịch hoặc tạo đơn mới.')
                : 'Vui lòng tạo đơn mới nếu bạn vẫn muốn thanh toán.',
          )
        else if (approved)
          _resultBanner(
            icon: Icons.check_circle_rounded,
            color: AppColors.mint,
            title: 'Studio đã xác nhận thanh toán',
            message: 'Đang cập nhật quyền lợi cho tài khoản của bạn...',
          )
        else if (_isWaitingConfirmation)
          _waitingBanner()
        else
          ElevatedButton(
            onPressed: _onTransferred,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Tôi đã chuyển khoản',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        const SizedBox(height: 8),
        if (!approved)
          TextButton(
            onPressed: widget.onCancel,
            child: Text(
              rejected || expired ? 'Tạo đơn mới' : 'Huỷ / chọn lại',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _waitingBanner() {
    final timedOut = _pollingTimedOut;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!timedOut)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  timedOut
                      ? 'Studio chưa xác nhận. Bạn có thể kiểm tra lại sau — đơn vẫn được lưu.'
                      : 'Đang chờ Studio xác nhận đã nhận tiền... (tự động kiểm tra mỗi 3 giây)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          if (_connectionIssue) ...[
            const SizedBox(height: 6),
            Text(
              'Mất kết nối tới máy chủ, đang thử lại...',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.rose),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isChecking ? null : () => _checkStatus(manual: true),
            icon: _isChecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Kiểm tra trạng thái'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBanner({required IconData icon, required Color color, required String title, required String message}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 2),
                Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false, bool copyable = true, String? copyValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.primary : Colors.white,
              ),
            ),
          ),
          if (copyable && value != '—') ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _copy(copyValue ?? value, label.toLowerCase()),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 15, color: AppColors.primary),
              ),
            ),
          ] else
            const SizedBox(width: 27),
        ],
      ),
    );
  }
}
