import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/analytics.dart';

/// Textes du rapport, résolus par l'appelant dans la langue voulue.
class ReportLabels {
  const ReportLabels({
    required this.title,
    required this.company,
    required this.period,
    required this.filters,
    required this.generatedOn,
    required this.total,
    required this.deposits,
    required this.quality,
    required this.byMaterial,
    required this.byCollector,
    required this.lots,
    required this.material,
    required this.kg,
    required this.share,
    required this.collector,
    required this.date,
    required this.grade,
    required this.reference,
    required this.zones,
    required this.materialName,
    required this.fmtDate,
  });

  final String title;
  final String company;
  final String period;
  final String filters;
  final String generatedOn;
  final String total;
  final String deposits;
  final String quality;
  final String byMaterial;
  final String byCollector;
  final String lots;
  final String material;
  final String kg;
  final String share;
  final String collector;
  final String date;
  final String grade;
  final String reference;
  final String zones;
  final String Function(String material) materialName;
  final String Function(DateTime) fmtDate;
}

String _kg(double v) => v.toStringAsFixed(1);
String _pct(double v) => '${(v * 100).toStringAsFixed(0)} %';

List<List<String>> _materialRows(SupplyReport r, ReportLabels l) => [
  for (final e in r.ranked)
    [l.materialName(e.key.name), _kg(e.value), _pct(r.totalKg == 0 ? 0 : e.value / r.totalKg)],
];

List<List<String>> _collectorRows(SupplyReport r) => [
  for (final c in r.byCollector.values.toList()..sort((a, b) => b.kg.compareTo(a.kg)))
    [c.name, _kg(c.kg)],
];

List<List<String>> _lotRows(SupplyReport r, ReportLabels l) => [
  for (final lot in r.lots)
    [
      lot.reference,
      lot.receivedAt == null ? '' : l.fmtDate(lot.receivedAt!),
      l.materialName(lot.material.name),
      lot.grade.name.toUpperCase(),
      _kg(lot.initialKg),
      lot.collectorName ?? '',
      lot.zoneIds.join(', '),
    ],
];

/// Rapport PDF (US-083). [font] : police TTF embarquée (accents).
Future<Uint8List> buildSupplyPdf(SupplyReport r, ReportLabels l, {ByteData? font}) async {
  // Même police pour toutes les graisses : les polices PDF standard
  // n'ont pas l'Unicode (apostrophe typographique, accents).
  final f = font == null ? null : pw.Font.ttf(font);
  final theme = f == null
      ? null
      : pw.ThemeData.withFont(base: f, bold: f, italic: f, boldItalic: f);
  final doc = pw.Document(theme: theme, title: l.title, author: l.company);
  const green = PdfColor.fromInt(0xFF0B7A4B);
  pw.Widget table(List<String> head, List<List<String>> rows) => pw.TableHelper.fromTextArray(
    headers: head,
    data: rows,
    headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: green),
    cellAlignments: {for (var i = 1; i < head.length; i++) i: pw.Alignment.centerRight},
    cellStyle: const pw.TextStyle(fontSize: 10),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(
          l.title,
          style: pw.TextStyle(fontSize: 22, color: green, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('${l.company} · ${l.period}'),
        if (l.filters.isNotEmpty) pw.Text(l.filters, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(l.generatedOn, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            for (final (k, v) in [
              (l.total, '${_kg(r.totalKg)} kg'),
              (l.deposits, '${r.deposits}'),
              (l.quality, _pct(r.quality)),
            ])
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF4EFE4),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(k, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(v, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(l.byMaterial, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        table([l.material, l.kg, l.share], _materialRows(r, l)),
        pw.SizedBox(height: 16),
        pw.Text(l.byCollector, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        table([l.collector, l.kg], _collectorRows(r)),
        pw.SizedBox(height: 16),
        pw.Text(l.lots, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        table([
          l.reference,
          l.date,
          l.material,
          l.grade,
          l.kg,
          l.collector,
          l.zones,
        ], _lotRows(r, l)),
      ],
    ),
  );
  return doc.save();
}

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _col(int i) => String.fromCharCode(65 + i);

/// Feuille SpreadsheetML : nombres en cellules numériques, texte en ligne.
String _sheet(List<List<String>> rows, {Set<int> numeric = const {}}) {
  final b = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (final (r, row) in rows.indexed) {
    b.write('<row r="${r + 1}">');
    for (final (c, v) in row.indexed) {
      final ref = '${_col(c)}${r + 1}';
      final n = double.tryParse(v);
      if (r > 0 && numeric.contains(c) && n != null) {
        b.write('<c r="$ref"><v>$n</v></c>');
      } else {
        b.write('<c r="$ref" t="inlineStr"><is><t>${_xml(v)}</t></is></c>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

/// Classeur Excel (.xlsx) : une feuille par entrée (nom, lignes, colonnes
/// numériques). Construit à la main (SpreadsheetML) : pas de dépendance.
Uint8List buildXlsx(List<(String, List<List<String>>, Set<int>)> sheets) {
  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  const ns = 'http://schemas.openxmlformats.org';
  add(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="$ns/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '${[for (var i = 1; i <= sheets.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$ns/package/2006/relationships">'
        '<Relationship Id="rId1" Type="$ns/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
  );
  add(
    'xl/workbook.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="$ns/spreadsheetml/2006/main" xmlns:r="$ns/officeDocument/2006/relationships"><sheets>'
        '${[for (final (i, s) in sheets.indexed) '<sheet name="${_xml(s.$1.length > 31 ? s.$1.substring(0, 31) : s.$1)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$ns/package/2006/relationships">'
        '${[for (var i = 1; i <= sheets.length; i++) '<Relationship Id="rId$i" Type="$ns/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
        '</Relationships>',
  );
  for (final (i, s) in sheets.indexed) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheet(s.$2, numeric: s.$3));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Classeur Excel (.xlsx) à deux feuilles : synthèse et lots (US-083).
Uint8List buildSupplyXlsx(SupplyReport r, ReportLabels l) {
  final summary = [
    [l.title, ''],
    [l.company, l.period],
    [l.total, _kg(r.totalKg)],
    [l.deposits, '${r.deposits}'],
    [l.quality, _pct(r.quality)],
    ['', ''],
    [l.material, l.kg, l.share],
    ..._materialRows(r, l),
    ['', ''],
    [l.collector, l.kg],
    ..._collectorRows(r),
  ];
  final lots = [
    [l.reference, l.date, l.material, l.grade, l.kg, l.collector, l.zones],
    ..._lotRows(r, l),
  ];
  return buildXlsx([
    (l.byMaterial, summary, {1}),
    (l.lots, lots, {4}),
  ]);
}

/// Nom de fichier du rapport, sans caractère problématique.
String reportFileName(String ext, DateTime now) =>
    'ecoflow_approvisionnements_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.$ext';
