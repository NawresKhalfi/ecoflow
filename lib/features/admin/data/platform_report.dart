import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../recycler/data/report_export.dart';
import '../domain/platform_stats.dart';

/// Textes du rapport global, résolus par l'appelant (US-115).
class PlatformReportLabels {
  const PlatformReportLabels({
    required this.title,
    required this.period,
    required this.generatedOn,
    required this.kpis,
    required this.byMaterial,
    required this.material,
    required this.share,
    required this.materialName,
    required this.methodNote,
  });

  final String title;
  final String period;
  final String generatedOn;

  /// (libellé, valeur) déjà formatés : tonnes, collectes, CO₂, taux…
  final List<(String, String)> kpis;
  final String byMaterial;
  final String material;
  final String share;
  final String Function(String) materialName;
  final String methodNote;
}

const _green = PdfColor.fromInt(0xFF0B7A4B);
const _paper = PdfColor.fromInt(0xFFF4EFE4);

List<List<String>> _rows(PlatformStats s, PlatformReportLabels l) => [
  for (final e in (s.kgByMaterial.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
    [
      l.materialName(e.key.name),
      e.value.toStringAsFixed(1),
      '${(s.totalKg == 0 ? 0 : e.value / s.totalKg * 100).round()} %',
    ],
];

Future<Uint8List> buildPlatformPdf(PlatformStats s, PlatformReportLabels l, {ByteData? font}) async {
  final f = font == null ? null : pw.Font.ttf(font);
  final doc = pw.Document(
    theme: f == null ? null : pw.ThemeData.withFont(base: f, bold: f, italic: f, boldItalic: f),
    title: l.title,
    author: 'EcoFlow',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(l.title, style: pw.TextStyle(fontSize: 22, color: _green, fontWeight: pw.FontWeight.bold)),
        pw.Text(l.period),
        pw.Text(l.generatedOn, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 14),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (k, v) in l.kpis)
              pw.Container(
                width: 160,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: _paper, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(v, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(k, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(l.byMaterial, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: [l.material, 'kg', l.share],
          data: _rows(s, l),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: _green),
          cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 16),
        pw.Text(l.methodNote, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ),
  );
  return doc.save();
}

Uint8List buildPlatformXlsx(PlatformStats s, PlatformReportLabels l) => buildXlsx([
  (
    l.title,
    [
      [l.title, l.period],
      for (final (k, v) in l.kpis) [k, v],
    ],
    const <int>{},
  ),
  (
    l.byMaterial,
    [
      [l.material, 'kg', l.share],
      ..._rows(s, l),
    ],
    {1},
  ),
]);
