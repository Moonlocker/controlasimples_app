import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/derive.dart';
import '../core/utils/formatters.dart';

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.series, this.onMonthTap});

  final List<MonthPoint> series;
  final ValueChanged<String>? onMonthTap;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Sem dados no período')),
      );
    }

    final maxValue = series
        .expand((point) => [point.received, point.forecast])
        .fold<double>(0, (max, value) => value > max ? value : max);
    final maxY = maxValue == 0 ? 100.0 : maxValue * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 54,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) => Text(
                  brlCompact(value),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= series.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      monthLabel(series[index].key),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchCallback: onMonthTap == null
                ? null
                : (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final index = response?.spot?.touchedBarGroupIndex;
                    if (index == null || index < 0 || index >= series.length) {
                      return;
                    }
                    onMonthTap!(series[index].key);
                  },
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = rodIndex == 0 ? 'Recebido' : 'A receber';
                return BarTooltipItem(
                  '$label\n${brl(rod.toY)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: series[i].received,
                    color: AppColors.chart1,
                    width: 9,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: series[i].forecast,
                    color: AppColors.chart2,
                    width: 9,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _LegendDot(color: AppColors.chart1, label: 'Recebido'),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.chart2, label: 'A receber'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}
