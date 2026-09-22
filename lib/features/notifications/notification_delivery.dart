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

/// Idade máxima de um aviso para ainda virar notificação do sistema. Evita
/// avisar sobre cobranças atrasadas há semanas ao reabrir o app.
const Duration _maxNotificationAge = Duration(days: 7);

/// Acima disso, os avisos são resumidos em uma única notificação (em vez de
/// várias mensagens seguidas).
const int _maxIndividualNotifications = 3;

/// Id fixo do resumo — assim ele substitui o anterior em vez de acumular.
const int _digestNotificationId = 900000001;

/// Compara os avisos atuais com os já exibidos e dispara notificações do
/// sistema para os novos, respeitando as preferências do usuário.
///
/// Regras para não incomodar:
/// - na primeira execução apenas registra o estado atual como base;
/// - ignora avisos antigos (mais de [_maxNotificationAge]);
/// - não envia o "resumo" diário como push (ele já aparece dentro do app);
/// - quando há muitos avisos novos de uma vez, envia um único resumo.
Future<void> syncOsNotifications(
  WidgetRef ref,
  List<AppNotification> notifications,
) async {
  final preferences = await ref.read(
    localNotificationPreferencesProvider.future,
  );
  final delivered = await ref.read(osDeliveredNotificationIdsProvider.future);
  final notifier = ref.read(osDeliveredNotificationIdsProvider.notifier);

  if (!await notifier.hasBaseline()) {
    await notifier.markDelivered(notifications.map((n) => n.id));
    await notifier.markBaselineDone();
    return;
  }

  final now = DateTime.now();
  final fresh = notifications.where((notification) {
    if (delivered.contains(notification.id)) return false;
    if (notification.kind == NotificationKind.resumo) return false;
    if (!preferences.allows(notification.kind)) return false;
    final age = now.difference(notification.createdAt);
    return !age.isNegative && age <= _maxNotificationAge;
  }).toList();

  // Marca tudo como processado (inclusive o que foi filtrado) para não
  // reprocessar depois.
  await notifier.markDelivered(notifications.map((n) => n.id));

  if (!preferences.enabled || fresh.isEmpty) return;

  await LocalNotifications.instance.ensurePermission();

  if (fresh.length > _maxIndividualNotifications) {
    await LocalNotifications.instance.show(
      id: _digestNotificationId,
      title: '${fresh.length} novidades no Controla Simples',
      body: _digestBody(fresh),
    );
    return;
  }

  for (final notification in fresh) {
    await LocalNotifications.instance.show(
      id: notification.id.hashCode & 0x7fffffff,
      title: osNotificationTitle(notification.kind),
      body: notification.title,
      payload: notification.id,
    );
  }
}

/// Resumo curto por tipo, ex.: "2 pagamentos recebidos · 1 cobrança atrasada".
String _digestBody(List<AppNotification> items) {
  final paid = items.where((n) => n.kind == NotificationKind.pago).length;
  final overdue = items
      .where((n) => n.kind == NotificationKind.atrasado)
      .length;
  final upcoming = items
      .where(
        (n) =>
            n.kind == NotificationKind.vencendo ||
            n.kind == NotificationKind.recorrente,
      )
      .length;

  final parts = <String>[
    if (paid > 0)
      '$paid ${paid == 1 ? 'pagamento recebido' : 'pagamentos recebidos'}',
    if (overdue > 0)
      '$overdue ${overdue == 1 ? 'cobrança atrasada' : 'cobranças atrasadas'}',
    if (upcoming > 0)
      '$upcoming ${upcoming == 1 ? 'cobrança a vencer' : 'cobranças a vencer'}',
  ];
  return parts.isEmpty
      ? 'Abra o app para ver as novidades.'
      : parts.join(' · ');
}
