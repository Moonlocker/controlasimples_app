import 'package:flutter/material.dart';

import '../core/constants/enums.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';

class RecordRow {
  const RecordRow({
    required this.clientName,
    required this.description,
    required this.amount,
    required this.date,
    this.dateLabel = 'Vence',
    this.serviceName,
    this.method,
    this.status,
    this.badgeLabel,
    this.note,
  });

  final String clientName;
  final String? serviceName;
  final String description;
  final double amount;
  final DateTime date;
  final String dateLabel;
  final PaymentMethod? method;
  final ChargeStatus? status;
  final String? badgeLabel;
  final String? note;
}

class RecordSection {
  const RecordSection({
    required this.title,
    required this.rows,
    this.hint,
    this.tone = AppColors.info,
  });

  final String title;
  final String? hint;
  final Color tone;
  final List<RecordRow> rows;
}

Future<void> showRecordsSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<RecordSection> sections,
  String emptyHint = 'Nenhum registro no período.',
}) {
  final hasRows = sections.any((section) => section.rows.isNotEmpty);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !hasRows
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        emptyHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      for (final section in sections)
                        if (section.rows.isNotEmpty) ...[
                          _SectionHeader(section: section),
                          for (final row in section.rows) _RecordTile(row: row),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final RecordSection section;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = section.rows.fold<double>(0, (sum, row) => sum + row.amount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: section.tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (section.hint != null)
                  Text(
                    section.hint!,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ),
          Text(
            brl(total),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.row});

  final RecordRow row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.clientName,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  row.serviceName == null
                      ? row.description
                      : '${row.description} · ${row.serviceName}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${row.dateLabel} ${formatDate(row.date)}',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                    ),
                    if (row.method != null) ...[
                      Text(
                        ' · ${row.method!.label}',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                    if (row.note != null) ...[
                      Text(
                        ' · ${row.note}',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                brl(row.amount),
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (row.badgeLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  row.badgeLabel!,
                  style: textTheme.labelSmall?.copyWith(
                    color: row.status == ChargeStatus.atrasado
                        ? AppColors.danger
                        : AppColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
