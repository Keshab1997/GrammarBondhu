import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/remote/progress_cloud_backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake cloud store whose `mergeAndWrite` calls can be held behind a gate,
/// so a sync stays in flight while the device makes local edits, disconnects,
/// or switches accounts.
class _GateFakeStore implements ProgressBackupStore {
  _GateFakeStore();

  /// When set, every call fails with this instead of writing.
  Object? error;

  /// Every invocation, with the local snapshot it was asked to upload.
  final List<_Call> calls = [];

  /// Every completed write, in completion order.
  final List<_Write> writes = [];
  final List<Completer<void>> _gates = [];
  final List<Completer<void>> _finishers = [];

  /// A held call blocks the moment `mergeAndWrite` is invoked.
  bool get isBlocked => _gates.isNotEmpty;

  /// Completes once every finished call has returned (success or failure).
  Future<void> get allCallsFinished =>
      Future.wait(_finishers.map((finisher) => finisher.future));

  @override
  Future<UserProgress> mergeAndWrite(String userId, UserProgress local) async {
    calls.add(
        _Call(userId: userId, local: UserProgress.fromJson(local.toJson())));
    final finished = Completer<void>();
    _finishers.add(finished);
    try {
      if (_gates.isNotEmpty) {
        final gate = Completer<void>();
        _gates.add(gate);
        await gate.future;
      }
      if (error != null) throw error!;
      // An empty remote account: the upload becomes the cloud snapshot.
      final merged = UserProgress.fromJson(local.toJson());
      writes.add(_Write(userId: userId, progress: merged));
      return merged;
    } finally {
      finished.complete();
      _finishers.remove(finished);
    }
  }

  /// Hold the next call that reaches `mergeAndWrite` behind a network gate.
  void block() => _gates.add(Completer<void>());

  /// Release every held call and clear the gate list.
  void releaseAll() {
    for (final gate in _gates) {
      if (!gate.isCompleted) gate.complete();
    }
    _gates.clear();
  }
}

class _Call {
  const _Call({required this.userId, required this.local});
  final String userId;
  final UserProgress local;
}

class _Write {
  const _Write({required this.userId, required this.progress});
  final String userId;
  final UserProgress progress;
}

Future<LocalStore> _mockStore() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore(await SharedPreferences.getInstance());
}

/// Pumps microtasks until [condition] holds, then asserts that it did.
Future<void> _pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future.delayed(Duration.zero);
  }
  expect(condition(), isTrue, reason: 'condition never became true');
}

