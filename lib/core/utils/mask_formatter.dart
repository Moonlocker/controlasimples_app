import 'package:flutter/services.dart';

/// Aplica uma máscara (CPF/CNPJ, telefone, etc.) enquanto o usuário digita.
class MaskTextInputFormatter extends TextInputFormatter {
  MaskTextInputFormatter(this.mask);

  final String Function(String) mask;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final masked = mask(newValue.text);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}
