import 'dart:async';

import 'package:ecoflow/core/firebase/offline_write.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server ack within the grace period: synced', () async {
    expect(await settleWrite(Future.value()), WriteOutcome.synced);
    await expectLater(settleWrite(Future.error(StateError('denied'))), throwsStateError);
  });

  test('offline: queued, then synced or refused later (US-126)', () {
    fakeAsync((async) {
      final ack = Completer<void>();
      WriteOutcome? outcome;
      var done = false;
      settleWrite(ack.future, onLateDone: () => done = true).then((o) => outcome = o);
      async.elapse(const Duration(seconds: 2));
      expect(outcome, isNull, reason: 'still waiting for the server');
      async.elapse(const Duration(seconds: 2));
      expect(outcome, WriteOutcome.queued, reason: 'the UI is released');
      ack.complete();
      async.flushMicrotasks();
      expect(done, isTrue, reason: 'synced when the network is back');

      final refused = Completer<void>();
      Object? late;
      settleWrite(refused.future, onLateError: (e) => late = e);
      async.elapse(const Duration(seconds: 4));
      refused.completeError(StateError('mission changed'));
      async.flushMicrotasks();
      expect(late, isA<StateError>(), reason: 'conflict surfaced');
    });
  });

  test('sync tracker counts pending actions and conflicts', () {
    fakeAsync((async) {
      final c = ProviderContainer.test();
      final a = Completer<void>();
      final b = Completer<void>();
      final tracker = c.read(syncTrackerProvider.notifier);
      tracker.write(a.future);
      tracker.write(b.future);
      async.elapse(const Duration(seconds: 4));
      expect(c.read(syncTrackerProvider).pending, 2);
      a.complete();
      b.completeError(StateError('refused'));
      async.flushMicrotasks();
      final s = c.read(syncTrackerProvider);
      expect((s.pending, s.conflicts), (0, 1));
    });
  });
}
