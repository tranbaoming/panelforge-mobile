import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Thanh điều hướng dưới cùng: 5 tab biểu tượng + nhãn, tab đang mở có nền "viên thuốc" cam nhạt.
/// Thứ tự tab khớp thứ tự `StatefulShellBranch` trong `app_router.dart`.
/// Khi mất kết nối mạng, hiển thị banner ngoại tuyến cho phép nhảy thẳng tới `/downloads`.
class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  static const tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Trang chủ'),
    (Icons.auto_stories_outlined, Icons.auto_stories_rounded, 'Dành cho bạn'),
    (Icons.search_rounded, Icons.search_rounded, 'Tìm kiếm'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Cửa hàng'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Cá nhân'),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = navigationShell.currentIndex;
    final isOffline = ref.watch(isOfflineProvider).asData?.value ?? false;

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: Column(
        children: [
          if (isOffline) const _OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ForgeColors.navBar,
          border: Border(top: BorderSide(color: ForgeColors.divider, width: 0.8)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: tabs[i].$3,
                      child: InkWell(
                        onTap: () => _onTap(i),
                        child: Semantics(
                          selected: i == current,
                          button: true,
                          child: _NavItem(
                            icon: i == current ? tabs[i].$2 : tabs[i].$1,
                            label: tabs[i].$3,
                            active: i == current,
                          ),
                        ),
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bạn đang ngoại tuyến',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => context.push('/downloads'),
                child: Text(
                  'Truyện đã tải',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _NavItem({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? ForgeColors.accent : ForgeColors.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          height: 30,
          decoration: BoxDecoration(
            color: active ? ForgeColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 23, color: color),
        ),
        const SizedBox(height: 4),
        // Màn hình hẹp (< 360dp): thu nhỏ nhãn thay vì cắt chữ.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
