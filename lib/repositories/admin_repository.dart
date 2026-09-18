import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/enums.dart';
import '../core/utils/dates.dart';
import '../models/admin.dart';
import '../models/asaas.dart';
import '../models/plan.dart';
import '../models/subscription.dart';
import '../models/whatsapp_template.dart';
import '../services/mobile_api_service.dart';
import '../services/supabase_service.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(
    ref.watch(supabaseProvider),
    ref.watch(mobileApiServiceProvider),
  );
});

class AdminRepository {
  AdminRepository(this._client, this._api);

  final SupabaseClient _client;
  final MobileApiService _api;

  List<Map<String, dynamic>> _rows(Object? data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return const [];
  }

  Future<AdminData> fetchAdminData() async {
    final monthStart = DateTime(today().year, today().month).toIso8601String();

    final profilesFuture = _client
        .from('profiles')
        .select(
          'id, name, email, company, phone, document, active, whatsapp_quota_override, created_at',
        )
        .order('created_at');
    final subsFuture = _client
        .from('subscriptions')
        .select(
          'user_id, plan_id, status, current_period_end, asaas_status, asaas_invoice_url',
        );
    final rolesFuture = _client.from('user_roles').select('user_id, role');
    final plansFuture = _client.from(Plan.table).select().order('sort_order');
    final clientsFuture = _client.from('clients').select('user_id');
    final chargesFuture = _client
        .from('charges')
        .select('user_id, amount, status');
    final paymentsFuture = _client.from('payments').select('user_id, amount');
    final messagesFuture = _client
        .from('whatsapp_messages')
        .select('user_id, status')
        .gte('created_at', monthStart);

    final profiles = await profilesFuture;
    final subs = await subsFuture;
    final roles = await rolesFuture;
    final plans = await plansFuture;
    final clients = await clientsFuture;
    final charges = await chargesFuture;
    final payments = await paymentsFuture;
    final messages = await messagesFuture;

    final subsByUser = <String, Map<String, dynamic>>{};
    for (final row in _rows(subs)) {
      subsByUser[row['user_id'] as String] = row;
    }
    final superadmins = _rows(roles)
        .where((row) => row['role'] == 'superadmin')
        .map((row) => row['user_id'] as String)
        .toSet();

    final clientsByUser = <String, int>{};
    for (final row in _rows(clients)) {
      final id = row['user_id'] as String;
      clientsByUser.update(id, (value) => value + 1, ifAbsent: () => 1);
    }
    final chargesByUser = <String, int>{};
    final receivedByUser = <String, double>{};
    for (final row in _rows(charges)) {
      final id = row['user_id'] as String;
      chargesByUser.update(id, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final row in _rows(payments)) {
      final id = row['user_id'] as String;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      receivedByUser.update(
        id,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }
    final sentByUser = <String, int>{};
    var sentTotal = 0;
    var failedTotal = 0;
    for (final row in _rows(messages)) {
      final id = row['user_id'] as String?;
      final status = row['status'] as String?;
      if (status == 'enviado') {
        sentTotal += 1;
        if (id != null) {
          sentByUser.update(id, (value) => value + 1, ifAbsent: () => 1);
        }
      } else {
        failedTotal += 1;
      }
    }

    final users = _rows(profiles).map((row) {
      final id = row['id'] as String;
      final sub = subsByUser[id];
      return AdminUser(
        id: id,
        name: (row['name'] as String?) ?? '',
        email: (row['email'] as String?) ?? '',
        company: row['company'] as String?,
        phone: row['phone'] as String?,
        document: row['document'] as String?,
        active: row['active'] != false,
        whatsappQuotaOverride: (row['whatsapp_quota_override'] as num?)
            ?.toInt(),
        planId: sub?['plan_id'] as String?,
        subscriptionStatus: sub == null
            ? null
            : SubscriptionStatus.fromWire(sub['status'] as String?),
        currentPeriodEnd: tryParseDateTime(sub?['current_period_end']),
        asaasStatus: sub?['asaas_status'] as String?,
        asaasInvoiceUrl: sub?['asaas_invoice_url'] as String?,
        isSuperadmin: superadmins.contains(id),
        clients: clientsByUser[id] ?? 0,
        charges: chargesByUser[id] ?? 0,
        received: receivedByUser[id] ?? 0,
        whatsappSent: sentByUser[id] ?? 0,
        createdAt: tryParseDateTime(row['created_at']),
      );
    }).toList();

    return AdminData(
      users: users,
      plans: _rows(plans).map(Plan.fromMap).toList(),
      whatsappSentTotal: sentTotal,
      whatsappFailedTotal: failedTotal,
    );
  }

  Future<void> updateProfile({
    required String userId,
    String? name,
    String? company,
    String? phone,
    String? document,
    bool? active,
    Object? whatsappQuotaOverride = _unset,
  }) async {
    final payload = <String, dynamic>{
      'name': ?name,
      'company': ?company,
      'phone': ?phone,
      'document': ?document,
      'active': ?active,
      if (!identical(whatsappQuotaOverride, _unset))
        'whatsapp_quota_override': whatsappQuotaOverride,
    };
    if (payload.isEmpty) return;
    await _client.from('profiles').update(payload).eq('id', userId);
  }

  Future<void> updateSubscription({
    required String userId,
    String? planId,
    SubscriptionStatus? status,
    DateTime? currentPeriodEnd,
    bool clearPeriodEnd = false,
  }) async {
    final payload = <String, dynamic>{
      'plan_id': ?planId,
      'status': ?status?.wire,
      if (clearPeriodEnd) 'current_period_end': null,
      if (!clearPeriodEnd && currentPeriodEnd != null)
        'current_period_end': currentPeriodEnd.toIso8601String(),
    };
    if (payload.isEmpty) return;
    final existing = await _client
        .from(Subscription.table)
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null) {
      await _client.from(Subscription.table).insert({
        'user_id': userId,
        'status': SubscriptionStatus.trial.wire,
        'started_at': DateTime.now().toIso8601String(),
        ...payload,
      });
    } else {
      await _client
          .from(Subscription.table)
          .update(payload)
          .eq('user_id', userId);
    }
  }

  Future<void> setSuperadmin(String userId, bool value) async {
    if (value) {
      await _client.from('user_roles').insert({
        'user_id': userId,
        'role': 'superadmin',
      });
    } else {
      await _client
          .from('user_roles')
          .delete()
          .eq('user_id', userId)
          .eq('role', 'superadmin');
    }
  }

  Future<void> savePlan({
    String? id,
    required String name,
    required String slug,
    String description = '',
    required int priceCents,
    int sortOrder = 0,
    int? maxClients,
    int? maxChargesMonth,
    int? maxWhatsappMonth,
    bool allowAsaasIntegration = true,
    bool allowWhatsappNotifications = true,
    List<String> features = const [],
    bool highlighted = false,
    bool active = true,
  }) async {
    final payload = {
      'name': name,
      'slug': slug,
      'description': description,
      'price_cents': priceCents,
      'sort_order': sortOrder,
      'max_clients': maxClients,
      'max_charges_month': maxChargesMonth,
      'max_whatsapp_month': maxWhatsappMonth,
      'allow_asaas_integration': allowAsaasIntegration,
      'allow_whatsapp_notifications': allowWhatsappNotifications,
      'features': features,
      'highlighted': highlighted,
      'active': active,
    };
    if (id == null) {
      await _client.from(Plan.table).insert(payload);
    } else {
      await _client.from(Plan.table).update(payload).eq('id', id);
    }
  }

  Future<void> setPlanActive(String id, bool active) async {
    await _client.from(Plan.table).update({'active': active}).eq('id', id);
  }

  Future<void> deletePlan(String id) async {
    await _client.from(Plan.table).delete().eq('id', id);
  }

  Future<List<WhatsappMessage>> fetchMessages({
    String? userId,
    int limit = 100,
  }) async {
    final data = userId == null
        ? await _client
              .from('whatsapp_messages')
              .select()
              .order('created_at', ascending: false)
              .limit(limit)
        : await _client
              .from('whatsapp_messages')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(limit);
    return _rows(data).map(WhatsappMessage.fromMap).toList();
  }

  Future<AsaasConfig> asaasAdminConfig() async {
    return AsaasConfig.fromMap(
      await _api.get('/api/mobile/admin/asaas/config'),
    );
  }

  Future<void> saveAsaasAdminConfig({
    bool? enabled,
    String? environment,
    String? apiKey,
    String? webhookToken,
  }) async {
    await _api.post('/api/mobile/admin/asaas/config', {
      'enabled': ?enabled,
      'environment': ?environment,
      'apiKey': ?apiKey,
      'webhookToken': ?webhookToken,
    });
  }

  Future<({bool ok, String message})> testAsaasAdmin() async {
    final result = await _api.post('/api/mobile/admin/asaas/config', {
      'action': 'test',
    });
    return (
      ok: result['ok'] == true,
      message: (result['message'] as String?) ?? '',
    );
  }

  Future<WhatsappAdminConfig> whatsappAdminConfig() async {
    return WhatsappAdminConfig.fromMap(
      await _api.get('/api/mobile/admin/whatsapp/config'),
    );
  }

  Future<void> saveWhatsappAdminConfig({
    bool? enabled,
    String? phoneNumberId,
    String? businessAccountId,
    String? accessToken,
    String? verifyToken,
    String? appSecret,
    String? apiVersion,
    String? templateName,
    String? templateLanguage,
    int? defaultMonthlyQuota,
    int? costPerMessageCents,
    bool? autoNotificationsEnabled,
    int? maxReminderDaysBefore,
    int? maxOverdueDays,
  }) async {
    await _api.post('/api/mobile/admin/whatsapp/config', {
      'enabled': ?enabled,
      'phoneNumberId': ?phoneNumberId,
      'businessAccountId': ?businessAccountId,
      'accessToken': ?accessToken,
      'verifyToken': ?verifyToken,
      'appSecret': ?appSecret,
      'apiVersion': ?apiVersion,
      'templateName': ?templateName,
      'templateLanguage': ?templateLanguage,
      'defaultMonthlyQuota': ?defaultMonthlyQuota,
      'costPerMessageCents': ?costPerMessageCents,
      'autoNotificationsEnabled': ?autoNotificationsEnabled,
      'maxReminderDaysBefore': ?maxReminderDaysBefore,
      'maxOverdueDays': ?maxOverdueDays,
    });
  }

  /// Exclui definitivamente um usuário e todos os registros dele (superadmin).
  Future<void> deleteUser(String userId) async {
    await _api.post('/api/mobile/admin/users/delete', {'userId': userId});
  }

  Future<({bool ok, String message})> testWhatsappAdmin() async {
    final result = await _api.post('/api/mobile/admin/whatsapp/config', {
      'action': 'test',
    });
    return (
      ok: result['ok'] == true,
      message: (result['message'] as String?) ?? '',
    );
  }

  Future<WhatsappOverview> whatsappOverview() async {
    return WhatsappOverview.fromMap(
      await _api.get('/api/mobile/admin/whatsapp/overview'),
    );
  }

  Future<void> setWhatsappQuota(String userId, int? quota) async {
    await _api.post('/api/mobile/admin/whatsapp/quota', {
      'userId': userId,
      'quota': quota,
    });
  }

  Future<void> sendWhatsappAdmin({
    required String to,
    required String userId,
    String? clientId,
    required String mode,
    required String body,
    List<String> params = const [],
    String? buttonUrl,
  }) async {
    await _api.post('/api/mobile/admin/whatsapp/send', {
      'to': to,
      'userId': userId,
      'clientId': ?clientId,
      'mode': mode,
      'body': body,
      'params': params,
      'buttonUrl': ?buttonUrl,
    });
  }

  Future<List<WhatsappTemplate>> fetchWhatsappTemplates() async {
    final result = await _api.get('/api/mobile/admin/whatsapp/templates');
    final raw = result['templates'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => WhatsappTemplate.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> saveWhatsappTemplate({
    String? id,
    required String name,
    required String label,
    required String language,
    required String category,
    required String occasion,
    required String body,
    List<String> variables = const [],
    bool buttonUrlEnabled = false,
    bool active = true,
    int sortOrder = 0,
  }) async {
    await _api.post('/api/mobile/admin/whatsapp/templates', {
      'id': ?id,
      'name': name,
      'label': label,
      'language': language,
      'category': category,
      'occasion': occasion,
      'body': body,
      'variables': variables,
      'buttonUrlEnabled': buttonUrlEnabled,
      'active': active,
      'sortOrder': sortOrder,
    });
  }

  Future<void> deleteWhatsappTemplate(String id) async {
    await _api.post('/api/mobile/admin/whatsapp/templates', {
      'action': 'delete',
      'id': id,
    });
  }
}

const Object _unset = Object();
