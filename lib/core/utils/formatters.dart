import 'package:intl/intl.dart';

import 'dates.dart';

final NumberFormat _currency = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);

final DateFormat _shortDate = DateFormat('dd/MM/yyyy', 'pt_BR');
final DateFormat _monthShort = DateFormat('MMM', 'pt_BR');
final DateFormat _monthLong = DateFormat('MMMM yyyy', 'pt_BR');

String brl(num value) => _currency.format(value);

String brlCompact(num value) {
  if (value.abs() >= 1000000) {
    return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) {
    return 'R\$ ${(value / 1000).toStringAsFixed(1)}k';
  }
  return brl(value);
}

String formatDate(DateTime value) => _shortDate.format(value);

String monthLabel(String key) {
  final parts = key.split('-');
  if (parts.length < 2) return key;
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  return _monthShort.format(date).replaceAll('.', '');
}

String monthLongLabel(String key) {
  final parts = key.split('-');
  if (parts.length < 2) return key;
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  return _monthLong.format(date);
}

String initials(String value) {
  final words = value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final first = words.first.substring(0, 1);
  final second = words.length > 1 ? words[1].substring(0, 1) : '';
  return (first + second).toUpperCase();
}

String todayIso() => isoDate(today());

String phoneMask(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final d = digits.length > 11 ? digits.substring(0, 11) : digits;
  if (d.length <= 2) return d;
  if (d.length <= 6) return '(${d.substring(0, 2)}) ${d.substring(2)}';
  if (d.length <= 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
}

String cpfCnpjMask(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final d = digits.length > 14 ? digits.substring(0, 14) : digits;
  if (d.length <= 11) {
    final buffer = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(d[i]);
    }
    return buffer.toString();
  }
  final buffer = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 5) buffer.write('.');
    if (i == 8) buffer.write('/');
    if (i == 12) buffer.write('-');
    buffer.write(d[i]);
  }
  return buffer.toString();
}

String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');
