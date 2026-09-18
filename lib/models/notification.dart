enum NotificationKind {
  pago('pago', 'Pagamento'),
  atrasado('atrasado', 'Atrasado'),
  vencendo('vencendo', 'Vencendo'),
  recorrente('recorrente', 'Recorrente'),
  resumo('resumo', 'Resumo');

  const NotificationKind(this.wire, this.label);

  final String wire;
  final String label;

  static NotificationKind fromWire(String? value) {
    return NotificationKind.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => NotificationKind.resumo,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final NotificationKind kind;
  final DateTime createdAt;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    kind: kind,
    createdAt: createdAt,
    read: read ?? this.read,
  );
}
