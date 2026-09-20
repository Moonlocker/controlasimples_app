import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Envolve o `flutter_local_notifications` para exibir avisos do sistema
/// (pagamento recebido, cobrança atrasada, vencimentos próximos).
///
/// As notificações são disparadas pelo próprio app quando os dados são
/// atualizados — inclusive por eventos em tempo real do Supabase (retorno do
/// Asaas). Não depende de um servidor de push externo.
class LocalNotifications {
  LocalNotifications._();

  static final LocalNotifications instance = LocalNotifications._();

  static const String _channelId = 'controla_simples.eventos';
  static const String _channelName = 'Avisos de cobrança';
  static const String _channelDescription =
      'Pagamentos recebidos, cobranças atrasadas e vencimentos próximos.';

  /// Ícone monocromático (marca do Controla Simples) usado na barra de status.
  static const String _icon = '@drawable/ic_stat_notification';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String?> _taps = StreamController<String?>.broadcast();

  bool _initialized = false;
  bool _permissionRequested = false;

  /// Payloads das notificações tocadas pelo usuário (para navegação).
  Stream<String?> get taps => _taps.stream;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings(_icon);
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) =>
            _taps.add(response.payload),
        onDidReceiveBackgroundNotificationResponse: _backgroundResponse,
      );
      _initialized = true;
    } catch (error) {
      // Em plataformas sem suporte o app segue normalmente.
      debugPrint('LocalNotifications.init falhou: $error');
    }
  }

  /// Pede permissão de exibição (Android 13+ / iOS). Retorna se foi concedida.
  Future<bool> requestPermission() async {
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      }
    } catch (error) {
      debugPrint('LocalNotifications.requestPermission falhou: $error');
    }
    _permissionRequested = true;
    return true;
  }

  /// Garante que a permissão seja pedida apenas uma vez por sessão.
  Future<void> ensurePermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    await requestPermission();
  }

  Future<void> show({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    await init();
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: _icon,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: body == null ? null : BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (error) {
      debugPrint('LocalNotifications.show falhou: $error');
    }
  }

  Future<void> cancel(int id) async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } catch (error) {
      debugPrint('LocalNotifications.cancel falhou: $error');
    }
  }

  Future<void> cancelAll() async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('LocalNotifications.cancelAll falhou: $error');
    }
  }
}

@pragma('vm:entry-point')
void _backgroundResponse(NotificationResponse response) {
  // Ações em background não são necessárias no momento.
}
