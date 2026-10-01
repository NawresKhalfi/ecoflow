import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../recycler/domain/stock.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../application/market_providers.dart';
import '../../domain/market.dart';

/// Publication ou modification d'une annonce (US-094, US-095) ; une vente
/// peut partir d'un lot du stock ([fromLot]).
Future<bool?> showListingForm(
  BuildContext context, {
  Listing? existing,
  ListingType type = ListingType.sell,
  StockLot? fromLot,
}) => showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (c) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: _ListingForm(existing: existing, type: type, lot: fromLot),
    ),
  ),
);

class _ListingForm extends ConsumerStatefulWidget {
  const _ListingForm({this.existing, required this.type, this.lot});
  final Listing? existing;
  final ListingType type;
  final StockLot? lot;

  @override
  ConsumerState<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends ConsumerState<_ListingForm> {
  late final e = widget.existing;
  late ListingType _type = e?.type ?? widget.type;
  late RecyclableMaterial _material = e?.material ?? widget.lot?.material ?? RecyclableMaterial.pet;
  late MaterialForm _form = e?.form ?? widget.lot?.form ?? MaterialForm.raw;
  late QualityGrade? _grade = e?.grade ?? widget.lot?.grade;
  late final _qty = TextEditingController(
    text: (e?.quantityKg ?? widget.lot?.kg)?.toStringAsFixed(0) ?? '',
  );
  late final _price = TextEditingController(text: e?.priceDtPerKg?.toString() ?? '');
  late final _city = TextEditingController(text: e?.city ?? '');
  late final _desc = TextEditingController(text: e?.description ?? '');
  late int _days = 30;
  bool _cityFilled = false;

  @override
  void dispose() {
    for (final c in [_qty, _price, _city, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(marketControllerProvider);
    final company = ref.watch(companyProfileProvider).value;
    // Ville de l'entreprise proposée une seule fois (l'utilisateur peut l'effacer).
    if (!_cityFilled && company != null) {
      _cityFilled = true;
      if (_city.text.isEmpty) _city.text = company.city;
    }
    final now = ref.watch(clockProvider)();
    final deadline = e?.deadline ?? DateTime(now.year, now.month, now.day + _days, 23, 59);
    final draft = Listing(
      id: e?.id ?? '',
      type: _type,
      ownerUid: ref.read(currentUidProvider) ?? '',
      ownerName: company?.legalName ?? '',
      material: _material,
      form: _form,
      grade: _grade,
      quantityKg: _num(_qty) ?? 0,
      priceDtPerKg: _price.text.trim().isEmpty ? null : _num(_price),
      city: _city.text.trim(),
      deadline: deadline,
      description: _desc.text.trim(),
      lotIds: e?.lotIds ?? [?widget.lot?.id],
    );
    final issue = validateListing(draft, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(e == null ? l.listingNew : l.listingEdit, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (e == null && widget.lot == null)
          SegmentedButton<ListingType>(
            segments: [
              ButtonSegment(value: ListingType.sell, label: Text(l.listingSell)),
              ButtonSegment(value: ListingType.buy, label: Text(l.listingBuy)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        if (widget.lot != null) EcoChip(label: '🏷️ ${widget.lot!.reference}', tone: ChipTone.sky),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in RecyclableMaterial.values)
              EcoChip(
                label: '${materialEmoji(m)} ${materialLabel(l, m)}',
                selected: _material == m,
                onTap: widget.lot == null ? () => setState(() => _material = m) : null,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in MaterialForm.values)
              EcoChip(label: formLabel(l, f), selected: _form == f, onTap: () => setState(() => _form = f)),
            for (final g in QualityGrade.values)
              EcoChip(
                label: gradeLabel(l, g),
                tone: ChipTone.sun,
                selected: _grade == g,
                onTap: () => setState(() => _grade = _grade == g ? null : g),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: EcoTextField(
                label: l.listingQty,
                controller: _qty,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: EcoTextField(
                label: _type == ListingType.sell ? l.listingPrice : l.listingMaxPrice,
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                helper: _type == ListingType.buy ? l.listingOptional : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        EcoTextField(label: l.listingCity, controller: _city, emoji: '📍', onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        if (e == null) ...[
          Text(
            _type == ListingType.buy ? l.listingNeededBy(fmtDate(context, deadline)) : l.listingAvailableUntil(fmtDate(context, deadline)),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final d in [7, 14, 30, 60])
                EcoChip(label: l.listingInDays(d), selected: _days == d, onTap: () => setState(() => _days = d)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        EcoTextField(label: l.rewardDescription, controller: _desc, maxLength: 1000),
        const SizedBox(height: 8),
        EcoButton(
          label: e == null ? l.listingPublish : l.commonSave,
          leading: '📢',
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: issue != null
              ? null
              : () async {
                  final ok = await ref.read(marketControllerProvider.notifier).saveListing(draft);
                  if (context.mounted) Navigator.pop(context, ok);
                },
        ),
      ],
    );
  }
}
