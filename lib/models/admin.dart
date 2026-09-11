import '../core/constants/enums.dart';
import '../models/plan.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.company,
    this.phone,
    this.document,
    this.active = true,
    this.whatsappQuotaOverride,
    this.planId,
    this.subscriptionStatus,
    this.currentPeriodEnd,
    this.asaasStatus,
    this.asaasInvoiceUrl,
    this.isSuperadmin = false,
    this.clients = 0,
    this.charges = 0,
    this.received = 0,
    this.whatsappSent = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String? company;
  final String? phone;
  final String? document;
  final bool active;
  final int? whatsappQuotaOverride;
  final String? planId;
  final SubscriptionStatus? subscriptionStatus;
  final DateTime? currentPeriodEnd;
  final String? asaasStatus;
  final String? asaasInvoiceUrl;
  final bool isSuperadmin;
  final int clients;
  final int charges;
  final double received;
  final int whatsappSent;
  final DateTime? createdAt;
}

class AdminData {
  const AdminData({
    required this.users,
    required this.plans,
    this.asaasEnabled = false,
    this.whatsappSentTotal = 0,
    this.whatsappFailedTotal = 0,
  });

  final List<AdminUser> users;
  final List<Plan> plans;
  final bool asaasEnabled;
  final int whatsappSentTotal;
  final int whatsappFailedTotal;

  Plan? planById(String? id) {
    if (id == null) return null;
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  int get activeSubscriptions => users
      .where((u) => u.subscriptionStatus == SubscriptionStatus.ativa)
      .length;

  int get trials => users.where((u) => u.subscriptionStatus == SubscriptionStatus.trial).length;

  double get mrr => users
      .where((u) => u.subscriptionStatus == SubscriptionStatus.ativa)
      .fold<double>(0, (sum, u) => sum + (planById(u.planId)?.price ?? 0));

  double get platformReceived => users.fold<double>(0, (sum, u) => sum + u.received);

  int get totalClients => users.fold<int>(0, (sum, u) => sum + u.clients);

  int get totalCharges => users.fold<int>(0, (sum, u) => sum + u.charges);
}

class WhatsappAdminConfig {
  const WhatsappAdminConfig({
    this.enabled = false,
    this.phoneNumberId,
    this.businessAccountId,
    this.hasToken = false,
    this.hasVerifyToken = false,
    this.maskedToken,
    this.apiVersion = 'v21.0',
    this.templateName = 'cobranca_aviso',
    this.templateLanguage = 'pt_BR',
    this.defaultMonthlyQuota = 0,
    this.costPerMessageCents = 0,
  });

  final bool enabled;
  final String? phoneNumberId;
  final String? businessAccountId;
  final bool hasToken;
  final bool hasVerifyToken;
  final String? maskedToken;
  final String apiVersion;
  final String templateName;
  final String templateLanguage;
  final int defaultMonthlyQuota;
  final int costPerMessageCents;

  factory WhatsappAdminConfig.fromMap(Map<String, dynamic> map) {
    return WhatsappAdminConfig(
      enabled: map['enabled'] == true,
      phoneNumberId: map['phoneNumberId'] as String?,
      businessAccountId: map['businessAccountId'] as String?,
      hasToken: map['hasToken'] == true,
      hasVerifyToken: map['hasVerifyToken'] == true,
      maskedToken: map['maskedToken'] as String?,
      apiVersion: (map['apiVersion'] as String?) ?? 'v21.0',
      templateName: (map['templateName'] as String?) ?? 'cobranca_aviso',
      templateLanguage: (map['templateLanguage'] as String?) ?? 'pt_BR',
      defaultMonthlyQuota: (map['defaultMonthlyQuota'] as num?)?.toInt() ?? 0,
      costPerMessageCents: (map['costPerMessageCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class WhatsappOverviewRow {
  const WhatsappOverviewRow({
    required this.userId,
    required this.name,
    required this.email,
    required this.sent,
    required this.quota,
    this.override,
  });

  final String userId;
  final String name;
  final String email;
  final int sent;
  final int quota;
  final int? override;

  factory WhatsappOverviewRow.fromMap(Map<String, dynamic> map) {
    return WhatsappOverviewRow(
      userId: map['userId'] as String,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      sent: (map['sent'] as num?)?.toInt() ?? 0,
      quota: (map['quota'] as num?)?.toInt() ?? 0,
      override: (map['override'] as num?)?.toInt(),
    );
  }
}

class WhatsappOverview {
  const WhatsappOverview({
    this.users = const [],
    this.sentTotal = 0,
    this.failedTotal = 0,
    this.costCents = 0,
  });

  final List<WhatsappOverviewRow> users;
  final int sentTotal;
  final int failedTotal;
  final int costCents;

  factory WhatsappOverview.fromMap(Map<String, dynamic> map) {
    final rawUsers = map['users'];
    return WhatsappOverview(
      users: rawUsers is List
          ? rawUsers
              .whereType<Map>()
              .map((row) => WhatsappOverviewRow.fromMap(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
      sentTotal: (map['sentTotal'] as num?)?.toInt() ?? 0,
      failedTotal: (map['failedTotal'] as num?)?.toInt() ?? 0,
      costCents: (map['costCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class WhatsappMessage {
  const WhatsappMessage({
    required this.id,
    required this.direction,
    required this.body,
    required this.status,
    required this.createdAt,
    this.toPhone,
    this.fromPhone,
    this.userId,
    this.clientId,
    this.chargeId,
    this.kind,
    this.error,
    this.costCents = 0,
  });

  final String id;
  final String direction;
  final String body;
  final String status;
  final DateTime createdAt;
  final String? toPhone;
  final String? fromPhone;
  final String? userId;
  final String? clientId;
  final String? chargeId;
  final String? kind;
  final String? error;
  final int costCents;

  factory WhatsappMessage.fromMap(Map<String, dynamic> map) {
    return WhatsappMessage(
      id: map['id'] as String,
      direction: (map['direction'] as String?) ?? 'saida',
      body: (map['body'] as String?) ?? '',
      status: (map['status'] as String?) ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      toPhone: map['to_phone'] as String?,
      fromPhone: map['from_phone'] as String?,
      userId: map['user_id'] as String?,
      clientId: map['client_id'] as String?,
      chargeId: map['charge_id'] as String?,
      kind: map['kind'] as String?,
      error: map['error'] as String?,
      costCents: (map['cost_cents'] as num?)?.toInt() ?? 0,
    );
  }
}
