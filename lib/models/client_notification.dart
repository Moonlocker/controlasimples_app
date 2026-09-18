import '../core/utils/dates.dart';

/// Notificação de WhatsApp enviada/recebida de um cliente do usuário.
class ClientNotification {
  const ClientNotification({
    required this.id,
    required this.createdAt,
    this.direction = 'saida',
    this.status = '',
    this.kind = '',
    this.source = 'manual',
    this.body = '',
    this.error,
    this.costCents = 0,
    this.deliveredAt,
    this.readAt,
    this.chargeId,
    this.chargeDescription = '',
    this.chargeAmount = 0,
    this.chargeDueDate,
  });

  final String id;
  final DateTime createdAt;
  final String direction;
  final String status;
  final String kind;
  final String source;
  final String body;
  final String? error;
  final int costCents;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? chargeId;
  final String chargeDescription;
  final double chargeAmount;
  final String? chargeDueDate;

  bool get inbound => direction == 'entrada';

  String get deliveryLabel {
    if (inbound) return 'Recebida do cliente';
    if (status == 'erro') return 'Falha na entrega';
    if (readAt != null) return 'Lida pelo cliente';
    if (deliveredAt != null) return 'Entregue';
    if (status == 'enviado') return 'Enviada (aguardando confirmação)';
    return status.isEmpty ? '—' : status;
  }

  factory ClientNotification.fromMap(Map<String, dynamic> map) {
    return ClientNotification(
      id: (map['id'] ?? '') as String,
      createdAt:
          tryParseDateTime(map['createdAt']) ??
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      direction: (map['direction'] as String?) ?? 'saida',
      status: (map['status'] as String?) ?? '',
      kind: (map['kind'] as String?) ?? '',
      source: (map['source'] as String?) ?? 'manual',
      body: (map['body'] as String?) ?? '',
      error: map['error'] as String?,
      costCents: (map['costCents'] as num?)?.toInt() ?? 0,
      deliveredAt: tryParseDateTime(map['deliveredAt']),
      readAt: tryParseDateTime(map['readAt']),
      chargeId: map['chargeId'] as String?,
      chargeDescription: (map['chargeDescription'] as String?) ?? '',
      chargeAmount: (map['chargeAmount'] as num?)?.toDouble() ?? 0,
      chargeDueDate: map['chargeDueDate'] as String?,
    );
  }
}
