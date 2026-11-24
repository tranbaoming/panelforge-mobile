import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/app_router.dart';
import 'providers/api_providers.dart';
import 'providers/library_sync_provider.dart';
import 'services/api_client.dart';
import 'services/app_config_service.dart';
import 'services/crash_reporter.dart';
import 'services/google_play_billing_service.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_gate_overlay.dart';
import 'widgets/vietqr_payment_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.init();
  CrashReporter.install();
  await ApiClient.initCookieJar();
  runApp(const ProviderScope(child: PanelForgeApp()));
}

class PanelForgeApp extends ConsumerStatefulWidget {
  const PanelForgeApp({super.key});

  @override
  ConsumerState<PanelForgeApp> createState() => _PanelForgeAppState();
}

class _PanelForgeAppState extends ConsumerState<PanelForgeApp> with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (GooglePlayBillingService.isSupportedPlatform) {
      // Nghe giao dịch Google Play từ lúc mở app (kể cả giao dịch về khi không màn nào đang mở).
      final billing = ref.read(googlePlayBillingProvider)..start();
      billing.events.listen(_onBillingEvent);
      Future.microtask(billing.retryPendingPurchases);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại app thì tải lại cấu hình vận hành (bật bảo trì / bắt buộc cập nhật giữa phiên).
    if (state == AppLifecycleState.resumed) ref.invalidate(mobileAppConfigProvider);
  }

  void _onBillingEvent(BillingEvent event) {
    final messenger = _messengerKey.currentState;
    switch (event) {
      case BillingVerified(:final result):
        ref.read(walletNotifierProvider.notifier).refresh(silent: true);
        if (result.alreadyProcessed) return;
        messenger?.showSnackBar(paymentResultSnackBar(
          result.message.isNotEmpty ? result.message : 'Nạp thành công vào Ví qua Google Play!',
          success: true,
        ));
      case BillingPending():
        messenger?.showSnackBar(paymentResultSnackBar(
          'Giao dịch Google Play đang chờ thanh toán. Ví sẽ được cộng khi Google xác nhận.',
          success: true,
        ));
      case BillingFailed(:final message):
        messenger?.showSnackBar(paymentResultSnackBar(message, success: false));
      case BillingCanceled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    // Giữ đồng bộ thư viện cá nhân chạy suốt vòng đời app (không dựng lại MaterialApp khi trạng thái đổi).
    ref.listen(librarySyncProvider, (_, _) {});
    // Đăng nhập xong thì gửi lại giao dịch Google Play còn dang dở.
    ref.listen(authStateProvider.select((s) => s.isAuthenticated), (was, now) {
      if (now && was != true && GooglePlayBillingService.isSupportedPlatform) {
        ref.read(googlePlayBillingProvider).retryPendingPurchases();
      }
    });
    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
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
