import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/enums.dart';
import '../core/utils/dates.dart';
import '../models/charge.dart';
import '../models/recurring_charge.dart';
import '../models/service.dart';
import '../services/supabase_service.dart';

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  return ServicesRepository(ref.watch(supabaseProvider));
});

class ServicesRepository {
  ServicesRepository(this._client);

  final SupabaseClient _client;

  Future<String> save({
    String? id,
    required String userId,
    required String clientId,
    required String name,
    String? description,
    String? link,
    double amount = 0,
    ServiceStatus status = ServiceStatus.negociacao,
    ServiceBilling billingType = ServiceBilling.unico,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final payload = {
      'client_id': clientId,
      'name': name,
      'description': description,
      'link': link,
      'amount': amount,
      'status': status.wire,
      'billing_type': billingType.wire,
      'start_date': isoDate(startDate),
      'end_date': endDate == null ? null : isoDate(endDate),
    };
    if (id == null) {
      final result = await _client
          .from(Service.table)
          .insert({'user_id': userId, ...payload})
          .select('id')
          .single();
      return result['id'] as String;
    }
    await _client.from(Service.table).update(payload).eq('id', id);
    return id;
  }

  Future<void> createCharge({
    required String userId,
    required String clientId,
    required String serviceId,
    required String description,
    required double amount,
    required DateTime dueDate,
  }) async {
    await _client.from(Charge.table).insert({
      'user_id': userId,
      'client_id': clientId,
      'project_id': serviceId,
      'description': description,
      'amount': amount,
      'due_date': isoDate(dueDate),
      'status': ChargeStatus.pendente.wire,
    });
  }

  Future<void> deactivateRecurring(String serviceId) async {
    await _client
        .from(RecurringCharge.table)
        .update({'active': false}).eq('project_id', serviceId);
  }

  Future<void> delete(String id, {bool removeCharges = true}) async {
    if (removeCharges) {
      await _client.from(RecurringCharge.table).delete().eq('project_id', id);
      await _client.from(Charge.table).delete().eq('project_id', id);
    }
    await _client.from(Service.table).delete().eq('id', id);
  }

  Future<void> setStatus(String id, ServiceStatus status) async {
    await _client.from(Service.table).update({'status': status.wire}).eq('id', id);
  }
}
