import '../core/constants/enums.dart';
import '../core/utils/dates.dart';

/// Maps the `projects` table. In the product UI a "project" is called "serviço".
class Service {
  const Service({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.name,
    this.description,
    this.link,
    this.amount = 0,
    this.status = ServiceStatus.negociacao,
    this.billingType = ServiceBilling.unico,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  static const String table = 'projects';

  final String id;
  final String userId;
  final String clientId;
  final String name;
  final String? description;
  final String? link;
  final double amount;
  final ServiceStatus status;
  final ServiceBilling billingType;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  factory Service.fromMap(Map<String, dynamic> map) {
    final createdAt = parseDate(map['created_at']);
    return Service(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clientId: map['client_id'] as String,
      name: (map['name'] as String?) ?? '',
      description: map['description'] as String?,
      link: map['link'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: ServiceStatus.fromWire(map['status'] as String?),
      billingType: ServiceBilling.fromWire(map['billing_type'] as String?),
      startDate: parseDate(map['start_date'], fallback: createdAt),
      endDate: tryParseDate(map['end_date']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toInsertMap(String userId) {
    return {
      'user_id': userId,
      'client_id': clientId,
      'name': name,
      'description': description,
      'link': link,
      'amount': amount,
      'status': status.wire,
      'billing_type': billingType.wire,
      'start_date': isoDate(startDate),
      'end_date': endDate == null ? null : isoDate(endDate!),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'client_id': clientId,
      'name': name,
      'description': description,
      'link': link,
      'amount': amount,
      'status': status.wire,
      'billing_type': billingType.wire,
      'start_date': isoDate(startDate),
      'end_date': endDate == null ? null : isoDate(endDate!),
    };
  }
}
