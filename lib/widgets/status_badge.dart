import 'package:flutter/material.dart';

import '../core/constants/enums.dart';
import '../core/theme/app_colors.dart';

Color serviceStatusTone(ServiceStatus status) => switch (status) {
  ServiceStatus.negociacao => AppColors.warning,
  ServiceStatus.andamento => AppColors.info,
  ServiceStatus.concluido => AppColors.success,
  ServiceStatus.cancelado => AppColors.mutedForeground,
};

IconData serviceStatusIcon(ServiceStatus status) => switch (status) {
  ServiceStatus.negociacao => Icons.handshake_outlined,
  ServiceStatus.andamento => Icons.play_circle_outline,
  ServiceStatus.concluido => Icons.check_circle_outline,
  ServiceStatus.cancelado => Icons.block,
};

Color quoteStatusTone(QuoteStatus status) => switch (status) {
  QuoteStatus.rascunho => AppColors.mutedForeground,
  QuoteStatus.enviado => AppColors.info,
  QuoteStatus.aprovado => AppColors.success,
  QuoteStatus.recusado => AppColors.danger,
};

IconData quoteStatusIcon(QuoteStatus status) => switch (status) {
  QuoteStatus.rascunho => Icons.edit_note_outlined,
  QuoteStatus.enviado => Icons.send_outlined,
  QuoteStatus.aprovado => Icons.check_circle_outline,
  QuoteStatus.recusado => Icons.cancel_outlined,
};

/// Pílula de status genérica, usada em toda a aplicação para manter o mesmo
/// padrão visual de cores, cantos e tipografia.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 12, color: tone),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: tone, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final ChargeStatus status;
  final bool compact;

  static (Color, IconData) styleFor(ChargeStatus status) {
    return switch (status) {
      ChargeStatus.pago => (AppColors.success, Icons.check_circle_outline),
      ChargeStatus.pendente => (AppColors.info, Icons.schedule_outlined),
      ChargeStatus.atrasado => (AppColors.danger, Icons.error_outline),
      ChargeStatus.cancelado => (AppColors.mutedForeground, Icons.block),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = styleFor(status);
    return StatusPill(
      label: status.label,
      tone: color,
      icon: icon,
      compact: compact,
    );
  }
}
