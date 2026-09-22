import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asaas.dart';
import '../models/payment_provider.dart';
import '../services/mobile_api_service.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.watch(mobileApiServiceProvider));
});

/// Provedores de pagamento configurados + qual está ativo.
final paymentProvidersProvider = FutureProvider<PaymentProvidersView>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchProviders();
});

class PaymentsRepository {
  PaymentsRepository(this._api);

  final MobileApiService _api;

  Future<PaymentProvidersView> fetchProviders() async {
    return PaymentProvidersView.fromMap(
      await _api.get('/api/mobile/payments/config'),
    );
  }

  Future<PaymentProvidersView> saveProvider({
    required String provider,
    bool? enabled,
    String? environment,
    String? accessToken,
    String? webhookSecret,
  }) async {
    return PaymentProvidersView.fromMap(
      await _api.post('/api/mobile/payments/config', {
        'provider': provider,
        'enabled': ?enabled,
        'environment': ?environment,
        'accessToken': ?accessToken,
        'webhookSecret': ?webhookSecret,
      }),
    );
  }

  Future<({bool ok, String message})> testProvider({
    required String provider,
    String? environment,
    String? accessToken,
  }) async {
    final result = await _api.post('/api/mobile/payments/config', {
      'provider': provider,
      'action': 'test',
      'environment': ?environment,
      'accessToken': ?accessToken,
    });
    return (
      ok: result['ok'] == true,
      message: (result['message'] as String?) ?? '',
    );
  }

  Future<PaymentProvidersView> activateProvider(String provider) async {
    return PaymentProvidersView.fromMap(
      await _api.post('/api/mobile/payments/config', {
        'provider': provider,
        'action': 'activate',
      }),
    );
  }

  Future<AsaasPaymentFiles> emit(
    String chargeId,
    BillingType billingType,
  ) async {
    return AsaasPaymentFiles.fromMap(
      await _api.post('/api/mobile/payments/emit', {
        'chargeId': chargeId,
        'billingType': billingType.wire,
      }),
    );
  }

  Future<AsaasPaymentFiles> files(String chargeId) async {
    return AsaasPaymentFiles.fromMap(
      await _api.get('/api/mobile/payments/files', {'chargeId': chargeId}),
    );
  }

  /// Cancela a cobrança no gateway e libera a emissão de uma nova.
  Future<void> resetEmission(String chargeId) async {
    await _api.post('/api/mobile/payments/reset', {'chargeId': chargeId});
  }

  Future<String> sync(String chargeId) async {
    final result = await _api.post('/api/mobile/payments/sync', {
      'chargeId': chargeId,
    });
    return (result['status'] as String?) ?? '';
  }

  Future<int> runAuto() async {
    final result = await _api.post('/api/mobile/payments/auto');
    return (result['created'] as num?)?.toInt() ?? 0;
  }
}
