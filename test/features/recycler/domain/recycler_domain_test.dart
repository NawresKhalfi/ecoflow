import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:ecoflow/features/missions/domain/deposit.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:ecoflow/features/recycler/data/report_export.dart';
import 'package:ecoflow/features/recycler/domain/analytics.dart';
import 'package:ecoflow/features/recycler/domain/purchasing.dart';
import 'package:ecoflow/features/recycler/domain/reception.dart';
import 'package:ecoflow/features/recycler/domain/stock.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 1, 12);

StockLot lot(
  String id,
  RecyclableMaterial m,
  double kg, {
  QualityGrade grade = QualityGrade.a,
  int daysAgo = 1,
  String collector = 'k1',
  String zone = 'sousse',
  String? deposit,
}) => StockLot(
  id: id,
  recyclerUid: 'r',
  material: m,
  grade: grade,
  initialKg: kg,
  kg: kg,
  depositId: deposit ?? 'd$id',
  collectorUid: collector,
  collectorName: collector.toUpperCase(),
  zoneIds: [zone],
  receivedAt: now.subtract(Duration(days: daysAgo)),
);

const labels = ReportLabels(
  title: 'Rapport',
  company: 'GreenPlast',
  period: '30 jours',
  filters: '',
  generatedOn: 'Généré',
  total: 'Total',
  deposits: 'Livraisons',
  quality: 'Qualité',
  byMaterial: 'Par matière',
  byCollector: 'Par collecteur',
  lots: 'Lots',
  material: 'Matière',
  kg: 'kg',
  share: 'Part',
  collector: 'Collecteur',
  date: 'Date',
  grade: 'Qualité',
  reference: 'Lot',
  zones: 'Zone',
  materialName: _name,
  fmtDate: _date,
);
String _name(String m) => m.toUpperCase();
String _date(DateTime d) => '${d.day}/${d.month}';

