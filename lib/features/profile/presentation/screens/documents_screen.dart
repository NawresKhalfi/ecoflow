import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/verification_status.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../application/documents_controller.dart';
import '../../application/profile_providers.dart';
import '../../data/document_picker.dart';
import '../../domain/collector_document.dart';
import '../widgets/verification_widgets.dart';

String documentLabel(AppLocalizations l, CollectorDocumentType t) => switch (t) {
      CollectorDocumentType.nationalId => l.docNationalId,
      CollectorDocumentType.drivingLicense => l.docDrivingLicense,
      CollectorDocumentType.vehicleRegistration => l.docVehicleRegistration,
      CollectorDocumentType.vehiclePhoto => l.docVehiclePhoto,
    };

String documentEmoji(CollectorDocumentType t) => switch (t) {
      CollectorDocumentType.nationalId => '🪪',
      CollectorDocumentType.drivingLicense => '🚗',
      CollectorDocumentType.vehicleRegistration => '📄',
      CollectorDocumentType.vehiclePhoto => '🚚',
    };

/// Dossier de vérification du collecteur (US-006).
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(sessionProvider).profile;
    final docs = ref.watch(collectorDocumentsProvider).value ?? const [];
    final state = ref.watch(documentsControllerProvider);
    final status = profile?.verificationStatus ?? VerificationStatus.notSubmitted;
    final editable = status.canSubmit;
    final complete = isDossierComplete(docs);
    final error = state.error;
    return LayeredPage(
      header: HeroHeader(
        title: l.documentsTitle,
        subtitle: l.documentsSubtitle,
        emoji: '🪪',
        gradient: EcoGradients.coral,
      ),
      children: [
        if (profile != null)
          VerificationCard(
              role: profile.role, status: status, rejectionReason: profile.rejectionReason),
        EcoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(l.docProgress(docs.length), style: Theme.of(context).textTheme.titleMedium)),
              StatusChip(status),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: docs.length / CollectorDocumentType.values.length,
                minHeight: 12,
                backgroundColor: context.eco.line,
                color: EcoColors.coral,
              ),
            ),
            const SizedBox(height: 6),
            for (final (i, type) in CollectorDocumentType.values.indexed)
              _DocumentRow(
                type: type,
                doc: docs.where((d) => d.type == type).firstOrNull,
                editable: editable && !state.isLoading,
                last: i == CollectorDocumentType.values.length - 1,
              ),
          ]),
        ),
        if (error != null)
          ErrorBanner(error is DocumentTooLarge ? l.docTooLarge : failureText(context, error)),
        if (editable)
          EcoButton(
            label: complete ? l.docSubmit : l.docIncomplete,
            leading: '📨',
            loading: state.isLoading,
            onPressed: complete
                ? () async {
                    final ok = await ref.read(documentsControllerProvider.notifier).submit();
                    if (ok && context.mounted) showEcoToast(context, l.docSubmitted);
                  }
                : null,
          ),
      ],
    );
  }
}

class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({required this.type, required this.doc, required this.editable, required this.last});

  final CollectorDocumentType type;
  final CollectorDocument? doc;
  final bool editable;
  final bool last;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final source = await showModalBottomSheet<PickSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            EcoButton(
                label: l.docTakePhoto,
                leading: '📷',
                style: EcoButtonStyle.green,
                onPressed: () => Navigator.pop(ctx, PickSource.camera)),
            const SizedBox(height: 10),
            EcoButton(
                label: l.docFromGallery,
                leading: '🖼️',
                style: EcoButtonStyle.ghost,
                onPressed: () => Navigator.pop(ctx, PickSource.gallery)),
          ]),
        ),
      ),
    );
    if (source == null) return;
    final ok = await ref.read(documentsControllerProvider.notifier).pickAndUpload(type, source);
    if (ok && context.mounted && ref.read(documentsControllerProvider).error == null) {
      showEcoToast(context, l.docUploaded);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = doc;
    return EcoListTile(
      leading: EcoAvatar(text: documentEmoji(type), gradient: d != null ? EcoGradients.green : null),
      title: documentLabel(l, type),
      subtitle: d == null
          ? null
          : [
              '${d.fileName} · ${(d.sizeBytes / 1024).round()} Ko',
              if ((d.rejectionReason ?? '').isNotEmpty) l.verifReason(d.rejectionReason!),
            ].join('\n'),
      showDivider: !last,
      trailing: editable
          ? EcoChip(
              label: d == null ? '➕ ${l.docUpload}' : '🔄 ${l.docReplace}',
              tone: d == null ? ChipTone.coral : ChipTone.green,
              onTap: () => _pick(context, ref),
            )
          : (d != null ? StatusChip(d.status) : null),
    );
  }
}
