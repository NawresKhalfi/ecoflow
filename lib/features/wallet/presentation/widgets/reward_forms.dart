import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/wallet_providers.dart';
import '../../domain/rewards.dart';
import 'wallet_labels.dart';

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (c) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: child),
  ),
);

String? _required(AppLocalizations l, String? v) => (v ?? '').trim().isEmpty ? l.errRequired : null;

/// Création / modification d'un partenaire (US-074).
Future<void> showPartnerForm(BuildContext context, {Partner? existing}) =>
    _sheet(context, _PartnerForm(existing: existing));

class _PartnerForm extends ConsumerStatefulWidget {
  const _PartnerForm({this.existing});
  final Partner? existing;

  @override
  ConsumerState<_PartnerForm> createState() => _PartnerFormState();
}

class _PartnerFormState extends ConsumerState<_PartnerForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _city = TextEditingController(text: widget.existing?.city ?? 'Sousse');
  late final _emoji = TextEditingController(text: widget.existing?.emoji ?? '🏪');
  late bool _active = widget.existing?.active ?? true;

  @override
  void dispose() {
    for (final c in [_name, _city, _emoji]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(walletAdminControllerProvider);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.partnerFormTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          EcoTextField(label: l.partnerName, controller: _name, validator: (v) => _required(l, v)),
          const SizedBox(height: 10),
          EcoTextField(label: l.partnerCity, controller: _city),
          const SizedBox(height: 10),
          EcoTextField(label: l.partnerEmoji, controller: _emoji, maxLength: 4),
          SwitchListTile(
            value: _active,
            title: Text(l.adminActive),
            onChanged: (v) => setState(() => _active = v),
          ),
          EcoButton(
            label: l.commonSave,
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              final ok = await ref
                  .read(walletAdminControllerProvider.notifier)
                  .savePartner(
                    Partner(
                      id: widget.existing?.id ?? '',
                      name: _name.text.trim(),
                      city: _city.text.trim(),
                      emoji: _emoji.text.trim().isEmpty ? '🏪' : _emoji.text.trim(),
                      active: _active,
                    ),
                  );
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Création / modification d'une offre (US-074).
Future<void> showRewardForm(BuildContext context, List<Partner> partners, {Reward? existing}) =>
    _sheet(context, _RewardForm(partners: partners, existing: existing));

class _RewardForm extends ConsumerStatefulWidget {
  const _RewardForm({required this.partners, this.existing});
  final List<Partner> partners;
  final Reward? existing;

  @override
  ConsumerState<_RewardForm> createState() => _RewardFormState();
}

class _RewardFormState extends ConsumerState<_RewardForm> {
  final _form = GlobalKey<FormState>();
  late final e = widget.existing;
  late final _title = TextEditingController(text: e?.title);
  late final _desc = TextEditingController(text: e?.description);
  late final _emoji = TextEditingController(text: e?.emoji ?? '🎁');
  late final _cost = TextEditingController(text: e?.cost.toString());
  late final _stock = TextEditingController(text: e?.stock?.toString());
  late String? _partnerId = e?.partnerId ?? widget.partners.firstOrNull?.id;
  late RewardKind _kind = e?.kind ?? RewardKind.discount;
  late bool _active = e?.active ?? true;

  @override
  void dispose() {
    for (final c in [_title, _desc, _emoji, _cost, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(walletAdminControllerProvider);
    String? positive(String? v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : l.errInvalidNumber;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.rewardFormTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _partnerId,
            decoration: InputDecoration(labelText: l.rewardPartner),
            items: [
              for (final p in widget.partners)
                DropdownMenuItem(value: p.id, child: Text('${p.emoji} ${p.name}')),
            ],
            validator: (v) => v == null ? l.errRequired : null,
            onChanged: (v) => setState(() => _partnerId = v),
          ),
          const SizedBox(height: 10),
          EcoTextField(
            label: l.rewardTitleField,
            controller: _title,
            validator: (v) => _required(l, v),
          ),
          const SizedBox(height: 10),
          EcoTextField(label: l.rewardDescription, controller: _desc, maxLength: 200),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final k in RewardKind.values)
                EcoChip(
                  label: rewardKindLabel(l, k),
                  selected: _kind == k,
                  onTap: () => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: EcoTextField(
                  label: l.rewardCost,
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  validator: positive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EcoTextField(
                  label: l.rewardStockField,
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  helper: l.rewardStockHelp,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          EcoTextField(label: l.partnerEmoji, controller: _emoji, maxLength: 4),
          SwitchListTile(
            value: _active,
            title: Text(l.adminActive),
            onChanged: (v) => setState(() => _active = v),
          ),
          EcoButton(
            label: l.commonSave,
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              final partner = widget.partners.firstWhere((p) => p.id == _partnerId);
              final ok = await ref
                  .read(walletAdminControllerProvider.notifier)
                  .saveReward(
                    Reward(
                      id: e?.id ?? '',
                      partnerId: partner.id,
                      partnerName: partner.name,
                      title: _title.text.trim(),
                      description: _desc.text.trim(),
                      kind: _kind,
                      emoji: _emoji.text.trim().isEmpty ? '🎁' : _emoji.text.trim(),
                      cost: int.parse(_cost.text.trim()),
                      stock: int.tryParse(_stock.text.trim()),
                      active: _active,
                    ),
                  );
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
