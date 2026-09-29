import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/vision_admin_controllers.dart';
import '../widgets/category_form.dart';

/// Catalogue des classes de déchets (US-022).
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(catalogAdminControllerProvider);
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final isDefault = identical(catalog, defaultCatalog);
    return LayeredPage(
      header: HeroHeader(
        title: l.catalogTitle,
        subtitle: l.catalogSubtitle,
        emoji: '🗂️',
        gradient: EcoGradients.violet,
      ),
      children: [
        if (isDefault)
          EcoCard(
            gradient: EcoGradients.sun,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.catalogDefaultBanner, style: const TextStyle(color: EcoColors.onSun)),
                const SizedBox(height: 10),
                EcoButton(
                  label: l.catalogPublish,
                  leading: '🚀',
                  style: EcoButtonStyle.ghost,
                  loading: state.isLoading,
                  onPressed: ref.read(catalogAdminControllerProvider.notifier).seedDefaults,
                ),
              ],
            ),
          )
        else
          EcoButton(label: l.catalogAdd, leading: '➕', onPressed: () => showCategoryForm(context)),
        ResponsiveGrid(
          minItemWidth: 300,
          children: [
            for (final c in catalog)
              EcoCard(
                onTap: isDefault ? null : () => showCategoryForm(context, existing: c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        EcoAvatar(text: c.emoji),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.name(languageOf(context)),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (!c.active) EcoChip(label: '⏸', tone: ChipTone.coral),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        EcoChip(label: '♻️ ${recyclabilityLabel(l, c.recyclability)}'),
                        EcoChip(
                          label:
                              '💰 ${c.material == null ? l.catalogNoMaterial : materialLabel(l, c.material!)}',
                          tone: ChipTone.sun,
                        ),
                        for (final m in c.modelLabels)
                          EcoChip(label: '🧠 $m', tone: ChipTone.violet),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
