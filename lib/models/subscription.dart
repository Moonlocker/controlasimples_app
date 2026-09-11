import '../core/constants/enums.dart';
import '../core/utils/dates.dart';

class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    this.planId,
    this.status = SubscriptionStatus.trial,
    required this.startedAt,
    this.currentPeriodEnd,
    this.asaasSubscriptionId,
    this.asaasInvoiceUrl,
    this.asaasStatus,
  });

  static const String table = 'subscriptions';

  final String id;
  final String userId;
  final String? planId;
  final SubscriptionStatus status;
  final DateTime startedAt;
  final DateTime? currentPeriodEnd;
  final String? asaasSubscriptionId;
  final String? asaasInvoiceUrl;
  final String? asaasStatus;

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      planId: map['plan_id'] as String?,
      status: SubscriptionStatus.fromWire(map['status'] as String?),
      startedAt: parseDate(map['started_at']),
      currentPeriodEnd: tryParseDateTime(map['current_period_end']),
      asaasSubscriptionId: map['asaas_subscription_id'] as String?,
      asaasInvoiceUrl: map['asaas_invoice_url'] as String?,
      asaasStatus: map['asaas_status'] as String?,
    );
  }
}
