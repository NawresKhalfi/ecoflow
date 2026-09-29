import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/domain/validators.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../application/addresses_controller.dart';
import '../../application/profile_providers.dart';
import '../../domain/address.dart';

/// Création / modification d'une adresse avec position GPS (US-005).
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.addressId});

  final String? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  double? _lat;
  double? _lng;
  bool _isDefault = false;
  bool _locating = false;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_label, _street, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(List<SavedAddress> list) {
    if (_loaded) return;
    _loaded = true;
    final a = list.where((a) => a.id == widget.addressId).firstOrNull;
    if (a == null) {
      _isDefault = list.isEmpty;
      return;
    }
    _label.text = a.label;
    _street.text = a.street;
    _city.text = a.city;
    _lat = a.latitude;
    _lng = a.longitude;
    _isDefault = a.isDefault;
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final pos = await ref.read(addressesControllerProvider.notifier).locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _lat = pos?.latitude ?? _lat;
      _lng = pos?.longitude ?? _lng;
    });
    if (pos == null) showEcoToast(context, context.l10n.addressGpsUnavailable);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref
        .read(addressesControllerProvider.notifier)
        .save(
          SavedAddress(
            id: widget.addressId ?? '',
            label: _label.text.trim(),
            street: _street.text.trim(),
            city: _city.text.trim(),
            latitude: _lat,
            longitude: _lng,
            isDefault: _isDefault,
          ),
        );
    if (ok && mounted) {
      showEcoToast(context, context.l10n.addressSaved);
      context.go(Routes.addresses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = ref.watch(addressesProvider).value;
    if (list != null) _prefill(list);
    final state = ref.watch(addressesControllerProvider);
    final required = fieldValidator(context, (v) => validateRequired(v, maxLength: 120));
    return LayeredPage(
      header: HeroHeader(
        title: widget.addressId == null ? l.addAddress : l.editAddress,
        subtitle: l.addressesSubtitle,
        emoji: '🏠',
        gradient: EcoGradients.sky,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.addresses),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        EcoCard(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EcoTextField(
                  label: l.addressLabel,
                  emoji: '🏷️',
                  controller: _label,
                  validator: required,
                ),
                const SizedBox(height: 12),
                EcoTextField(
                  label: l.addressStreet,
                  emoji: '🏠',
                  controller: _street,
                  autofillHints: const [AutofillHints.fullStreetAddress],
                  validator: required,
                ),
                const SizedBox(height: 12),
                EcoTextField(
                  label: l.addressCity,
                  emoji: '🏙️',
                  controller: _city,
                  autofillHints: const [AutofillHints.addressCity],
                  validator: required,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EcoChip(
                      tone: _lat != null ? ChipTone.sky : ChipTone.coral,
                      label: _lat != null
                          ? '🛰️ ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                          : l.addressNoGps,
                    ),
                    EcoButton(
                      label: l.addressUseGps,
                      leading: '🛰️',
                      style: EcoButtonStyle.ghost,
                      expand: false,
                      loading: _locating,
                      onPressed: _locate,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.addressIsDefault, style: Theme.of(context).textTheme.titleSmall),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
                if (state.error != null) ...[
                  ErrorBanner(failureText(context, state.error!)),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                EcoButton(
                  label: l.commonSave,
                  style: EcoButtonStyle.green,
                  loading: state.isLoading,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
