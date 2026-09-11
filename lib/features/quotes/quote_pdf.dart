import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/formatters.dart';
import '../../models/quote.dart';
import '../../models/user_business.dart';
import '../../repositories/workspace_providers.dart';
import 'quotes_providers.dart';

Future<void> previewQuotePdf(BuildContext context, WidgetRef ref, Quote quote) async {
  final workspace = ref.read(workspaceProvider).value;
  final business = ref.read(businessProvider).value;
  final profile = workspace?.profile;
  final bytes = await buildQuotePdf(
    quote: quote,
    clientName: workspace?.clientName(quote.clientId) ?? '—',
    business: business,
    fallbackCompany: profile?.company,
    fallbackPhone: profile?.phone,
    fallbackEmail: profile?.email,
    fallbackDocument: profile?.document,
  );
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: quote.number);
}

Future<Uint8List> buildQuotePdf({
  required Quote quote,
  required String clientName,
  UserBusiness? business,
  String? fallbackCompany,
  String? fallbackPhone,
  String? fallbackEmail,
  String? fallbackDocument,
}) async {
  final document = pw.Document();
  final company = business?.company ?? fallbackCompany ?? 'Controla Simples';
  final documentId = business?.document ?? fallbackDocument;
  final email = business?.email ?? fallbackEmail;
  final phone = business?.phone ?? fallbackPhone;
  final isModern = quote.layout != 'classico';
  final accent = isModern ? PdfColor.fromInt(0xFFEE6A3B) : PdfColors.grey800;
  pw.MemoryImage? logoImage;
  final logo = business?.logo;
  if (logo != null && logo.contains(',')) {
    try {
      logoImage = pw.MemoryImage(base64Decode(logo.split(',').last));
    } catch (_) {
      logoImage = null;
    }
  }

  pw.Widget identity() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoImage != null) ...[
            pw.Image(logoImage, height: 42, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 6),
          ],
          pw.Text(company,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: isModern ? PdfColors.white : PdfColors.black,
              )),
          if (documentId != null)
            pw.Text('CNPJ/CPF: $documentId',
                style: pw.TextStyle(color: isModern ? PdfColors.white : PdfColors.black)),
          if (phone != null)
            pw.Text(phone, style: pw.TextStyle(color: isModern ? PdfColors.white : PdfColors.black)),
          if (email != null)
            pw.Text(email, style: pw.TextStyle(color: isModern ? PdfColors.white : PdfColors.black)),
        ],
      );

  pw.Widget titleBlock() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('ORÇAMENTO',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: isModern ? PdfColors.white : accent,
              )),
          pw.Text(quote.number, style: pw.TextStyle(color: isModern ? PdfColors.white : PdfColors.black)),
          pw.Text('Emitido em ${formatDate(quote.issuedOn)}',
              style: pw.TextStyle(color: isModern ? PdfColors.white : PdfColors.black)),
          if (quote.validUntil != null)
            pw.Text('Válido até ${formatDate(quote.validUntil!)}',
                style: pw.TextStyle(color: isModern ? PdfColors.white : PdfColors.black)),
        ],
      );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        if (isModern)
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [identity(), titleBlock()],
            ),
          )
        else
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [identity(), titleBlock()],
          ),
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(quote.title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Cliente: $clientName'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Descrição', 'Qtd', 'Valor', 'Total'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: [
            for (final item in quote.items)
              [
                item.description,
                item.qty.toString(),
                brl(item.price),
                brl(item.total),
              ],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 220,
            child: pw.Column(
              children: [
                _totalRow('Subtotal', brl(quote.subtotal)),
                if (quote.discount > 0) _totalRow('Desconto', '- ${brl(quote.discount)}'),
                pw.Divider(),
                _totalRow('Total', brl(quote.total), bold: true),
              ],
            ),
          ),
        ),
        if (quote.note != null && quote.note!.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('Observações', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(quote.note!),
        ],
        if (business?.paymentInfo != null && business!.paymentInfo!.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Formas de pagamento',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(business.paymentInfo!),
        ],
      ],
    ),
  );

  return document.save();
}

pw.Widget _totalRow(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontSize: bold ? 12 : 11,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    ),
  );
}
