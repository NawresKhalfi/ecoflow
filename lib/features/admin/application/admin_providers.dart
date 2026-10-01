import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/application/collection_providers.dart';
import '../../collection/domain/service_zone.dart';
import '../../recycler/application/recycler_providers.dart';
import '../../recycler/domain/analytics.dart';
import '../../scan/application/scan_providers.dart';
import '../../scan/domain/waste_category.dart';
import '../../vision_admin/application/vision_admin_controllers.dart';
import '../data/admin_repository.dart';
import '../data/platform_report.dart';
import '../domain/admin.dart';
import '../domain/platform_stats.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(firestoreProvider)),
);

List<WasteCategory> _catalog(Ref ref) => ref.read(catalogProvider).value ?? defaultCatalog;

final adminUsersProvider = StreamProvider<List<AdminUserView>>(
  (ref) => ref.watch(adminRepositoryProvider).watchUsers(),
);

final pendingReviewsProvider = FutureProvider.autoDispose<List<PendingReview>>(
  (ref) => ref.watch(adminRepositoryProvider).pendingReviews(),
);

final liveCollectionsProvider = StreamProvider.autoDispose<List<CollectionStat>>(
  (ref) => ref.watch(adminRepositoryProvider).watchLive(_catalog(ref)),
);

final onlineCollectorsProvider = StreamProvider.autoDispose<List<OnlineCollector>>(
  (ref) => ref.watch(adminRepositoryProvider).watchOnlineCollectors(),
);

/// Données brutes des indicateurs (rechargées à l'ouverture).
final statsDataProvider =
    FutureProvider.autoDispose<
      ({List<CollectionStat> collections, List<UserStat> users, List<ScanTiming> scans})
    >((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return (
        collections: await repo.allCollections(_catalog(ref)),
        users: await repo.userStats(),
        scans: await repo.scanTimings().catchError((_) => const <ScanTiming>[]),
      );
    });

final scanLatencyProvider = Provider.autoDispose<({int? p90Ms, double? withinTarget, int count})?>((
  ref,
) {
  final data = ref.watch(statsDataProvider).value;
  if (data == null) return null;
  final now = ref.watch(clockProvider)();
  final p = ref.watch(statsPeriodProvider);
  return scanLatency(data.scans, now.subtract(Duration(days: p.days)), now);
});

class StatsPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.month;

  void set(ReportPeriod p) => state = p;
}

final statsPeriodProvider = NotifierProvider<StatsPeriodNotifier, ReportPeriod>(
  StatsPeriodNotifier.new,
);

final platformStatsProvider = Provider.autoDispose<PlatformStats?>((ref) {
  final data = ref.watch(statsDataProvider).value;
  if (data == null) return null;
  final now = ref.watch(clockProvider)();
  final p = ref.watch(statsPeriodProvider);
  return platformStats(data.collections, data.users, now.subtract(Duration(days: p.days)), now);
});

final disputesProvider = StreamProvider<List<Dispute>>(
  (ref) => ref.watch(adminRepositoryProvider).watchDisputes(),
);

final auditProvider = StreamProvider.autoDispose<List<AuditEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).watchAudit(),
);

final announcementsProvider = StreamProvider<List<Announcement>>(
  (ref) => ref.watch(adminRepositoryProvider).watchAnnouncements(),
);

/// Annonces qui concernent l'utilisateur connecté (rôle et zones de ses
/// collectes).
final myAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  final role = ref.watch(sessionProvider).role;
  if (role == null) return const [];
  final zones = <String>{
    for (final c in ref.watch(myCollectionsProvider).value ?? const []) c.place.zoneId,
  };
  return [
    for (final a in ref.watch(announcementsProvider).value ?? const <Announcement>[])
      if (a.segment.matches(role, zones)) a,
  ];
});

/// Actions d'administration (US-106 à US-117).
class AdminController extends ActionController {
  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    ref.watch(currentProfileProvider);
    return super.build();
  }

  ({String uid, String name}) get _actor => (
    uid: ref.read(currentUidProvider)!,
    name: ref.read(currentProfileProvider).value?.displayName ?? '',
  );
  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<bool> setBlocked(AdminUserView u, {required bool blocked, String reason = ''}) =>
      run(() => _repo.setBlocked(_actor, u, blocked: blocked, reason: reason));

  Future<bool> setAdmin(AdminUserView u, {required bool admin, Set<String>? permissions}) =>
      run(() async {
        if (u.uid == _actor.uid) throw StateError('self');
        await _repo.setAdmin(_actor, u, admin: admin, permissions: permissions);
      });

  Future<bool> review(PendingReview r, {required bool approve, String reason = ''}) =>
      run(() async {
        if (!approve && reason.trim().isEmpty) throw ArgumentError('reason');
        await _repo.review(_actor, r, approve: approve, reason: reason);
        ref.invalidate(pendingReviewsProvider);
      });

  Future<bool> resolve(Dispute d, {required bool upheld, required String resolution}) =>
      run(() async {
        if (resolution.trim().isEmpty) throw ArgumentError('resolution');
        await _repo.resolveDispute(_actor, d, upheld: upheld, resolution: resolution);
      });

  Future<bool> announce(String title, String body, Segment s) => run(() async {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty ||
        b.isEmpty ||
        t.length > maxAnnouncementTitle ||
        b.length > maxAnnouncementBody) {
      throw ArgumentError('announcement');
    }
    await _repo.announce(_actor, t, b, s);
  });

  Future<bool> saveZones(List<ServiceZone> zones) => run(() => _repo.saveZones(_actor, zones));

  /// Rapport global PDF ou Excel pour les partenaires (US-115).
  Future<bool> export(
    PlatformStats s,
    PlatformReportLabels l, {
    required bool pdf,
  }) => run(() async {
    final now = ref.read(clockProvider)();
    final Uint8List bytes = pdf
        ? await buildPlatformPdf(
            s,
            l,
            font: await rootBundle.load('assets/fonts/BricolageGrotesque.ttf'),
          )
        : buildPlatformXlsx(s, l);
    final dir = await ref.read(exportDirectoryProvider)();
    final name =
        'ecoflow_rapport_plateforme_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.${pdf ? 'pdf' : 'xlsx'}';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    await ref.read(fileSharerProvider)(file.path);
  });
}

final adminControllerProvider = NotifierProvider.autoDispose<AdminController, AsyncValue<void>>(
  AdminController.new,
);
