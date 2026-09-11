import '../core/constants/enums.dart';
import '../core/utils/dates.dart';

class QuoteItem {
  const QuoteItem({
    required this.description,
    this.qty = 1,
    this.price = 0,
  });

  final String description;
  final double qty;
  final double price;

  double get total => qty * price;

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      description: (map['description'] as String?) ?? '',
      qty: (map['qty'] as num?)?.toDouble() ?? 1,
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'description': description, 'qty': qty, 'price': price};
  }
}

class Quote {
  const Quote({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.number,
    this.title = 'Orçamento',
    required this.issuedOn,
    this.validUntil,
    this.status = QuoteStatus.rascunho,
    this.layout = 'moderno',
    this.note,
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    required this.createdAt,
  });

  static const String table = 'quotes';

  final String id;
  final String userId;
  final String clientId;
  final String number;
  final String title;
  final DateTime issuedOn;
  final DateTime? validUntil;
  final QuoteStatus status;
  final String layout;
  final String? note;
  final List<QuoteItem> items;
  final double subtotal;
  final double discount;
  final DateTime createdAt;

  double get total => subtotal - discount;

  factory Quote.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    return Quote(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clientId: map['client_id'] as String,
      number: (map['number'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Orçamento',
      issuedOn: parseDate(map['issued_on']),
      validUntil: tryParseDate(map['valid_until']),
      status: QuoteStatus.fromWire(map['status'] as String?),
      layout: (map['layout'] as String?) ?? 'moderno',
      note: map['note'] as String?,
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => QuoteItem.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap(String userId) {
    return {
      'user_id': userId,
      ..._payload(),
    };
  }

  Map<String, dynamic> toUpdateMap() => _payload();

  Map<String, dynamic> _payload() {
    return {
      'client_id': clientId,
      'number': number,
      'title': title,
      'issued_on': isoDate(issuedOn),
      'valid_until': validUntil == null ? null : isoDate(validUntil!),
      'status': status.wire,
      'layout': layout,
      'note': note,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
    };
  }
}
