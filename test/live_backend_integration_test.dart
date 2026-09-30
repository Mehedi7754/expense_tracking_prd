import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/core/config/app_env.dart';
import 'package:expense_tracking_prd/core/network/api_client.dart';
import 'package:expense_tracking_prd/core/network/api_endpoints.dart';
import 'package:expense_tracking_prd/core/network/api_exceptions.dart';
import 'package:expense_tracking_prd/repositories/auth_repository.dart';
import 'package:expense_tracking_prd/repositories/category_repository.dart';
import 'package:expense_tracking_prd/repositories/client_repository.dart';
import 'package:expense_tracking_prd/repositories/expense_repository.dart';
import 'package:expense_tracking_prd/repositories/project_repository.dart';

void main() {
  const liveBaseUrl = 'http://xqeqm4yyv7fqxryrkm6phk55.163.227.239.97.sslip.io/api/v1';

  setUpAll(() {
    AppEnv.initializeForTesting({
      'ENVIRONMENT': 'development',
      'API_BASE_URL': liveBaseUrl,
      'API_TIMEOUT_SECONDS': '15',
    });
  });

  group('Live Backend Integration Suite ($liveBaseUrl)', () {
    final client = ApiClient(baseUrl: liveBaseUrl);
    final authRepo = AuthRepository(client);
    final projectRepo = ProjectRepository(client);
    final expenseRepo = ExpenseRepository(client);
    final categoryRepo = CategoryRepository(client);
    final clientRepo = ClientRepository(client);

    test('1. Health check returns 200 and connected status', () async {
      final res = await client.get(ApiEndpoints.health);
      expect(res, isA<Map<String, dynamic>>());
      expect(res['status'], 'ok');
      expect(res['database'], 'connected');
    });

    test('2. Authentication with wrong password throws UnauthorizedException', () async {
      expect(
        () => authRepo.login('admin@pfis.com', 'WrongPassword!'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('3. Authentication login succeeds and sets Bearer token', () async {
      final user = await authRepo.login('admin@pfis.com', 'password123');
      expect(user.email, 'admin@pfis.com');
      expect(client.authToken, isNotNull);
      expect(client.authToken!.isNotEmpty, true);
    });

    test('4. Authenticated current user profile (/auth/me)', () async {
      final profile = await authRepo.getCurrentUser();
      expect(profile, isNotNull);
      expect(profile!.email, 'admin@pfis.com');
    });

    test('5. Fetch live categories via CategoryRepository', () async {
      final categories = await categoryRepo.getCategories();
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c.name.toLowerCase().contains('equipment')), isTrue);
    });

    test('6. Fetch live projects via ProjectRepository', () async {
      final projects = await projectRepo.getProjects();
      expect(projects, isA<List>());
      expect(projects.isNotEmpty, isTrue);
    });

    test('7. Fetch live clients via ClientRepository', () async {
      final clients = await clientRepo.getClients();
      expect(clients, isA<List>());
      expect(clients.isNotEmpty, isTrue);
    });

    test('8. Fetch live expenses via ExpenseRepository', () async {
      final expenses = await expenseRepo.getExpenses();
      expect(expenses, isA<List>());
    });
  });
}
