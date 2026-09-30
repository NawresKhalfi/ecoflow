import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../collection/application/collection_providers.dart';
import '../../application/chat_controller.dart';
import '../../application/tracking_providers.dart';
import '../../domain/chat.dart';

/// Messagerie de la collecte, numéros masqués (US-067).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final uid = ref.watch(currentUidProvider);
    final r = ref.watch(collectionByIdProvider(widget.collectionId)).value;
    final messages = ref.watch(chatProvider(widget.collectionId)).value ?? const <ChatMessage>[];
    final state = ref.watch(chatControllerProvider);
    final role = ref.watch(currentProfileProvider).value?.role;
    final hm = DateFormat.Hm(Localizations.localeOf(context).languageCode);
    return LayeredPage(
      header: HeroHeader(
        title: l.chatTitle,
        subtitle: r?.place.address,
        emoji: '💬',
        gradient: EcoGradients.violet,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(
            role == UserRole.collector
                ? Routes.missionDetail(widget.collectionId)
                : Routes.collectionDetail(widget.collectionId),
          ),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.chatPrivacy, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              if (messages.isEmpty) Text(l.chatEmpty),
              for (final m in messages)
                Align(
                  alignment: m.fromUid == uid
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: m.fromUid == uid ? EcoColors.primary : context.eco.chipSky.$1,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.text,
                          style: AppTheme.weighted(
                            15,
                            500,
                            color: m.fromUid == uid ? Colors.white : context.eco.ink,
                          ),
                        ),
                        if (m.at != null)
                          Text(
                            hm.format(m.at!),
                            style: AppTheme.weighted(
                              11,
                              500,
                              color: m.fromUid == uid ? Colors.white70 : context.eco.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                maxLength: maxMessageLength,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(hintText: l.chatHint),
              ),
              EcoButton(
                label: l.chatSend,
                leading: '📨',
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: () async {
                  if (await ref
                      .read(chatControllerProvider.notifier)
                      .send(widget.collectionId, _text.text)) {
                    _text.clear();
                  }
                },
              ),
              const SizedBox(height: 8),
              EcoLink(
                label: '📞 ${l.chatCall}',
                onPressed: () => showEcoToast(context, l.chatCallUnavailable),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
