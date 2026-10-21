/// The content manifest lists every bundled chapter file.
///
/// New chapter = one JSON file under `assets/data/chapters/` + one entry here.
class ContentManifest {
  const ContentManifest({required this.version, required this.entries, this.defaultSupportLanguage = 'bn'});

  final int version;
  final List<ManifestEntry> entries;

  /// Supporting language used before the learner picks one ('bn' or 'hi').
  final String defaultSupportLanguage;

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    final chapters = json['chapters'];
    if (chapters is! List || chapters.isEmpty) {
      throw FormatException('manifest: "chapters" must be a non-empty list');
    }
    final entries = chapters
        .map((e) => ManifestEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return ContentManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      entries: entries,
      defaultSupportLanguage: (json['default_support_language'] as String?) ?? 'bn',
    );
  }
}

class ManifestEntry {
  const ManifestEntry({required this.chapterId, required this.file, required this.order});

  final String chapterId;

  /// Path relative to `assets/data/`, e.g. `chapters/chapter_01.json`.
  final String file;
  final int order;

  factory ManifestEntry.fromJson(Map<String, dynamic> json) {
    final id = json['chapter_id'];
    final file = json['file'];
    if (id is! String || id.isEmpty) {
      throw FormatException('manifest entry: missing "chapter_id"');
    }
    if (file is! String || file.isEmpty) {
      throw FormatException('manifest entry $id: missing "file"');
    }
    return ManifestEntry(
      chapterId: id,
      file: file,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}
