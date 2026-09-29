import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/charge_notification.dart';
import '../../models/notification_preferences.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/whatsapp_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import 'notification_widgets.dart';

/// Painel de notificações (automáticas e manual) de uma cobrança.
///
/// Usa o mesmo layout com abas do modal de configuração de avisos do cliente
/// (Antes / No dia / Após), com a diferença de que cada ocasião mostra a data
/// prevista de envio calculada a partir do vencimento da cobrança e permite
/// disparar o aviso na hora, quando dentro do intervalo permitido.
Future<void> showChargeNotificationsSheet(
  BuildContext context, {
  required String chargeId,
  String? description,
}) {
  return showAppFormSheet(
    context,
    _ChargeNotificationsSheet(chargeId: chargeId, description: description),
  );
}

class _ChargeNotificationsSheet extends ConsumerStatefulWidget {
  const _ChargeNotificationsSheet({required this.chargeId, this.description});

  final String chargeId;
  final String? description;

  @override
  ConsumerState<_ChargeNotificationsSheet> createState() =>
      _ChargeNotificationsSheetState();
}

class _ChargeNotificationsSheetState
    extends ConsumerState<_ChargeNotificationsSheet>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  String? _sendingOccasion;
  NotificationPreferences? _form;
  bool? _chargeEnabled;
  bool? _clientEnabled;
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

  void _invalidate() {
    ref.invalidate(chargeNotificationsProvider(widget.chargeId));
    ref.invalidate(notificationSettingsProvider);
    ref.invalidate(workspaceProvider);
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
    if (form == null || _busy) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(notificationsRepositoryProvider);
      await repository.savePreferences(_sync(form));
      if (_chargeEnabled != null) {
        await repository.saveChargeNotifications(
          chargeId: widget.chargeId,
          chargeEnabled: _chargeEnabled,
        );
      }
      if (_clientEnabled != null) {
        await repository.saveChargeNotifications(
          chargeId: widget.chargeId,
          clientEnabled: _clientEnabled,
        );
      }
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Avisos atualizados.')));
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

  Future<void> _sendNow(String occasion) async {
    if (_sendingOccasion != null) return;
    setState(() => _sendingOccasion = occasion);
    try {
      await ref
          .read(whatsappRepositoryProvider)
          .sendCharge(widget.chargeId, occasion: occasion);
      _invalidate();
      ref.invalidate(whatsappUsageProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso enviado no WhatsApp.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _sendingOccasion = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chargeNotificationsProvider(widget.chargeId));
    return async.when(
      loading: () => AppFormSheet(
        title: 'Notificações da cobrança',
        formKey: GlobalKey<FormState>(),
        onSave: () async => Navigator.of(context).pop(),
        saveLabel: 'Fechar',
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => AppFormSheet(
        title: 'Notificações da cobrança',
        formKey: GlobalKey<FormState>(),
        onSave: () async => Navigator.of(context).pop(),
        saveLabel: 'Fechar',
        children: [Text('Não foi possível carregar: ${friendlyError(error)}')],
      ),
      data: (data) => _buildBody(context, data),
    );
  }

  Widget _buildBody(BuildContext context, ChargeNotificationContext data) {
    final textTheme = Theme.of(context).textTheme;
    final charge = data.charge;
    final client = data.client;
    _form ??= data.preferences;
    _chargeEnabled ??= charge?.notificationsEnabled;
    _clientEnabled ??= client?.notificationsEnabled ?? true;

    final form = _form!;
    final limits = data.limits;
    final dueDate = charge?.dueDate;
    final canSend =
        charge != null &&
        charge.status != 'pago' &&
        charge.status != 'cancelado' &&
        data.integrationEnabled;

    return AppFormSheet(
      title: 'Notificações da cobrança',
      subtitle: widget.description,
      formKey: GlobalKey<FormState>(),
      busy: _busy,
      saveLabel: 'Salvar avisos',
      onSave: _save,
      children: [
        if (!data.integrationEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'O envio pelo WhatsApp oficial está temporariamente indisponível.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
        if (charge != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        charge.description,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vence ${formatDate(charge.dueDate)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      if (client?.phone != null && client!.phone!.isNotEmpty)
                        Text(
                          'WhatsApp: ${client.phone}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  brl(charge.amount),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Escolha as ocasiões em que o cliente deve ser avisado. As datas são '
          'calculadas a partir do vencimento desta cobrança.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 12),
        ref
            .watch(notificationTemplatesProvider)
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Não foi possível carregar as prévias.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              data: (templates) => Column(
                children: [
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
                    height: 420,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        OccasionPanel(
                          title: 'Antes do vencimento',
                          description:
                              'Enviado alguns dias antes do vencimento.',
                          enabled: form.reminderBeforeEnabled,
                          canEdit: true,
                          onToggle: (value) => _update(
                            form.copyWith(reminderBeforeEnabled: value),
                          ),
                          days: form.reminderBeforeDays,
                          maxDays: limits.maxReminderDaysBefore,
                          onDaysChanged: (value) =>
                              _update(form.copyWith(reminderBeforeDays: value)),
                          template: _templateFor(
                            templates,
                            'cobranca_vencendo',
                          ),
                          scheduleDate: _scheduleDate(
                            data,
                            'cobranca_vencendo',
                          ),
                          onSendNow: canSend
                              ? () => _sendNow('cobranca_vencendo')
                              : null,
                          canSendNow:
                              canSend &&
                              form.reminderBeforeEnabled &&
                              dueDate != null &&
                              _withinWindow('cobranca_vencendo', dueDate, form),
                          sendBusy: _sendingOccasion == 'cobranca_vencendo',
                        ),
                        OccasionPanel(
                          title: 'No dia do vencimento',
                          description: 'Enviado no dia do vencimento.',
                          enabled: form.onDueEnabled,
                          canEdit: true,
                          onToggle: (value) =>
                              _update(form.copyWith(onDueEnabled: value)),
                          template: _templateFor(templates, 'cobranca'),
                          scheduleDate: _scheduleDate(data, 'cobranca'),
                          onSendNow: canSend
                              ? () => _sendNow('cobranca')
                              : null,
                          canSendNow:
                              canSend &&
                              form.onDueEnabled &&
                              dueDate != null &&
                              _withinWindow('cobranca', dueDate, form),
                          sendBusy: _sendingOccasion == 'cobranca',
                        ),
                        OccasionPanel(
                          title: 'Após o vencimento',
                          description:
                              'Reenviado enquanto a cobrança estiver aberta.',
                          enabled: form.overdueEnabled,
                          canEdit: true,
                          onToggle: (value) =>
                              _update(form.copyWith(overdueEnabled: value)),
                          days: form.overdueDays,
                          maxDays: limits.maxOverdueDays,
                          onDaysChanged: (value) =>
                              _update(form.copyWith(overdueDays: value)),
                          template: _templateFor(templates, 'cobranca_atraso'),
                          scheduleDate: _scheduleDate(data, 'cobranca_atraso'),
                          onSendNow: canSend
                              ? () => _sendNow('cobranca_atraso')
                              : null,
                          canSendNow:
                              canSend &&
                              form.overdueEnabled &&
                              dueDate != null &&
                              _withinWindow('cobranca_atraso', dueDate, form),
                          sendBusy: _sendingOccasion == 'cobranca_atraso',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _chargeEnabled ?? true,
          onChanged: _busy
              ? null
              : (value) => setState(() => _chargeEnabled = value),
          title: const Text('Avisos desta cobrança'),
          subtitle: Text(
            charge?.notificationsEnabled == null
                ? 'Usando o padrão do cliente.'
                : (_chargeEnabled == true
                      ? 'Ativados para esta cobrança.'
                      : 'Desativados para esta cobrança.'),
          ),
        ),
        if (charge?.notificationsEnabled != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final repository = ref.read(
                        notificationsRepositoryProvider,
                      );
                      setState(() => _busy = true);
                      try {
                        await repository.saveChargeNotifications(
                          chargeId: widget.chargeId,
                          clearChargeOverride: true,
                        );
                        _invalidate();
                        if (mounted) setState(() => _chargeEnabled = true);
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(friendlyError(error))),
                        );
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Voltar a usar o padrão do cliente'),
            ),
          ),
        if (client != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _clientEnabled ?? client.notificationsEnabled,
            onChanged: _busy
                ? null
                : (value) => setState(() => _clientEnabled = value),
            title: Text('Avisos do cliente (${client.name})'),
            subtitle: Text(
              (_clientEnabled ?? client.notificationsEnabled)
                  ? 'O cliente recebe avisos automáticos.'
                  : 'O cliente não recebe avisos automáticos.',
            ),
          ),
        if (data.history.isNotEmpty) ...[
          const Divider(height: 24),
          Text(
            'Histórico desta cobrança',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final message in data.history.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_kindLabel(message.kind)} · '
                      '${message.source == 'auto' ? 'automático' : 'manual'}',
                      style: textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    _statusLabel(message.status),
                    style: textTheme.labelSmall?.copyWith(
                      color: message.status == 'enviado'
                          ? AppColors.success
                          : AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  DateTime? _scheduleDate(ChargeNotificationContext data, String occasion) {
    for (final item in data.schedule) {
      if (item.occasion == occasion) return item.date;
    }
    return null;
  }

  bool _withinWindow(
    String occasion,
    DateTime dueDate,
    NotificationPreferences prefs,
  ) {
    final due = dateOnly(dueDate);
    final now = today();
    switch (occasion) {
      case 'cobranca_vencendo':
        final start = due.subtract(Duration(days: prefs.reminderBeforeDays));
        return !now.isBefore(start) && !now.isAfter(due);
      case 'cobranca':
        return now == due;
      case 'cobranca_atraso':
        final start = due.add(Duration(days: prefs.overdueDays));
        return !now.isBefore(start);
      default:
        return false;
    }
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

  static String _kindLabel(String kind) {
    switch (kind) {
      case 'cobranca_vencendo':
        return 'Antes do vencimento';
      case 'cobranca':
        return 'No vencimento';
      case 'cobranca_atraso':
        return 'Após o vencimento';
      default:
        return kind.isEmpty ? 'Aviso' : kind;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'enviado':
        return 'Enviado';
      case 'erro':
        return 'Falhou';
      default:
        return status.isEmpty ? '—' : status;
    }
  }
}
