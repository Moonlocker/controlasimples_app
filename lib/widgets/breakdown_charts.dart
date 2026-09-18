import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/derive.dart';
import '../core/utils/formatters.dart';

const List<Color> chartPalette = [
  AppColors.chart1,
  AppColors.chart2,
  AppColors.chart3,
  AppColors.chart4,
  Color(0xFF8B5CF6),
  Color(0xFF14B8A6),
];

class BreakdownPie extends StatelessWidget {
  const BreakdownPie({super.key, required this.items});

  final List<BreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: items[i].value,
                    color: chartPalette[i % chartPalette.length],
                    radius: 24,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: chartPalette[i % chartPalette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          items[i].name,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        brl(items[i].value),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Total ${brl(total)}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BreakdownBars extends StatelessWidget {
  const BreakdownBars({
    super.key,
    required this.items,
    this.tone = AppColors.primary,
  });

  final List<BreakdownItem> items;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final max = items.fold<double>(
      0,
      (value, item) => item.value > value ? item.value : value,
    );
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      brl(item.value),
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : item.value / max,
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    color: tone,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
