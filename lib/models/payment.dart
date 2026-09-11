import '../core/constants/enums.dart';
import '../core/utils/dates.dart';

class Payment {
  const Payment({
    required this.id,
    required this.userId,
    required this.chargeId,
    this.amount = 0,
    required this.paidAt,
    this.receivedAt,
    this.method = PaymentMethod.pix,
    required this.createdAt,
  });

  static const String table = 'payments';

  final String id;
  final String userId;
  final String chargeId;
  final double amount;
  final DateTime paidAt;
  final DateTime? receivedAt;
  final PaymentMethod method;
  final DateTime createdAt;

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      chargeId: map['charge_id'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paidAt: parseDate(map['paid_at']),
      receivedAt: tryParseDateTime(map['received_at']),
      method: PaymentMethod.fromWire(map['method'] as String?),
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap(String userId) {
    return {
      'user_id': userId,
      'charge_id': chargeId,
      'amount': amount,
      'paid_at': isoDate(paidAt),
      'received_at': receivedAt?.toIso8601String(),
      'method': method.wire,
    };
  }
}
