import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/derive.dart';
import '../core/utils/formatters.dart';

/// Gráfico de evolução das receitas no mesmo formato do web: barras para o
/// recebido e uma linha para o previsto/a receber (ComposedChart).
///
/// O fl_chart não tem um gráfico combinado, então sobrepomos um [BarChart]
/// (recebido) e um [LineChart] transparente (a receber) com a mesma escala e
/// área de plotagem — assim os pontos da linha caem no centro das barras.
class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.series, this.onMonthTap});

  final List<MonthPoint> series;
  final ValueChanged<String>? onMonthTap;

  static const double _leftReserved = 54;
  static const double _bottomReserved = 28;

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
    final count = series.length.toDouble();

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
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
                    reservedSize: _leftReserved,
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
                    reservedSize: _bottomReserved,
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
                        if (index == null ||
                            index < 0 ||
                            index >= series.length) {
                          return;
                        }
                        onMonthTap!(series[index].key);
                      },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        'Recebido\n${brl(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < series.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: series[i].received,
                        color: AppColors.chart1,
                        width: 16,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Linha "a receber" (mesma área de plotagem das barras).
          IgnorePointer(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: count,
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                      reservedSize: _leftReserved,
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                      reservedSize: _bottomReserved,
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < series.length; i++)
                        FlSpot(i + 0.5, series[i].forecast),
                    ],
                    isCurved: false,
                    color: AppColors.chart2,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.chart2,
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
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
