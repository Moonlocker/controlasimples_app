import 'package:flutter_controlasimples/widgets/money_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata centavos como moeda brasileira', () {
    expect(CurrencyInputFormatter.formatCents(123456), 'R\$ 1.234,56');
    expect(CurrencyInputFormatter.formatCents(5), 'R\$ 0,05');
  });

  test('interpreta texto formatado de volta para valor', () {
    expect(CurrencyInputFormatter.parse('R\$ 1.234,56'), 1234.56);
    expect(CurrencyInputFormatter.parse(''), 0);
  });
}
