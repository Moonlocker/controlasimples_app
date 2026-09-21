import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../models/notification_preferences.dart';
import '../../repositories/notifications_repository.dart';
import '../../widgets/app_form_sheet.dart';
import '../settings/payment_providers_section.dart';

/// Abre a configuração dos meios de pagamento do usuário.
Future<void> showAsaasConfigSheet(BuildContext context) {
  return showPaymentProvidersSheet(context);
}

/// Abre as preferências de notificações automáticas (WhatsApp) do cliente.
Future<void> showNotificationPreferencesSheet(BuildContext context) {
  return showAppFormSheet(context, const _NotificationPreferencesSheet());
}

class _NotificationPreferencesSheet extends ConsumerStatefulWidget {
  const _NotificationPreferencesSheet();

  @override
  ConsumerState<_NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends ConsumerState<_NotificationPreferencesSheet> {
  NotificationPreferences? _form;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(notificationSettingsProvider.future).then((settings) {
      if (mounted) setState(() => _form = settings.preferences);
    });
  }

  NotificationPreferences _syncEnabled(NotificationPreferences value) {
    return value.copyWith(
      whatsappEnabled:
          value.reminderBeforeEnabled ||
          value.onDueEnabled ||
          value.overdueEnabled,
    );
  }

  void _update(NotificationPreferences value) {
    setState(() => _form = _syncEnabled(value));
  }

  Future<void> _save() async {
    final form = _form;
    if (form == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .savePreferences(_syncEnabled(form));
      ref.invalidate(notificationSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferências de notificação salvas.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationSettingsProvider);
    return async.when(
      loading: () => const _SimpleSheet(
        title: 'Notificações automáticas',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _SimpleSheet(
        title: 'Notificações automáticas',
        child: Text('Não foi possível carregar: ${friendlyError(error)}'),
      ),
      data: (settings) {
        final form = _form ?? settings.preferences;
        final limits = settings.limits;
        return AppFormSheet(
          title: 'Notificações automáticas',
          subtitle:
              'Avisos enviados ao cliente pelo WhatsApp oficial da plataforma.',
          formKey: GlobalKey<FormState>(),
          busy: _busy,
          saveLabel: 'Salvar preferências',
          onSave: _save,
          children: [
            if (!limits.integrationEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'O envio pelo WhatsApp oficial está temporariamente indisponível.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.warning),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: form.reminderBeforeEnabled,
              onChanged: (value) =>
                  _update(form.copyWith(reminderBeforeEnabled: value)),
              title: const Text('Antes do vencimento'),
              subtitle: Text(
                'Avisa até ${form.reminderBeforeDays} dia(s) antes (máx. ${limits.maxReminderDaysBefore}).',
              ),
            ),
            if (limits.maxReminderDaysBefore > 1)
              Slider(
                value: form.reminderBeforeDays
                    .clamp(1, limits.maxReminderDaysBefore)
                    .toDouble(),
                min: 1,
                max: limits.maxReminderDaysBefore.toDouble(),
                divisions: limits.maxReminderDaysBefore - 1,
                label: '${form.reminderBeforeDays} dia(s)',
                onChanged: form.reminderBeforeEnabled
                    ? (value) => _update(
                        form.copyWith(reminderBeforeDays: value.round()),
                      )
                    : null,
              ),
            const Divider(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: form.onDueEnabled,
              onChanged: (value) => _update(form.copyWith(onDueEnabled: value)),
              title: const Text('No dia do vencimento'),
            ),
            const Divider(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: form.overdueEnabled,
              onChanged: (value) =>
                  _update(form.copyWith(overdueEnabled: value)),
              title: const Text('Após o vencimento'),
              subtitle: Text(
                'Relembra até ${form.overdueDays} dia(s) depois (máx. ${limits.maxOverdueDays}).',
              ),
            ),
            if (limits.maxOverdueDays > 1)
              Slider(
                value: form.overdueDays
                    .clamp(1, limits.maxOverdueDays)
                    .toDouble(),
                min: 1,
                max: limits.maxOverdueDays.toDouble(),
                divisions: limits.maxOverdueDays - 1,
                label: '${form.overdueDays} dia(s)',
                onChanged: form.overdueEnabled
                    ? (value) =>
                          _update(form.copyWith(overdueDays: value.round()))
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _SimpleSheet extends StatelessWidget {
  const _SimpleSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: title,
      formKey: GlobalKey<FormState>(),
      onSave: () async => Navigator.of(context).pop(),
      saveLabel: 'Fechar',
      children: [child],
    );
  }
}
