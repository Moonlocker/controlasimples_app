class WhatsappUsage {
  const WhatsappUsage({
    this.enabled = false,
    this.sent = 0,
    this.quota = 0,
    this.remaining = 0,
  });

  final bool enabled;
  final int sent;
  final int quota;
  final int remaining;

  factory WhatsappUsage.fromMap(Map<String, dynamic> map) {
    return WhatsappUsage(
      enabled: map['enabled'] == true,
      sent: (map['sent'] as num?)?.toInt() ?? 0,
      quota: (map['quota'] as num?)?.toInt() ?? 0,
      remaining: (map['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}
