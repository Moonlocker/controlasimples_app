/// Configuração de cobrança da plataforma (campos seguros, sem credenciais).
class BillingInfo {
  const BillingInfo({
    this.enabled = true,
    this.billingCycle = 'MONTHLY',
    this.defaultBillingType = 'CREDIT_CARD',
    this.allowOtherBillingTypes = true,
    this.trialDays = 14,
  });

  final bool enabled;
  final String billingCycle;
  final String defaultBillingType;
  final bool allowOtherBillingTypes;
  final int trialDays;

  factory BillingInfo.fromMap(Map<String, dynamic> map) {
    return BillingInfo(
      enabled: map['enabled'] != false,
      billingCycle: (map['billingCycle'] as String?) ?? 'MONTHLY',
      defaultBillingType:
          (map['defaultBillingType'] as String?) ?? 'CREDIT_CARD',
      allowOtherBillingTypes: map['allowOtherBillingTypes'] != false,
      trialDays: (map['trialDays'] as num?)?.toInt() ?? 14,
    );
  }

  String get cycleLabel => switch (billingCycle) {
    'QUARTERLY' => 'trimestral',
    'SEMIANNUAL' => 'semestral',
    'YEARLY' => 'anual',
    _ => 'mensal',
  };

  String get billingTypeLabel => switch (defaultBillingType) {
    'CREDIT_CARD' => 'cartão de crédito',
    'PIX' => 'Pix',
    'BOLETO' => 'boleto',
    _ => 'escolhida no gateway',
  };
}
