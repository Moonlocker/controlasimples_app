import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/dates.dart';
import '../core/utils/period.dart';

class PeriodSelection {
  const PeriodSelection(this.range);

  final PeriodRange? range;
}

/// Abre o seletor de período (presets + intervalo personalizado).
Future<PeriodSelection?> showPeriodPicker(
  BuildContext context, {
  required PeriodRange? current,
  DateTime? earliest,
  String nullLabel = 'Todos os períodos',
}) {
  return showModalBottomSheet<PeriodSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _PeriodPickerSheet(
      current: current,
      earliest: earliest,
      nullLabel: nullLabel,
    ),
  );
}

class _PeriodPickerSheet extends StatelessWidget {
  const _PeriodPickerSheet({
    required this.current,
    required this.earliest,
    required this.nullLabel,
  });

  final PeriodRange? current;
  final DateTime? earliest;
  final String nullLabel;

  Future<void> _pickCustom(BuildContext context) async {
    final now = today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: earliest ?? DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: current == null
          ? null
          : DateTimeRange(start: current!.from, end: current!.to),
      helpText: 'Selecione o período',
      saveText: 'Aplicar',
    );
    if (picked != null && context.mounted) {
      Navigator.of(context)
          .pop(PeriodSelection(PeriodRange(picked.start, picked.end)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final activePreset = current == null
        ? PeriodPreset.all
        : PeriodPreset.values.where((preset) {
            final range = presetRange(preset, earliest);
            if (range == null || current == null) return false;
            return range.from == current!.from && range.to == current!.to;
          }).firstOrNull;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Período',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in PeriodPreset.values)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected: activePreset == preset,
                    showCheckmark: false,
                    onSelected: (_) => Navigator.of(context)
                        .pop(PeriodSelection(presetRange(preset, earliest))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _pickCustom(context),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: const Text('Escolher intervalo personalizado'),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(
              Icons.all_inclusive,
              color: AppColors.mutedForeground,
            ),
            title: Text(nullLabel),
            onTap: () => Navigator.of(context).pop(const PeriodSelection(null)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Barra reutilizável com setas para navegar mês a mês e abrir o seletor.
class PeriodBar extends StatelessWidget {
  const PeriodBar({
    super.key,
    required this.range,
    required this.onChanged,
    this.earliest,
    this.nullLabel = 'Todos os períodos',
    this.showArrows = true,
  });

  final PeriodRange? range;
  final ValueChanged<PeriodRange?> onChanged;
  final DateTime? earliest;
  final String nullLabel;
  final bool showArrows;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showArrows)
          IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(shiftPeriod(range, -1)),
          ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final result = await showPeriodPicker(
                context,
                current: range,
                earliest: earliest,
                nullLabel: nullLabel,
              );
              if (result != null) onChanged(result.range);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      rangeLabel(range, nullLabel: nullLabel),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showArrows)
          IconButton(
            tooltip: 'Próximo mês',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(shiftPeriod(range, 1)),
          ),
      ],
    );
  }
}
