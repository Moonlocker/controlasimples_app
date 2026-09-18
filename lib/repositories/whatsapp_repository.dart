import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whatsapp.dart';
import '../services/mobile_api_service.dart';

final whatsappRepositoryProvider = Provider<WhatsappRepository>((ref) {
  return WhatsappRepository(ref.watch(mobileApiServiceProvider));
});

final whatsappUsageProvider = FutureProvider<WhatsappUsage>((ref) async {
  return ref.watch(whatsappRepositoryProvider).usage();
});

class WhatsappRepository {
  WhatsappRepository(this._api);

  final MobileApiService _api;

  Future<WhatsappUsage> usage() async {
    return WhatsappUsage.fromMap(await _api.get('/api/mobile/whatsapp/usage'));
  }

  Future<int> sendCharge(String chargeId) async {
    final result = await _api.post('/api/mobile/whatsapp/send', {
      'chargeId': chargeId,
    });
    return (result['remaining'] as num?)?.toInt() ?? 0;
  }

  Future<String> checkClient(String clientId) async {
    final result = await _api.post('/api/mobile/whatsapp/check', {
      'clientId': clientId,
    });
    return (result['status'] as String?) ?? 'invalid';
  }
}
