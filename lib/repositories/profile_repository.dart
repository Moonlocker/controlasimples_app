import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/supabase_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseProvider));
});

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<void> update({
    required String userId,
    String? name,
    String? company,
    String? phone,
    String? document,
  }) async {
    final payload = <String, dynamic>{
      'name': ?name,
      'company': ?company,
      'phone': ?phone,
      'document': ?document,
    };
    if (payload.isEmpty) return;
    await _client.from(Profile.table).update(payload).eq('id', userId);
  }
}
