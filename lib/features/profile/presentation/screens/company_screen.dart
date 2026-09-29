import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/validators.dart';
import '../../../auth/domain/verification_status.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../application/company_controller.dart';
import '../../application/profile_providers.dart';
import '../../domain/company_profile.dart';
import '../widgets/verification_widgets.dart';

String materialLabel(AppLocalizations l, RecyclableMaterial m) => switch (m) {
  RecyclableMaterial.pet => l.matPet,
  RecyclableMaterial.hdpe => l.matHdpe,
  RecyclableMaterial.pp => l.matPp,
  RecyclableMaterial.cardboard => l.matCardboard,
  RecyclableMaterial.aluminium => l.matAluminium,
  RecyclableMaterial.glass => l.matGlass,
  RecyclableMaterial.other => l.matOther,
};

/// Profil entreprise du recycleur soumis à validation (US-007).
class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _taxId = TextEditingController();
  final _capacity = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _materials = <RecyclableMaterial>{};
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _taxId, _capacity, _city, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(CompanyProfile? p) {
    if (_loaded) return;
    _loaded = true;
    if (p == null) return;
    _name.text = p.legalName;
    _taxId.text = p.taxId;
    _capacity.text = p.monthlyCapacityTons.toString();
    _city.text = p.city;
    _phone.text = p.contactPhone;
    _materials.addAll(p.materials);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref
        .read(companyControllerProvider.notifier)
        .submit(
          CompanyProfile(
            legalName: _name.text,
            taxId: _taxId.text,
            materials: {..._materials},
            monthlyCapacityTons: double.parse(_capacity.text.trim().replaceAll(',', '.')),
            city: _city.text,
            contactPhone: normalizePhone(_phone.text) ?? _phone.text.trim(),
          ),
        );
    if (ok && mounted) showEcoToast(context, context.l10n.companySubmitted);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final company = ref.watch(companyProfileProvider);
    if (company.hasValue) _prefill(company.value);
    final profile = ref.watch(sessionProvider).profile;
    final status = profile?.verificationStatus ?? VerificationStatus.notSubmitted;
    final editable = status.canSubmit;
    final state = ref.watch(companyControllerProvider);
    final error = state.error;
    final req = fieldValidator(context, (v) => validateRequired(v, maxLength: 120));
    return LayeredPage(
      header: HeroHeader(
        title: l.companyTitle,
        subtitle: l.companySubtitle,
        emoji: '🏭',
        gradient: EcoGradients.sky,
      ),
      children: [
        if (profile != null)
          VerificationCard(
            role: profile.role,
            status: status,
            rejectionReason: profile.rejectionReason,
          ),
        if (!editable) EcoCard(child: Text(l.companyLocked)),
        EcoCard(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EcoTextField(
                  label: l.companyLegalName,
                  emoji: '🏢',
                  controller: _name,
                  validator: req,
                  enabled: editable,
                ),
                const SizedBox(height: 12),
                EcoTextField(
                  label: l.companyTaxId,
                  hint: l.companyTaxIdHint,
                  emoji: '🧾',
                  controller: _taxId,
                  enabled: editable,
                  validator: fieldValidator(context, validateTaxId),
                ),
                const SizedBox(height: 16),
                Text(l.companyMaterials, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in RecyclableMaterial.values)
                      EcoChip(
                        label: materialLabel(l, m),
                        selected: _materials.contains(m),
                        onTap: editable
                            ? () => setState(
                                () => _materials.contains(m)
                                    ? _materials.remove(m)
                                    : _materials.add(m),
                              )
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                EcoTextField(
                  label: l.companyCapacity,
                  emoji: '⚖️',
                  controller: _capacity,
                  enabled: editable,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: fieldValidator(context, validatePositiveNumber),
                ),
                const SizedBox(height: 12),
                EcoTextField(
                  label: l.companyCity,
                  emoji: '📍',
                  controller: _city,
                  validator: req,
                  enabled: editable,
                ),
                const SizedBox(height: 12),
                EcoTextField(
                  label: l.companyPhone,
                  emoji: '📞',
                  controller: _phone,
                  enabled: editable,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: fieldValidator(context, validatePhone),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(
                    error is NoMaterialSelected ? l.companyNoMaterial : failureText(context, error),
                  ),
                ],
                if (editable) ...[
                  const SizedBox(height: 16),
                  EcoButton(
                    label: l.companySubmit,
                    leading: '📨',
                    loading: state.isLoading,
                    onPressed: _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
