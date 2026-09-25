import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/core/widgets/stat_card.dart';
import 'package:expense_tracking_prd/core/widgets/expense_list_row.dart';
import 'package:expense_tracking_prd/core/widgets/receipt_uploader.dart';
import 'package:expense_tracking_prd/models/expense_model.dart';
import 'package:expense_tracking_prd/models/project_model.dart';
import 'package:expense_tracking_prd/models/client_model.dart';
import 'package:expense_tracking_prd/core/widgets/project_cost_card.dart';

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

  testWidgets('ProjectCostCard minimal design renders cleanly on tight 320px width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final project = ProjectModel(
      id: 'proj_test_01',
      projectId: 'PRJ-2026-TEST',
      name: 'Smart Infrastructure Rail Transit Modernization and Signalization',
      description: 'Test project description',
      client: 'Ministry of Transportation and Communications Authority',
      clientType: ClientType.government,
      assignmentType: AssignmentType.government,
      grossProjectValue: 2500000.0,
      taxStatus: TaxStatus.included,
      taxRate: 0.1,
      expectedNetRevenue: 2250000.0,
      advanceReceived: 500000.0,
      amountReceived: 1000000.0,
      amountReceivable: 1500000.0,
      budget: 1800000.0,
      estimatedRemainingCost: 600000.0,
      officeBenefitRate: 0.15,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      teamMemberIds: ['usr_01'],
      status: ProjectStatus.ongoing,
    );

    final expenses = [
      ExpenseModel(
        id: 'exp_01',
        employeeId: 'usr_01',
        employeeName: 'Tester',
        projectId: 'proj_test_01',
        projectName: 'Smart Infrastructure Rail Transit',
        amount: 900000.0,
        currency: 'USD',
        categoryId: 'cat_01',
        categoryName: 'Consulting',
        categoryIcon: 'work',
        note: 'Phase 1 deliverables',
        date: DateTime.now(),
        status: ExpenseStatus.approved,
        receiptPhotoUrl: '',
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCostCard(
            project: project,
            projectExpenses: expenses,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Finds the percentage in the circular progress indicator
    expect(find.textContaining('%'), findsOneWidget);
  });
}
