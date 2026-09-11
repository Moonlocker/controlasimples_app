import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final formatted = formatCents(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatCents(int cents) {
    final raw = cents.toString().padLeft(3, '0');
    final integer = raw.substring(0, raw.length - 2);
    final decimals = raw.substring(raw.length - 2);
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      if (i > 0 && (integer.length - i) % 3 == 0) buffer.write('.');
      buffer.write(integer[i]);
    }
    return 'R\$ $buffer,$decimals';
  }

  static String fromDouble(double value) {
    if (value <= 0) return '';
    return formatCents((value * 100).round());
  }

  static double parse(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits) / 100;
  }
}

class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label = 'Valor',
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [CurrencyInputFormatter()],
      decoration: InputDecoration(labelText: label, prefixText: null),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
