import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Thanh điều hướng dưới cùng: 5 tab biểu tượng + nhãn, tab đang mở có nền "viên thuốc" cam nhạt.
/// Thứ tự tab khớp thứ tự `StatefulShellBranch` trong `app_router.dart`.
class ScaffoldWithNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: navigationShell,
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
