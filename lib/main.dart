import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/app_router.dart';
import 'providers/api_providers.dart';
import 'services/api_client.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.init();
  await ApiClient.initCookieJar();
  runApp(const ProviderScope(child: PanelForgeApp()));
}

class PanelForgeApp extends ConsumerWidget {
  const PanelForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'PanelForge • Comic & Manga Review',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(appThemeModeProvider),
      routerConfig: router,
      // ForgeColors đọc độ sáng hiệu lực; đổi chế độ thì dựng lại cây để mọi màn hình lấy bảng màu mới.
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        ForgeColors.apply(brightness);
        return KeyedSubtree(key: ValueKey(brightness), child: child ?? const SizedBox.shrink());
      },
    );
  }
}
