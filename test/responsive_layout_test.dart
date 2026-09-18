import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/core/widgets/stat_card.dart';
import 'package:expense_tracking_prd/core/widgets/expense_list_row.dart';
import 'package:expense_tracking_prd/core/widgets/receipt_uploader.dart';
import 'package:expense_tracking_prd/models/expense_model.dart';

void main() {
  testWidgets('StatCard renders without overflow in tight 140x110 box', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 145,
              height: 115,
              child: StatCard(
                label: 'Total Submitted Very Long Label',
                value: '\$1,450,230.00',
                icon: Icons.receipt_long_rounded,
                trendText: 'Action needed urgently',
                trendDirection: TrendDirection.down,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ExpenseListRow renders without horizontal overflow on 320px screen width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final expense = ExpenseModel(
      id: 'exp_overflow_test',
      employeeId: 'usr_01',
      employeeName: 'Christopher Alexander Montgomery Junior',
      projectId: 'proj_01',
      projectName: 'Global Enterprise Cloud Infrastructure Migration Pipeline',
      amount: 145290.50,
      currency: 'USD',
      categoryId: 'cat_01',
      categoryName: 'Hardware & Infrastructure Devices Special Supplies',
      categoryIcon: 'hardware',
      note: 'Annual server cluster hardware procurement and rack mounts',
      date: DateTime.now(),
      status: ExpenseStatus.pending,
      receiptPhotoUrl: 'sample_receipt_invoice.jpg',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpenseListRow(
              expense: expense,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReceiptUploader renders sample receipt without bottom overflow', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReceiptUploader(
              imagePath: 'sample_receipt_invoice.jpg',
              isReadOnly: true,
              onImageChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
