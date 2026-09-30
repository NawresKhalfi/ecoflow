import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../domain/estimate.dart';
import '../../domain/estimation_coefficients.dart';

String _lang(BuildContext c) => Localizations.localeOf(c).languageCode;

/// Kilogrammes à 2 décimales, séparateurs de la langue.
String fmtKg(BuildContext c, double v) => NumberFormat('#,##0.00', _lang(c)).format(v);

/// Dinars à 3 décimales (millimes).
String fmtDt(BuildContext c, double v) => NumberFormat('#,##0.000', _lang(c)).format(v);

String fmtDate(BuildContext c, DateTime d) => DateFormat.yMMMd(_lang(c)).format(d);

String methodLabel(AppLocalizations l, EstimationMethod m) => switch (m) {
  EstimationMethod.manual => l.estMethodManual,
  EstimationMethod.container => l.estMethodContainer,
  EstimationMethod.count => l.estMethodCount,
};

String containerLabel(AppLocalizations l, WasteContainer c) => switch (c) {
  WasteContainer.bag30 => l.contBag30,
  WasteContainer.bag50 => l.contBag50,
  WasteContainer.bag100 => l.contBag100,
  WasteContainer.cardboardBox => l.contBox,
  WasteContainer.crate => l.contCrate,
};

/// Saisie décimale tolérante (virgule ou point) ; `null` si vide/invalide.
double? parseKg(String v) {
  final t = v.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  return n == null || n < 0 ? null : n;
}

/// Date courte dans une langue donnée (rapports exportés).
String fmtDateLocale(String lang, DateTime d) => DateFormat.yMMMd(lang).format(d);
