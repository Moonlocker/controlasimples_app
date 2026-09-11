import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/enums.dart';
import '../models/asaas.dart';
import '../models/subscription.dart';
import '../services/mobile_api_service.dart';
import '../services/supabase_service.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(
    ref.watch(mobileApiServiceProvider),
    ref.watch(supabaseProvider),
  );
});

class SubscriptionRepository {
  SubscriptionRepository(this._api, this._client);

  final MobileApiService _api;
  final SupabaseClient _client;

  Future<({String? invoiceUrl, String status})> subscribe({
    required String planId,
    required String document,
    BillingType? billingType,
  }) async {
    final result = await _api.post('/api/mobile/subscription/subscribe', {
      'planId': planId,
      'document': document,
      if (billingType != null) 'billingType': billingType.wire,
    });
    return (
      invoiceUrl: result['invoiceUrl'] as String?,
      status: (result['status'] as String?) ?? '',
    );
  }

  Future<({bool ok, bool fallbackToFree})> cancel() async {
    final result = await _api.post('/api/mobile/subscription/cancel');
    return (
      ok: result['ok'] == true,
      fallbackToFree: result['fallbackToFree'] == true,
    );
  }

  Future<void> setPlanDirect({
    required String userId,
    required String? planId,
    required SubscriptionStatus status,
  }) async {
    final payload = {'plan_id': planId, 'status': status.wire};
    final existing = await _client
        .from(Subscription.table)
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null) {
      await _client.from(Subscription.table).insert({
        'user_id': userId,
        'started_at': DateTime.now().toIso8601String(),
        ...payload,
      });
    } else {
      await _client.from(Subscription.table).update(payload).eq('user_id', userId);
    }
  }
}
