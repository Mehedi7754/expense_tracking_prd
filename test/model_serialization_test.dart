import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/audit_log_model.dart';
import 'package:expense_tracking_prd/models/category_model.dart';
import 'package:expense_tracking_prd/models/client_model.dart';
import 'package:expense_tracking_prd/models/comment_model.dart';
import 'package:expense_tracking_prd/models/expense_model.dart';
import 'package:expense_tracking_prd/models/historical_project_model.dart';
import 'package:expense_tracking_prd/models/notification_model.dart';
import 'package:expense_tracking_prd/models/project_model.dart';
import 'package:expense_tracking_prd/models/task_model.dart';
import 'package:expense_tracking_prd/models/user_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';

void main() {
  group('Model Serialization Tests', () {
    test('UserModel round-trip serialization', () {
      final user = UserModel(
        id: 'usr_001',
        name: 'Eleanor Vance',
        email: 'eleanor@pfis.com',
        role: UserRole.mainAdmin,
        department: 'Executive Governance',
        designation: 'Managing Director',
        phone: '+8801700000000',
        avatarUrl: 'https://example.com/avatar.png',
        isActive: true,
        assignedProjectIds: ['proj_001', 'proj_002'],
      );

      final json = user.toJson();
      final parsed = UserModel.fromJson(json);

      expect(parsed.id, user.id);
      expect(parsed.name, user.name);
      expect(parsed.email, user.email);
      expect(parsed.role, user.role);
      expect(parsed.department, user.department);
      expect(parsed.designation, user.designation);
      expect(parsed.phone, user.phone);
      expect(parsed.avatarUrl, user.avatarUrl);
      expect(parsed.isActive, true);
      expect(parsed.assignedProjectIds, ['proj_001', 'proj_002']);
    });

    test('ProjectModel with RevenueEntry and FinancialSummary round-trip serialization', () {
      final summary = ProjectFinancialSummary(
        contractValue: 2500000.0,
        taxInfo: 'IT-VAT: Included (10%)',
        totalRevenue: 1500000.0,
        directExpenditure: 800000.0,
        officeBenefit: 240000.0,
        netProjectCost: 1040000.0,
        profit: 460000.0,
        profitMargin: 30.67,
        totalReceivable: 1000000.0,
        receiptComplianceRate: 92.5,
        teamMembersCount: 5,
        budgetVariance: -12.4,
        closedAt: DateTime(2026, 12, 31),
      );

      final revenue = RevenueEntry(
        id: 'rev_001',
        projectId: 'proj_001',
        amount: 500000.0,
        date: DateTime(2026, 3, 1),
        note: 'Mobilization Advance Payment',
        createdBy: 'Finance Officer',
      );

      final project = ProjectModel(
        id: 'p_001',
        projectId: 'PRJ-2026-001',
        name: 'Enterprise ERP Migration',
        description: 'Complete multi-tenant ERP modernization.',
        client: 'Apex Global Corp',
        clientId: 'cli_001',
        clientType: ClientType.private,
        assignmentType: AssignmentType.directConsultancy,
        grossProjectValue: 2500000.0,
        taxStatus: TaxStatus.included,
        taxRate: 0.10,
        expectedNetRevenue: 2250000.0,
        advanceReceived: 500000.0,
        amountReceived: 1500000.0,
        amountReceivable: 1000000.0,
        budget: 2000000.0,
        categoryBudgets: {'equipment': 400000.0, 'transportation': 300000.0},
        estimatedRemainingCost: 450000.0,
        officeBenefitRate: 0.30,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        teamMemberIds: ['usr_001', 'usr_002'],
        status: ProjectStatus.ongoing,
        revenueEntries: [revenue],
        isClosed: false,
        closingSummary: summary,
      );

      final json = project.toJson();
      final parsed = ProjectModel.fromJson(json);

      expect(parsed.id, project.id);
      expect(parsed.projectId, 'PRJ-2026-001');
      expect(parsed.grossProjectValue, 2500000.0);
      expect(parsed.taxRate, 0.10);
      expect(parsed.clientType, ClientType.private);
      expect(parsed.assignmentType, AssignmentType.directConsultancy);
      expect(parsed.revenueEntries.length, 1);
      expect(parsed.revenueEntries.first.amount, 500000.0);
      expect(parsed.closingSummary?.profitMargin, 30.67);
    });

    test('ExpenseModel with structured details and comments round-trip', () {
      final comment = CommentModel(
        id: 'c_01',
        expenseId: 'exp_001',
        authorId: 'usr_002',
        authorName: 'Sarah Jenkins',
        authorRole: UserRole.projectManager,
        text: 'Receipt verified with vendor invoice.',
        timestamp: DateTime(2026, 9, 20),
      );

      final equipment = EquipmentDetails(
        equipmentType: 'GPU Workstation Server',
        isRental: true,
        quantity: 2,
        rentalAmount: 45000.0,
        rentalPeriod: '1 month',
      );

      final transportation = TransportationDetails(
        transportationType: TransportationType.uberPathao,
        fromLocation: 'Head Office',
        toLocation: 'Field Deployment Site',
        vehicle: 'Car',
        distanceKm: 28.5,
        fuelCost: 1200.0,
        otherTransportCost: 350.0,
      );

      final expense = ExpenseModel(
        id: 'exp_001',
        employeeId: 'usr_001',
        employeeName: 'Fahim Ahmed',
        projectId: 'proj_001',
        projectName: 'Smart Grid Project',
        amount: 45000.0,
        officeBenefitAmount: 13500.0,
        currency: 'BDT',
        categoryId: 'cat_equip',
        categoryName: 'Equipment',
        categoryIcon: 'hardware',
        note: 'Server equipment rental for on-site deployment.',
        date: DateTime(2026, 9, 15),
        hasReceipt: true,
        receiptPhotoUrl: 'https://example.com/receipt.jpg',
        status: ExpenseStatus.approved,
        comments: [comment],
        createdAt: DateTime(2026, 9, 15),
        justificationStatus: JustificationStatus.none,
        equipmentDetails: equipment,
        transportationDetails: transportation,
      );

      final json = expense.toJson();
      final parsed = ExpenseModel.fromJson(json);

      expect(parsed.id, expense.id);
      expect(parsed.amount, 45000.0);
      expect(parsed.officeBenefitAmount, 13500.0);
      expect(parsed.totalWithBenefit, 58500.0);
      expect(parsed.status, ExpenseStatus.approved);
      expect(parsed.equipmentDetails?.rentalAmount, 45000.0);
      expect(parsed.transportationDetails?.distanceKm, 28.5);
      expect(parsed.comments.length, 1);
      expect(parsed.comments.first.text, 'Receipt verified with vendor invoice.');
    });

    test('CategoryModel, ClientModel, TaskModel, AuditLogModel, NotificationModel round-trip', () {
      final category = CategoryModel(id: 'cat_01', name: 'Software', iconName: 'software', isDefault: true);
      expect(CategoryModel.fromJson(category.toJson()).name, 'Software');

      final client = ClientModel(
        id: 'cli_01',
        name: 'GovTech BD',
        clientType: ClientType.government,
        contactPerson: 'Director General',
        email: 'dg@gov.bd',
        phone: '123456',
        address: 'Dhaka',
      );
      expect(ClientModel.fromJson(client.toJson()).clientType, ClientType.government);

      final task = TaskModel(
        id: 'tsk_01',
        projectId: 'proj_01',
        title: 'Backend API Migration',
        description: 'Migrate to PostgreSQL',
        assigneeId: 'usr_01',
        assigneeName: 'Alex',
        dueDate: DateTime(2026, 10, 1),
        status: TaskStatus.inProgress,
      );
      expect(TaskModel.fromJson(task.toJson()).status, TaskStatus.inProgress);

      final log = AuditLogModel(
        id: 'log_01',
        userId: 'usr_01',
        userName: 'Admin',
        userRole: UserRole.mainAdmin,
        action: 'Approve Expense',
        entityType: 'Expense',
        entityId: 'exp_01',
        details: 'Approved 5000 BDT',
        timestamp: DateTime(2026, 9, 29),
      );
      expect(AuditLogModel.fromJson(log.toJson()).action, 'Approve Expense');

      final notif = NotificationModel(
        id: 'notif_01',
        userId: 'usr_01',
        title: 'Claim Approved',
        message: 'Your claim was approved',
        fullExplanation: 'Full details here',
        type: NotificationType.expenseApproved,
        timestamp: DateTime(2026, 9, 29),
      );
      expect(NotificationModel.fromJson(notif.toJson()).type, NotificationType.expenseApproved);

      final bench = HistoricalProjectBenchmark(
        id: 'bench_01',
        projectName: 'Power Grid Feasibility',
        projectType: 'Engineering',
        durationMonths: 6,
        staffCount: 12,
        locationsCount: 4,
        respondentsCount: 200,
        travelIntensity: 'High',
        totalActualCost: 1500000.0,
        transportCostPercentage: 20.0,
        accommodationCostPercentage: 15.0,
        foodCostPercentage: 10.0,
        equipmentCostPercentage: 25.0,
        officeCostPercentage: 15.0,
        personnelCostPercentage: 15.0,
        averageProfitMargin: 35.0,
      );
      expect(HistoricalProjectBenchmark.fromJson(bench.toJson()).totalActualCost, 1500000.0);
    });
  });
}
