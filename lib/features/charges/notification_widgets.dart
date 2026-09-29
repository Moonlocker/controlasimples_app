import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/notification_preferences.dart';

/// Aba de ocasião de aviso (Antes / No dia / Após) com indicador ligado/desligado.
class OccasionTab extends StatelessWidget {
  const OccasionTab({super.key, required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: enabled ? AppColors.success : AppColors.mutedForeground,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

/// Bolha de mensagem no estilo WhatsApp.
class WhatsappBubble extends StatelessWidget {
  const WhatsappBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: const Color(0xFF111B21)),
      ),
    );
  }
}

/// Prévia da mensagem de um modelo de notificação, com fallbacks amigáveis.
class TemplatePreviewBody extends StatelessWidget {
  const TemplatePreviewBody({
    super.key,
    required this.template,
    this.emptyText = 'Prévia indisponível.',
  });

  final NotificationTemplatePreview? template;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final value = template;
    if (value == null) return Text(emptyText, style: _muted(textTheme));
    if (value.usingPlatformDefault) {
      return Text(
        'Usa o modelo padrão aprovado na Meta.',
        style: _muted(textTheme),
      );
    }
    return WhatsappBubble(
      text: value.preview.isEmpty ? value.body : value.preview,
    );
  }

  TextStyle? _muted(TextTheme textTheme) =>
      textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground);
}

/// Painel de uma ocasião: liga/desliga, intervalo de dias e prévia da mensagem.
///
/// Quando [scheduleDate] é informado (painel de uma cobrança), mostra a data
/// prevista do envio; quando [onSendNow] é informado, exibe o botão
/// "Enviar agora" (habilitado conforme [canSendNow]).
class OccasionPanel extends StatelessWidget {
  const OccasionPanel({
    super.key,
    required this.title,
    required this.description,
    required this.enabled,
    required this.canEdit,
    required this.onToggle,
    required this.template,
    this.days,
    this.maxDays,
    this.onDaysChanged,
    this.scheduleDate,
    this.scheduleHint,
    this.canSendNow = false,
    this.onSendNow,
    this.sendBusy = false,
  });

  final String title;
  final String description;
  final bool enabled;
  final bool canEdit;
  final ValueChanged<bool> onToggle;
  final NotificationTemplatePreview? template;
  final int? days;
  final int? maxDays;
  final ValueChanged<int>? onDaysChanged;
  final DateTime? scheduleDate;
  final String? scheduleHint;
  final bool canSendNow;
  final VoidCallback? onSendNow;
  final bool sendBusy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = this.days;
    final maxDays = this.maxDays;
    final editable = canEdit && enabled;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: canEdit ? onToggle : null,
          title: Text(title),
          subtitle: Text(description),
        ),
        if (scheduleDate != null)
          _ScheduleRow(date: scheduleDate!, hint: scheduleHint),
        if (days != null && maxDays != null && maxDays > 1)
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: days.clamp(1, maxDays).toDouble(),
                  min: 1,
                  max: maxDays.toDouble(),
                  divisions: maxDays - 1,
                  label: '$days dia(s)',
                  onChanged: editable
                      ? (value) => onDaysChanged?.call(value.round())
                      : null,
                ),
              ),
              Text('$days dia(s)', style: textTheme.labelSmall),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          'Prévia da mensagem',
          style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TemplatePreviewBody(
          template: template,
          emptyText: 'Prévia indisponível.',
        ),
        if (template?.buttonUrlEnabled == true)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Inclui botão com o link de pagamento.',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        if (!canEdit)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Ative o envio de avisos acima para editar.',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        if (onSendNow != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: (!canSendNow || sendBusy) ? null : onSendNow,
              icon: sendBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(sendBusy ? 'Enviando…' : 'Enviar agora'),
            ),
          ),
          if (!canSendNow)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'O envio agora fica disponível dentro do intervalo previsto para esta ocasião.',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.date, this.hint});

  final DateTime date;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: hint ?? '',
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Envio previsto: ${formatDate(date)}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
