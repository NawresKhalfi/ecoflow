import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../application/market_providers.dart';
import '../../domain/market.dart';
import '../widgets/market_widgets.dart';

/// Mes commandes d'achat et de vente (US-100).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final uid = ref.watch(currentUidProvider) ?? '';
    final orders = ref.watch(myOrdersProvider).value ?? const <MarketOrder>[];
    return LayeredPage(
      header: HeroHeader(
        title: l.ordersTitle,
        subtitle: l.ordersSubtitle,
        emoji: '📦',
        gradient: EcoGradients.sky,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.market),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        if (orders.isEmpty) EcoCard(child: Text(l.ordersEmpty)),
        if (orders.isNotEmpty)
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, o) in orders.indexed)
                  EcoListTile(
                    leading: EcoAvatar(text: o.isSeller(uid) ? '📤' : '📥'),
                    title: '${o.number} · ${o.counterpartName(uid)}',
                    subtitle: [
                      '${materialEmoji(o.material)} ${materialLabel(l, o.material)} ${l.kg(fmtKg(context, o.quantityKg))}',
                      l.dt(fmtDt(context, o.totalTtc)),
                      orderStatusLabel(l, o.status),
                    ].join(' · '),
                    onTap: () => context.go(Routes.order(o.id)),
                    showDivider: i < orders.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
