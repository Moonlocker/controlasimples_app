class PaymentProviderConfig {
  const PaymentProviderConfig({
    required this.id,
    required this.label,
    this.enabled = false,
    this.configured = false,
    this.environment = 'sandbox',
    this.hasAccessToken = false,
    this.maskedAccessToken,
    this.hasWebhookSecret = false,
    this.active = false,
  });

  final String id;
  final String label;
  final bool enabled;
  final bool configured;
  final String environment;
  final bool hasAccessToken;
  final String? maskedAccessToken;
  final bool hasWebhookSecret;
  final bool active;

  factory PaymentProviderConfig.fromMap(Map<String, dynamic> map) {
    return PaymentProviderConfig(
      id: (map['id'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      enabled: map['enabled'] == true,
      configured: map['configured'] == true,
      environment: (map['environment'] as String?) ?? 'sandbox',
      hasAccessToken: map['hasAccessToken'] == true,
      maskedAccessToken: map['maskedAccessToken'] as String?,
      hasWebhookSecret: map['hasWebhookSecret'] == true,
      active: map['active'] == true,
    );
  }
}

class PaymentProvidersView {
  const PaymentProvidersView({
    this.selectedProvider,
    this.activeProvider,
    this.providers = const [],
  });

  final String? selectedProvider;
  final String? activeProvider;
  final List<PaymentProviderConfig> providers;

  factory PaymentProvidersView.fromMap(Map<String, dynamic> map) {
    final raw = map['providers'];
    return PaymentProvidersView(
      selectedProvider: map['selectedProvider'] as String?,
      activeProvider: map['activeProvider'] as String?,
      providers: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (row) => PaymentProviderConfig.fromMap(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
    );
  }
}
