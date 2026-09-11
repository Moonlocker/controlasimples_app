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
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'company': company,
      'phone': phone,
    };
  }
}