void main() {
  group('stock (US-081)', () {
    test('summary by material then grade, depleted lots ignored', () {
      final s = stockSummary([
        lot('1', RecyclableMaterial.pet, 10),
        lot('2', RecyclableMaterial.pet, 5, grade: QualityGrade.b),
        lot('3', RecyclableMaterial.glass, 8).copyWithKg(0),
      ]);
      expect(s.keys, [RecyclableMaterial.pet]);
      expect(s[RecyclableMaterial.pet], {QualityGrade.a: 10, QualityGrade.b: 5});
      expect(totalKg(s[RecyclableMaterial.pet]!), 15);
    });

    test('FIFO consumption takes the oldest batches first', () {
      final lots = [
        lot('new', RecyclableMaterial.pet, 10, daysAgo: 1),
        lot('old', RecyclableMaterial.pet, 4, daysAgo: 9),
        lot('glass', RecyclableMaterial.glass, 50, daysAgo: 20),
      ];
      final taken = consumeFifo(lots, RecyclableMaterial.pet, 6);
      expect([for (final (l, kg) in taken) (l.id, kg)], [('old', 4.0), ('new', 2.0)]);
      expect(
        () => consumeFifo(lots, RecyclableMaterial.pet, 15),
        throwsA(isA<InsufficientStock>().having((e) => e.availableKg, 'available', 14)),
      );
    });
  });

  group('reception (US-080)', () {
    test('catalogue categories map to recycler materials', () {
      final m = declaredByMaterial({
        'can': 4,
        'paper': 2,
        'cardboard': 3,
        'glass': 1,
        'x': 1,
      }, defaultCatalog);
      expect(m, {
        RecyclableMaterial.aluminium: 4.0,
        RecyclableMaterial.cardboard: 5.0,
        RecyclableMaterial.glass: 1.0,
        RecyclableMaterial.other: 1.0,
      });
    });

    test('validation and gap with the declaration', () {
      ReceptionInput r(Map<RecyclableMaterial, double> kg, {double c = 0}) =>
          ReceptionInput(kgByMaterial: kg, grade: QualityGrade.a, contaminationPct: c);
      expect(validateReception(r({RecyclableMaterial.pet: 0})), ReceptionIssue.empty);
      expect(validateReception(r({RecyclableMaterial.pet: -1})), ReceptionIssue.negative);
      expect(
        validateReception(r({RecyclableMaterial.pet: 3}, c: 120)),
        ReceptionIssue.contamination,
      );
      expect(validateReception(r({RecyclableMaterial.pet: 3})), isNull);
      expect(receptionGap(10, 8), closeTo(-.2, 1e-9));
      expect(receptionGap(0, 8), 0);
    });
  });

  group('purchasing (US-085)', () {
    final pay = {
      RecyclableMaterial.pet: const MaterialOffer(priceDtPerKg: .5),
      RecyclableMaterial.glass: const MaterialOffer(priceDtPerKg: .1),
    };
    final picky = {RecyclableMaterial.glass: const MaterialOffer(accepting: false)};

    test('round trip and offer value', () {
      expect(purchasingFromMap(purchasingToMap(pay))[RecyclableMaterial.pet]!.priceDtPerKg, .5);
      expect(
        offerValue(pay, {RecyclableMaterial.pet: 10, RecyclableMaterial.glass: 10}),
        closeTo(6, 1e-9),
      );
      expect(offerValue(picky, {RecyclableMaterial.glass: 1}), isNull);
    });

    test('best offer first, refusing recyclers last', () {
      final ranked = rankRecyclers(
        [
          (uid: 'no', name: 'No', city: '', purchasing: picky),
          (
            uid: 'cheap',
            name: 'Cheap',
            city: '',
            purchasing: {RecyclableMaterial.glass: const MaterialOffer(priceDtPerKg: .05)},
          ),
          (uid: 'best', name: 'Best', city: '', purchasing: pay),
        ],
        {RecyclableMaterial.glass: 20},
      );
      expect([for (final (r, _) in ranked) r.uid], ['best', 'cheap', 'no']);
    });
  });

  group('dashboard (US-079, US-082)', () {
    final lots = [
      lot('1', RecyclableMaterial.pet, 850, deposit: 'A'),
      lot('2', RecyclableMaterial.hdpe, 320, deposit: 'A', grade: QualityGrade.b),
      lot('3', RecyclableMaterial.pp, 180, collector: 'k2', zone: 'monastir', daysAgo: 10),
      lot('4', RecyclableMaterial.other, 75, daysAgo: 60),
    ];

    test('totals, ranking, deposits and weighted quality', () {
      final r = supplyReport(lots, const DashboardFilter(), now);
      expect(r.totalKg, 1350);
      expect(r.ranked.first.key, RecyclableMaterial.pet);
      expect(r.deposits, 2);
      expect(r.quality, closeTo((850 + 320 * .6 + 180) / 1350, 1e-9));
      expect(r.weekly.last, 1170, reason: 'this week: PET + HDPE');
      expect(r.byCollector['k2']!.kg, 180);
    });

    test('filters by period, zone and collector', () {
      expect(
        supplyReport(lots, const DashboardFilter(period: ReportPeriod.quarter), now).totalKg,
        1425,
      );
      expect(
        supplyReport(lots, const DashboardFilter(period: ReportPeriod.week), now).totalKg,
        1170,
      );
      expect(supplyReport(lots, const DashboardFilter(zoneId: 'monastir'), now).totalKg, 180);
      expect(supplyReport(lots, const DashboardFilter(collectorUid: 'k1'), now).totalKg, 1170);
      final c = filterChoices(lots);
      expect(c.zones, {'sousse', 'monastir'});
      expect(c.collectors, {'k1': 'K1', 'k2': 'K2'});
    });
  });

  test('production validation (US-087)', () {
    ProductionInput p(double i, double o, [MaterialForm f = MaterialForm.flakes]) =>
        ProductionInput(
          material: RecyclableMaterial.pet,
          inputKg: i,
          form: f,
          outputKg: o,
          grade: QualityGrade.a,
        );
    expect(validateProduction(p(100, 92)), isNull);
    expect(p(100, 92).yieldRatio, closeTo(.92, 1e-9));
    expect(validateProduction(p(100, 120)), ProductionIssue.overYield);
    expect(validateProduction(p(0, 1)), ProductionIssue.noInput);
    expect(validateProduction(p(10, 5, MaterialForm.raw)), ProductionIssue.rawForm);
  });

  group('export (US-083)', () {
    final r = supplyReport(
      [
        lot('abc123', RecyclableMaterial.pet, 850),
        lot('def456', RecyclableMaterial.glass, 120.5, collector: 'k&2'),
      ],
      const DashboardFilter(),
      now,
    );

    test('xlsx is a valid workbook with summary and batch sheets', () {
      final zip = ZipDecoder().decodeBytes(buildSupplyXlsx(r, labels));
      final names = [for (final f in zip.files) f.name];
      expect(
        names,
        containsAll([
          '[Content_Types].xml',
          'xl/workbook.xml',
          'xl/worksheets/sheet1.xml',
          'xl/worksheets/sheet2.xml',
        ]),
      );
      String file(String n) =>
          utf8.decode(zip.files.firstWhere((f) => f.name == n).content as List<int>);
      expect(file('xl/workbook.xml'), contains('name="Par matière"'));
      final summary = file('xl/worksheets/sheet1.xml');
      expect(summary, contains('<v>850.0</v>'), reason: 'numbers stay numeric');
      expect(summary, contains('K&amp;2'), reason: 'XML escaped');
      expect(file('xl/worksheets/sheet2.xml'), contains('LOT-ABC123'));
    });

    test('pdf document is produced', () async {
      final bytes = await buildSupplyPdf(r, labels);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('file name carries the date', () {
      expect(reportFileName('xlsx', now), 'ecoflow_approvisionnements_2026-10-01.xlsx');
    });
  });

  test('mission snapshot round trip (US-084)', () {
    final m = MissionRef(id: 'c1', zoneId: 'sousse', day: DateTime(2026, 9, 30), kg: 3.5);
    final back = MissionRef.fromMap(m.toMap(), (v) => v as DateTime?);
    expect((back.id, back.zoneId, back.day, back.kg), ('c1', 'sousse', DateTime(2026, 9, 30), 3.5));
  });
}

extension on StockLot {
  StockLot copyWithKg(double kg) => StockLot(
    id: id,
    recyclerUid: recyclerUid,
    material: material,
    grade: grade,
    initialKg: initialKg,
    kg: kg,
  );
}
