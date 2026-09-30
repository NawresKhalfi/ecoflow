import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/data/document_picker.dart';
import '../../application/collection_actions_controller.dart';
import '../../domain/collection_request.dart';
import '../../domain/feedback.dart';
import 'collection_labels.dart';

/// Note 1 à 5 étoiles + commentaire, une seule fois (US-040).
class RatingCard extends ConsumerStatefulWidget {
  const RatingCard({super.key, required this.request});
  final CollectionRequest request;

  @override
  ConsumerState<RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends ConsumerState<RatingCard> {
  int _stars = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(collectionActionsControllerProvider);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('⭐ ${l.detRateTitle}', style: Theme.of(context).textTheme.titleMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i/5',
                  iconSize: 36,
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF5A800),
                  ),
                ),
            ],
          ),
          TextField(
            controller: _comment,
            maxLength: maxCommentLength,
            maxLines: 2,
            decoration: InputDecoration(hintText: l.detRateComment),
          ),
          EcoButton(
            label: l.detRateSend,
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: _stars == 0
                ? null
                : () async {
                    final ok = await ref
                        .read(collectionActionsControllerProvider.notifier)
                        .rate(widget.request, _stars, _comment.text);
                    if (ok && context.mounted) showEcoToast(context, l.detRated);
                  },
          ),
        ],
      ),
    );
  }
}

/// Signalement d'un problème avec motif et photos (US-041).
Future<void> showReportSheet(BuildContext context, CollectionRequest r) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ReportForm(request: r),
      ),
    );

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.request});
  final CollectionRequest request;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  ProblemReason _reason = ProblemReason.collectorAbsent;
  final _text = TextEditingController();
  final _photos = <Uint8List>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(collectionActionsControllerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.detReport, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ProblemReason.values)
                  EcoChip(
                    label: reasonLabel(l, r),
                    selected: _reason == r,
                    onTap: () => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLength: maxCommentLength,
              maxLines: 4,
              decoration: InputDecoration(hintText: l.reportDescription),
            ),
            if (_photos.length < maxReportPhotos)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: EcoChip(
                  label: '📷 ${l.reportAddPhoto(_photos.length)}',
                  onTap: () async {
                    final f = await ref.read(documentPickerProvider).pick(PickSource.gallery);
                    if (f != null && mounted) setState(() => _photos.add(f.bytes));
                  },
                ),
              ),
            const SizedBox(height: 12),
            EcoButton(
              label: l.reportSend,
              leading: '📨',
              loading: state.isLoading,
              onPressed: _text.text.trim().isEmpty && _reason == ProblemReason.other
                  ? null
                  : () async {
                      final ok = await ref
                          .read(collectionActionsControllerProvider.notifier)
                          .report(widget.request, _reason, _text.text, _photos);
                      if (ok && context.mounted) {
                        showEcoToast(context, l.reportSent);
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
