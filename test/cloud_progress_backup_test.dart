import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/remote/progress_cloud_backup.dart';
import 'package:grammar_bondhu/features/settings/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryBackupStore implements ProgressBackupStore {
  UserProgress? snapshot;
  int writes = 0;

  @override
  Future<UserProgress> mergeAndWrite(String userId, UserProgress local) async {
    final current = snapshot;
    final merged = current == null
        ? UserProgress.fromJson(local.toJson())
        : UserProgress.mergeForCloud(local, current);
    snapshot = UserProgress.fromJson(merged.toJson());
    writes += 1;
    return merged;
  }
}

class _PendingSync {
  _PendingSync(this.userId, this.snapshot);

  final String userId;
  final UserProgress snapshot;
  final result = Completer<UserProgress>();
}

class _ControlledBackupStore implements ProgressBackupStore {
  final calls = <_PendingSync>[];

  @override
  Future<UserProgress> mergeAndWrite(String userId, UserProgress local) {
    final call = _PendingSync(userId, local);
    calls.add(call);
    return call.result.future;
  }
}

// Run queued microtasks without having to complete an in-flight network call.
Future<void> _flushCloudJobs() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressCloudBackup', () {
    test('first sign-in uploads the local progress snapshot', () async {
      final store = _MemoryBackupStore();
      final backup = ProgressCloudBackup(store: store);
      final local = UserProgress(totalXp: 120)
        ..chapter('ch01').missedQuestionIds.add('q01');

      final result = await backup.synchronize('learner-1', local);

      expect(result.totalXp, 120);
      expect(store.snapshot?.totalXp, 120);
      expect(store.snapshot?.chapter('ch01').missedQuestionIds, {'q01'});
      expect(store.writes, 1);
    });

    test('existing cloud and local snapshots merge without double-counting',
        () async {
      final store = _MemoryBackupStore()
        ..snapshot = UserProgress(
          totalXp: 200,
          coins: 10,
          chapters: {
            'ch01': ChapterProgress(
              chapterId: 'ch01',
              completed: true,
              stars: 3,
              bestScorePercent: 100,
              attempts: 4,
              coinsEarned: 10,
              missedQuestionIds: {'q02'},
              lastOpenedAt: DateTime(2026, 1, 2),
              resumeSceneIndex: 3,
            ),
          },
        );
      final backup = ProgressCloudBackup(store: store);
      final local = UserProgress(
        totalXp: 150,
        coins: 15,
        chapters: {
          'ch01': ChapterProgress(
            chapterId: 'ch01',
            stars: 1,
            bestScorePercent: 80,
            attempts: 2,
            missedQuestionIds: {'q01'},
            lastOpenedAt: DateTime(2026, 1, 1),
            resumeSceneIndex: 1,
          ),
          'ch02': ChapterProgress(
            chapterId: 'ch02',
            completed: true,
            coinsEarned: 15,
          ),
        },
      );

      final result = await backup.synchronize('learner-1', local);

      expect(result.totalXp, 200);
      expect(result.coins, 25);
      expect(result.chapters['ch01']!.completed, isTrue);
      expect(result.chapters['ch01']!.stars, 3);
      expect(result.chapters['ch01']!.attempts, 4);
      expect(result.chapters['ch01']!.resumeSceneIndex, 3);
      expect(result.chapters['ch01']!.missedQuestionIds, {'q01', 'q02'});
      expect(result.chapters['ch02']!.completed, isTrue);
      expect(store.writes, 1);
    });
  });

  group('ProgressController cloud sessions', () {
    late LocalStore store;
    late ProgressController controller;
    late _ControlledBackupStore remote;
    late ProgressCloudBackup backup;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await LocalStore.open();
      controller = ProgressController(store, store.loadProgress());
      remote = _ControlledBackupStore();
      backup = ProgressCloudBackup(store: remote);
      addTearDown(controller.dispose);
    });

    test('explicit and background sync preserve edits made in flight',
        () async {
      final connect = controller.connectCloudBackup(
        userId: 'learner',
        backup: backup,
      );
      await _flushCloudJobs();
      final first = remote.calls.single;
      await controller.openChapter('ch01', 1, now: DateTime(2026, 11, 17));
      expect(remote.calls, hasLength(1)); // No overlapping background sync.
      expect(first.snapshot.chapters, isEmpty);

      first.result.complete(UserProgress(totalXp: 90));
      await connect;
      expect(controller.progress.totalXp, 90);
      expect(store.loadProgress().chapter('ch01').resumeSceneIndex, 1);

      await _flushCloudJobs();
      final background = remote.calls[1];
      await controller.openChapter('ch01', 2, now: DateTime(2026, 11, 18));
      expect(remote.calls, hasLength(2));
      expect(background.snapshot.chapter('ch01').resumeSceneIndex, 1);
      background.result.complete(background.snapshot);
      await _flushCloudJobs();
      expect(controller.chapterProgress('ch01').resumeSceneIndex, 2);
      expect(store.loadProgress().chapter('ch01').resumeSceneIndex, 2);

      final followUp = remote.calls[2];
      expect(followUp.snapshot.chapter('ch01').resumeSceneIndex, 2);
      followUp.result.complete(followUp.snapshot);
      await _flushCloudJobs();
      expect(controller.cloudSyncing, isFalse);
    });

    test('disconnect drops queued sync and ignores a late restore after reset',
        () async {
      final connect = controller.connectCloudBackup(
        userId: 'learner',
        backup: backup,
      );
      await _flushCloudJobs();
      final inFlight = remote.calls.single;
      expect(controller.cloudSyncing, isTrue);
      final queued = controller.syncCloudNow();
      await controller.setDailyGoal(15); // Queue a background sync, too.

      controller.disconnectCloudBackup();
      expect(controller.cloudSyncing, isFalse);
      await controller.resetAll();
      final resetSnapshot = store.loadProgress().toJson();
      var notifications = 0;
      controller.addListener(() => notifications++);

      inFlight.result.complete(UserProgress(totalXp: 250));
      await connect;
      await queued;
      await _flushCloudJobs();

      expect(remote.calls, hasLength(1));
      expect(controller.progress.toJson(), resetSnapshot);
      expect(store.loadProgress().toJson(), resetSnapshot);
      expect(controller.dailyGoalQuestions, 15);
      expect(controller.cloudConnected, isFalse);
      expect(controller.cloudSyncing, isFalse);
      expect(controller.lastCloudSyncError, isNull);
      expect(notifications, 0);
    });

    test('switching accounts isolates old work and keeps the new sync state',
        () async {
      final firstConnect = controller.connectCloudBackup(
        userId: 'learner-a',
        backup: backup,
      );
      await _flushCloudJobs();
      remote.calls.single.result.complete(UserProgress());
      await firstConnect;

      await controller.setDailyGoal(10);
      await _flushCloudJobs();
      final oldBackground = remote.calls[1];
      final oldQueued = controller.syncCloudNow();
      final newConnect = controller.connectCloudBackup(
        userId: 'learner-b',
        backup: backup,
      );
      await _flushCloudJobs();
      expect(remote.calls.map((call) => call.userId), [
        'learner-a',
        'learner-a',
        'learner-b',
      ]);
      final current = remote.calls.last;
      expect(controller.cloudSyncing, isTrue);

      var notifications = 0;
      controller.addListener(() => notifications++);
      oldBackground.result.completeError(StateError('Old account unavailable'));
      await oldQueued;
      await _flushCloudJobs();
      expect(remote.calls, hasLength(3));
      expect(controller.cloudSyncing, isTrue);
      expect(controller.lastCloudSyncError, isNull);
      expect(notifications, 0);

      final failure = StateError('New account unavailable');
      final failed = expectLater(newConnect, throwsA(same(failure)));
      current.result.completeError(failure);
      await failed;
      expect(controller.cloudSyncing, isFalse);
      expect(controller.lastCloudSyncError, same(failure));

      final retry = controller.syncCloudNow();
      await _flushCloudJobs();
      expect(remote.calls.last.userId, 'learner-b');
      remote.calls.last.result.complete(UserProgress(totalXp: 70));
      await retry;
      expect(controller.lastCloudSyncError, isNull);
      expect(store.loadProgress().totalXp, 70);
      expect(store.loadProgress().dailyGoalQuestions, 10);
    });
  });

  testWidgets('Reset Progress is device-only and requires disconnecting Google',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final initial = UserProgress(totalXp: 60, dailyGoalQuestions: 15)
      ..chapter('ch01').completed = true;
    await store.saveProgress(initial);
    final progress = ProgressController(store, store.loadProgress());
    final settings = SettingsController(store, store.loadSettings());
    final remote = _MemoryBackupStore();
    await settings.signInWithGoogle(displayName: 'Learner', userId: 'learner');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: progress),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final resetTile = find.text('Reset Progress');
    await tester.scrollUntilVisible(resetTile, 200);

    Future<void> expectResetBlocked() async {
      await tester.tap(resetTile);
      await tester.pumpAndSettle();
      expect(find.text('Disconnect Google first'), findsOneWidget);
      expect(find.textContaining('Google in Profile first'), findsOneWidget);
      expect(find.text('Reset'), findsNothing);
      expect(find.text('Progress reset.'), findsNothing);
      expect(progress.progress.toJson(), initial.toJson());
      expect(store.loadProgress().toJson(), initial.toJson());
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    }

    // Settings can remain connected when the backup service is not attached.
    await expectResetBlocked();
    expect(remote.writes, 0);

    // Also guard against a connected backup while settings say guest.
    await settings.signOutToGuest();
    await progress.connectCloudBackup(
      userId: 'learner',
      backup: ProgressCloudBackup(store: remote),
    );
    await progress.resetAll(); // A direct call cannot bypass the UI guard.
    await tester.pumpAndSettle();
    await expectResetBlocked();
    expect(remote.writes, 1);

    progress.disconnectCloudBackup();
    await tester.tap(resetTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Progress reset.'), findsOneWidget);
    expect(progress.progress.chapters, isEmpty);
    expect(progress.progress.totalXp, 0);
    expect(progress.dailyGoalQuestions, 15);
    expect(store.loadProgress().toJson(), progress.progress.toJson());
    expect(remote.writes, 1);
    expect(remote.snapshot?.toJson(), initial.toJson());
  });
}
