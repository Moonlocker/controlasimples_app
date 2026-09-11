import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/derive.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/period.dart';
import '../../models/workspace.dart';

Future<Uint8List> buildReportPdf({
  required Workspace scoped,
  required PeriodRange? range,
  required String rangeText,
  required RangeSummary summary,
  String? company,
  String? clientName,
  String? serviceName,
}) async {
  final document = pw.Document();
  final views = chargeViews(scoped);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(company ?? 'Controla Simples',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Relatório financeiro'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Período: $rangeText'),
                if (clientName != null) pw.Text('Cliente: $clientName'),
                if (serviceName != null) pw.Text('Serviço: $serviceName'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _metric('Recebido', brl(summary.received)),
            _metric('Em aberto', brl(summary.open)),
            _metric('Atrasado', brl(summary.overdue)),
            _metric('Ticket médio', brl(summary.avgTicket)),
            _metric('Taxa de recebimento', '${summary.receiveRate.toStringAsFixed(0)}%'),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('Cobranças', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Cliente', 'Descrição', 'Serviço', 'Vencimento', 'Valor', 'Status'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {
            4: pw.Alignment.centerRight,
            5: pw.Alignment.center,
          },
          data: [
            for (final view in views)
              [
                view.clientName,
                view.description,
                view.serviceName ?? '',
                formatDate(view.dueDate),
                brl(view.amount),
                view.status.label,
              ],
          ],
        ),
      ],
    ),
  );

  return document.save();
}

pw.Widget _metric(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    ],
  );
}
