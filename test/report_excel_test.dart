import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_controlasimples/core/constants/enums.dart';
import 'package:flutter_controlasimples/core/utils/derive.dart';
import 'package:flutter_controlasimples/features/reports/report_excel.dart';
import 'package:flutter_controlasimples/models/charge.dart';
import 'package:flutter_controlasimples/models/client.dart';
import 'package:flutter_controlasimples/models/payment.dart';
import 'package:flutter_controlasimples/models/workspace.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  final now = DateTime(2026, 9, 29);
  final client = Client(
    id: 'c1',
    userId: 'u1',
    name: 'Maria & Filhos',
    createdAt: now,
  );
  final charge = Charge(
    id: 'ch1',
    userId: 'u1',
    clientId: 'c1',
    description: 'Mensalidade <setembro>',
    amount: 1234.5,
    dueDate: now,
    status: ChargeStatus.pago,
    createdAt: now,
  );
  final payment = Payment(
    id: 'p1',
    userId: 'u1',
    chargeId: 'ch1',
    amount: 1234.5,
    paidAt: now,
    method: PaymentMethod.pix,
    createdAt: now,
  );
  final workspace = Workspace(
    clients: [client],
    charges: [charge],
    payments: [payment],
  );
  const summary = RangeSummary(
    received: 1234.5,
    open: 0,
    overdue: 0,
    avgTicket: 1234.5,
    paidCount: 1,
    totalCharges: 1,
  );

  test('gera um xlsx válido com as três abas e dados escapados', () {
    final bytes = buildReportExcel(
      scoped: workspace,
      summary: summary,
      rangeText: 'Setembro/2026',
    );

    expect(bytes, isNotEmpty);
    expect(bytes.take(2).toList(), [0x50, 0x4B]); // "PK" (assinatura do zip)

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, contains('xl/workbook.xml'));
    expect(names, contains('xl/worksheets/sheet1.xml'));
    expect(names, contains('xl/worksheets/sheet2.xml'));
    expect(names, contains('xl/worksheets/sheet3.xml'));

    final workbook = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'xl/workbook.xml').content
          as List<int>,
    );
    expect(workbook, contains('Resumo'));
    expect(workbook, contains('Cobranças'));
    expect(workbook, contains('Pagamentos'));

    final sheet2 = utf8.decode(
      archive.files
              .firstWhere((f) => f.name == 'xl/worksheets/sheet2.xml')
              .content
          as List<int>,
    );
    // Texto do cliente/descrição precisa estar escapado no XML.
    expect(sheet2, contains('Maria &amp; Filhos'));
    expect(sheet2, contains('Mensalidade &lt;setembro&gt;'));
    // Valor numérico vira célula numérica.
    expect(sheet2, contains('1234.5'));
  });
}
