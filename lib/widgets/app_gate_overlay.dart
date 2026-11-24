import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config_service.dart';
import '../services/app_info.dart';
import '../theme/app_theme.dart';

/// Lớp chắn toàn ứng dụng: hiển thị màn hình Bảo trì (Maintenance Mode) hoặc Bắt buộc cập nhật (Force Update)
/// dựa trên `GET /api/app/mobile-config`. Khi mất mạng (config == null), không chặn người dùng để vẫn đọc Offline.
class AppGateOverlay extends ConsumerWidget {
  final Widget child;
  final String currentVersion;

  const AppGateOverlay({
    super.key,
    required this.child,
    this.currentVersion = AppInfo.version,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(mobileAppConfigProvider).asData?.value;
    if (config == null) return child;

    if (config.maintenanceMode) {
      return _GateScreen(
        icon: Icons.construction_rounded,
        title: 'Hệ thống đang bảo trì',
        message: config.maintenanceMessage,
        primaryLabel: 'Thử lại',
        onPrimary: () => ref.invalidate(mobileAppConfigProvider),
      );
    }

    if (config.requiresForceUpdate(currentVersion)) {
      final storeUrl = (!kIsWeb && Platform.isIOS)
          ? (config.storeUrlIos.isNotEmpty ? config.storeUrlIos : config.storeUrlAndroid)
          : config.storeUrlAndroid;
      return _GateScreen(
        icon: Icons.system_update_rounded,
        title: 'Cần cập nhật ứng dụng',
        message:
            'Phiên bản hiện tại ($currentVersion) đã cũ. Vui lòng cập nhật lên phiên bản mới nhất '
            '(${config.latestVersion}) trên cửa hàng ứng dụng để tiếp tục sử dụng PanelForge.',
        primaryLabel: 'Cập nhật ngay',
        onPrimary: () async {
          if (storeUrl.isNotEmpty) {
            await launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication);
          }
        },
      );
    }

    return child;
  }
}

class _GateScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const _GateScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onPrimary,
                    child: Text(
                      primaryLabel,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
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
}
