class NotificationPreferences {
  const NotificationPreferences({
    this.whatsappEnabled = false,
    this.reminderBeforeEnabled = false,
    this.reminderBeforeDays = 3,
    this.onDueEnabled = false,
    this.overdueEnabled = false,
    this.overdueDays = 1,
  });

  final bool whatsappEnabled;
  final bool reminderBeforeEnabled;
  final int reminderBeforeDays;
  final bool onDueEnabled;
  final bool overdueEnabled;
  final int overdueDays;

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      whatsappEnabled: map['whatsappEnabled'] == true,
      reminderBeforeEnabled: map['reminderBeforeEnabled'] == true,
      reminderBeforeDays: (map['reminderBeforeDays'] as num?)?.toInt() ?? 3,
      onDueEnabled: map['onDueEnabled'] == true,
      overdueEnabled: map['overdueEnabled'] == true,
      overdueDays: (map['overdueDays'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'whatsappEnabled': whatsappEnabled,
      'reminderBeforeEnabled': reminderBeforeEnabled,
      'reminderBeforeDays': reminderBeforeDays,
      'onDueEnabled': onDueEnabled,
      'overdueEnabled': overdueEnabled,
      'overdueDays': overdueDays,
    };
  }

  NotificationPreferences copyWith({
    bool? whatsappEnabled,
    bool? reminderBeforeEnabled,
    int? reminderBeforeDays,
    bool? onDueEnabled,
    bool? overdueEnabled,
    int? overdueDays,
  }) {
    return NotificationPreferences(
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      reminderBeforeEnabled:
          reminderBeforeEnabled ?? this.reminderBeforeEnabled,
      reminderBeforeDays: reminderBeforeDays ?? this.reminderBeforeDays,
      onDueEnabled: onDueEnabled ?? this.onDueEnabled,
      overdueEnabled: overdueEnabled ?? this.overdueEnabled,
      overdueDays: overdueDays ?? this.overdueDays,
    );
  }
}

class NotificationLimits {
  const NotificationLimits({
    this.autoEnabled = true,
    this.integrationEnabled = false,
    this.maxReminderDaysBefore = 7,
    this.maxOverdueDays = 15,
  });

  final bool autoEnabled;
  final bool integrationEnabled;
  final int maxReminderDaysBefore;
  final int maxOverdueDays;

  factory NotificationLimits.fromMap(Map<String, dynamic> map) {
    return NotificationLimits(
      autoEnabled: map['autoEnabled'] != false,
      integrationEnabled: map['integrationEnabled'] == true,
      maxReminderDaysBefore:
          (map['maxReminderDaysBefore'] as num?)?.toInt() ?? 7,
      maxOverdueDays: (map['maxOverdueDays'] as num?)?.toInt() ?? 15,
    );
  }
}

class NotificationSettings {
  const NotificationSettings({required this.preferences, required this.limits});

  final NotificationPreferences preferences;
  final NotificationLimits limits;
}

/// Prévia de um modelo de notificação configurado pelo superadmin.
class NotificationTemplatePreview {
  const NotificationTemplatePreview({
    required this.occasion,
    required this.label,
    required this.description,
    this.templateName,
    required this.body,
    required this.preview,
    required this.buttonUrlEnabled,
    required this.usingPlatformDefault,
  });

  final String occasion;
  final String label;
  final String description;
  final String? templateName;
  final String body;
  final String preview;
  final bool buttonUrlEnabled;
  final bool usingPlatformDefault;

  factory NotificationTemplatePreview.fromMap(Map<String, dynamic> map) {
    return NotificationTemplatePreview(
      occasion: (map['occasion'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      templateName: map['templateName'] as String?,
      body: (map['body'] as String?) ?? '',
      preview: (map['preview'] as String?) ?? '',
      buttonUrlEnabled: map['buttonUrlEnabled'] == true,
      usingPlatformDefault: map['usingPlatformDefault'] == true,
    );
  }
}

/// Contexto de notificações de um cliente: avisos, preferências e prévias.
class ClientNotificationContext {
  const ClientNotificationContext({
    required this.clientId,
    required this.clientName,
    this.phone,
    required this.notificationsEnabled,
    required this.preferences,
    required this.limits,
    required this.templates,
  });

  final String clientId;
  final String clientName;
  final String? phone;
  final bool notificationsEnabled;
  final NotificationPreferences preferences;
  final NotificationLimits limits;
  final List<NotificationTemplatePreview> templates;

  factory ClientNotificationContext.fromMap(Map<String, dynamic> map) {
    final client = map['client'];
    final prefs = map['preferences'];
    final limits = map['limits'];
    final templates = map['templates'];
    final clientMap = client is Map
        ? Map<String, dynamic>.from(client)
        : const <String, dynamic>{};
    return ClientNotificationContext(
      clientId: (clientMap['id'] as String?) ?? '',
      clientName: (clientMap['name'] as String?) ?? '',
      phone: clientMap['phone'] as String?,
      notificationsEnabled: clientMap['notificationsEnabled'] != false,
      preferences: prefs is Map
          ? NotificationPreferences.fromMap(Map<String, dynamic>.from(prefs))
          : const NotificationPreferences(),
      limits: limits is Map
          ? NotificationLimits.fromMap(Map<String, dynamic>.from(limits))
          : const NotificationLimits(),
      templates: templates is List
          ? templates
                .whereType<Map>()
                .map(
                  (row) => NotificationTemplatePreview.fromMap(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
    );
  }
}
