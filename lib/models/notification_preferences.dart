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
