import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/eco_widgets.dart';

/// Consentement explicite obligatoire avant toute écriture Firebase.
class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(!value),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(l.consentLabel, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 36),
          child: EcoLink(label: l.consentRead, onPressed: () => context.push(Routes.privacy)),
        ),
      ],
    );
  }
}
