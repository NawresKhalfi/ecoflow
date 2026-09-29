import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/addresses_controller.dart';
import '../../application/profile_providers.dart';
import '../../domain/address.dart';

/// Liste des adresses enregistrées du citoyen (US-005).
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final addresses = ref.watch(addressesProvider);
    return LayeredPage(
      header: HeroHeader(title: l.addressesTitle, subtitle: l.addressesSubtitle, emoji: '📍'),
      children: [
        EcoButton(
          label: l.addAddress,
          leading: '➕',
          onPressed: () => context.go(Routes.addressNew),
        ),
        ...addresses.when(
          loading: () => [const Center(child: CircularProgressIndicator())],
          error: (e, _) => [EcoCard(child: Text(l.failUnknown))],
          data: (list) => list.isEmpty
              ? [
                  EcoCard(
                    child: Row(children: [
                      const EcoAvatar(text: '🏠', gradient: EcoGradients.sun),
                      const SizedBox(width: 14),
                      Expanded(child: Text(l.addressesEmpty)),
                    ]),
                  ),
                ]
              : [
                  ResponsiveGrid(children: [for (final a in list) _AddressCard(address: a)]),
                ],
        ),
      ],
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address});
  final SavedAddress address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ctrl = ref.read(addressesControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    return EcoCard(
      onTap: () => context.go(Routes.addressEdit(address.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          EcoAvatar(
              text: address.isDefault ? '🏠' : '📍',
              gradient: address.isDefault ? EcoGradients.green : null),
          const SizedBox(width: 12),
          Expanded(child: Text(address.label, style: text.titleMedium)),
          if (address.isDefault) EcoChip(label: '⭐ ${l.addressDefault}', tone: ChipTone.sun),
        ]),
        const SizedBox(height: 10),
        Text('${address.street}, ${address.city}', style: text.bodyMedium),
        const SizedBox(height: 6),
        EcoChip(
          tone: address.hasPosition ? ChipTone.sky : ChipTone.coral,
          label: address.hasPosition
              ? '🛰️ ${address.latitude!.toStringAsFixed(4)}, ${address.longitude!.toStringAsFixed(4)}'
              : l.addressNoGps,
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 4, children: [
          if (!address.isDefault)
            EcoLink(label: l.addressMakeDefault, onPressed: () => ctrl.setDefault(address.id)),
          EcoLink(
            label: l.addressDelete,
            color: const Color(0xFFC4482A),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.addressDeleteConfirm),
                  actions: [
                    EcoLink(label: l.commonCancel, onPressed: () => Navigator.pop(ctx, false)),
                    EcoLink(
                        label: l.addressDelete,
                        color: const Color(0xFFC4482A),
                        onPressed: () => Navigator.pop(ctx, true)),
                  ],
                ),
              );
              if (ok == true) await ctrl.delete(address.id);
            },
          ),
        ]),
      ]),
    );
  }
}
