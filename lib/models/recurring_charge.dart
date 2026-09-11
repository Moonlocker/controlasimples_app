import '../core/constants/enums.dart';
import '../core/utils/dates.dart';

class RecurringCharge {
  const RecurringCharge({
    required this.id,
    required this.userId,
    required this.clientId,
    this.serviceId,
    required this.description,
    this.amount = 0,
    this.frequency = Recurrence.mensal,
    this.dueDay = 10,
    required this.startDate,
    this.endDate,
    this.active = true,
    this.autoAsaas = false,
    this.asaasBillingType = 'BOLETO',
    required this.createdAt,
  });

  static const String table = 'recurring_charges';

  final String id;
  final String userId;
  final String clientId;
  final String? serviceId;
  final String description;
  final double amount;
  final Recurrence frequency;
  final int dueDay;
  final DateTime startDate;
  final DateTime? endDate;
  final bool active;
  final bool autoAsaas;
  final String asaasBillingType;
  final DateTime createdAt;

  factory RecurringCharge.fromMap(Map<String, dynamic> map) {
    return RecurringCharge(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clientId: map['client_id'] as String,
      serviceId: map['project_id'] as String?,
      description: (map['description'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      frequency: Recurrence.fromWire(map['frequency'] as String?),
      dueDay: (map['due_day'] as num?)?.toInt() ?? 10,
      startDate: parseDate(map['start_date']),
      endDate: tryParseDate(map['end_date']),
      active: map['active'] == true,
      autoAsaas: map['auto_asaas'] == true,
      asaasBillingType: (map['asaas_billing_type'] as String?) ?? 'BOLETO',
      createdAt: parseDate(map['created_at']),
    );
  }
}
