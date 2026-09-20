import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/notification_delivery.dart';
import 'features/notifications/notifications_providers.dart';
import 'models/notification.dart';
import 'repositories/workspace_providers.dart';
import 'services/local_notifications.dart';

class ControlaSimplesApp extends ConsumerStatefulWidget {
  const ControlaSimplesApp({super.key});

  @override
  ConsumerState<ControlaSimplesApp> createState() => _ControlaSimplesAppState();
}

class _ControlaSimplesAppState extends ConsumerState<ControlaSimplesApp>
    with WidgetsBindingObserver {
  StreamSubscription<String?>? _tapSubscription;
  bool _syncing = false;
  DateTime? _lastResumeRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalNotifications.instance.init();
    _tapSubscription = LocalNotifications.instance.taps.listen(_handleTap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSubscription?.cancel();
    super.dispose();
  }

  void _handleTap(String? payload) {
    // Abre a central de avisos do app ao tocar na notificação do sistema.
    ref.read(routerProvider).go('/more/notifications');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (_lastResumeRefresh != null &&
        now.difference(_lastResumeRefresh!).inMinutes < 2) {
      return;
    }
    _lastResumeRefresh = now;
    // Ao voltar para o app, atualiza os dados para detectar novos eventos.
    ref.invalidate(workspaceProvider);
  }

  Future<void> _syncNotifications(List<AppNotification> notifications) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await syncOsNotifications(ref, notifications);
    } catch (error) {
      debugPrint('syncOsNotifications falhou: $error');
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eventos em tempo real (retorno do Asaas/webhooks) atualizam os dados e,
    // com isso, disparam os avisos no aparelho.
    ref.watch(realtimeEventsProvider);

    ref.listen<List<AppNotification>>(appNotificationsProvider, (_, next) {
      _syncNotifications(next);
    });

    ref.listen<AsyncValue<LocalNotificationPreferences>>(
      localNotificationPreferencesProvider,
      (_, next) {
        final preferences = next.value;
        if (preferences == null) return;
        if (preferences.enabled) {
          LocalNotifications.instance.ensurePermission();
        }
        _syncNotifications(ref.read(appNotificationsProvider));
      },
    );

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
