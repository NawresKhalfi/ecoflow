import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/domain/geo.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../missions/presentation/widgets/mission_labels.dart';
import '../../application/routing_providers.dart';
import '../../domain/optimization_config.dart';
import '../../domain/route_solver.dart';
import '../../domain/tour.dart';
import '../widgets/savings_card.dart';
import '../widgets/tour_map.dart';

const _sousse = GeoPoint(35.8256, 10.6084);

/// Jeu de simulation fixe : 12 collectes à Sousse sur 4 créneaux.
List<Stop> simulationStops() {
  final r = Random(2026);
  final day = DateTime(2026, 10, 1);
  return [
    for (var i = 0; i < 12; i++)
      () {
        final from = [8, 10, 14, 16][i % 4];
        return Stop(
          id: 'sim$i',
          point: GeoPoint(
            _sousse.lat + (r.nextDouble() - .5) * .08,
            _sousse.lng + (r.nextDouble() - .5) * .08,
          ),
          kg: 5 + r.nextDouble() * 25,
          windowStart: DateTime(day.year, day.month, day.day, from),
          windowEnd: DateTime(day.year, day.month, day.day, from + 2),
          label: 'Collecte ${i + 1}',
        );
      }(),
  ];
}

/// Paramètres de l'algorithme, simulation et historique (US-062).
class OptimizationScreen extends ConsumerStatefulWidget {
  const OptimizationScreen({super.key});

  @override
  ConsumerState<OptimizationScreen> createState() => _OptimizationScreenState();
}

class _OptimizationScreenState extends ConsumerState<OptimizationScreen> {
  OptimizationConfig? _draft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final published = ref.watch(optimizationConfigProvider).value ?? const OptimizationConfig();
    final c = _draft ?? published;
    final history = ref.watch(optimizationHistoryProvider).value ?? const [];
    final state = ref.watch(optimizationAdminControllerProvider);
    final solver = RouteSolver(c);
    final stops = simulationStops();
    final start = DateTime(2026, 10, 1, 8);
    final tour = solver.solve(stops, start: _sousse, startAt: start, capacityKg: 150);
    final naive = solver.naive(stops, start: _sousse, startAt: start, capacityKg: 150);
    void set(OptimizationConfig v) => setState(() => _draft = v);

    Widget slider(
      String label,
      double value,
      double min,
      double max,
      int div,
      String Function(double) fmt,
      ValueChanged<double> f,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            EcoChip(label: fmt(value), tone: ChipTone.sky),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, divisions: div, onChanged: f),
      ],
    );
    String one(double v) => v.toStringAsFixed(1);
    return LayeredPage(
      header: HeroHeader(
        title: l.optTitle,
        subtitle: l.optSubtitle,
        emoji: '⚙️',
        gradient: EcoGradients.violet,
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: EcoChip(
                  label: _draft == null ? l.optCurrent : l.optDraft,
                  tone: _draft == null ? ChipTone.green : ChipTone.sun,
                ),
              ),
              const SizedBox(height: 8),
              slider(
                l.optDistanceWeight,
                c.distanceWeight,
                0,
                3,
                30,
                one,
                (v) => set(c.copyWith(distanceWeight: v)),
              ),
              slider(
                l.optWaitWeight,
                c.waitWeight,
                0,
                2,
                20,
                one,
                (v) => set(c.copyWith(waitWeight: v)),
              ),
              slider(
                l.optDetour,
                c.maxDetourKm,
                .5,
                10,
                19,
                one,
                (v) => set(c.copyWith(maxDetourKm: v)),
              ),
              slider(
                l.optCluster,
                c.clusterRadiusKm,
                .5,
                10,
                19,
                one,
                (v) => set(c.copyWith(clusterRadiusKm: v)),
              ),
              slider(
                l.optRoadFactor,
                c.roadFactor,
                1,
                2,
                20,
                (v) => '× ${v.toStringAsFixed(2)}',
                (v) => set(c.copyWith(roadFactor: v)),
              ),
              slider(
                l.optSpeed,
                c.speedKmh,
                10,
                60,
                50,
                (v) => v.round().toString(),
                (v) => set(c.copyWith(speedKmh: v)),
              ),
              slider(
                l.optService,
                c.serviceMinutes,
                2,
                30,
                28,
                (v) => v.round().toString(),
                (v) => set(c.copyWith(serviceMinutes: v)),
              ),
              slider(
                l.optFuelPrice,
                c.fuelPriceDt,
                1,
                4,
                30,
                (v) => fmtDt(context, v),
                (v) => set(c.copyWith(fuelPriceDt: v)),
              ),
              const SizedBox(height: 8),
              EcoButton(
                label: l.optPublish,
                leading: '📢',
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: _draft == null
                    ? null
                    : () async {
                        if (await ref
                                .read(optimizationAdminControllerProvider.notifier)
                                .publish(c) &&
                            context.mounted) {
                          setState(() => _draft = null);
                          showEcoToast(context, l.optPublished);
                        }
                      },
              ),
            ],
          ),
        ),
        SectionTitle('🧪 ${l.optSimulation}'),
        TourMap(start: _sousse, tour: tour, height: 240),
        EcoCard(
          child: Text(
            '${l.optSimResult(fmtKm(context, tour.distanceKm), naive == null ? '—' : fmtKm(context, naive.distanceKm))}'
            '${tour.unassigned.isEmpty ? '' : ' · ⚠️ ${tour.unassigned.length}'}',
          ),
        ),
        SavingsCard(savings: solver.savings(tour, naive, litersPer100Km: 10)),
        if (history.isNotEmpty) ...[
          SectionTitle(l.optHistory),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, h) in history.indexed)
                  EcoListTile(
                    leading: const EcoAvatar(text: '🕒'),
                    title: h.at == null ? '—' : fmtDate(context, h.at!),
                    subtitle:
                        '${l.optDistanceWeight} ×${one(h.config.distanceWeight)} · '
                        '${l.optWaitWeight} ×${one(h.config.waitWeight)} · ${l.optDetour} ${one(h.config.maxDetourKm)}',
                    showDivider: i < history.length - 1,
                    onTap: () => set(h.config),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
