import '../core/utils/dates.dart';
import 'notification_preferences.dart';

class ChargeNotificationScheduleItem {
  const ChargeNotificationScheduleItem({
    required this.occasion,
    required this.label,
    this.date,
    required this.enabled,
  });

  final String occasion;
  final String label;
  final DateTime? date;
  final bool enabled;

  factory ChargeNotificationScheduleItem.fromMap(Map<String, dynamic> map) {
    return ChargeNotificationScheduleItem(
      occasion: (map['occasion'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      date: tryParseDate(map['date']),
      enabled: map['enabled'] == true,
    );
  }
}

class ChargeNotificationHistoryItem {
  const ChargeNotificationHistoryItem({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.source,
    required this.status,
    required this.body,
    this.error,
    this.deliveredAt,
    this.readAt,
  });

  final String id;
  final DateTime? createdAt;
  final String kind;
  final String source;
  final String status;
  final String body;
  final String? error;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  factory ChargeNotificationHistoryItem.fromMap(Map<String, dynamic> map) {
    return ChargeNotificationHistoryItem(
      id: (map['id'] as String?) ?? '',
      createdAt: tryParseDateTime(map['createdAt']),
      kind: (map['kind'] as String?) ?? '',
      source: (map['source'] as String?) ?? '',
      status: (map['status'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      error: map['error'] as String?,
      deliveredAt: tryParseDateTime(map['deliveredAt']),
      readAt: tryParseDateTime(map['readAt']),
    );
  }
}

class ChargeNotificationCharge {
  const ChargeNotificationCharge({
    required this.id,
    required this.clientId,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.notificationsEnabled,
  });

  final String id;
  final String clientId;
  final String description;
  final double amount;
  final DateTime dueDate;
  final String status;

  /// null = herda do cliente.
  final bool? notificationsEnabled;

  factory ChargeNotificationCharge.fromMap(Map<String, dynamic> map) {
    return ChargeNotificationCharge(
      id: (map['id'] as String?) ?? '',
      clientId: (map['clientId'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      dueDate: parseDate(map['dueDate']),
      status: (map['status'] as String?) ?? '',
      notificationsEnabled: map['notificationsEnabled'] as bool?,
    );
  }
}

class ChargeNotificationClient {
  const ChargeNotificationClient({
    required this.id,
    required this.name,
    this.phone,
    required this.notificationsEnabled,
  });

  final String id;
  final String name;
  final String? phone;
  final bool notificationsEnabled;

  factory ChargeNotificationClient.fromMap(Map<String, dynamic> map) {
    return ChargeNotificationClient(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      phone: map['phone'] as String?,
      notificationsEnabled: map['notificationsEnabled'] != false,
    );
  }
}

class ChargeNotificationContext {
  const ChargeNotificationContext({
    required this.integrationEnabled,
    required this.autoEnabled,
    required this.preferences,
    required this.limits,
    this.charge,
    this.client,
    required this.schedule,
    required this.history,
  });

  final bool integrationEnabled;
  final bool autoEnabled;
  final NotificationPreferences preferences;
  final NotificationLimits limits;
  final ChargeNotificationCharge? charge;
  final ChargeNotificationClient? client;
  final List<ChargeNotificationScheduleItem> schedule;
  final List<ChargeNotificationHistoryItem> history;

  factory ChargeNotificationContext.fromMap(Map<String, dynamic> map) {
    final prefs = map['preferences'];
    final limits = map['limits'];
    final charge = map['charge'];
    final client = map['client'];
    final schedule = map['schedule'];
    final history = map['history'];
    return ChargeNotificationContext(
      integrationEnabled: map['integrationEnabled'] == true,
      autoEnabled: map['autoEnabled'] != false,
      preferences: prefs is Map
          ? NotificationPreferences.fromMap(Map<String, dynamic>.from(prefs))
          : const NotificationPreferences(),
      limits: limits is Map
          ? NotificationLimits.fromMap(Map<String, dynamic>.from(limits))
          : const NotificationLimits(),
      charge: charge is Map
          ? ChargeNotificationCharge.fromMap(Map<String, dynamic>.from(charge))
          : null,
      client: client is Map
          ? ChargeNotificationClient.fromMap(Map<String, dynamic>.from(client))
          : null,
      schedule: schedule is List
          ? schedule
                .whereType<Map>()
                .map(
                  (row) => ChargeNotificationScheduleItem.fromMap(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
      history: history is List
          ? history
                .whereType<Map>()
                .map(
                  (row) => ChargeNotificationHistoryItem.fromMap(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
    );
  }
}
