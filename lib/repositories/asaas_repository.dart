import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asaas.dart';
import '../services/mobile_api_service.dart';

final asaasRepositoryProvider = Provider<AsaasRepository>((ref) {
  return AsaasRepository(ref.watch(mobileApiServiceProvider));
});

final asaasConfigProvider = FutureProvider<AsaasConfig>((ref) async {
  return ref.watch(asaasRepositoryProvider).config();
});

class AsaasRepository {
  AsaasRepository(this._api);

  final MobileApiService _api;

  Future<AsaasConfig> config() async {
    return AsaasConfig.fromMap(await _api.get('/api/mobile/asaas/config'));
  }

  Future<void> saveConfig({
    bool? enabled,
    String? environment,
    String? apiKey,
  }) async {
    await _api.post('/api/mobile/asaas/config', {
      'enabled': ?enabled,
      'environment': ?environment,
      'apiKey': ?apiKey,
    });
  }

  Future<({bool ok, String message})> testConnection() async {
    final result = await _api.post('/api/mobile/asaas/config', {'action': 'test'});
    return (ok: result['ok'] == true, message: (result['message'] as String?) ?? '');
  }

  Future<AsaasPaymentFiles> emit(String chargeId, BillingType billingType) async {
    final result = await _api.post('/api/mobile/asaas/emit', {
      'chargeId': chargeId,
      'billingType': billingType.wire,
    });
    return AsaasPaymentFiles.fromMap(result);
  }

  Future<AsaasPaymentFiles> files(String chargeId) async {
    return AsaasPaymentFiles.fromMap(
      await _api.get('/api/mobile/asaas/files', {'chargeId': chargeId}),
    );
  }

  Future<String> sync(String chargeId) async {
    final result = await _api.post('/api/mobile/asaas/sync', {'chargeId': chargeId});
    return (result['status'] as String?) ?? '';
  }

  Future<int> runAuto() async {
    final result = await _api.post('/api/mobile/asaas/auto');
    return (result['created'] as num?)?.toInt() ?? 0;
  }
}
