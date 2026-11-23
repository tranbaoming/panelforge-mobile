import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/services/app_config_service.dart';
import 'package:panelforge/widgets/app_gate_overlay.dart';

void main() {
  group('MobileAppConfig semver comparison', () {
    test('detects when current version is below minVersion', () {
      expect(MobileAppConfig.compareSemver('1.3.9', '1.4.0'), lessThan(0));
      expect(MobileAppConfig.compareSemver('1.4.0', '1.4.0'), equals(0));
      expect(MobileAppConfig.compareSemver('1.4.1', '1.4.0'), greaterThan(0));
      expect(MobileAppConfig.compareSemver('2.0.0+5', '1.9.9'), greaterThan(0));
    });

    test('requiresForceUpdate returns true only when strictly older', () {
      const cfg = MobileAppConfig(
        minVersion: '1.5.0',
        latestVersion: '1.6.0',
        maintenanceMode: false,
        maintenanceMessage: '',
        storeUrlAndroid: 'https://play.google.com/store/apps/details?id=com.panelforge.reader',
        storeUrlIos: '',
      );
      expect(cfg.requiresForceUpdate('1.4.0'), isTrue);
      expect(cfg.requiresForceUpdate('1.5.0'), isFalse);
      expect(cfg.requiresForceUpdate('1.6.0'), isFalse);
    });
  });

  group('AppGateOverlay Widget Tests', () {
    testWidgets('shows maintenance screen when maintenanceMode is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileAppConfigProvider.overrideWith(
              (ref) async => const MobileAppConfig(
                minVersion: '1.4.0',
                latestVersion: '1.4.0',
                maintenanceMode: true,
                maintenanceMessage: 'Đang nâng cấp máy chủ.',
                storeUrlAndroid: '',
                storeUrlIos: '',
              ),
            ),
          ],
          child: const MaterialApp(
            home: AppGateOverlay(child: Text('Main App Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hệ thống đang bảo trì'), findsOneWidget);
      expect(find.text('Đang nâng cấp máy chủ.'), findsOneWidget);
      expect(find.text('Main App Content'), findsNothing);
    });

    testWidgets('shows force update screen when version is below minVersion', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileAppConfigProvider.overrideWith(
              (ref) async => const MobileAppConfig(
                minVersion: '2.0.0',
                latestVersion: '2.1.0',
                maintenanceMode: false,
                maintenanceMessage: '',
                storeUrlAndroid: 'https://play.google.com/store/apps/details?id=com.panelforge.reader',
                storeUrlIos: '',
              ),
            ),
          ],
          child: const MaterialApp(
            home: AppGateOverlay(currentVersion: '1.4.0', child: Text('Main App Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cần cập nhật ứng dụng'), findsOneWidget);
      expect(find.text('Cập nhật ngay'), findsOneWidget);
      expect(find.text('Main App Content'), findsNothing);
    });

    testWidgets('renders child normally when config is null (offline)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileAppConfigProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: AppGateOverlay(child: Text('Main App Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main App Content'), findsOneWidget);
    });
  });
}
