enum BillingType {
  boleto('BOLETO', 'Boleto'),
  pix('PIX', 'PIX'),
  creditCard('CREDIT_CARD', 'Cartão'),
  undefined('UNDEFINED', 'Deixar o cliente escolher');

  const BillingType(this.wire, this.label);

  final String wire;
  final String label;

  static BillingType fromWire(String? wire) {
    for (final value in BillingType.values) {
      if (value.wire == wire) return value;
    }
    return BillingType.boleto;
  }
}

class AsaasConfig {
  const AsaasConfig({
    this.enabled = false,
    this.environment = 'sandbox',
    this.hasKey = false,
    this.maskedKey,
    this.hasWebhookToken = false,
    this.tutorialVideoUrl,
  });

  final bool enabled;
  final String environment;
  final bool hasKey;
  final String? maskedKey;
  final bool hasWebhookToken;

  /// Vídeo explicativo do Asaas definido pelo superadmin.
  final String? tutorialVideoUrl;

  bool get isProduction => environment == 'production';

  factory AsaasConfig.fromMap(Map<String, dynamic> map) {
    return AsaasConfig(
      enabled: map['enabled'] == true,
      environment: (map['environment'] as String?) ?? 'sandbox',
      hasKey: map['hasKey'] == true,
      maskedKey: map['maskedKey'] as String?,
      hasWebhookToken: map['hasWebhookToken'] == true,
      tutorialVideoUrl: map['tutorialVideoUrl'] as String?,
    );
  }
}

/// Arquivos/links de pagamento retornados pelo gateway configurado.
class AsaasPaymentFiles {
  const AsaasPaymentFiles({
    this.emitted = false,
    this.provider,
    this.providerLabel,
    this.paymentId,
    this.billingType,
    this.asaasStatus,
    this.invoiceUrl,
    this.bankSlipUrl,
    this.pixPayload,
    this.pixQrCode,
  });

  final bool emitted;
  final String? provider;
  final String? providerLabel;
  final String? paymentId;
  final String? billingType;

  /// Status bruto no gateway (campo histórico; hoje vem de `providerStatus`).
  final String? asaasStatus;
  final String? invoiceUrl;
  final String? bankSlipUrl;
  final String? pixPayload;
  final String? pixQrCode;

  factory AsaasPaymentFiles.fromMap(Map<String, dynamic> map) {
    return AsaasPaymentFiles(
      emitted: map['emitted'] == true,
      provider: map['provider'] as String?,
      providerLabel: map['providerLabel'] as String?,
      paymentId: map['paymentId'] as String?,
      billingType: map['billingType'] as String?,
      asaasStatus: (map['providerStatus'] ?? map['asaasStatus']) as String?,
      invoiceUrl: map['invoiceUrl'] as String?,
      bankSlipUrl: map['bankSlipUrl'] as String?,
      pixPayload: map['pixPayload'] as String?,
      pixQrCode: map['pixQrCode'] as String?,
    );
  }
}
