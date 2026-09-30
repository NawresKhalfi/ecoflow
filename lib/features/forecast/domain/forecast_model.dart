import 'dart:math';

/// Jour civil (heure ignorée) : clé des séries journalières.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Série journalière continue de [from] à [to] inclus, jours sans collecte à 0.
List<double> dailySeries(Map<DateTime, double> kgByDay, DateTime from, DateTime to) {
  final out = <double>[];
  for (var d = dayOf(from); !d.isAfter(dayOf(to)); d = DateTime(d.year, d.month, d.day + 1)) {
    out.add(kgByDay[d] ?? 0);
  }
  return out;
}

/// Paramètres d'un modèle de Holt-Winters additif (niveau, tendance,
/// saisonnalité hebdomadaire).
class HoltWintersParams {
  const HoltWintersParams(this.alpha, this.beta, this.gamma);
  final double alpha;
  final double beta;
  final double gamma;

  Map<String, double> toMap() => {'alpha': alpha, 'beta': beta, 'gamma': gamma};
}

/// Modèle entraîné : état final + erreur résiduelle pour l'intervalle.
class FittedModel {
  const FittedModel({
    required this.method,
    required this.level,
    required this.trend,
    required this.season,
    required this.residualStd,
    required this.params,
    required this.samples,
  });

  final ForecastMethod method;
  final double level;
  final double trend;

  /// Composante saisonnière (7 valeurs), alignée sur le jour suivant la fin.
  final List<double> season;
  final double residualStd;
  final HoltWintersParams? params;
  final int samples;

  /// Prévision journalière sur [h] jours (jamais négative).
  List<double> forecast(int h) => [
    for (var i = 1; i <= h; i++) max(0, level + i * trend + season[(i - 1) % season.length]),
  ];

  /// Intervalle à ~95 % du cumul sur [h] jours.
  ({double low, double high}) interval(int h) {
    final total = forecast(h).fold(0.0, (a, b) => a + b);
    final spread = 1.96 * residualStd * sqrt(h.toDouble());
    return (low: max(0, total - spread), high: total + spread);
  }
}

enum ForecastMethod {
  /// Holt-Winters additif, saisonnalité 7 jours (≥ 3 semaines d'historique).
  holtWinters,

  /// Moyenne des 14 derniers jours (historique court).
  movingAverage,

  /// Aucune donnée.
  none,
}

const _season = 7;
const _grid = [.1, .3, .5, .7];

/// Un passage de Holt-Winters ; renvoie l'erreur quadratique à un pas.
({double sse, double level, double trend, List<double> season, List<double> errors}) _run(
  List<double> y,
  HoltWintersParams p,
) {
  // Initialisation : niveau = moyenne de la 1re semaine, tendance = écart
  // moyen entre les deux premières semaines, saison = écart à la moyenne.
  final first = y.sublist(0, _season);
  final second = y.sublist(_season, 2 * _season);
  final m1 = first.reduce((a, b) => a + b) / _season;
  final m2 = second.reduce((a, b) => a + b) / _season;
  var level = m1;
  var trend = (m2 - m1) / _season;
  final season = [for (final v in first) v - m1];
  var sse = 0.0;
  final errors = <double>[];
  for (var t = _season; t < y.length; t++) {
    final s = season[t % _season];
    final predicted = level + trend + s;
    final e = y[t] - predicted;
    errors.add(e);
    sse += e * e;
    final prevLevel = level;
    level = p.alpha * (y[t] - s) + (1 - p.alpha) * (level + trend);
    trend = p.beta * (level - prevLevel) + (1 - p.beta) * trend;
    season[t % _season] = p.gamma * (y[t] - level) + (1 - p.gamma) * s;
  }
  // Saison réalignée pour que l'indice 0 corresponde au jour suivant.
  final n = y.length;
  final aligned = [for (var i = 0; i < _season; i++) season[(n + i) % _season]];
  return (sse: sse, level: level, trend: trend, season: aligned, errors: errors);
}

double _std(List<double> e) {
  if (e.length < 2) return 0;
  final mean = e.reduce((a, b) => a + b) / e.length;
  return sqrt(e.fold(0.0, (s, x) => s + (x - mean) * (x - mean)) / (e.length - 1));
}

/// Entraînement (US-093) : recherche des paramètres minimisant l'erreur à
/// un pas ; repli sur la moyenne mobile si l'historique est trop court.
FittedModel fitModel(List<double> y) {
  if (y.isEmpty || y.every((v) => v == 0)) {
    return const FittedModel(
      method: ForecastMethod.none,
      level: 0,
      trend: 0,
      season: [0],
      residualStd: 0,
      params: null,
      samples: 0,
    );
  }
  if (y.length < 3 * _season) {
    final recent = y.sublist(max(0, y.length - 14));
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    return FittedModel(
      method: ForecastMethod.movingAverage,
      level: mean,
      trend: 0,
      season: const [0],
      residualStd: _std([for (final v in recent) v - mean]),
      params: null,
      samples: y.length,
    );
  }
  HoltWintersParams? best;
  ({double sse, double level, double trend, List<double> season, List<double> errors})? run;
  for (final a in _grid) {
    for (final b in [.01, .1, .3]) {
      for (final g in _grid) {
        final p = HoltWintersParams(a, b, g);
        final r = _run(y, p);
        if (run == null || r.sse < run.sse) {
          run = r;
          best = p;
        }
      }
    }
  }
  return FittedModel(
    method: ForecastMethod.holtWinters,
    level: run!.level,
    trend: run.trend,
    season: run.season,
    residualStd: _std(run.errors),
    params: best,
    samples: y.length,
  );
}

/// Précision (US-092) : le modèle est entraîné sans les [holdout] derniers
/// jours puis comparé au réel. MAPE sur les jours non nuls et WAPE (écart
/// pondéré par le volume, robuste aux jours vides).
({double? mape, double? wape, int days}) backtest(List<double> y, {int holdout = 7}) {
  if (y.length < holdout + 2 * _season) return (mape: null, wape: null, days: 0);
  final train = y.sublist(0, y.length - holdout);
  final actual = y.sublist(y.length - holdout);
  final predicted = fitModel(train).forecast(holdout);
  var ape = 0.0;
  var n = 0;
  var absErr = 0.0;
  var total = 0.0;
  for (var i = 0; i < holdout; i++) {
    absErr += (actual[i] - predicted[i]).abs();
    total += actual[i];
    if (actual[i] > 0) {
      ape += (actual[i] - predicted[i]).abs() / actual[i];
      n++;
    }
  }
  return (mape: n == 0 ? null : ape / n, wape: total == 0 ? null : absErr / total, days: holdout);
}
