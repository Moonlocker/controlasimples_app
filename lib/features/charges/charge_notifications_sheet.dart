import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
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
/// (Antes / No dia / Após). Cada ocasião mostra a data prevista de envio
/// calculada a partir do vencimento da cobrança, a prévia do modelo da Meta
/// configurado para a ocasião e o botão "Enviar agora".
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

  Future<void> _clearChargeOverride() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .saveChargeNotifications(
            chargeId: widget.chargeId,
            clearChargeOverride: true,
          );
      _invalidate();
      if (mounted) setState(() => _chargeEnabled = true);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final canSend =
        charge != null &&
        charge.status != 'pago' &&
        charge.status != 'cancelado' &&
        data.integrationEnabled;
    final autoDisabled = (_chargeEnabled == false) || (_clientEnabled == false);

    return AppFormSheet(
      title: 'Notificações da cobrança',
      subtitle: widget.description,
      formKey: GlobalKey<FormState>(),
      busy: _busy,
      saveLabel: 'Salvar avisos',
      onSave: _save,
      children: [
        // Resumo da cobrança.
        if (charge != null)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                        'Vence ${formatDate(charge.dueDate)}'
                        '${client?.phone != null && client!.phone!.isNotEmpty ? ' · ${client.phone}' : ''}',
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

        if (!data.integrationEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'O envio pelo WhatsApp oficial está temporariamente indisponível.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),

        const SizedBox(height: 12),

        // Avisos automáticos: discrição no topo.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                'Avisos automáticos',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              _AutoToggle(
                label: 'Cobrança',
                value: _chargeEnabled ?? true,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _chargeEnabled = value),
              ),
              const SizedBox(width: 6),
              if (client != null)
                _AutoToggle(
                  label: 'Cliente',
                  value: _clientEnabled ?? true,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _clientEnabled = value),
                ),
            ],
          ),
        ),
        if (charge?.notificationsEnabled != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _clearChargeOverride,
              child: const Text('Usar padrão do cliente'),
            ),
          ),
        if (autoDisabled)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  size: 15,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Os avisos automáticos estão desativados. O envio manual abaixo continua funcionando.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // Ocasiões em abas.
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
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 380,
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
                          canSendNow: canSend && form.reminderBeforeEnabled,
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
                          canSendNow: canSend && form.onDueEnabled,
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
                          canSendNow: canSend && form.overdueEnabled,
                          sendBusy: _sendingOccasion == 'cobranca_atraso',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

        // Histórico recolhível.
        if (data.history.isNotEmpty) ...[
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              leading: const Icon(
                Icons.history,
                size: 18,
                color: AppColors.mutedForeground,
              ),
              title: Text(
                'Histórico desta cobrança',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text('${data.history.length} registro(s)'),
              children: [
                for (final message in data.history.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_kindLabel(message.kind)} · '
                                '${message.source == 'auto' ? 'automático' : 'manual'}',
                                style: textTheme.bodySmall,
                              ),
                              Text(
                                message.createdAt == null
                                    ? '—'
                                    : formatDateTime(message.createdAt!),
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
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

class _AutoToggle extends StatelessWidget {
  const _AutoToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!active),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              size: 14,
              color: active ? AppColors.success : AppColors.mutedForeground,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? AppColors.success : AppColors.mutedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
