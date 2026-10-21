import '../local/json_loader.dart';
import '../models/chapter.dart';
import '../models/manifest.dart';

/// Loads all bundled chapters from `assets/data/` and serves them in
/// manifest order. Adding a chapter = one JSON file + one manifest entry.
class ContentRepository {
  ContentRepository([JsonLoader? loader]) : _loader = loader ?? JsonLoader();

  static const String manifestAsset = 'assets/data/manifest.json';
  static const String _dataRoot = 'assets/data/';

  final JsonLoader _loader;

  ContentManifest? _manifest;
  List<Chapter> _chapters = const [];

  bool get isLoaded => _manifest != null;

  ContentManifest get manifest {
    final manifest = _manifest;
    if (manifest == null) {
      throw StateError('ContentRepository.load() has not completed');
    }
    return manifest;
  }

  /// Chapters in learning order.
  List<Chapter> get chapters => _chapters;

  /// Loads and validates every registered chapter. Throws
  /// [ContentLoadException] when a file is missing or malformed.
  Future<void> load() async {
    final manifestJson = await _loader.loadJsonMap(manifestAsset);
    final manifest = ContentManifest.fromJson(manifestJson);

    final chapters = <Chapter>[];
    for (final entry in manifest.entries) {
      final json = await _loader.loadJsonMap('$_dataRoot${entry.file}');
      final chapter = Chapter.fromJson(json);
      if (chapter.id != entry.chapterId) {
        throw ContentLoadException(
          'Chapter file "${entry.file}" declares id "${chapter.id}", '
          'but the manifest registers "${entry.chapterId}"',
        );
      }
      chapters.add(chapter);
    }
    _manifest = manifest;
    _chapters = List.unmodifiable(chapters);
  }

  Chapter? byId(String chapterId) {
    for (final chapter in _chapters) {
      if (chapter.id == chapterId) return chapter;
    }
    return null;
  }

  /// The chapter after [chapterId] in learning order; null at the end.
  Chapter? nextAfter(String chapterId) {
    for (var i = 0; i < _chapters.length; i++) {
      if (_chapters[i].id == chapterId) {
        return i + 1 < _chapters.length ? _chapters[i + 1] : null;
      }
    }
    return null;
  }

  /// The first not-yet-completed chapter, or the last one when all are done.
  Chapter recommendedNext(bool Function(String chapterId) isCompleted) {
    for (final chapter in _chapters) {
      if (!isCompleted(chapter.id)) return chapter;
    }
    return _chapters.last;
  }
}
