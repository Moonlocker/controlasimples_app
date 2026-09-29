import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../models/notification_preferences.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../settings/payment_providers_section.dart';
import 'notification_widgets.dart';

/// Abre a configuração dos meios de pagamento do usuário.
Future<void> showAsaasConfigSheet(BuildContext context) {
  return showPaymentProvidersSheet(context);
}

/// Abre as preferências de notificações automáticas (WhatsApp) do cliente.
Future<void> showNotificationPreferencesSheet(BuildContext context) {
  return showAppFormSheet(context, const _NotificationPreferencesSheet());
}

/// Avisos automáticos de um cliente específico (ligar/desligar e prévias).
Future<void> showClientNotificationSheet(
  BuildContext context, {
  required String clientId,
}) {
  return showAppFormSheet(
    context,
    _ClientNotificationSheet(clientId: clientId),
  );
}

class _ClientNotificationSheet extends ConsumerStatefulWidget {
  const _ClientNotificationSheet({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_ClientNotificationSheet> createState() =>
      _ClientNotificationSheetState();
}

class _ClientNotificationSheetState
    extends ConsumerState<_ClientNotificationSheet>
    with SingleTickerProviderStateMixin {
  bool? _clientEnabled;
  NotificationPreferences? _form;
  bool _busy = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  NotificationPreferences _sync(NotificationPreferences value) {
    return value.copyWith(
      whatsappEnabled:
          value.reminderBeforeEnabled ||
          value.onDueEnabled ||
          value.overdueEnabled,
    );
  }

  void _update(NotificationPreferences value) {
    setState(() => _form = _sync(value));
  }

  Future<void> _save() async {
    final form = _form;
    final clientEnabled = _clientEnabled;
    if (form == null || clientEnabled == null) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(notificationsRepositoryProvider);
      await repository.savePreferences(_sync(form));
      await repository.setClientNotifications(
        clientId: widget.clientId,
        enabled: clientEnabled,
      );
      ref.invalidate(notificationSettingsProvider);
      ref.invalidate(clientNotificationContextProvider(widget.clientId));
      ref.invalidate(workspaceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferências de avisos salvas.')),
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
    final async = ref.watch(clientNotificationContextProvider(widget.clientId));
    final textTheme = Theme.of(context).textTheme;
    return async.when(
      loading: () => const _SimpleSheet(
        title: 'Avisos do cliente',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _SimpleSheet(
        title: 'Avisos do cliente',
        child: Text('Não foi possível carregar: ${friendlyError(error)}'),
      ),
      data: (ctx) {
        _clientEnabled ??= ctx.notificationsEnabled;
        _form ??= ctx.preferences;
        final form = _form!;
        final limits = ctx.limits;
        final clientEnabled = _clientEnabled!;

        return AppFormSheet(
          title: 'Avisos do cliente',
          subtitle: ctx.clientName.isEmpty ? null : ctx.clientName,
          formKey: GlobalKey<FormState>(),
          busy: _busy,
          saveLabel: 'Salvar avisos',
          onSave: _save,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: clientEnabled
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.muted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: clientEnabled
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: clientEnabled,
                onChanged: (value) => setState(() => _clientEnabled = value),
                title: Text(
                  'Enviar avisos para ${ctx.clientName}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  clientEnabled
                      ? 'Ativado: o cliente recebe os avisos pelo WhatsApp oficial.'
                      : 'Desativado: nenhum aviso é enviado a este cliente.',
                ),
              ),
            ),
            if (!limits.integrationEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'O WhatsApp oficial está temporariamente indisponível.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.mutedForeground,
              indicatorColor: AppColors.primary,
              dividerColor: AppColors.border,
              tabs: [
                OccasionTab(
                  label: 'Antes',
                  enabled: form.reminderBeforeEnabled,
                ),
                OccasionTab(label: 'No dia', enabled: form.onDueEnabled),
                OccasionTab(label: 'Após', enabled: form.overdueEnabled),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: TabBarView(
                controller: _tabController,
                children: [
                  OccasionPanel(
                    title: 'Antes do vencimento',
                    description: 'Enviado alguns dias antes do vencimento.',
                    enabled: form.reminderBeforeEnabled,
                    canEdit: clientEnabled,
                    onToggle: (value) =>
                        _update(form.copyWith(reminderBeforeEnabled: value)),
                    days: form.reminderBeforeDays,
                    maxDays: limits.maxReminderDaysBefore,
                    onDaysChanged: (value) =>
                        _update(form.copyWith(reminderBeforeDays: value)),
                    template: _templateFor(ctx.templates, 'cobranca_vencendo'),
                  ),
                  OccasionPanel(
                    title: 'No dia do vencimento',
                    description: 'Enviado no dia do vencimento.',
                    enabled: form.onDueEnabled,
                    canEdit: clientEnabled,
                    onToggle: (value) =>
                        _update(form.copyWith(onDueEnabled: value)),
                    template: _templateFor(ctx.templates, 'cobranca'),
                  ),
                  OccasionPanel(
                    title: 'Após o vencimento',
                    description:
                        'Reenviado enquanto a cobrança estiver aberta.',
                    enabled: form.overdueEnabled,
                    canEdit: clientEnabled,
                    onToggle: (value) =>
                        _update(form.copyWith(overdueEnabled: value)),
                    days: form.overdueDays,
                    maxDays: limits.maxOverdueDays,
                    onDaysChanged: (value) =>
                        _update(form.copyWith(overdueDays: value)),
                    template: _templateFor(ctx.templates, 'cobranca_atraso'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  NotificationTemplatePreview? _templateFor(
    List<NotificationTemplatePreview> templates,
    String occasion,
  ) {
    for (final template in templates) {
      if (template.occasion == occasion) return template;
    }
    return null;
  }
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
