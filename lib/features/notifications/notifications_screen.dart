import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/derive.dart';
import '../../models/notification.dart';
import '../../widgets/empty_state.dart';
import 'notifications_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ids = ref.read(appNotificationsProvider).map((n) => n.id).toList();
      if (ids.isNotEmpty) {
        ref.read(readNotificationIdsProvider.notifier).markAllRead(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(appNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              tooltip: 'Excluir todas',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () {
                final ids = notifications.map((item) => item.id).toList();
                ref
                    .read(dismissedNotificationIdsProvider.notifier)
                    .dismiss(ids);
              },
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'Nenhuma notificação',
              description:
                  'Avisos de vencimentos, atrasos e pagamentos aparecem aqui.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _NotificationTile(item: notifications[index]),
            ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  (IconData, Color) get _style => switch (item.kind) {
    NotificationKind.pago => (Icons.check_circle_outline, AppColors.success),
    NotificationKind.atrasado => (
      Icons.warning_amber_outlined,
      AppColors.danger,
    ),
    NotificationKind.vencendo => (Icons.schedule_outlined, AppColors.warning),
    NotificationKind.recorrente => (Icons.autorenew, AppColors.info),
    NotificationKind.resumo => (Icons.summarize_outlined, AppColors.info),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readIds =
        ref.watch(readNotificationIdsProvider).value ?? const <String>{};
    final read = readIds.contains(item.id);
    final (icon, color) = _style;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: read ? AppColors.surface : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: read ? AppColors.border : color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notificationTime(item.createdAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (!read)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
