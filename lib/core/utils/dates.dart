DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime today() => dateOnly(DateTime.now());

String isoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String monthKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  return '${value.year}-$month';
}

DateTime? tryParseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return dateOnly(value);
  final text = value.toString();
  if (text.isEmpty) return null;
  return dateOnly(DateTime.parse(text));
}

DateTime parseDate(Object? value, {DateTime? fallback}) {
  return tryParseDate(value) ?? fallback ?? today();
}

DateTime? tryParseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

int daysBetween(DateTime from, DateTime to) {
  return dateOnly(to).difference(dateOnly(from)).inDays;
}

DateTime addMonths(DateTime date, int months, [int? dueDay]) {
  final base = DateTime(date.year, date.month + months, 1);
  final day = dueDay ?? date.day;
  final lastDay = DateTime(base.year, base.month + 1, 0).day;
  return DateTime(base.year, base.month, day.clamp(1, lastDay));
}
