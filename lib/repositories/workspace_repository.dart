import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/enums.dart';
import '../models/charge.dart';
import '../models/client.dart';
import '../models/payment.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/recurring_charge.dart';
import '../models/service.dart';
import '../models/subscription.dart';
import '../models/workspace.dart';
import '../services/supabase_service.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepository(ref.watch(supabaseProvider));
});

class WorkspaceRepository {
  WorkspaceRepository(this._client);

  final SupabaseClient _client;

  List<Map<String, dynamic>> _rows(Object? data) {
    if (data is List) {
      return data.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    }
    return const [];
  }

  Future<Workspace> fetchWorkspace(String userId) async {
    final clientsFuture =
        _client.from(Client.table).select().eq('user_id', userId).order('name');
    final servicesFuture =
        _client.from(Service.table).select().eq('user_id', userId).order('created_at');
    final chargesFuture =
        _client.from(Charge.table).select().eq('user_id', userId).order('due_date');
    final recurringFuture =
        _client.from(RecurringCharge.table).select().eq('user_id', userId).order('created_at');
    final paymentsFuture = _client
        .from(Payment.table)
        .select()
        .eq('user_id', userId)
        .order('paid_at', ascending: false);
    final profileFuture =
        _client.from(Profile.table).select().eq('id', userId).maybeSingle();
    final subscriptionFuture =
        _client.from(Subscription.table).select().eq('user_id', userId).maybeSingle();
    final rolesFuture = _client.from('user_roles').select('role').eq('user_id', userId);
    final plansFuture =
        _client.from(Plan.table).select().eq('active', true).order('sort_order');

    final clients = await clientsFuture;
    final services = await servicesFuture;
    final charges = await chargesFuture;
    final recurring = await recurringFuture;
    final payments = await paymentsFuture;
    final profile = await profileFuture;
    final subscription = await subscriptionFuture;
    final roles = await rolesFuture;
    final plans = await plansFuture;

    return Workspace(
      clients: _rows(clients).map(Client.fromMap).toList(),
      services: _rows(services).map(Service.fromMap).toList(),
      charges: _rows(charges).map(Charge.fromMap).toList(),
      recurring: _rows(recurring).map(RecurringCharge.fromMap).toList(),
      payments: _rows(payments).map(Payment.fromMap).toList(),
      profile: profile == null ? null : Profile.fromMap(profile),
      subscription: subscription == null ? null : Subscription.fromMap(subscription),
      roles: _rows(roles)
          .map((row) => AppRole.fromWire(row['role'] as String?))
          .whereType<AppRole>()
          .toList(),
      plans: _rows(plans).map(Plan.fromMap).toList(),
    );
  }
}
