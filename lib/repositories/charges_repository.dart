import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/enums.dart';
import '../core/utils/dates.dart';
import '../models/charge.dart';
import '../models/payment.dart';
import '../models/recurring_charge.dart';
import '../services/supabase_service.dart';

final chargesRepositoryProvider = Provider<ChargesRepository>((ref) {
  return ChargesRepository(ref.watch(supabaseProvider));
});

class ChargesRepository {
  ChargesRepository(this._client);

  final SupabaseClient _client;

  Future<void> save({
    String? id,
    required String userId,
    required String clientId,
    String? serviceId,
    required String description,
    double amount = 0,
    required DateTime dueDate,
  }) async {
    final payload = {
      'client_id': clientId,
      'project_id': serviceId,
      'description': description,
      'amount': amount,
      'due_date': isoDate(dueDate),
    };
    if (id == null) {
      await _client.from(Charge.table).insert({'user_id': userId, ...payload});
    } else {
      await _client.from(Charge.table).update(payload).eq('id', id);
    }
  }

  Future<void> delete(String id) async {
    await _client.from(Charge.table).delete().eq('id', id);
  }

  Future<void> cancel(String id) async {
    await _client.from(Charge.table).update({'status': ChargeStatus.cancelado.wire}).eq('id', id);
  }

  Future<void> registerPayment({
    required String userId,
    required String chargeId,
    required double amount,
    required DateTime paidAt,
    required PaymentMethod method,
    DateTime? receivedAt,
  }) async {
    await _client.from(Payment.table).insert({
      'user_id': userId,
      'charge_id': chargeId,
      'amount': amount,
      'paid_at': isoDate(paidAt),
      'received_at': receivedAt?.toIso8601String(),
      'method': method.wire,
    });
    await _client.from(Charge.table).update({
      'status': ChargeStatus.pago.wire,
      'paid_date': isoDate(paidAt),
    }).eq('id', chargeId);
  }

  Future<void> reopen(String chargeId) async {
    await _client.from(Payment.table).delete().eq('charge_id', chargeId);
    await _client.from(Charge.table).update({
      'status': ChargeStatus.pendente.wire,
      'paid_date': null,
    }).eq('id', chargeId);
  }

  Future<void> insertOccurrences(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from(Charge.table).insert(rows);
  }

  Future<void> saveRecurring({
    String? id,
    required String userId,
    required String clientId,
    String? serviceId,
    required String description,
    double amount = 0,
    Recurrence frequency = Recurrence.mensal,
    int dueDay = 10,
    required DateTime startDate,
    DateTime? endDate,
    bool active = true,
    bool autoAsaas = false,
    String? asaasBillingType,
  }) async {
    final payload = <String, dynamic>{
      'client_id': clientId,
      'project_id': serviceId,
      'description': description,
      'amount': amount,
      'frequency': frequency.wire,
      'due_day': dueDay.clamp(1, 28),
      'start_date': isoDate(startDate),
      'end_date': endDate == null ? null : isoDate(endDate),
      'active': active,
      'auto_asaas': autoAsaas,
      'asaas_billing_type': ?asaasBillingType,
    };
    if (id == null) {
      await _client.from(RecurringCharge.table).insert({
        'user_id': userId,
        'asaas_billing_type': asaasBillingType ?? 'BOLETO',
        ...payload,
      });
    } else {
      await _client.from(RecurringCharge.table).update(payload).eq('id', id);
    }
  }

  Future<void> toggleRecurring(String id, bool active) async {
    await _client.from(RecurringCharge.table).update({'active': active}).eq('id', id);
  }

  Future<void> deleteRecurring(String id) async {
    await _client.from(RecurringCharge.table).delete().eq('id', id);
  }
}
