import 'package:ecoflow/core/firebase/offline_write.dart';
import 'package:ecoflow/core/widgets/sync_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('offline banner tells the collector actions are kept (US-126)', (t) async {
    await pumpScreen(
      t,
      const SyncBanner(),
      overrides: [offlineProvider.overrideWithValue(const AsyncData(true))],
    );
    await settle(t);
    expect(find.textContaining('Hors ligne : tes actions sont enregistrées'), findsOneWidget);
  });
}
