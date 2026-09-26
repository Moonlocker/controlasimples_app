import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/charge_notification.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/whatsapp_repository.dart';
import '../../widgets/app_form_sheet.dart';

/// Painel de notificações (automáticas e manual) de uma cobrança.
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
    extends ConsumerState<_ChargeNotificationsSheet> {
  bool _busy = false;
  bool _sending = false;

  void _invalidate() {
    ref.invalidate(chargeNotificationsProvider(widget.chargeId));
  }

  Future<void> _save({
    bool? chargeEnabled,
    bool clearChargeOverride = false,
    bool? clientEnabled,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .saveChargeNotifications(
            chargeId: widget.chargeId,
            chargeEnabled: chargeEnabled,
            clearChargeOverride: clearChargeOverride,
            clientEnabled: clientEnabled,
          );
      _invalidate();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendNow() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(whatsappRepositoryProvider).sendCharge(widget.chargeId);
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
      if (mounted) setState(() => _sending = false);
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
      data: (context_) => _buildBody(context, context_),
    );
  }

  Widget _buildBody(BuildContext context, ChargeNotificationContext data) {
    final textTheme = Theme.of(context).textTheme;
    final charge = data.charge;
    final client = data.client;
    final isOpen =
        charge != null &&
        charge.status != 'pago' &&
        charge.status != 'cancelado';

    return AppFormSheet(
      title: 'Notificações da cobrança',
      subtitle: widget.description,
      formKey: GlobalKey<FormState>(),
      onSave: () async => Navigator.of(context).pop(),
      saveLabel: 'Fechar',
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
        const SizedBox(height: 16),
        Text(
          'Datas previstas dos avisos automáticos',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'As ocasiões são definidas em Configurações. Aqui você liga/desliga '
          'os avisos desta cobrança e deste cliente.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in data.schedule)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: textTheme.bodyMedium),
                        Text(
                          item.date == null ? '—' : formatDate(item.date!),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: item.enabled
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.muted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.enabled ? 'Ativa' : 'Desativada',
                      style: textTheme.labelSmall?.copyWith(
                        color: item.enabled
                            ? AppColors.success
                            : AppColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: charge?.notificationsEnabled ?? true,
          onChanged: _busy ? null : (value) => _save(chargeEnabled: value),
          title: const Text('Avisos desta cobrança'),
          subtitle: Text(
            charge?.notificationsEnabled == null
                ? 'Usando o padrão do cliente.'
                : (charge!.notificationsEnabled!
                      ? 'Ativados para esta cobrança.'
                      : 'Desativados para esta cobrança.'),
          ),
        ),
        if (charge?.notificationsEnabled != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : () => _save(clearChargeOverride: true),
              child: const Text('Voltar a usar o padrão do cliente'),
            ),
          ),
        if (client != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: client.notificationsEnabled,
            onChanged: _busy ? null : (value) => _save(clientEnabled: value),
            title: Text('Avisos do cliente (${client.name})'),
            subtitle: Text(
              client.notificationsEnabled
                  ? 'O cliente recebe avisos automáticos.'
                  : 'O cliente não recebe avisos automáticos.',
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (!isOpen || _sending || !data.integrationEnabled)
                ? null
                : _sendNow,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Enviando…' : 'Enviar aviso agora'),
          ),
        ),
        const Divider(height: 24),
        Text(
          'Prévia das mensagens',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Texto configurado pela plataforma para cada ocasião de aviso.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 10),
        ref
            .watch(notificationTemplatesProvider)
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Não foi possível carregar as prévias.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              data: (templates) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final template in templates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.label,
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (template.usingPlatformDefault)
                            Text(
                              'Usa o modelo padrão aprovado na Meta.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCF8C6),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                  bottomRight: Radius.circular(14),
                                ),
                              ),
                              child: Text(
                                template.preview.isEmpty
                                    ? template.body
                                    : template.preview,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF111B21),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
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
