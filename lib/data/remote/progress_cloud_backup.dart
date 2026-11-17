import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/progress.dart';

/// Storage boundary keeps merge behaviour testable without Firebase.
abstract interface class ProgressBackupStore {
  Future<UserProgress> mergeAndWrite(String userId, UserProgress local);
}

/// Uploads the local snapshot on first sign-in, or safely merges it with an
/// existing account snapshot before saving the result to both places.
class ProgressCloudBackup {
  ProgressCloudBackup({ProgressBackupStore? store})
      : _store = store ?? FirestoreProgressBackupStore();

  final ProgressBackupStore _store;

  Future<UserProgress> synchronize(String userId, UserProgress local) =>
      _store.mergeAndWrite(userId, local);
}

/// One private document per Firebase account. Security rules must restrict
/// each path to its matching authenticated UID (see `firestore.rules`).
class FirestoreProgressBackupStore implements ProgressBackupStore {
  FirestoreProgressBackupStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('backups')
      .doc('progress');

  @override
  Future<UserProgress> mergeAndWrite(String userId, UserProgress local) {
    final document = _document(userId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final data = snapshot.data();
      UserProgress? remote;
      if (snapshot.exists) {
        if (data?['schema_version'] != 1) {
          throw const FormatException('Unsupported cloud progress version.');
        }
        final rawProgress = data?['progress'];
        if (rawProgress is! Map) {
          throw const FormatException('Cloud progress snapshot is invalid.');
        }
        remote = UserProgress.fromJson(rawProgress.cast<String, dynamic>());
      }
      final merged = remote == null
          ? UserProgress.fromJson(local.toJson())
          : UserProgress.mergeForCloud(local, remote);
      transaction.set(document, {
        'schema_version': 1,
        'progress': merged.toJson(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return merged;
    });
  }
}
