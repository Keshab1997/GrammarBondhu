import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Loads and decodes bundled JSON content files.
class JsonLoader {
  JsonLoader([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<Map<String, dynamic>> loadJsonMap(String assetPath) async {
    final String raw;
    try {
      raw = await _bundle.loadString(assetPath);
    } catch (e) {
      throw ContentLoadException('Could not read asset "$assetPath": $e');
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw ContentLoadException('Asset "$assetPath" is not a JSON object');
      }
      return decoded;
    } on FormatException catch (e) {
      throw ContentLoadException('Asset "$assetPath" is not valid JSON: ${e.message}');
    }
  }
}

/// Thrown when a bundled content file is missing or malformed.
class ContentLoadException implements Exception {
  ContentLoadException(this.message);

  final String message;

  @override
  String toString() => 'ContentLoadException: $message';
}
