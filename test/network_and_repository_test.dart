import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_tracking_prd/core/network/api_client.dart';
import 'package:expense_tracking_prd/core/network/api_exceptions.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/repositories/auth_repository.dart';
import 'package:expense_tracking_prd/repositories/project_repository.dart';

void main() {
  group('ApiClient & Network Tests', () {
    test('ApiClient handles successful GET and parses JSON body', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/test');
        expect(request.headers['Authorization'], 'Bearer test_token_123');
        return http.Response(jsonEncode({'status': 'ok', 'data': [1, 2, 3]}), 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );
      apiClient.setAuthToken('test_token_123');

      final result = await apiClient.get('/test');
      expect(result['status'], 'ok');
      expect(result['data'], [1, 2, 3]);
    });

    test('ApiClient throws UnauthorizedException on 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Invalid token'}), 401);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => apiClient.get('/protected'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('ApiClient throws NotFoundException on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Resource not found'}), 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => apiClient.get('/missing'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('ApiClient throws ServerException on 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => apiClient.get('/server-error'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('AuthRepository Tests', () {
    test('login sets bearer token and parses UserModel', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'admin@pfis.com');
        return http.Response(
          jsonEncode({
            'token': 'jwt_secret_token_xyz',
            'user': {
              'id': 'usr_admin',
              'name': 'Super Admin',
              'email': 'admin@pfis.com',
              'role': 'main_admin',
              'department': 'Governance',
            },
          }),
          200,
        );
      });

      final apiClient = ApiClient(baseUrl: 'http://api.test/api/v1', httpClient: mockClient);
      final authRepo = AuthRepository(apiClient);

      final user = await authRepo.login('admin@pfis.com', 'secret123');
      expect(user.id, 'usr_admin');
      expect(user.role, UserRole.mainAdmin);
      expect(apiClient.authToken, 'jwt_secret_token_xyz');

      await authRepo.logout();
      expect(apiClient.authToken, isNull);
    });
  });

  group('ProjectRepository Tests', () {
    test('getProjects parses list of projects', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'proj_100',
              'project_id': 'PRJ-2026-100',
              'name': 'Smart Irrigation System',
              'description': 'IoT sensors for agricultural water efficiency',
              'client': 'Ministry of Agriculture',
              'gross_project_value': 1200000.0,
              'expected_net_revenue': 1080000.0,
              'amount_received': 300000.0,
              'amount_receivable': 900000.0,
              'budget': 950000.0,
              'status': 'ongoing',
              'start_date': '2026-01-01',
              'end_date': '2026-08-31',
              'team_member_ids': ['usr_01'],
            }
          ]),
          200,
        );
      });

      final apiClient = ApiClient(baseUrl: 'http://api.test/api/v1', httpClient: mockClient);
      final projectRepo = ProjectRepository(apiClient);

      final projects = await projectRepo.getProjects();
      expect(projects.length, 1);
      expect(projects.first.name, 'Smart Irrigation System');
      expect(projects.first.grossProjectValue, 1200000.0);
    });
  });
}
