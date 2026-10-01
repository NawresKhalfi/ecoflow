import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../collection/application/collection_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/admin_providers.dart';
import '../../domain/admin.dart';

/// Annonces à un segment d'utilisateurs : rôle et zone (US-116).
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  UserRole? _role;
  String? _zone;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final zones = ref.watch(collectionConfigProvider).value?.zones ?? const [];
    final sent = ref.watch(announcementsProvider).value ?? const <Announcement>[];
    final state = ref.watch(adminControllerProvider);
    String segmentLabel(Segment s) => [
      s.role == null ? l.broadcastEveryone : roleLabel(l, s.role!),
      if (s.zoneId != null) zones.where((z) => z.id == s.zoneId).firstOrNull?.name ?? s.zoneId!,
    ].join(' · ');
    return LayeredPage(
      header: HeroHeader(
        title: l.broadcastTitle,
        subtitle: l.broadcastSubtitle,
        emoji: '📣',
        gradient: EcoGradients.coral,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.supervision),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EcoTextField(
                label: l.broadcastTitleField,
                controller: _title,
                maxLength: maxAnnouncementTitle,
              ),
              const SizedBox(height: 8),
              EcoTextField(
                label: l.broadcastBody,
                controller: _body,
                maxLength: maxAnnouncementBody,
              ),
              const SizedBox(height: 8),
              Text(l.broadcastSegment, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EcoChip(
                    label: l.broadcastEveryone,
                    selected: _role == null,
                    onTap: () => setState(() => _role = null),
                  ),
                  for (final r in [UserRole.citizen, UserRole.collector, UserRole.recycler])
                    EcoChip(
                      label: roleLabel(l, r),
                      selected: _role == r,
                      onTap: () => setState(() => _role = r),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _zone,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.dashZone),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.dashAllZones)),
                  for (final z in zones) DropdownMenuItem(value: z.id, child: Text(z.name)),
                ],
                onChanged: (v) => setState(() => _zone = v),
              ),
              const SizedBox(height: 12),
              EcoButton(
                label: l.broadcastSend,
                leading: '📣',
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: () async {
                  final ok = await ref
                      .read(adminControllerProvider.notifier)
                      .announce(_title.text, _body.text, Segment(role: _role, zoneId: _zone));
                  if (!context.mounted) return;
                  showEcoToast(context, ok ? l.broadcastSent : l.broadcastInvalid);
                  if (ok) {
                    _title.clear();
                    _body.clear();
                  }
                },
              ),
            ],
          ),
        ),
        if (sent.isNotEmpty) ...[
          SectionTitle('🕒 ${l.broadcastHistory}'),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, a) in sent.indexed)
                  EcoListTile(
                    leading: const EcoAvatar(text: '📣'),
                    title: a.title,
                    subtitle: [
                      segmentLabel(a.segment),
                      if (a.createdAt != null) fmtDate(context, a.createdAt!),
                    ].join(' · '),
                    showDivider: i < sent.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
