import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/domain/collection_request.dart';
import '../../../collection/domain/feedback.dart';
import '../../../profile/data/document_picker.dart';
import '../../application/mission_actions_controller.dart';
import '../../data/mission_repository.dart';
import 'mission_labels.dart';

/// Citoyen absent / adresse introuvable (US-053).
Future<void> showNoShowSheet(BuildContext context, CollectionRequest r) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _NoShowForm(request: r),
      ),
    );

class _NoShowForm extends ConsumerStatefulWidget {
  const _NoShowForm({required this.request});
  final CollectionRequest request;

  @override
  ConsumerState<_NoShowForm> createState() => _NoShowFormState();
}

class _NoShowFormState extends ConsumerState<_NoShowForm> {
  NoShowReason _reason = NoShowReason.citizenAbsent;
  final _note = TextEditingController();
  Uint8List? _photo;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(missionActionsControllerProvider);
    final ctrl = ref.read(missionActionsControllerProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.missionNoShow, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final r in NoShowReason.values)
                  EcoChip(
                    label: noShowLabel(l, r),
                    selected: _reason == r,
                    onTap: () => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: maxCommentLength,
              maxLines: 3,
              decoration: InputDecoration(hintText: l.noShowNote),
            ),
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_photo!, height: 100, fit: BoxFit.cover),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: EcoChip(
                  label: '📷 ${l.noShowPhoto}',
                  onTap: () async {
                    final p = await ctrl.pickPhoto(PickSource.camera);
                    if (p != null && mounted) setState(() => _photo = p);
                  },
                ),
              ),
            const SizedBox(height: 12),
            EcoButton(
              label: l.noShowSend,
              leading: '📨',
              loading: state.isLoading,
              onPressed: () async {
                final ok = await ctrl.reportNoShow(widget.request, _reason, _note.text, _photo);
                if (ok && context.mounted) {
                  showEcoToast(context, l.noShowDone);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
