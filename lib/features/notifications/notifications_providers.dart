import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/derive.dart';
import '../../models/notification.dart';
import '../../repositories/workspace_providers.dart';
import '../auth/auth_providers.dart';

final readNotificationIdsProvider =
    AsyncNotifierProvider<ReadNotificationIds, Set<String>>(ReadNotificationIds.new);

class ReadNotificationIds extends AsyncNotifier<Set<String>> {
  String get _key {
    final userId = ref.watch(currentUserIdProvider) ?? 'anon';
    return 'controla_simples.notif.read.$userId';
  }

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> markAllRead(Iterable<String> ids) async {
    final current = state.value ?? <String>{};
    final next = {...current, ...ids};
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }

  Future<void> clear() async {
    state = const AsyncData(<String>{});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final appNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final workspace = ref.watch(workspaceProvider).value;
  if (workspace == null) return const [];
  return buildNotifications(workspace);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(appNotificationsProvider);
  final readIds = ref.watch(readNotificationIdsProvider).value ?? const <String>{};
  return notifications.where((n) => !readIds.contains(n.id)).length;
});
