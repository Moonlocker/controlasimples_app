import 'package:flutter/material.dart';

import '../core/constants/enums.dart';
import '../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ChargeStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      ChargeStatus.pago => (AppColors.success, AppColors.success.withValues(alpha: 0.12)),
      ChargeStatus.pendente => (AppColors.info, AppColors.info.withValues(alpha: 0.12)),
      ChargeStatus.atrasado => (AppColors.danger, AppColors.danger.withValues(alpha: 0.12)),
      ChargeStatus.cancelado => (AppColors.mutedForeground, AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
