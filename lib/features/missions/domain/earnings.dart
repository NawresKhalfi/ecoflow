/// Revenu d'une mission terminée : `earnings/{missionId}` (US-050/051).
class Earning {
  const Earning({
    required this.missionId,
    required this.amountDt,
    required this.kg,
    required this.at,
  });

  final String missionId;
  final double amountDt;
  final double kg;
  final DateTime at;
}

enum PayoutStatus { requested, processing, paid, rejected }

enum PayoutMethod { bankTransfer, mobileWallet, cash }

/// Demande de retrait : `payouts/{id}` (US-052).
class Payout {
  const Payout({
    required this.id,
    required this.amountDt,
    required this.method,
    required this.status,
    this.requestedAt,
  });

  final String id;
  final double amountDt;
  final PayoutMethod method;
  final PayoutStatus status;
  final DateTime? requestedAt;
}

/// Solde minimal pour demander un retrait.
const minWithdrawalDt = 20.0;

/// Solde disponible : gains − retraits non refusés.
double availableBalance(List<Earning> earnings, List<Payout> payouts) {
  final earned = earnings.fold(0.0, (s, e) => s + e.amountDt);
  final out = payouts
      .where((p) => p.status != PayoutStatus.rejected)
      .fold(0.0, (s, p) => s + p.amountDt);
  return earned - out;
}

bool canWithdraw(double balance, double amount) =>
    amount >= minWithdrawalDt && amount <= balance + 1e-9;

enum EarningsPeriod { day, week, month }

/// Début de la période contenant [now] (semaine commençant le lundi).
DateTime periodStart(EarningsPeriod p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (p) {
    EarningsPeriod.day => today,
    EarningsPeriod.week => today.subtract(Duration(days: today.weekday - 1)),
    EarningsPeriod.month => DateTime(now.year, now.month),
  };
}

/// Totaux de la période (US-051).
({double dt, double kg, int missions}) periodTotals(
  List<Earning> e,
  EarningsPeriod p,
  DateTime now,
) {
  final start = periodStart(p, now);
  final inPeriod = e.where((x) => !x.at.isBefore(start));
  return (
    dt: inPeriod.fold(0.0, (s, x) => s + x.amountDt),
    kg: inPeriod.fold(0.0, (s, x) => s + x.kg),
    missions: inPeriod.length,
  );
}

/// Gains des 7 derniers jours (graphique), du plus ancien au plus récent.
List<double> lastSevenDays(List<Earning> e, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = 6; i >= 0; i--)
      e
          .where((x) {
            final d = DateTime(x.at.year, x.at.month, x.at.day);
            return d == today.subtract(Duration(days: i));
          })
          .fold(0.0, (s, x) => s + x.amountDt),
  ];
}