void main() {
  group('in-flight cloud sync races', () {
    test('progress earned locally while a sync is in flight is not lost',
        () async {
      final store = await _mockStore();
      final fake = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: fake));

      expect(controller.dailyGoalQuestions, 5);
      expect(controller.cloudConnected, isTrue);

      fake.block();
      await controller.setDailyGoal(8);
      await _pumpUntil(() => fake.calls.length == 2);
      expect(fake.isBlocked, isTrue);

      // Earned while the sync above is waiting on the network.
      await controller.setDailyGoal(12);

      fake.releaseAll();
      await _pumpUntil(() => fake.writes.length == 3);

      expect(controller.dailyGoalQuestions, 12);
      expect(controller.cloudSyncing, isFalse);
      expect(controller.lastCloudSyncError, isNull);
      // The sync that ran after both edits uploaded the newer local snapshot.
      expect(fake.writes.last.progress.dailyGoalQuestions, 12);
      expect(fake.calls.last.local.dailyGoalQuestions, 12);
    });

    test('disconnect mid-sync: the late result cannot alter current data',
        () async {
      final store = await _mockStore();
      final fake = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: fake));

      fake.block();
      await controller.setDailyGoal(8);
      await _pumpUntil(() => fake.calls.length == 2);

      controller.disconnectCloudBackup();
      expect(controller.cloudConnected, isFalse);
      expect(controller.cloudSyncing, isFalse);

      // Guest edits under no account must stay local.
      await controller.setDailyGoal(12);
      expect(controller.dailyGoalQuestions, 12);

      // The old account's late result completes now and is discarded.
      fake.releaseAll();
      await _pumpUntil(() => fake.writes.length == 2);

      expect(controller.dailyGoalQuestions, 12);
      expect(controller.cloudConnected, isFalse);
      expect(controller.cloudSyncing, isFalse);
      expect(controller.lastCloudSyncError, isNull);

      // Only pre-disconnect snapshots were written to the old account: the
      // newer guest edit (12) was never sent to it.
      final oldAccountWrites =
          fake.writes.where((write) => write.userId == 'learner-a').toList();
      expect(oldAccountWrites.length, 2);
      expect(
          oldAccountWrites
              .every((write) => write.progress.dailyGoalQuestions != 12),
          isTrue);
    });

    test('account switch mid-sync: the old account\'s late result is discarded',
        () async {
      final store = await _mockStore();
      final fakeA = _GateFakeStore();
      final fakeB = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: fakeA));

      fakeA.block();
      await controller.setDailyGoal(8);
      await _pumpUntil(() => fakeA.calls.length == 2);

      controller.disconnectCloudBackup();
      // A's late result completes after the session ended: discarded.
      fakeA.releaseAll();
      await _pumpUntil(() => fakeA.writes.length == 2);

      await controller.connectCloudBackup(
          userId: 'learner-b', backup: ProgressCloudBackup(store: fakeB));
      expect(controller.cloudConnected, isTrue);

      await controller.setDailyGoal(15);
      await _pumpUntil(() => fakeB.writes.length == 2);

      expect(controller.dailyGoalQuestions, 15);
      expect(controller.cloudSyncing, isFalse);
      expect(controller.lastCloudSyncError, isNull);
      expect(fakeB.writes.last.progress.dailyGoalQuestions, 15);
      // B's newer data was never written to A's document.
      expect(
          fakeA.writes
              .every((write) => write.progress.dailyGoalQuestions != 15),
          isTrue);
    });

    test('account switch mid-sync: the old account\'s late error is discarded',
        () async {
      final store = await _mockStore();
      final fakeA = _GateFakeStore();
      final fakeB = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: fakeA));

      fakeA.block();
      await controller.setDailyGoal(8);
      await _pumpUntil(() => fakeA.calls.length == 2);

      controller.disconnectCloudBackup();
      fakeA.error = StateError('network down');
      fakeA.releaseAll();
      await fakeA.allCallsFinished;

      // A's late failure must not become the current session's error.
      expect(controller.lastCloudSyncError, isNull);
      expect(controller.cloudSyncing, isFalse);

      await controller.connectCloudBackup(
          userId: 'learner-b', backup: ProgressCloudBackup(store: fakeB));
      await controller.setDailyGoal(15);
      await _pumpUntil(() => fakeB.writes.length == 2);

      expect(controller.dailyGoalQuestions, 15);
      expect(controller.cloudConnected, isTrue);
      expect(controller.lastCloudSyncError, isNull);
    });

    test('current-session failure records the error and a retry clears it',
        () async {
      final store = await _mockStore();
      final flaky = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: flaky));
      expect(controller.lastCloudSyncError, isNull);

      flaky.error = StateError('network down');
      try {
        await controller.syncCloudNow();
        fail('syncCloudNow should throw the current session\'s error');
      } on StateError {
        // Expected: the current session records the failure.
      }
      expect(controller.lastCloudSyncError, isInstanceOf<StateError>());
      expect(controller.cloudSyncing, isFalse);

      // Retry from the Profile screen: the same session recovers.
      flaky.error = null;
      await controller.syncCloudNow();
      expect(controller.lastCloudSyncError, isNull);
      expect(controller.cloudSyncing, isFalse);
    });

    test('syncCloudNow throws when no account is connected', () async {
      final store = await _mockStore();
      final controller = ProgressController(store, UserProgress());
      Object? caught;
      try {
        await controller.syncCloudNow();
      } catch (error) {
        caught = error;
      }
      expect(caught, isInstanceOf<StateError>());
      expect(controller.lastCloudSyncError, isNull);
    });

    test('queued A sync is not hijacked by an account switch to B', () async {
      final store = await _mockStore();
      final fakeA = _GateFakeStore();
      final fakeB = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: fakeA));
      await _pumpUntil(() => fakeA.writes.length == 1);

      // Hold A's background sync.
      fakeA.block();
      await controller.setDailyGoal(8);
      await _pumpUntil(() => fakeA.calls.length == 2);
      expect(fakeA.isBlocked, isTrue);

      // Queue an A manual sync behind the held background sync. Do not await
      // it: syncCloudNow blocks on _cloudQueue, which A is currently holding.
      unawaited(controller.syncCloudNow());

      // Switch to B and make a B edit while A's syncs are queued/held.
      // connectCloudBackup(B) also suspends on _cloudQueue, but the account
      // switch itself (session, backup, userId) takes effect synchronously
      // before the await, so B is live immediately.
      unawaited(controller.connectCloudBackup(
          userId: 'learner-b', backup: ProgressCloudBackup(store: fakeB)));
      await controller.setDailyGoal(15);

      // Release A: A's late result and the queued manual sync complete and
      // are discarded because the session has moved to B.
      fakeA.releaseAll();
      await Future.wait([fakeA.allCallsFinished, fakeB.allCallsFinished]);
      await _pumpUntil(() => !controller.cloudSyncing);

      // B's data is never sent to A.
      expect(
        fakeA.writes.every((w) => w.progress.dailyGoalQuestions != 15),
        isTrue,
      );
      // B's session owns the current state; A's late sync did not overwrite it.
      expect(controller.dailyGoalQuestions, 15);
      expect(controller.cloudConnected, isTrue);
      expect(controller.cloudSyncing, isFalse);
      expect(controller.lastCloudSyncError, isNull);
    });

    test(
        'local answer earned during a held sync survives in memory and storage',
        () async {
      final store = await _mockStore();
      final fake = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: fake));
      await _pumpUntil(() => fake.writes.length == 1);

      fake.block();
      // syncCloudNow blocks on fake.synchronize (held), not on _cloudQueue.
      unawaited(controller.syncCloudNow());
      await _pumpUntil(() => fake.calls.length == 2);
      expect(fake.isBlocked, isTrue);

      // Earn progress locally while the sync is held.
      await controller.registerQuestionAnswered();
      expect(controller.progress.questionsAnsweredToday, 1);

      fake.releaseAll();
      // Initial sync + held manual sync + the background sync chained by the
      // local edit.
      await _pumpUntil(() => fake.writes.length == 3);
      await _pumpUntil(() => !controller.cloudSyncing);

      // The locally earned answer survives in memory and in local storage.
      expect(controller.progress.questionsAnsweredToday, 1);
      expect(store.loadProgress().questionsAnsweredToday, 1);
    });

    test(
        'old account result completing while new account sync is in flight is discarded',
        () async {
      final store = await _mockStore();
      final fakeA = _GateFakeStore();
      final fakeB = _GateFakeStore();
      final controller = ProgressController(store, UserProgress());
      await controller.connectCloudBackup(
          userId: 'learner-a', backup: ProgressCloudBackup(store: fakeA));
      await _pumpUntil(() => fakeA.writes.length == 1);

      // Hold A's background sync, then switch to B.
      fakeA.block();
      await controller.setDailyGoal(8);
      await _pumpUntil(() => fakeA.calls.length == 2);

      controller.disconnectCloudBackup();
      fakeB.block();
      // connectCloudBackup(B) suspends on _cloudQueue (held by A); the B
      // account switch is already in effect synchronously.
      unawaited(controller.connectCloudBackup(
          userId: 'learner-b', backup: ProgressCloudBackup(store: fakeB)));

      // Release A: A's late result is discarded while B's sync proceeds and
      // is then held by fakeB.
      fakeA.releaseAll();
      await _pumpUntil(() => fakeB.calls.length == 1);
      await fakeA.allCallsFinished;

      // A's late result/error must not touch B's in-flight sync or state.
      expect(controller.lastCloudSyncError, isNull);
      expect(controller.cloudConnected, isTrue);
      expect(controller.cloudSyncing, isTrue);
      expect(controller.dailyGoalQuestions, 8);

      // Release B: its sync completes cleanly.
      fakeB.releaseAll();
      await _pumpUntil(() => fakeB.writes.length == 1);
      await _pumpUntil(() => !controller.cloudSyncing);
      expect(controller.lastCloudSyncError, isNull);
      expect(controller.cloudSyncing, isFalse);
      expect(controller.dailyGoalQuestions, 8);
      expect(fakeB.writes.last.progress.dailyGoalQuestions, 8);
    });
  });
}
