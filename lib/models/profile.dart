import '../core/utils/dates.dart';

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.email,
    this.company,
    this.phone,
    this.document,
    this.active = true,
    this.onboardingCompleted = false,
    this.setupCompleted = true,
    this.whatsappQuotaOverride,
    required this.createdAt,
  });

  static const String table = 'profiles';

  final String id;
  final String name;
  final String email;
  final String? company;
  final String? phone;
  final String? document;
  final bool active;
  final bool onboardingCompleted;

  /// Indica que o assistente de primeiros passos foi concluído.
  ///
  /// Se a coluna ainda não existir no banco (migração não aplicada), assume
  /// `true` para não prender todos os usuários no assistente.
  final bool setupCompleted;
  final int? whatsappQuotaOverride;
  final DateTime createdAt;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      company: map['company'] as String?,
      phone: map['phone'] as String?,
      document: map['document'] as String?,
      active: map['active'] != false,
      onboardingCompleted: map['onboarding_completed'] == true,
      setupCompleted: map.containsKey('setup_completed')
          ? map['setup_completed'] == true
          : true,
      whatsappQuotaOverride: (map['whatsapp_quota_override'] as num?)?.toInt(),
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'company': company, 'phone': phone};
  }
}
