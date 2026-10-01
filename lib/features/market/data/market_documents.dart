import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../recycler/domain/stock.dart';
import '../domain/market.dart';

const _green = PdfColor.fromInt(0xFF0B7A4B);
const _paper = PdfColor.fromInt(0xFFF4EFE4);

pw.ThemeData? _theme(ByteData? font) {
  if (font == null) return null;
  final f = pw.Font.ttf(font);
  return pw.ThemeData.withFont(base: f, bold: f, italic: f, boldItalic: f);
}

String _n(double v, [int digits = 3]) => v.toStringAsFixed(digits);

pw.Widget _kv(String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 150,
        child: pw.Text(k, style: const pw.TextStyle(color: PdfColors.grey700)),
      ),
      pw.Expanded(child: pw.Text(v)),
    ],
  ),
);

/// Facture d'une commande (US-104). [t] : textes résolus par l'appelant.
Future<Uint8List> buildInvoicePdf(
  MarketOrder o,
  Map<String, String> t, {
  required String material,
  required String date,
  ByteData? font,
}) async {
  final doc = pw.Document(theme: _theme(font), title: '${t['invoice']} ${o.number}');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EcoFlow',
                style: pw.TextStyle(fontSize: 22, color: _green, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${t['invoice']} ${o.number}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Text(date),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (label, name) in [
                (t['seller']!, o.sellerName),
                (t['buyer']!, o.buyerName),
              ])
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 10),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: _paper,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          label,
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                        pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: [t['item']!, t['qty']!, t['unit']!, t['amount']!],
            data: [
              [
                material,
                '${_n(o.quantityKg, 1)} kg',
                '${_n(o.priceDtPerKg)} DT',
                '${_n(o.totalHt)} DT',
              ],
            ],
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: _green),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _kv(t['totalHt']!, '${_n(o.totalHt)} DT'),
                  _kv('${t['vat']} ${(vatRate * 100).round()} %', '${_n(o.vat)} DT'),
                  pw.Divider(),
                  _kv(t['totalTtc']!, '${_n(o.totalTtc)} DT'),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 18),
          _kv(t['payment']!, t['paymentStatus']!),
          _kv(t['delivery']!, t['deliveryValue']!),
          pw.Spacer(),
          pw.Text(t['footer']!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Certificat de recyclage d'un ou plusieurs lots (US-105) : quantités,
/// origine (collectes, zones), émissions évitées estimées.
Future<Uint8List> buildCertificatePdf(
  List<StockLot> lots,
  Map<String, String> t, {
  required String company,
  required String number,
  required String date,
  required String Function(StockLot) materialOf,
  String? beneficiary,
  int? pickups,
  String Function(StockLot)? referenceOf,
  String Function(double)? fmt,
  ByteData? font,
}) async {
  final num = fmt ?? (double v) => _n(v, 1);
  final refOf = referenceOf ?? (StockLot l) => l.reference;
  final kg = lots.fold(0.0, (s, l) => s + l.initialKg);
  final co2 = lots.fold(0.0, (s, l) => s + l.initialKg * co2AvoidedPerKg(l.material));
  final pickupCount = pickups ?? {for (final l in lots) ...l.missions.map((m) => m.id)}.length;
  final zones = {for (final l in lots) ...l.zoneIds};
  final doc = pw.Document(theme: _theme(font), title: '${t['certificate']} $number');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(24),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _green, width: 3),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              t['certificate']!.toUpperCase(),
              style: pw.TextStyle(fontSize: 24, color: _green, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('N° $number · $date'),
            pw.SizedBox(height: 18),
            pw.Text(t['intro']!, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),
            pw.Text(company, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (beneficiary != null) ...[
              pw.SizedBox(height: 6),
              pw.Text('${t['beneficiary']} : $beneficiary'),
            ],
            pw.SizedBox(height: 18),
            pw.Row(
              children: [
                for (final (k, v) in [
                  (t['recycled']!, '${num(kg)} kg'),
                  (t['co2']!, '${num(co2)} kg CO₂e'),
                  // Sans lot lié (demande d'achat), l'origine n'est pas connue.
                  if (pickupCount > 0) (t['pickups']!, '$pickupCount'),
                ])
                  pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _paper,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            v,
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(k, style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: [t['lot']!, t['material']!, 'kg'],
              data: [
                for (final l in lots) [refOf(l), materialOf(l), num(l.initialKg)],
              ],
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: _green),
            ),
            pw.SizedBox(height: 10),
            if (zones.isNotEmpty) _kv(t['zones']!, zones.join(', ')),
            pw.Spacer(),
            pw.Text(
              t['method']!,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
