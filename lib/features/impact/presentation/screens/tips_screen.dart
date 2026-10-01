import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/impact_providers.dart';
import '../../domain/sorting_tips.dart';
import '../widgets/impact_widgets.dart';
import '../widgets/tip_content.dart';

/// Conseils de tri et de réduction (US-120) : fiches illustrées par
/// matière, contenu embarqué (consultable hors ligne).
class TipsScreen extends ConsumerWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sheets = sheetsFor(ref.watch(personalImpactProvider).kgByCategory);
    return LayeredPage(
      header: HeroHeader(
        title: l.tipsTitle,
        subtitle: l.tipsSubtitle,
        emoji: '💡',
        gradient: EcoGradients.sun,
        leading: const HeroBack(to: Routes.impact),
      ),
      children: [
        EcoChip(label: '📶 ${l.tipsOffline}', tone: ChipTone.sky),
        ResponsiveGrid(
          minItemWidth: 160,
          spacing: 12,
          children: [
            for (final s in sheets)
              _SheetTile(sheet: s, onTap: () => context.go(Routes.tipSheet(s.name))),
          ],
        ),
        SectionTitle('🌿 ${l.tipsReduceTitle}'),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, t) in tipItems(l.tipsReduceItems).indexed)
                TipLine(index: i + 1, text: t),
            ],
          ),
        ),
      ],
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({required this.sheet, required this.onTap});
  final TipSheet sheet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = tipContent(context.l10n, sheet);
    return EcoCard(
      gradient: sheetGradient(sheet),
      decorated: true,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      semanticLabel: c.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text(sheet.emoji, style: const TextStyle(fontSize: 40))),
          const SizedBox(height: 8),
          Text(c.title, style: AppTheme.weighted(17, 800, color: Colors.white)),
          Text(
            c.bin,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.weighted(13, 500, color: Colors.white.withValues(alpha: .92)),
          ),
        ],
      ),
    );
  }
}

/// Fiche détaillée d'une matière.
class TipSheetScreen extends StatelessWidget {
  const TipSheetScreen({super.key, required this.sheetName});
  final String sheetName;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sheet = TipSheet.values.where((s) => s.name == sheetName).firstOrNull;
    if (sheet == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.tips);
      });
      return const SizedBox.shrink();
    }
    final c = tipContent(l, sheet);
    return LayeredPage(
      header: HeroHeader(
        title: c.title,
        subtitle: c.bin,
        emoji: sheet.emoji,
        gradient: sheetGradient(sheet),
        leading: const HeroBack(to: Routes.tips),
      ),
      children: [
        TipSection(emoji: '✅', title: l.tipsYes, items: tipItems(c.yes), color: EcoColors.primary),
        TipSection(
          emoji: '🚫',
          title: l.tipsNo,
          items: tipItems(c.no),
          color: const Color(0xFFC4482A),
        ),
        TipSection(emoji: '🧽', title: l.tipsPrepare, items: tipItems(c.prepare), numbered: true),
        EcoCard(
          gradient: EcoGradients.green,
          decorated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🌿 ${l.tipsReduce}', style: AppTheme.weighted(17, 800, color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                c.reduce,
                style: AppTheme.weighted(15, 500, color: Colors.white.withValues(alpha: .95)),
              ),
            ],
          ),
        ),
        EcoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EcoAvatar(text: '🤓'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.tipsFact, style: Theme.of(context).textTheme.titleSmall),
                    Text(c.fact),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
