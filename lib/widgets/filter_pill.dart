import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'count_badge.dart';

/// Chip de filtro reutilizável (status, categorias etc.) com contador e tom
/// configurável. Mantém o mesmo visual em todas as telas de listagem.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
    this.tone = AppColors.primary,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;
  final Color tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? tone : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
            ],
            Text(label),
            CountBadge(count: count, selected: selected, tone: tone),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? tone : AppColors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: tone.withValues(alpha: 0.12),
        backgroundColor: AppColors.muted,
        side: BorderSide(
          color: selected ? tone.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
    );
  }
}
