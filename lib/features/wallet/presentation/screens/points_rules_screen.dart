import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../scan/domain/waste_category.dart';
import '../../application/wallet_providers.dart';
import '../../domain/points_rules.dart';
import '../widgets/wallet_labels.dart';

/// Collecte type pour la simulation : 5 kg de PET, 3 kg de verre, 1 kg de canettes.
const _sample = {'pet_bottle': 5.0, 'glass': 3.0, 'can': 1.0};

/// Règles de calcul des EcoPoints (US-071) : brouillon, simulation, publication.
class PointsRulesScreen extends ConsumerStatefulWidget {
  const PointsRulesScreen({super.key});

  @override
  ConsumerState<PointsRulesScreen> createState() => _PointsRulesScreenState();
}

class _PointsRulesScreenState extends ConsumerState<PointsRulesScreen> {
  PointsRules? _draft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final published = ref.watch(pointsRulesProvider).value ?? const PointsRules();
    final history = ref.watch(pointsRulesHistoryProvider).value ?? const [];
    final state = ref.watch(walletAdminControllerProvider);
    final r = _draft ?? published;
    void set(PointsRules v) => setState(() => _draft = v);
    final sample = computeAward(
      r,
      actualKg: _sample,
      actualTotalKg: 9,
      estimatedKg: 9,
      firstCollection: false,
      dayCount: 1,
    );

    Widget slider(
      String label,
      double value,
      double min,
      double max,
      int div,
      String shown,
      ValueChanged<double> f,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            EcoChip(label: shown, tone: ChipTone.sky),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: div,
          label: shown,
          onChanged: f,
        ),
      ],
    );
    String one(double v) => NumberFormat('0.0', lang).format(v);
    return LayeredPage(
      header: HeroHeader(
        title: l.pointsRulesTitle,
        subtitle: l.pointsRulesSubtitle,
        emoji: '🏅',
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
                l.rulesPerKg,
                r.pointsPerKg,
                1,
                50,
                49,
                r.pointsPerKg.round().toString(),
                (v) => set(r.copyWith(pointsPerKg: v.roundToDouble())),
              ),
              slider(
                l.rulesFirstBonus,
                r.firstCollectionBonus.toDouble(),
                0,
                200,
                20,
                '${r.firstCollectionBonus}',
                (v) => set(r.copyWith(firstCollectionBonus: v.round())),
              ),
              slider(
                l.rulesBigDropKg,
                r.bigDropKg,
                1,
                50,
                49,
                l.kg(one(r.bigDropKg)),
                (v) => set(r.copyWith(bigDropKg: v.roundToDouble())),
              ),
              slider(
                l.rulesBigDropBonus,
                r.bigDropBonus.toDouble(),
                0,
                100,
                20,
                '${r.bigDropBonus}',
                (v) => set(r.copyWith(bigDropBonus: v.round())),
              ),
              slider(
                l.rulesReferral,
                r.referralBonus.toDouble(),
                0,
                500,
                50,
                '${r.referralBonus}',
                (v) => set(r.copyWith(referralBonus: v.round())),
              ),
              slider(
                l.rulesExpiry,
                r.expiryMonths.toDouble(),
                3,
                36,
                33,
                l.months(r.expiryMonths),
                (v) => set(r.copyWith(expiryMonths: v.round())),
              ),
            ],
          ),
        ),
        SectionTitle('♻️ ${l.rulesMultipliers}'),
        EcoCard(
          child: Column(
            children: [
              for (final id in [...pointsCategoryIds, pointsOtherId])
                slider(
                  () {
                    final c = defaultCatalog.where((c) => c.id == id).firstOrNull;
                    return c == null ? id : '${c.emoji} ${c.name(lang)}';
                  }(),
                  r.multiplier(id),
                  0,
                  5,
                  50,
                  '× ${one(r.multiplier(id))}',
                  (v) =>
                      set(r.copyWith(multipliers: {...r.multipliers, id: (v * 10).round() / 10})),
                ),
            ],
          ),
        ),
        SectionTitle('🛡️ ${l.rulesFraud}'),
        EcoCard(
          child: Column(
            children: [
              slider(
                l.rulesDailyLimit,
                r.dailyLimit.toDouble(),
                1,
                10,
                9,
                '${r.dailyLimit}',
                (v) => set(r.copyWith(dailyLimit: v.round())),
              ),
              slider(
                l.rulesMaxKg,
                r.maxKgPerCollection,
                20,
                500,
                48,
                l.kg(r.maxKgPerCollection.round().toString()),
                (v) => set(r.copyWith(maxKgPerCollection: v.roundToDouble())),
              ),
              slider(
                l.rulesRatio,
                r.anomalyRatio,
                1.5,
                10,
                17,
                '× ${one(r.anomalyRatio)}',
                (v) => set(r.copyWith(anomalyRatio: (v * 2).round() / 2)),
              ),
            ],
          ),
        ),
        EcoCard(
          gradient: EcoGradients.green,
          child: Text(
            '🧪 ${l.rulesSample(l.points(fmtPoints(context, sample.total)))}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        EcoButton(
          label: l.optPublish,
          leading: '📢',
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: _draft == null
              ? null
              : () async {
                  final ok = await ref.read(walletAdminControllerProvider.notifier).publishRules(r);
                  if (ok && context.mounted) {
                    setState(() => _draft = null);
                    showEcoToast(context, l.optPublished);
                  }
                },
        ),
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
                        '${l.rulesPerKg} ${h.rules.pointsPerKg.round()} · '
                        '${l.rulesFirstBonus} ${h.rules.firstCollectionBonus} · '
                        '${l.rulesExpiry} ${l.months(h.rules.expiryMonths)}',
                    showDivider: i < history.length - 1,
                    onTap: () => set(h.rules),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
