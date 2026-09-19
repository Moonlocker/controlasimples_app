import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Contador pequeno exibido ao lado de filtros (status, categorias etc.),
/// para o usuário saber a quantidade antes mesmo de filtrar.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.selected = false,
    this.tone = AppColors.primary,
  });

  final int count;
  final bool selected;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? tone.withValues(alpha: 0.18)
            : AppColors.foreground.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: selected ? tone : AppColors.mutedForeground,
        ),
      ),
    );
  }
}
