import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/services/screen_security_service.dart';
import 'package:panelforge/widgets/no_print_security_overlay.dart';
import 'package:panelforge/widgets/security_blur_shield.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenSecurityService Unit Tests', () {
    test('isPrintOrSaveOrCaptureKey detects Ctrl+P and Cmd+P', () {
      final ctrlP = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyP,
        logicalKey: LogicalKeyboardKey.keyP,
        timeStamp: Duration.zero,
      );

      // Without modifiers -> false
      expect(ScreenSecurityService.isPrintOrSaveOrCaptureKey(ctrlP), isFalse);

      // With Control modifier -> true
      final ctrlDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft,
        timeStamp: Duration.zero,
      );
      HardwareKeyboard.instance.handleKeyEvent(ctrlDown);
      expect(ScreenSecurityService.isPrintOrSaveOrCaptureKey(ctrlP), isTrue);

      final ctrlUp = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft,
        timeStamp: Duration.zero,
      );
      HardwareKeyboard.instance.handleKeyEvent(ctrlUp);
    });

    test('isPrintOrSaveOrCaptureKey detects Ctrl+S', () {
      final ctrlS = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyS,
        logicalKey: LogicalKeyboardKey.keyS,
        timeStamp: Duration.zero,
      );

      expect(ScreenSecurityService.isPrintOrSaveOrCaptureKey(ctrlS), isFalse);

      final ctrlDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft,
        timeStamp: Duration.zero,
      );
      HardwareKeyboard.instance.handleKeyEvent(ctrlDown);
      expect(ScreenSecurityService.isPrintOrSaveOrCaptureKey(ctrlS), isTrue);

      final ctrlUp = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft,
        timeStamp: Duration.zero,
      );
      HardwareKeyboard.instance.handleKeyEvent(ctrlUp);
    });

    test('isPrintOrSaveOrCaptureKey detects PrintScreen key without modifier', () {
      final printScreen = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.printScreen,
        logicalKey: LogicalKeyboardKey.printScreen,
        timeStamp: Duration.zero,
      );

      expect(ScreenSecurityService.isPrintOrSaveOrCaptureKey(printScreen), isTrue);
    });

    test('isPrintOrSaveOrCaptureKey ignores ordinary keys like KeyA', () {
      final keyA = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      );

      expect(ScreenSecurityService.isPrintOrSaveOrCaptureKey(keyA), isFalse);
    });

    test('keepScreenAwake and orientation lock methods execute without error', () async {
      await ScreenSecurityService.keepScreenAwake(true);
      await ScreenSecurityService.keepScreenAwake(false);
      await ScreenSecurityService.lockOrientation(Orientation.portrait);
      await ScreenSecurityService.lockOrientation(Orientation.landscape);
      await ScreenSecurityService.unlockOrientation();
    });
  });

  group('NoPrintSecurityOverlay Widget Tests', () {
    testWidgets('Renders child content and can display No-Print alert dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: NoPrintSecurityOverlay(
                token: 'tok-test-12345',
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      NoPrintSecurityOverlay.showNoPrintAlert(context);
                    },
                    child: const Text('MỞ BẢN THẢO'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('MỞ BẢN THẢO'), findsOneWidget);

      // Tap button to trigger alert dialog
      await tester.tap(find.text('MỞ BẢN THẢO'));
      await tester.pumpAndSettle();

      // Verify the strict security warning message appears
      expect(find.text('CẢNH BÁO BẢO MẬT BẢN THẢO'), findsOneWidget);
      expect(
        find.textContaining('NGHIÊM CẤM IN ẤN: Bản thảo đang trong quá trình kiểm duyệt nội bộ'),
        findsOneWidget,
      );
      expect(find.text('Tôi Đã Hiểu & Đồng Ý'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Tôi Đã Hiểu & Đồng Ý'));
      await tester.pumpAndSettle();

      expect(find.text('CẢNH BÁO BẢO MẬT BẢN THẢO'), findsNothing);
    });
  });

  group('SecurityBlurShield Widget Tests', () {
    testWidgets('Renders privacy blur shield and triggers dismiss callback', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecurityBlurShield(
              title: '🔒 BẢO VỆ BẢN QUYỀN NỘI DUNG',
              message: 'Nội dung truyện tranh tạm thời được che mờ khi chuyển tác vụ.',
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('🔒 BẢO VỆ BẢN QUYỀN NỘI DUNG'), findsOneWidget);
      expect(
        find.text('Nội dung truyện tranh tạm thời được che mờ khi chuyển tác vụ.'),
        findsOneWidget,
      );
      expect(find.text('Tiếp Tục Đọc / Xem Bản Thảo'), findsOneWidget);

      // Tap dismiss
      await tester.tap(find.text('Tiếp Tục Đọc / Xem Bản Thảo'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });
}
