import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/app_router.dart';
import 'providers/api_providers.dart';
import 'providers/library_sync_provider.dart';
import 'services/api_client.dart';
import 'services/crash_reporter.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_gate_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.init();
  CrashReporter.install();
  await ApiClient.initCookieJar();
  runApp(const ProviderScope(child: PanelForgeApp()));
}

class PanelForgeApp extends ConsumerWidget {
  const PanelForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Giữ đồng bộ thư viện cá nhân chạy suốt vòng đời app (không dựng lại MaterialApp khi trạng thái đổi).
    ref.listen(librarySyncProvider, (_, _) {});
    return MaterialApp.router(
      title: 'PanelForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(appThemeModeProvider),
      routerConfig: router,
      // ForgeColors đọc độ sáng hiệu lực; đổi chế độ thì dựng lại cây để mọi màn hình lấy bảng màu mới.
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        ForgeColors.apply(brightness);
        // Cỡ chữ trong Cài đặt nhân thêm vào cỡ chữ hệ thống (hỗ trợ người đọc cần chữ to).
        final media = MediaQuery.of(context);
        final scale = ref.watch(textScaleProvider);
        return MediaQuery(
          data: media.copyWith(textScaler: _MultipliedTextScaler(media.textScaler, scale)),
          child: KeyedSubtree(
            key: ValueKey(brightness),
            child: AppGateOverlay(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

class _MultipliedTextScaler extends TextScaler {
  final TextScaler base;
  final double factor;
  const _MultipliedTextScaler(this.base, this.factor);

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => base.scale(14) / 14 * factor;

  @override
  bool operator ==(Object other) => other is _MultipliedTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
