/// Text in several languages, keyed by language code.
class LocalizedText {
  const LocalizedText(this._values);

  final Map<String, String> _values;

  /// Falls back to English, then to any available language.
  String resolve(String languageCode) =>
      _values[languageCode] ?? _values['en'] ?? _values.values.first;

  static LocalizedText fromJson(Object? json) {
    final map = (json as Map<String, Object?>).cast<String, String>();
    if (map.isEmpty) throw const FormatException('empty title');
    return LocalizedText(Map.unmodifiable(map));
  }
}

class PuzzleEntry {
  const PuzzleEntry({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.free,
    this.asset,
    this.url,
    this.sha256,
    this.bytes,
    this.thumb,
    this.thumbUrl,
  });

  final String id;
  final String categoryId;
  final LocalizedText title;
  final bool free;

  /// Path inside `assets/` for pictures bundled with the app.
  final String? asset;

  /// CDN address of a downloadable picture, relative to the CDN base URL
  /// or absolute. Comes with [sha256] and optionally [bytes].
  final String? url;
  final String? sha256;
  final int? bytes;

  /// Small preview inside `assets/`, or on the CDN when only [thumbUrl] is set.
  final String? thumb;
  final String? thumbUrl;

  String? get assetPath => asset == null ? null : 'assets/$asset';

  String? get thumbAssetPath => thumb == null ? null : 'assets/$thumb';
}

class CategoryEntry {
  const CategoryEntry({
    required this.id,
    required this.title,
    required this.puzzles,
  });

  final String id;
  final LocalizedText title;
  final List<PuzzleEntry> puzzles;
}

/// Content catalog described in `docs/PLAN.md`: categories with puzzles.
class ContentManifest {
  const ContentManifest({
    required this.version,
    required this.categories,
    this.minAppVersion = '1.0.0',
  });

  final int version;

  /// Oldest app version that understands this manifest.
  final String minAppVersion;
  final List<CategoryEntry> categories;

  /// All puzzles in catalog order.
  List<PuzzleEntry> get puzzles => [
    for (final category in categories) ...category.puzzles,
  ];

  PuzzleEntry? puzzleById(String id) {
    for (final puzzle in puzzles) {
      if (puzzle.id == id) return puzzle;
    }
    return null;
  }

  CategoryEntry? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// Puzzle after [id] in its category that passes [where], wrapping
  /// around to the first one. Null when no other puzzle passes.
  PuzzleEntry? nextPuzzle(String id, {bool Function(PuzzleEntry)? where}) {
    final puzzle = puzzleById(id);
    if (puzzle == null) return null;
    final siblings = categoryById(puzzle.categoryId)!.puzzles;
    final index = siblings.indexWhere((p) => p.id == id);
    for (var step = 1; step < siblings.length; step++) {
      final candidate = siblings[(index + step) % siblings.length];
      if (where == null || where(candidate)) return candidate;
    }
    return null;
  }

  static ContentManifest fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    final categories = <CategoryEntry>[];
    for (final rawCategory in map['categories'] as List) {
      final category = rawCategory as Map<String, Object?>;
      final categoryId = _id(category['id']);
      categories.add(
        CategoryEntry(
          id: categoryId,
          title: LocalizedText.fromJson(category['title']),
          puzzles: [
            for (final rawPuzzle in category['puzzles'] as List)
              _puzzleFromJson(rawPuzzle as Map<String, Object?>, categoryId),
          ],
        ),
      );
    }
    return ContentManifest(
      version: map['version'] as int,
      minAppVersion: map['minAppVersion'] as String? ?? '1.0.0',
      categories: List.unmodifiable(categories),
    );
  }

  static final _idPattern = RegExp(r'^[a-z0-9_]+$');

  /// Ids become file names, so only lowercase letters, digits and `_`.
  static String _id(Object? json) {
    final id = json as String;
    if (!_idPattern.hasMatch(id)) throw FormatException('bad id', id);
    return id;
  }

  static PuzzleEntry _puzzleFromJson(
    Map<String, Object?> json,
    String categoryId,
  ) {
    final asset = json['asset'] as String?;
    final url = json['url'] as String?;
    final sha256 = json['sha256'] as String?;
    if (asset == null && (url == null || sha256 == null)) {
      throw FormatException(
        'puzzle ${json['id']} has no asset or url + sha256',
      );
    }
    return PuzzleEntry(
      id: _id(json['id']),
      categoryId: categoryId,
      title: LocalizedText.fromJson(json['title']),
      free: json['free'] as bool? ?? false,
      asset: asset,
      url: url,
      sha256: sha256,
      bytes: json['bytes'] as int?,
      thumb: json['thumb'] as String?,
      thumbUrl: json['thumbUrl'] as String?,
    );
  }
}
