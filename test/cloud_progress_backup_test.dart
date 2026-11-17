import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/remote/progress_cloud_backup.dart';

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

void main() {
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
}
