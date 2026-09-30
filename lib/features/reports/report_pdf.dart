import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/theme/app_colors.dart' show AppColors;
import '../../core/utils/derive.dart';
import '../../core/utils/formatters.dart';
import '../../models/workspace.dart';

Future<Uint8List> buildReportPdf({
  required Workspace scoped,
  required String rangeText,
  required RangeSummary summary,
  String? company,
  String? clientName,
  String? serviceName,
}) async {
  final document = pw.Document();
  final views = chargeViews(scoped);
  final payments = scoped.payments;
  final generatedAt = DateTime.now();

  final headerStyle = pw.TextStyle(
    fontWeight: pw.FontWeight.bold,
    fontSize: 10,
  );
  final cellStyle = const pw.TextStyle(fontSize: 9);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  company ?? 'Controla Simples',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(AppColors.primary.toARGB32()),
                  ),
                ),
                pw.Text('Relatório financeiro'),
                pw.Text(
                  'Gerado em ${formatDate(generatedAt)}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
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
            _metric('Recebido', brl(summary.received), AppColors.success),
            _metric('Em aberto', brl(summary.open), AppColors.info),
            _metric('Atrasado', brl(summary.overdue), AppColors.danger),
            _metric('Ticket médio', brl(summary.avgTicket), AppColors.primary),
            _metric(
              'Taxa de recebimento',
              '${summary.receiveRate.toStringAsFixed(0)}%',
              AppColors.warning,
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Cobranças (${views.length})',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Cliente',
            'Descrição',
            'Serviço',
            'Vencimento',
            'Valor',
            'Status',
          ],
          headerStyle: headerStyle,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: cellStyle,
          cellAlignments: {4: pw.Alignment.centerRight, 5: pw.Alignment.center},
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
        pw.SizedBox(height: 20),
        pw.Text(
          'Pagamentos (${payments.length})',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Data', 'Cobrança', 'Cliente', 'Forma', 'Valor'],
          headerStyle: headerStyle,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: cellStyle,
          cellAlignments: {4: pw.Alignment.centerRight},
          data: [
            for (final payment in payments)
              () {
                final charge = scoped.chargeById(payment.chargeId);
                return [
                  formatDate(payment.paidAt),
                  charge?.description ?? '',
                  charge == null ? '' : scoped.clientName(charge.clientId),
                  payment.method.label,
                  brl(payment.amount),
                ];
              }(),
          ],
        ),
      ],
    ),
  );

  return document.save();
}

pw.Widget _metric(String label, String value, Color accent) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(accent.toARGB32()),
        ),
      ),
    ],
  );
}
