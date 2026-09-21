import '../core/utils/dates.dart';

class Client {
  const Client({
    required this.id,
    required this.userId,
    required this.name,
    this.document,
    this.phone,
    this.email,
    this.notes,
    this.active = true,
    this.asaasCustomerId,
    this.whatsappValid,
    this.whatsappCheckedAt,
    this.notificationsEnabled = true,
    required this.createdAt,
  });

  static const String table = 'clients';

  final String id;
  final String userId;
  final String name;
  final String? document;
  final String? phone;
  final String? email;
  final String? notes;
  final bool active;
  final String? asaasCustomerId;
  final bool? whatsappValid;
  final DateTime? whatsappCheckedAt;
  final bool notificationsEnabled;
  final DateTime createdAt;

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: (map['name'] as String?) ?? '',
      document: map['document'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      notes: map['notes'] as String?,
      active: map['active'] != false,
      asaasCustomerId: map['asaas_customer_id'] as String?,
      whatsappValid: map['whatsapp_valid'] as bool?,
      whatsappCheckedAt: tryParseDateTime(map['whatsapp_checked_at']),
      notificationsEnabled: map['notifications_enabled'] != false,
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap(String userId) {
    return {
      'user_id': userId,
      'name': name,
      'document': document,
      'phone': phone,
      'email': email,
      'notes': notes,
      'active': active,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'document': document,
      'phone': phone,
      'email': email,
      'notes': notes,
      'active': active,
    };
  }
}
