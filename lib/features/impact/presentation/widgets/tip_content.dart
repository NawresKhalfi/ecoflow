import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/sorting_tips.dart';

typedef TipContent = ({
  String title,
  String bin,
  String yes,
  String no,
  String prepare,
  String reduce,
  String fact,
});

TipContent tipContent(AppLocalizations l, TipSheet s) => switch (s) {
  TipSheet.plastic => (
    title: l.tipPlasticTitle,
    bin: l.tipPlasticBin,
    yes: l.tipPlasticYes,
    no: l.tipPlasticNo,
    prepare: l.tipPlasticPrepare,
    reduce: l.tipPlasticReduce,
    fact: l.tipPlasticFact,
  ),
  TipSheet.metal => (
    title: l.tipMetalTitle,
    bin: l.tipMetalBin,
    yes: l.tipMetalYes,
    no: l.tipMetalNo,
    prepare: l.tipMetalPrepare,
    reduce: l.tipMetalReduce,
    fact: l.tipMetalFact,
  ),
  TipSheet.cardboard => (
    title: l.tipCardboardTitle,
    bin: l.tipCardboardBin,
    yes: l.tipCardboardYes,
    no: l.tipCardboardNo,
    prepare: l.tipCardboardPrepare,
    reduce: l.tipCardboardReduce,
    fact: l.tipCardboardFact,
  ),
  TipSheet.paper => (
    title: l.tipPaperTitle,
    bin: l.tipPaperBin,
    yes: l.tipPaperYes,
    no: l.tipPaperNo,
    prepare: l.tipPaperPrepare,
    reduce: l.tipPaperReduce,
    fact: l.tipPaperFact,
  ),
  TipSheet.glass => (
    title: l.tipGlassTitle,
    bin: l.tipGlassBin,
    yes: l.tipGlassYes,
    no: l.tipGlassNo,
    prepare: l.tipGlassPrepare,
    reduce: l.tipGlassReduce,
    fact: l.tipGlassFact,
  ),
  TipSheet.eWaste => (
    title: l.tipEWasteTitle,
    bin: l.tipEWasteBin,
    yes: l.tipEWasteYes,
    no: l.tipEWasteNo,
    prepare: l.tipEWastePrepare,
    reduce: l.tipEWasteReduce,
    fact: l.tipEWasteFact,
  ),
  TipSheet.organic => (
    title: l.tipOrganicTitle,
    bin: l.tipOrganicBin,
    yes: l.tipOrganicYes,
    no: l.tipOrganicNo,
    prepare: l.tipOrganicPrepare,
    reduce: l.tipOrganicReduce,
    fact: l.tipOrganicFact,
  ),
  TipSheet.hazardous => (
    title: l.tipHazardTitle,
    bin: l.tipHazardBin,
    yes: l.tipHazardYes,
    no: l.tipHazardNo,
    prepare: l.tipHazardPrepare,
    reduce: l.tipHazardReduce,
    fact: l.tipHazardFact,
  ),
};

Gradient sheetGradient(TipSheet s) => switch (s) {
  TipSheet.plastic => EcoGradients.sky,
  TipSheet.metal => EcoGradients.violet,
  TipSheet.cardboard => EcoGradients.sun,
  TipSheet.paper => EcoGradients.sky,
  TipSheet.glass => EcoGradients.green,
  TipSheet.eWaste => EcoGradients.violet,
  TipSheet.organic => EcoGradients.green,
  TipSheet.hazardous => EcoGradients.coral,
};

/// Section d'une fiche : liste à puces ou étapes numérotées.
class TipSection extends StatelessWidget {
  const TipSection({
    super.key,
    required this.emoji,
    required this.title,
    required this.items,
    this.color,
    this.numbered = false,
  });

  final String emoji;
  final String title;
  final List<String> items;
  final Color? color;
  final bool numbered;

  @override
  Widget build(BuildContext context) => EcoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('$emoji $title', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        for (final (i, t) in items.indexed)
          numbered ? TipLine(index: i + 1, text: t) : _Bullet(text: t, color: color),
      ],
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color ?? EcoColors.primary, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Étape numérotée.
class TipLine extends StatelessWidget {
  const TipLine({super.key, required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EcoColors.primary.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Text('$index', style: AppTheme.weighted(13, 800, color: EcoColors.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
