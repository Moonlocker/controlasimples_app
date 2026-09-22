/// Modelos do modelo de assinatura da plataforma (admin).
class PlatformBillingConfig {
  const PlatformBillingConfig({
    this.enabled = true,
    this.provider = 'asaas',
    this.providerEnvironment = 'sandbox',
    this.hasAccessToken = false,
    this.maskedAccessToken,
    this.hasWebhookSecret = false,
    this.billingCycle = 'MONTHLY',
    this.defaultBillingType = 'CREDIT_CARD',
    this.allowOtherBillingTypes = true,
    this.trialDays = 14,
    this.supportsSubscription = true,
    this.supportsCard = true,
  });

  final bool enabled;
  final String provider;
  final String providerEnvironment;
  final bool hasAccessToken;
  final String? maskedAccessToken;
  final bool hasWebhookSecret;
  final String billingCycle;
  final String defaultBillingType;
  final bool allowOtherBillingTypes;
  final int trialDays;
  final bool supportsSubscription;
  final bool supportsCard;

  factory PlatformBillingConfig.fromMap(Map<String, dynamic> map) {
    return PlatformBillingConfig(
      enabled: map['enabled'] != false,
      provider: (map['provider'] as String?) ?? 'asaas',
      providerEnvironment: (map['providerEnvironment'] as String?) ?? 'sandbox',
      hasAccessToken: map['hasAccessToken'] == true,
      maskedAccessToken: map['maskedAccessToken'] as String?,
      hasWebhookSecret: map['hasWebhookSecret'] == true,
      billingCycle: (map['billingCycle'] as String?) ?? 'MONTHLY',
      defaultBillingType:
          (map['defaultBillingType'] as String?) ?? 'CREDIT_CARD',
      allowOtherBillingTypes: map['allowOtherBillingTypes'] != false,
      trialDays: (map['trialDays'] as num?)?.toInt() ?? 14,
      supportsSubscription: map['supportsSubscription'] != false,
      supportsCard: map['supportsCard'] != false,
    );
  }
}

class PlatformSubscription {
  const PlatformSubscription({
    required this.userId,
    this.name = '',
    this.email = '',
    this.planName,
    this.status = 'trial',
    this.provider,
    this.providerSubscriptionId,
    this.billingType,
    this.cycle,
    this.currentPeriodEnd,
    this.invoiceUrl,
  });

  final String userId;
  final String name;
  final String email;
  final String? planName;
  final String status;
  final String? provider;
  final String? providerSubscriptionId;
  final String? billingType;
  final String? cycle;
  final String? currentPeriodEnd;
  final String? invoiceUrl;

  factory PlatformSubscription.fromMap(Map<String, dynamic> map) {
    return PlatformSubscription(
      userId: (map['userId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      planName: map['planName'] as String?,
      status: (map['status'] as String?) ?? 'trial',
      provider: map['provider'] as String?,
      providerSubscriptionId: map['providerSubscriptionId'] as String?,
      billingType: map['billingType'] as String?,
      cycle: map['cycle'] as String?,
      currentPeriodEnd: map['currentPeriodEnd'] as String?,
      invoiceUrl: map['invoiceUrl'] as String?,
    );
  }
}
