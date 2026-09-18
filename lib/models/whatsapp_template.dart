class WhatsappTemplate {
  const WhatsappTemplate({
    required this.id,
    required this.name,
    required this.label,
    this.language = 'pt_BR',
    this.category = 'UTILITY',
    this.occasion = 'cobranca',
    this.body = '',
    this.variables = const [],
    this.buttonUrlEnabled = false,
    this.active = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  static const String table = 'whatsapp_templates';

  final String id;
  final String name;
  final String label;
  final String language;
  final String category;
  final String occasion;
  final String body;
  final List<String> variables;
  final bool buttonUrlEnabled;
  final bool active;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Lê tanto o payload da API mobile (camelCase) quanto a linha do Supabase
  /// (snake_case), mantendo o app compatível com os dois canais.
  factory WhatsappTemplate.fromMap(Map<String, dynamic> map) {
    final rawVariables = map['variables'];
    return WhatsappTemplate(
      id: (map['id'] ?? '') as String,
      name: (map['name'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      language: (map['language'] as String?) ?? 'pt_BR',
      category: (map['category'] as String?) ?? 'UTILITY',
      occasion: (map['occasion'] as String?) ?? 'cobranca',
      body: (map['body'] as String?) ?? '',
      variables: rawVariables is List
          ? rawVariables.map((e) => e.toString()).toList()
          : const [],
      buttonUrlEnabled:
          (map['buttonUrlEnabled'] ?? map['button_url_enabled']) == true,
      active: (map['active'] ?? true) != false,
      sortOrder:
          ((map['sortOrder'] ?? map['sort_order']) as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(
        (map['createdAt'] ?? map['created_at'])?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        (map['updatedAt'] ?? map['updated_at'])?.toString() ?? '',
      ),
    );
  }
}
