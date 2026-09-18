class Plan {
  const Plan({
    required this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.priceCents = 0,
    this.maxClients,
    this.maxChargesMonth,
    this.maxWhatsappMonth,
    this.allowAsaasIntegration = true,
    this.allowWhatsappNotifications = true,
    this.features = const [],
    this.highlighted = false,
    this.sortOrder = 0,
    this.active = true,
  });

  static const String table = 'plans';

  final String id;
  final String slug;
  final String name;
  final String description;
  final int priceCents;
  final int? maxClients;
  final int? maxChargesMonth;
  final int? maxWhatsappMonth;
  final bool allowAsaasIntegration;
  final bool allowWhatsappNotifications;
  final List<String> features;
  final bool highlighted;
  final int sortOrder;
  final bool active;

  double get price => priceCents / 100;

  factory Plan.fromMap(Map<String, dynamic> map) {
    final rawFeatures = map['features'];
    return Plan(
      id: map['id'] as String,
      slug: (map['slug'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      priceCents: (map['price_cents'] as num?)?.toInt() ?? 0,
      maxClients: (map['max_clients'] as num?)?.toInt(),
      maxChargesMonth: (map['max_charges_month'] as num?)?.toInt(),
      maxWhatsappMonth: (map['max_whatsapp_month'] as num?)?.toInt(),
      allowAsaasIntegration: map['allow_asaas_integration'] != false,
      allowWhatsappNotifications: map['allow_whatsapp_notifications'] != false,
      features: rawFeatures is List
          ? rawFeatures.map((e) => e.toString()).toList()
          : const [],
      highlighted: map['highlighted'] == true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      active: map['active'] != false,
    );
  }
}
