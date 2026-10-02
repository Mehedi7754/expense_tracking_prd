import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_tracking_prd/core/config/app_env.dart';
import 'package:expense_tracking_prd/core/network/api_client.dart';
import 'package:expense_tracking_prd/core/utils/fetch_cache_mixin.dart';
import 'package:expense_tracking_prd/repositories/file_upload_repository.dart';

class TestService with FetchCacheMixin {
  int fetchCallCount = 0;
  String? cachedData;

  Future<String?> fetchData({bool force = false}) async {
    if (!shouldFetch(force: force, hasData: cachedData != null)) {
      return cachedData;
    }
    markFetchStarted();
    try {
      fetchCallCount++;
      await Future.delayed(const Duration(milliseconds: 20));
      cachedData = 'data_$fetchCallCount';
      markFetchCompleted();
      return cachedData;
    } catch (_) {
      markFetchFailed();
      rethrow;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FetchCacheMixin Tests', () {
    test('Blocks duplicate in-flight calls when a fetch is in progress', () async {
      final service = TestService();

      final f1 = service.fetchData();
      expect(service.isFetching, isTrue);

      final f2 = service.fetchData();
      expect(service.fetchCallCount, 1);

      await Future.wait([f1, f2]);
      expect(service.fetchCallCount, 1);
      expect(service.isFetching, isFalse);
    });

    test('Returns cached result within TTL', () async {
      final service = TestService();

      final res1 = await service.fetchData();
      expect(res1, 'data_1');
      expect(service.fetchCallCount, 1);

      final res2 = await service.fetchData();
      expect(res2, 'data_1');
      expect(service.fetchCallCount, 1);
    });

    test('force: true bypasses cache and updates data', () async {
      final service = TestService();

      final res1 = await service.fetchData();
      expect(res1, 'data_1');
      expect(service.fetchCallCount, 1);

      final res2 = await service.fetchData(force: true);
      expect(res2, 'data_2');
      expect(service.fetchCallCount, 2);
    });

    test('invalidateCache() clears cache and allows refetch', () async {
      final service = TestService();

      await service.fetchData();
      expect(service.fetchCallCount, 1);

      service.invalidateCache();
      expect(service.isCacheValid(), isFalse);

      final res2 = await service.fetchData();
      expect(res2, 'data_2');
      expect(service.fetchCallCount, 2);
    });
  });

  group('FileUploadRepository Tests', () {
    test('Passthrough for existing HTTP and /uploads/ URLs without API call', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000/api/v1',
        httpClient: mockClient,
      );
      final repo = FileUploadRepository(apiClient);

      final res1 = await repo.upload(
        filePathOrDataUri: 'https://example.com/receipt.jpg',
        category: UploadCategory.receipts,
      );
      expect(res1.url, 'https://example.com/receipt.jpg');
      expect(requestCount, 0);

      final res2 = await repo.upload(
        filePathOrDataUri: '/uploads/avatars/user_123.jpg',
        category: UploadCategory.avatars,
      );
      expect(res2.url, '/uploads/avatars/user_123.jpg');
      expect(requestCount, 0);
    });

    test('Uploads base64 data to /uploads and returns UploadResult', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/uploads');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['category'], 'receipts');
        expect(body['entityId'], 'exp_456');
        expect(body['file'], startsWith('data:image/png;base64,'));

        return http.Response(
          jsonEncode({
            'url': '/uploads/receipts/exp_456_receipt.png',
            'filename': 'exp_456_receipt.png',
            'sizeBytes': 1024,
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000/api/v1',
        httpClient: mockClient,
      );
      final repo = FileUploadRepository(apiClient);

      final result = await repo.upload(
        filePathOrDataUri: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        category: UploadCategory.receipts,
        entityId: 'exp_456',
      );

      expect(result.url, '/uploads/receipts/exp_456_receipt.png');
      expect(result.filename, 'exp_456_receipt.png');
      expect(result.sizeBytes, 1024);
    });
  });

  group('AppEnv URL Resolution Tests', () {
    test('Resolves relative /uploads/ path to full URL', () {
      final resolved = AppEnv.resolveUrl('/uploads/projects/proj_1.jpg');
      expect(resolved, contains('/uploads/projects/proj_1.jpg'));
      expect(resolved, startsWith('http'));
    });

    test('Preserves already-absolute URLs', () {
      const url = 'https://cdn.example.com/photo.jpg';
      expect(AppEnv.resolveUrl(url), url);
    });
  });
}
