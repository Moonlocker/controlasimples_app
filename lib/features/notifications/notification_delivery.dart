import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/notification.dart';
import '../../services/local_notifications.dart';
import '../auth/auth_providers.dart';

/// Preferências dos avisos exibidos no aparelho (notificações do sistema).
class LocalNotificationPreferences {
  const LocalNotificationPreferences({
    this.enabled = true,
    this.payments = true,
    this.overdue = true,
    this.upcoming = true,
  });

  final bool enabled;
  final bool payments;
  final bool overdue;
  final bool upcoming;

  bool allows(NotificationKind kind) {
    if (!enabled) return false;
    switch (kind) {
      case NotificationKind.pago:
        return payments;
      case NotificationKind.atrasado:
        return overdue;
      case NotificationKind.vencendo:
      case NotificationKind.recorrente:
        return upcoming;
      case NotificationKind.resumo:
        return true;
    }
  }

  LocalNotificationPreferences copyWith({
    bool? enabled,
    bool? payments,
    bool? overdue,
    bool? upcoming,
  }) {
    return LocalNotificationPreferences(
      enabled: enabled ?? this.enabled,
      payments: payments ?? this.payments,
      overdue: overdue ?? this.overdue,
      upcoming: upcoming ?? this.upcoming,
    );
  }
}

final localNotificationPreferencesProvider =
    AsyncNotifierProvider<
      LocalNotificationPreferencesNotifier,
      LocalNotificationPreferences
    >(LocalNotificationPreferencesNotifier.new);

class LocalNotificationPreferencesNotifier
    extends AsyncNotifier<LocalNotificationPreferences> {
  String get _prefix {
    final userId = ref.watch(currentUserIdProvider) ?? 'anon';
    return 'controla_simples.notif.os.$userId';
  }

  @override
  Future<LocalNotificationPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalNotificationPreferences(
      enabled: prefs.getBool('$_prefix.enabled') ?? true,
      payments: prefs.getBool('$_prefix.payments') ?? true,
      overdue: prefs.getBool('$_prefix.overdue') ?? true,
      upcoming: prefs.getBool('$_prefix.upcoming') ?? true,
    );
  }

  Future<void> save(LocalNotificationPreferences value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix.enabled', value.enabled);
    await prefs.setBool('$_prefix.payments', value.payments);
    await prefs.setBool('$_prefix.overdue', value.overdue);
    await prefs.setBool('$_prefix.upcoming', value.upcoming);
  }
}

/// IDs de avisos já exibidos como notificação do sistema (evita repetição).
final osDeliveredNotificationIdsProvider =
    AsyncNotifierProvider<OsDeliveredNotificationIds, Set<String>>(
      OsDeliveredNotificationIds.new,
    );

class OsDeliveredNotificationIds extends AsyncNotifier<Set<String>> {
  String get _key {
    final userId = ref.watch(currentUserIdProvider) ?? 'anon';
    return 'controla_simples.notif.osdelivered.$userId';
  }

  String get _baselineKey => '$_key.baseline';

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<bool> hasBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_baselineKey) ?? false;
  }

  Future<void> markDelivered(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final current = state.value ?? <String>{};
    final next = {...current, ...ids};
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }

  Future<void> markBaselineDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_baselineKey, true);
  }

  Future<void> clear() async {
    state = const AsyncData(<String>{});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_baselineKey);
  }
}

/// Título curto exibido no sistema, de acordo com o tipo do aviso.
String osNotificationTitle(NotificationKind kind) {
  return switch (kind) {
    NotificationKind.pago => 'Pagamento recebido',
    NotificationKind.atrasado => 'Cobrança atrasada',
    NotificationKind.vencendo => 'Cobrança a vencer',
    NotificationKind.recorrente => 'Cobrança recorrente',
    NotificationKind.resumo => 'Resumo de cobranças',
  };
}

/// Compara os avisos atuais com os já exibidos e dispara notificações do
/// sistema para os novos, respeitando as preferências do usuário.
///
/// Na primeira execução apenas registra o estado atual como base, evitando
/// uma enxurrada de avisos ao instalar/atualizar o app.
Future<void> syncOsNotifications(
  WidgetRef ref,
  List<AppNotification> notifications,
) async {
  final preferences = await ref.read(
    localNotificationPreferencesProvider.future,
  );
  final delivered = await ref.read(osDeliveredNotificationIdsProvider.future);
  final notifier = ref.read(osDeliveredNotificationIdsProvider.notifier);

  final fresh = notifications
      .where((notification) => !delivered.contains(notification.id))
      .toList();

  if (!await notifier.hasBaseline()) {
    await notifier.markDelivered(notifications.map((n) => n.id));
    await notifier.markBaselineDone();
    return;
  }

  if (preferences.enabled) {
    for (final notification in fresh) {
      if (!preferences.allows(notification.kind)) continue;
      await LocalNotifications.instance.show(
        id: notification.id.hashCode & 0x7fffffff,
        title: osNotificationTitle(notification.kind),
        body: notification.title,
        payload: notification.id,
      );
    }
  }

  await notifier.markDelivered(fresh.map((n) => n.id));
}
