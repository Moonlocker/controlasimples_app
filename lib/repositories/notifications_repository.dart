import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client_notification.dart';
import '../models/notification_preferences.dart';
import '../services/mobile_api_service.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(mobileApiServiceProvider));
});

/// Preferências de notificação automática + limites definidos pelo superadmin.
final notificationSettingsProvider = FutureProvider<NotificationSettings>((
  ref,
) {
  return ref.watch(notificationsRepositoryProvider).fetchPreferences();
});

/// Notificações de WhatsApp de um cliente específico.
final clientNotificationsProvider =
    FutureProvider.family<List<ClientNotification>, String>((ref, clientId) {
      return ref
          .watch(notificationsRepositoryProvider)
          .fetchClientNotifications(clientId);
    });

class NotificationsRepository {
  NotificationsRepository(this._api);

  final MobileApiService _api;

  Future<NotificationSettings> fetchPreferences() async {
    return _parse(await _api.get('/api/mobile/notifications/preferences'));
  }

  Future<NotificationSettings> savePreferences(
    NotificationPreferences preferences,
  ) async {
    return _parse(
      await _api.post(
        '/api/mobile/notifications/preferences',
        preferences.toMap(),
      ),
    );
  }

  Future<List<ClientNotification>> fetchClientNotifications(
    String clientId,
  ) async {
    final result = await _api.get('/api/mobile/notifications/client', {
      'clientId': clientId,
    });
    final raw = result['notifications'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) => ClientNotification.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  NotificationSettings _parse(Map<String, dynamic> result) {
    final prefs = result['preferences'];
    final limits = result['limits'];
    return NotificationSettings(
      preferences: prefs is Map
          ? NotificationPreferences.fromMap(Map<String, dynamic>.from(prefs))
          : const NotificationPreferences(),
      limits: limits is Map
          ? NotificationLimits.fromMap(Map<String, dynamic>.from(limits))
          : const NotificationLimits(),
    );
  }
}
