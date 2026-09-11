import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';
import '../services/supabase_service.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(ref.watch(supabaseProvider));
});

class ClientsRepository {
  ClientsRepository(this._client);

  final SupabaseClient _client;

  Future<void> save({
    String? id,
    required String userId,
    required String name,
    String? document,
    String? phone,
    String? email,
    String? notes,
    bool active = true,
  }) async {
    final payload = {
      'name': name,
      'document': document,
      'phone': phone,
      'email': email,
      'notes': notes,
      'active': active,
    };
    if (id == null) {
      await _client.from(Client.table).insert({'user_id': userId, ...payload});
    } else {
      await _client.from(Client.table).update(payload).eq('id', id);
    }
  }

  Future<void> delete(String id) async {
    await _client.from(Client.table).delete().eq('id', id);
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from(Client.table).update({'active': active}).eq('id', id);
  }
}
