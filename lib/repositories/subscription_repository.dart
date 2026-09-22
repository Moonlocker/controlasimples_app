import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asaas.dart';
import '../models/billing_info.dart';
import '../services/mobile_api_service.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(mobileApiServiceProvider));
});

/// Configuração de cobrança da plataforma (ciclo/forma padrão).
final billingInfoProvider = FutureProvider<BillingInfo>((ref) {
  return ref.watch(subscriptionRepositoryProvider).fetchBillingInfo();
});

class SubscriptionRepository {
  SubscriptionRepository(this._api);

  final MobileApiService _api;

  Future<
    ({
      String? invoiceUrl,
      String? bankSlipUrl,
      String? pixPayload,
      String? pixQrCode,
      String status,
    })
  >
  subscribe({
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
      bankSlipUrl: result['bankSlipUrl'] as String?,
      pixPayload: result['pixPayload'] as String?,
      pixQrCode: result['pixQrCode'] as String?,
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

  Future<BillingInfo> fetchBillingInfo() async {
    return BillingInfo.fromMap(
      await _api.get('/api/mobile/subscription/billing'),
    );
  }
}
