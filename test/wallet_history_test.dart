import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/widgets/wallet_history.dart';

final _txs = [
  WalletTransactionDto(
    id: 'PF-1',
    title: 'Nạp ví',
    amountVnd: 50000,
    createdAt: DateTime(2026, 10, 5, 9),
    balanceAfter: 50000,
  ),
  WalletTransactionDto(
    id: 'PF-2',
    title: 'Mở khóa Chương 3',
    amountVnd: -5000,
    createdAt: DateTime(2026, 11, 2, 20),
    balanceAfter: 45000,
  ),
  WalletTransactionDto(
    id: 'PF-3',
    title: 'Mở khóa Chương 4',
    amountVnd: -5000,
    createdAt: DateTime(2026, 11, 3, 21),
    balanceAfter: 40000,
  ),
];

Widget _app() => MaterialApp(
  home: Scaffold(body: WalletHistoryList(transactions: _txs)),
);

void main() {
  testWidgets('shows every transaction and the totals by default', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Tháng 11/2026'), findsOneWidget);
    expect(find.text('Tháng 10/2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('tx-PF-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tx-PF-3')), findsOneWidget);
    expect(find.text(formatVnd(50000)), findsWidgets);
    expect(find.text(formatVnd(10000)), findsOneWidget);
  });

  testWidgets('month filter keeps only that month and updates totals', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Tháng 11/2026'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tx-PF-1')), findsNothing);
    expect(find.byKey(const ValueKey('tx-PF-2')), findsOneWidget);
    expect(find.text(formatVnd(0)), findsOneWidget); // không có nạp trong tháng 11
    expect(find.text(formatVnd(10000)), findsOneWidget);
  });

  testWidgets('tapping a transaction opens its receipt', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(const ValueKey('tx-PF-2')));
    await tester.pumpAndSettle();

    expect(find.text('Biên lai giao dịch'), findsOneWidget);
    expect(find.text('Thanh toán từ Ví'), findsOneWidget);
    expect(find.text('PF-2'), findsOneWidget);
    expect(find.text('02/11/2026 20:00'), findsWidgets);
    expect(find.text('Sao chép mã giao dịch'), findsOneWidget);
  });
}
