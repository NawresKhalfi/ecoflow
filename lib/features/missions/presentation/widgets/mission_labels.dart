import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/l10n.dart';
import '../../../collection/domain/geo.dart';
import '../../data/mission_repository.dart';
import '../../domain/deposit.dart';
import '../../domain/earnings.dart';
import '../../domain/vehicle.dart';

String vehicleLabel(AppLocalizations l, VehicleType t) => switch (t) {
  VehicleType.bike => l.vehBike,
  VehicleType.cargoBike => l.vehCargoBike,
  VehicleType.motorbike => l.vehMotorbike,
  VehicleType.car => l.vehCar,
  VehicleType.van => l.vehVan,
  VehicleType.truck => l.vehTruck,
};

String vehicleEmoji(VehicleType t) => switch (t) {
  VehicleType.bike => '🚲',
  VehicleType.cargoBike => '🚲',
  VehicleType.motorbike => '🏍️',
  VehicleType.car => '🚗',
  VehicleType.van => '🚐',
  VehicleType.truck => '🚚',
};

String payoutLabel(AppLocalizations l, PayoutStatus s) => switch (s) {
  PayoutStatus.requested => l.payoutRequested,
  PayoutStatus.processing => l.payoutProcessing,
  PayoutStatus.paid => l.payoutPaid,
  PayoutStatus.rejected => l.payoutRejected,
};

String methodLabel2(AppLocalizations l, PayoutMethod m) => switch (m) {
  PayoutMethod.bankTransfer => l.methodBank,
  PayoutMethod.mobileWallet => l.methodWallet,
  PayoutMethod.cash => l.methodCash,
};

String depositLabel(AppLocalizations l, DepositStatus s) => switch (s) {
  DepositStatus.pending => l.depPending,
  DepositStatus.confirmed => l.depConfirmed,
  DepositStatus.rejected => l.depRejected,
};

String noShowLabel(AppLocalizations l, NoShowReason r) => switch (r) {
  NoShowReason.citizenAbsent => l.noShowAbsent,
  NoShowReason.addressNotFound => l.noShowAddress,
};

String periodLabel(AppLocalizations l, EarningsPeriod p) => switch (p) {
  EarningsPeriod.day => l.periodDay,
  EarningsPeriod.week => l.periodWeek,
  EarningsPeriod.month => l.periodMonth,
};

String fmtKm(BuildContext c, double km) =>
    NumberFormat('#,##0.0', Localizations.localeOf(c).languageCode).format(km);

enum NavApp { googleMaps, waze, appleMaps }

/// Lien d'itinéraire vers la collecte (US-046).
Uri navigationUri(NavApp app, GeoPoint to) => switch (app) {
  NavApp.googleMaps => Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${to.lat},${to.lng}&travelmode=driving',
  ),
  NavApp.waze => Uri.parse('https://waze.com/ul?ll=${to.lat},${to.lng}&navigate=yes'),
  NavApp.appleMaps => Uri.parse('https://maps.apple.com/?daddr=${to.lat},${to.lng}'),
};

Future<void> openNavigation(NavApp app, GeoPoint to) =>
    launchUrl(navigationUri(app, to), mode: LaunchMode.externalApplication);
