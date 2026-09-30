import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_model.dart';
import '../repositories/client_repository.dart';

class ClientNotifier extends Notifier<List<ClientModel>> {
  @override
  List<ClientModel> build() {
    // Default clean empty state on startup (no hardcoded demo clients)
    return const [];
  }

  Future<void> fetchClients() async {
    try {
      final repo = ref.read(clientRepositoryProvider);
      final clients = await repo.getClients();
      state = clients;
    } catch (_) {
      // Keep existing state on network disconnect
    }
  }

  void setClients(List<ClientModel> clients) {
    state = clients;
  }

  Future<void> addClient(ClientModel client) async {
    state = [...state, client];

    try {
      final repo = ref.read(clientRepositoryProvider);
      await repo.createClient(client);
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> updateClient(ClientModel updated) async {
    state = [
      for (final c in state)
        if (c.id == updated.id) updated else c,
    ];

    try {
      final repo = ref.read(clientRepositoryProvider);
      await repo.updateClient(updated);
    } catch (_) {
      // Offline fallback
    }
  }
}

final clientProvider = NotifierProvider<ClientNotifier, List<ClientModel>>(ClientNotifier.new);
