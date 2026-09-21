import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class MetricItem {
  const MetricItem({
    required this.label,
    required this.value,
    this.tone = AppColors.foreground,
    this.icon,
    this.hint,
    this.active = false,
  });

  final String label;
  final String value;
  final Color tone;
  final IconData? icon;
  final String? hint;

  /// Destaca o item quando o filtro correspondente está aplicado.
  final bool active;
}

/// Faixa horizontal e compacta de indicadores. Boa para dar destaque aos
/// valores principais sem ocupar muito espaço vertical, como no topo de uma
/// listagem de cobranças.
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.items, this.onTap});

  final List<MetricItem> items;
  final void Function(int index)? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: _MetricTile(
                  item: items[i],
                  onTap: onTap == null ? null : () => onTap!(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item, this.onTap});

  final MetricItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.active
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 13, color: item.tone),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                item.value,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: item.tone,
                ),
                maxLines: 1,
              ),
            ),
            if (item.hint != null) ...[
              const SizedBox(height: 2),
              Text(
                item.hint!,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
