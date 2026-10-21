import 'package:flutter/foundation.dart';

import '../../data/models/chapter.dart';
import '../../data/repositories/content_repository.dart';

/// Loads and serves bundled chapter content (JSON-driven).
class ContentController extends ChangeNotifier {
  ContentController(this._repository);

  final ContentRepository _repository;

  bool isLoading = false;
  String? error;

  bool get isLoaded => _repository.isLoaded;

  bool get hasError => error != null;

  List<Chapter> get chapters => _repository.chapters;

  Chapter? byId(String chapterId) => _repository.byId(chapterId);

  Chapter? nextAfter(String chapterId) => _repository.nextAfter(chapterId);

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _repository.load();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }
}
