import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/domain/validators.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../application/vision_admin_controllers.dart';
import '../../domain/model_version.dart';

/// Chemin de modèle valide : URL https ou asset embarqué.
bool isValidModelSource(String v) {
  final t = v.trim();
  return t.startsWith('https://') || t.startsWith('assets/');
}

/// Ratio 0..1 optionnel.
double? parseRatio(String v) {
  final t = v.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  return n != null && n >= 0 && n <= 1 ? n : double.nan;
}

Future<void> showVersionForm(BuildContext context) => showModalBottomSheet<void>(
  useRootNavigator: true,
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: const _VersionForm(),
  ),
);

class _VersionForm extends ConsumerStatefulWidget {
  const _VersionForm();

  @override
  ConsumerState<_VersionForm> createState() => _VersionFormState();
}

class _VersionFormState extends ConsumerState<_VersionForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _ios = TextEditingController();
  final _android = TextEditingController();
  final _p = TextEditingController();
  final _r = TextEditingController();
  final _m = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _ios, _android, _p, _r, _m]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(modelAdminControllerProvider);
    String? source(String? v) => isValidModelSource(v ?? '') ? null : l.errInvalidUrl;
    String? ratio(String? v) => (parseRatio(v ?? '')?.isNaN ?? false) ? l.errInvalidRatio : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.modelAddVersion, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              EcoTextField(
                label: l.modelName,
                controller: _name,
                validator: fieldValidator(context, (v) => validateRequired(v)),
              ),
              const SizedBox(height: 10),
              EcoTextField(
                label: l.modelIos,
                controller: _ios,
                keyboardType: TextInputType.url,
                validator: source,
              ),
              const SizedBox(height: 10),
              EcoTextField(
                label: l.modelAndroid,
                controller: _android,
                keyboardType: TextInputType.url,
                validator: source,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: EcoTextField(label: l.modelPrecision, controller: _p, validator: ratio),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EcoTextField(label: l.modelRecall, controller: _r, validator: ratio),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EcoTextField(label: l.modelMap, controller: _m, validator: ratio),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              EcoButton(
                label: l.commonSave,
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final id = 'v-${DateTime.now().millisecondsSinceEpoch}';
                  final ok = await ref
                      .read(modelAdminControllerProvider.notifier)
                      .addVersion(
                        ModelVersion(
                          id: id,
                          name: _name.text.trim(),
                          iosModel: _ios.text.trim(),
                          androidModel: _android.text.trim(),
                          precision: parseRatio(_p.text),
                          recall: parseRatio(_r.text),
                          map50: parseRatio(_m.text),
                        ),
                      );
                  if (ok && context.mounted) {
                    showEcoToast(context, l.modelVersionSaved);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
