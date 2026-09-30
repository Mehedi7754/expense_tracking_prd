import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/client_model.dart';

class ClientRepository {
  final ApiClient _client;

  ClientRepository(this._client);

  Future<List<ClientModel>> getClients() async {
    final response = await _client.get(ApiEndpoints.clients);

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(ClientModel.fromJson)
          .toList();
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ClientModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<ClientModel> createClient(ClientModel client) async {
    final response = await _client.post(
      ApiEndpoints.clients,
      body: client.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ClientModel.fromJson(data);
  }

  Future<ClientModel> updateClient(ClientModel client) async {
    final response = await _client.put(
      ApiEndpoints.clientById(client.id),
      body: client.toJson(),
    );

    final data = response is Map<String, dynamic> && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response as Map<String, dynamic>;
    return ClientModel.fromJson(data);
  }
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider));
});
