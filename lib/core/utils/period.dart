import 'dates.dart';
import 'formatters.dart';

/// Intervalo inclusivo de dias. `null` representa "todos os períodos".
class PeriodRange {
  const PeriodRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  bool contains(DateTime value) =>
      !dateOnly(value).isBefore(dateOnly(from)) && !dateOnly(value).isAfter(dateOnly(to));
}

PeriodRange monthWindowOf(DateTime date) => PeriodRange(
      DateTime(date.year, date.month, 1),
      DateTime(date.year, date.month + 1, 0),
    );

PeriodRange currentMonthWindow() => monthWindowOf(today());

bool isMonthAligned(PeriodRange range) {
  if (monthKey(range.from) != monthKey(range.to)) return false;
  final start = DateTime(range.from.year, range.from.month, 1);
  final end = DateTime(range.from.year, range.from.month + 1, 0);
  return isoDate(range.from) == isoDate(start) && isoDate(range.to) == isoDate(end);
}

String? monthKeyOf(PeriodRange range) => isMonthAligned(range) ? monthKey(range.from) : null;

bool isCurrentMonth(PeriodRange range) =>
    isMonthAligned(range) && monthKey(range.from) == monthKey(today());

PeriodRange shiftPeriod(PeriodRange? range, int offset) {
  final base = range == null
      ? DateTime(today().year, today().month)
      : DateTime(range.from.year, range.from.month);
  final from = addMonths(base, offset);
  return PeriodRange(from, DateTime(from.year, from.month + 1, 0));
}

String rangeLabel(PeriodRange? range, {String nullLabel = 'Todos os períodos'}) {
  if (range == null) return nullLabel;
  final single = monthKeyOf(range);
  if (single != null) return monthLongLabel(single);
  if (isoDate(range.from) == isoDate(range.to)) return formatDate(range.from);
  return '${formatDate(range.from)} — ${formatDate(range.to)}';
}

enum PeriodPreset {
  month('Este mês'),
  prevMonth('Mês passado'),
  threeMonths('Últimos 3 meses'),
  ninetyDays('Últimos 90 dias'),
  year('Este ano'),
  all('Desde o início');

  const PeriodPreset(this.label);

  final String label;
}

PeriodRange? presetRange(PeriodPreset preset, DateTime? earliest, [DateTime? now]) {
  final reference = now ?? today();
  final y = reference.year;
  final m = reference.month;
  switch (preset) {
    case PeriodPreset.month:
      return PeriodRange(DateTime(y, m, 1), DateTime(y, m + 1, 0));
    case PeriodPreset.prevMonth:
      return PeriodRange(DateTime(y, m - 1, 1), DateTime(y, m, 0));
    case PeriodPreset.threeMonths:
      return PeriodRange(DateTime(y, m - 2, 1), reference);
    case PeriodPreset.ninetyDays:
      return PeriodRange(DateTime(y, m, reference.day - 89), reference);
    case PeriodPreset.year:
      return PeriodRange(DateTime(y, 1, 1), DateTime(y, 12, 31));
    case PeriodPreset.all:
      return earliest == null ? null : PeriodRange(earliest, reference);
  }
}
