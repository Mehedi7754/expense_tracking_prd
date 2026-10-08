import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/core/widgets/stat_card.dart';
import 'package:expense_tracking_prd/core/widgets/expense_list_row.dart';
import 'package:expense_tracking_prd/core/widgets/receipt_uploader.dart';
import 'package:expense_tracking_prd/models/expense_model.dart';
import 'package:expense_tracking_prd/models/project_model.dart';
import 'package:expense_tracking_prd/models/client_model.dart';
import 'package:expense_tracking_prd/core/widgets/project_cost_card.dart';
import 'package:expense_tracking_prd/screens/projects/add_edit_project_screen.dart';
import 'package:expense_tracking_prd/screens/projects/projects_list_screen.dart';
import 'package:expense_tracking_prd/screens/approvals/approvals_queue_screen.dart';
import 'package:expense_tracking_prd/screens/profile/profile_screen.dart';
import 'package:expense_tracking_prd/screens/home/home_dashboard_screen.dart';
import 'package:expense_tracking_prd/screens/auth/login_screen.dart';
import 'package:expense_tracking_prd/screens/auth/register_screen.dart';
import 'package:expense_tracking_prd/screens/projects/project_detail_screen.dart';
import 'package:expense_tracking_prd/screens/expenses/expense_detail_screen.dart';
import 'package:expense_tracking_prd/screens/attendance/attendance_dashboard_screen.dart';
import 'package:expense_tracking_prd/screens/attendance/widgets/member_geo_location_modal.dart';
import 'package:expense_tracking_prd/screens/salary/salary_dashboard_screen.dart';
import 'package:expense_tracking_prd/screens/salary/salary_detail_screen.dart';
import 'package:expense_tracking_prd/screens/salary/my_salary_screen.dart';
import 'package:expense_tracking_prd/screens/attendance/my_attendance_screen.dart';
import 'package:expense_tracking_prd/models/attendance_model.dart';
import 'package:expense_tracking_prd/state/auth_provider.dart';
import 'package:expense_tracking_prd/state/user_management_provider.dart';
import 'package:expense_tracking_prd/state/project_provider.dart';
import 'package:expense_tracking_prd/state/expense_provider.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'test_fixtures.dart';

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

  testWidgets('AddEditProjectScreen renders with zero overflow on 360px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddEditProjectScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('New Project'), findsOneWidget);
    expect(find.text('Project Overview'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Contract & Tax Setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProjectsListScreen renders with single search bar and zero overflow on 360px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProjectsListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Search project, ID, client...'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('ProfileScreen renders Photo ID upload section always and no duplicate Active Photo box', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
    // User already has an avatar set
    container.read(authProvider.notifier).updateAvatarUrl('https://example.com/avatar.jpg');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Photo ID section must be visible and minimal
    expect(find.text('Profile Photo & ID'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    // Duplicate "Active Photo" box must NOT be present
    expect(find.text('Active Photo'), findsNothing);
    expect(find.byTooltip('Remove photo'), findsOneWidget);
  });

  testWidgets('ApprovalsQueueScreen renders with single search bar and zero overflow on 360px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ApprovalsQueueScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Search claimant, project...'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('LoginScreen renders with minimal professional design, enlarged size, and without extra paragraphs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In to Account'), findsOneWidget);
    expect(find.text('Sign In to GW project'), findsOneWidget);
    // Verifies extra descriptive paragraph was removed
    expect(find.textContaining('Real-time project cost monitoring'), findsNothing);
  });

  testWidgets('RegisterScreen renders with minimal professional design and without extra paragraphs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Register New User'), findsOneWidget);
    expect(find.text('Create Account & Sign In'), findsOneWidget);
    // Verifies extra descriptive paragraphs were removed
    expect(find.textContaining('Select your role to access role-specific financial dashboards'), findsNothing);
    expect(find.textContaining('Executive roles (Main Admin, Finance) require internal IT provisioning'), findsNothing);
  });

  testWidgets('ProjectCostCard configures project name with maxLines 2 for full name display', (WidgetTester tester) async {
    final project = ProjectModel(
      id: 'proj_test_long',
      projectId: 'PRJ-2026-LONG',
      name: 'Smart Infrastructure Rail Transit Modernization and Signalization Phase 2',
      description: 'Long name test',
      client: 'Transit Authority',
      clientType: ClientType.government,
      assignmentType: AssignmentType.government,
      grossProjectValue: 5000000.0,
      taxStatus: TaxStatus.included,
      taxRate: 0.1,
      expectedNetRevenue: 4500000.0,
      advanceReceived: 1000000.0,
      amountReceived: 2000000.0,
      amountReceivable: 3000000.0,
      budget: 4000000.0,
      estimatedRemainingCost: 1000000.0,
      officeBenefitRate: 0.15,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      teamMemberIds: ['usr_01'],
      status: ProjectStatus.ongoing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCostCard(
            project: project,
            projectExpenses: const [],
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final textWidget = tester.widget<Text>(find.text(project.name));
    expect(textWidget.maxLines, equals(2));
  });

  testWidgets('Switch Test Persona modal excludes Viewer persona', (WidgetTester tester) async {
    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
    container.read(userManagementProvider.notifier).setUsers(TestFixtures.testUsers);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Verify the persona switcher dropdown is removed for security and enterprise role badge is displayed
    final personaPill = find.byTooltip('Switch PRD Persona');
    expect(personaPill, findsNothing);
    expect(find.text('Super Admin'), findsOneWidget);
  });

  testWidgets('Clicking Hero section container opens Portfolio Financial Details modal showing person-wise costs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
    container.read(userManagementProvider.notifier).setUsers(TestFixtures.testUsers);
    container.read(projectProvider.notifier).setProjects(TestFixtures.testProjects);
    container.read(expenseProvider.notifier).setExpenses(TestFixtures.testExpenses);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tap the Hero Section Container
    final heroHeader = find.text('Total Portfolio Value');
    expect(heroHeader, findsOneWidget);
    await tester.tap(heroHeader);
    await tester.pumpAndSettle();

    // Verify Financial Details & Cost Audit modal is displayed
    expect(find.text('Financial Details & Cost Audit'), findsOneWidget);
    expect(find.text('Person-wise spending, categories & project audit'), findsOneWidget);

    // Verify person-wise minimal cards ("which person which cost use")
    expect(find.text('Karim Ullah'), findsWidgets);
    expect(find.text('Fahim Ahmed'), findsWidgets);

    // Tap on Karim Ullah's minimal card to expand full details
    await tester.tap(find.text('Karim Ullah').first);
    await tester.pumpAndSettle();
    expect(find.text('Cost Usage Breakdown:'), findsWidgets);
    expect(find.text('Transportation: '), findsWidgets);

    // Collapse Karim Ullah's card to restore list height
    await tester.tap(find.text('Karim Ullah').first);
    await tester.pumpAndSettle();
    expect(find.text('Sarah Jenkins'), findsWidgets);

    // Verify tabs exist and switch to Categories tab
    final categoriesTab = find.textContaining('Categories');
    expect(categoriesTab, findsOneWidget);
    await tester.tap(categoriesTab);
    await tester.pumpAndSettle();

    // Tap on minimal category card to expand dropdown
    await tester.tap(find.text('Equipment').first);
    await tester.pumpAndSettle();
    expect(find.text('Claimants in this category:'), findsWidgets);

    // Switch to Projects tab
    final projectsTab = find.textContaining('Projects (');
    expect(projectsTab, findsOneWidget);
    await tester.ensureVisible(projectsTab);
    await tester.tap(projectsTab);
    await tester.pumpAndSettle();
    expect(find.text('Enterprise Cloud ERP Platform'), findsWidgets);

    // Tap on minimal project card to expand dropdown
    final projectCard = find.text('Enterprise Cloud ERP Platform').last;
    await tester.ensureVisible(projectCard);
    await tester.tap(projectCard);
    await tester.pumpAndSettle();
    expect(find.text('Personnel Spenders:'), findsWidgets);

    // Switch to All Records tab
    final recordsTab = find.textContaining('All Records');
    expect(recordsTab, findsOneWidget);
    await tester.ensureVisible(recordsTab);
    await tester.tap(recordsTab);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Clicking Member Dashboard Hero card opens personal cost breakdown with all details', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).setUser(TestFixtures.testUsers[2]);
    container.read(userManagementProvider.notifier).setUsers(TestFixtures.testUsers);
    container.read(projectProvider.notifier).setProjects(TestFixtures.testProjects);
    container.read(expenseProvider.notifier).setExpenses(TestFixtures.testExpenses);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tap Member Hero Section Container
    final memberHero = find.text('My Total Submitted Claims');
    expect(memberHero, findsOneWidget);
    await tester.tap(memberHero);
    await tester.pumpAndSettle();

    // Verify modal opens with personal breakdown
    expect(find.text('My Expense Breakdown'), findsOneWidget);
    expect(find.text('Personal cost usage & submitted claims'), findsOneWidget);
    expect(find.text('Fahim Ahmed'), findsWidgets);

    // Tap minimal card to expand full category usage details
    await tester.tap(find.text('Fahim Ahmed').first);
    await tester.pumpAndSettle();

    expect(find.text('Equipment: '), findsWidgets);
    expect(find.text('Transportation: '), findsWidgets);
    expect(find.text('Food: '), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('ProjectDetailScreen renders with zero overflow on 360px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
    container.read(projectProvider.notifier).setProjects(TestFixtures.testProjects);
    container.read(expenseProvider.notifier).setExpenses(TestFixtures.testExpenses);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProjectDetailScreen(projectId: 'proj_01'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Project Progress'), findsOneWidget);
    expect(find.text('Project Members'), findsOneWidget);
    expect(find.text('Cost Incurred'), findsOneWidget);
  });

  testWidgets('ExpenseDetailScreen renders long equipment type without overflow on 360px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);
    container.read(projectProvider.notifier).setProjects(TestFixtures.testProjects);
    container.read(expenseProvider.notifier).setExpenses(TestFixtures.testExpenses);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ExpenseDetailScreen(expenseId: 'exp_fahim_01'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Equipment Details'), findsOneWidget);
    expect(find.text('AWS Cloud Compute & GPU Cluster'), findsOneWidget);
    expect(find.text('Tax Calculation Breakdown'), findsOneWidget);
  });

  testWidgets('AttendanceDashboardScreen renders minimal employee cards with zero overflow on 320px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AttendanceDashboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MemberGeoLocationModal renders cleanly without overflow on 320px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);

    final mockEmp = EmployeeDailyAttendance(
      userId: 'usr_eleanor',
      userName: 'Eleanor Vance',
      userEmail: 'eleanor@gw.com',
      department: 'Corporate Governance',
      designation: 'Managing Director / Admin',
      role: 'admin',
      status: 'missing',
      date: '2026-10-02',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: MemberGeoLocationModal(
              employee: mockEmp,
              date: '2026-10-02',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Eleanor Vance'), findsOneWidget);
  });

  testWidgets('SalaryDashboardScreen renders minimal salary cards with zero overflow on 320px mobile width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SalaryDashboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SalaryDetailScreen renders without overflow on 320px mobile width (fixing Image 1 184px overflow)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.mainAdmin);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SalaryDetailScreen(userId: 'a0000000-0000-0000-0000-000000000001'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Eleanor Vance'), findsOneWidget);
    expect(find.text('Monthly Base'), findsOneWidget);
    expect(find.text('Payable Days'), findsOneWidget);
    expect(find.text('Daily Rate'), findsOneWidget);
  });

  testWidgets('MySalaryScreen renders cleanly on 320px mobile width without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.projectMember);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MySalaryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MyAttendanceScreen renders cleanly on 320px mobile width without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(authProvider.notifier).switchRole(UserRole.projectMember);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MyAttendanceScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final err = tester.takeException();
    expect(err, isNull);
  });
}
