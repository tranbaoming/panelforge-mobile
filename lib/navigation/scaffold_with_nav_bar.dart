import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Thanh điều hướng dưới cùng nền đen, icon cam khi active.
/// Thứ tự tab khớp thứ tự `StatefulShellBranch` trong `app_router.dart`.
class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  static const _tabs = [
    (Icons.home_filled, Icons.home_filled, 'Trang chủ'),
    (Icons.explore_outlined, Icons.explore, 'Khám phá'),
    (Icons.search, Icons.search, 'Tìm kiếm'),
    (Icons.person, Icons.person, 'Cá nhân'),
    (Icons.notifications_none, Icons.notifications, 'Thông báo'),
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
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => _onTap(i),
                      child: Semantics(
                        selected: i == current,
                        button: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              i == current ? _tabs[i].$2 : _tabs[i].$1,
                              size: 24,
                              color: i == current ? ForgeColors.accent : ForgeColors.muted,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tabs[i].$3,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                                color: i == current ? ForgeColors.accent : ForgeColors.muted,
                              ),
                            ),
                          ],
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
