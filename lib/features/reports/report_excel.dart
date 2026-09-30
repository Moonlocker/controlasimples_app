import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../core/utils/derive.dart';
import '../../core/utils/formatters.dart';
import '../../models/workspace.dart';

/// Gera um arquivo Excel (.xlsx) com o resumo, as cobranças e os pagamentos do
/// relatório filtrado.
///
/// A escrita é feita diretamente no formato OpenXML (zip + XML) para evitar
/// dependências que conflitam com o gerador de PDF usado no aplicativo.
Uint8List buildReportExcel({
  required Workspace scoped,
  required RangeSummary summary,
  required String rangeText,
  String? company,
  String? clientName,
  String? serviceName,
}) {
  final resumo = <List<Object?>>[
    [company ?? 'Controla Simples'],
    ['Relatório financeiro'],
    [],
    ['Período', rangeText],
    if (clientName != null) ['Cliente', clientName],
    if (serviceName != null) ['Serviço', serviceName],
    [],
    ['Indicador', 'Valor'],
    ['Recebido', summary.received],
    ['Em aberto', summary.open],
    ['Atrasado', summary.overdue],
    ['Ticket médio', summary.avgTicket],
    ['Cobranças', summary.totalCharges],
    ['Cobranças pagas', summary.paidCount],
    [
      'Taxa de recebimento (%)',
      double.parse(summary.receiveRate.toStringAsFixed(2)),
    ],
  ];

  final cobrancas = <List<Object?>>[
    ['Cliente', 'Descrição', 'Serviço', 'Vencimento', 'Valor', 'Status'],
    for (final view in chargeViews(scoped))
      [
        view.clientName,
        view.description,
        view.serviceName ?? '',
        formatDate(view.dueDate),
        view.amount,
        view.status.label,
      ],
  ];

  final pagamentos = <List<Object?>>[
    ['Data', 'Cobrança', 'Cliente', 'Valor', 'Forma'],
    for (final payment in scoped.payments)
      () {
        final charge = scoped.chargeById(payment.chargeId);
        return [
          formatDate(payment.paidAt),
          charge?.description ?? '',
          charge == null ? '' : scoped.clientName(charge.clientId),
          payment.amount,
          payment.method.label,
        ];
      }(),
  ];

  return _XlsxWriter([
    _Sheet('Resumo', resumo),
    _Sheet('Cobranças', cobrancas),
    _Sheet('Pagamentos', pagamentos),
  ]).build();
}

class _Sheet {
  const _Sheet(this.name, this.rows);

  final String name;
  final List<List<Object?>> rows;
}

class _XlsxWriter {
  _XlsxWriter(this.sheets);

  final List<_Sheet> sheets;

  Uint8List build() {
    final archive = Archive();

    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes());
    add('_rels/.rels', _rootRels());
    add('xl/workbook.xml', _workbook());
    add('xl/_rels/workbook.xml.rels', _workbookRels());
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  String _contentTypes() {
    final overrides = StringBuffer()
      ..writeln(
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.'
        'spreadsheetml.sheet.main+xml"/>',
      );
    for (var i = 0; i < sheets.length; i++) {
      overrides.writeln(
        '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.'
        'spreadsheetml.worksheet+xml"/>',
      );
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" '
        'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '$overrides'
        '</Types>';
  }

  String _rootRels() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/>'
        '</Relationships>';
  }

  String _workbook() {
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>',
    );
    for (var i = 0; i < sheets.length; i++) {
      buffer.write(
        '<sheet name="${_escape(sheets[i].name)}" sheetId="${i + 1}" '
        'r:id="rId${i + 1}"/>',
      );
    }
    buffer.write('</sheets></workbook>');
    return buffer.toString();
  }

  String _workbookRels() {
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
    for (var i = 0; i < sheets.length; i++) {
      buffer.write(
        '<Relationship Id="rId${i + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet${i + 1}.xml"/>',
      );
    }
    buffer.write('</Relationships>');
    return buffer.toString();
  }

  String _sheetXml(_Sheet sheet) {
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );
    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;
      buffer.write('<row r="${r + 1}">');
      for (var c = 0; c < row.length; c++) {
        final value = row[c];
        if (value == null) continue;
        final ref = '${_columnName(c)}${r + 1}';
        if (value is num) {
          buffer.write('<c r="$ref"><v>$value</v></c>');
        } else {
          buffer.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${_escape(value.toString())}</t></is></c>',
          );
        }
      }
      buffer.write('</row>');
    }
    buffer.write('</sheetData></worksheet>');
    return buffer.toString();
  }

  String _columnName(int index) {
    var value = index;
    final name = StringBuffer();
    while (value >= 0) {
      name.writeCharCode(65 + (value % 26));
      value = (value ~/ 26) - 1;
    }
    return name.toString().split('').reversed.join();
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ');
}
