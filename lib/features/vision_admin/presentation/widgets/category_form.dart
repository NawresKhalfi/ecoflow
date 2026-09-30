import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/domain/validators.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/vision_admin_controllers.dart';

/// Classes reconnues par le modèle embarqué.
const modelClasses = [
  'plastic',
  'metal',
  'cardboard',
  'paper',
  'glass',
  'e-waste',
  'organic',
  'medical',
];

/// Formulaire de création / modification d'une classe du catalogue.
Future<void> showCategoryForm(BuildContext context, {WasteCategory? existing}) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _CategoryForm(existing: existing),
      ),
    );

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.existing});
  final WasteCategory? existing;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _form = GlobalKey<FormState>();
  late final e = widget.existing;
  late final _id = TextEditingController(text: e?.id);
  late final _fr = TextEditingController(text: e?.names['fr']);
  late final _en = TextEditingController(text: e?.names['en']);
  late final _ar = TextEditingController(text: e?.names['ar']);
  late final _emoji = TextEditingController(text: e?.emoji ?? '♻️');
  late Recyclability _recyc = e?.recyclability ?? Recyclability.high;
  late RecyclableMaterial? _material = e?.material;
  late final Set<String> _labels = {...?e?.modelLabels};
  late bool _active = e?.active ?? true;

  @override
  void dispose() {
    for (final c in [_id, _fr, _en, _ar, _emoji]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref
        .read(catalogAdminControllerProvider.notifier)
        .save(
          WasteCategory(
            id: _id.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_'),
            names: {'fr': _fr.text.trim(), 'en': _en.text.trim(), 'ar': _ar.text.trim()},
            emoji: _emoji.text.trim(),
            recyclability: _recyc,
            modelLabels: _labels.toList()..sort(),
            material: _material,
            active: _active,
            order: e?.order ?? 50,
          ),
        );
    if (ok && mounted) {
      showEcoToast(context, context.l10n.catalogSaved);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(catalogAdminControllerProvider);
    final req = fieldValidator(context, (v) => validateRequired(v, maxLength: 60));
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                e == null ? l.catalogAdd : l.catalogEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              EcoTextField(label: l.catalogId, controller: _id, enabled: e == null, validator: req),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: EcoTextField(label: l.catalogEmoji, controller: _emoji, validator: req),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EcoTextField(label: l.catalogNameFr, controller: _fr, validator: req),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              EcoTextField(label: l.catalogNameEn, controller: _en, validator: req),
              const SizedBox(height: 10),
              EcoTextField(label: l.catalogNameAr, controller: _ar, validator: req),
              const SizedBox(height: 14),
              Text(l.catalogRecyclability, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in Recyclability.values)
                    EcoChip(
                      label: recyclabilityLabel(l, r),
                      selected: r == _recyc,
                      onTap: () => setState(() => _recyc = r),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(l.catalogMaterial, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EcoChip(
                    label: l.catalogNoMaterial,
                    selected: _material == null,
                    onTap: () => setState(() => _material = null),
                  ),
                  for (final m in RecyclableMaterial.values)
                    EcoChip(
                      label: materialLabel(l, m),
                      selected: m == _material,
                      onTap: () => setState(() => _material = m),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(l.catalogModelLabels, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in modelClasses)
                    EcoChip(
                      label: m,
                      tone: ChipTone.violet,
                      selected: _labels.contains(m),
                      onTap: () =>
                          setState(() => _labels.contains(m) ? _labels.remove(m) : _labels.add(m)),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.catalogActive),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              EcoButton(
                label: l.commonSave,
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: _save,
              ),
              if (e != null && e!.id != otherCategoryId)
                EcoLink(
                  label: l.catalogDelete,
                  color: const Color(0xFFC4482A),
                  onPressed: () async {
                    final ok = await ref
                        .read(catalogAdminControllerProvider.notifier)
                        .delete(e!.id);
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
