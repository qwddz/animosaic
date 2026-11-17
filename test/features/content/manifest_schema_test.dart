import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/catalog/domain/content_manifest.dart';
import 'package:puzzles/features/content/content_config.dart';

ContentManifest parse(List<Map<String, Object?>> puzzles, {int version = 2}) =>
    ContentManifest.fromJson({
      'version': version,
      'categories': [
        {
          'id': 'sea',
          'title': {'en': 'Sea'},
          'puzzles': puzzles,
        },
      ],
    });

void main() {
  final hash = 'ab' * 32;

  test('reads downloadable pictures and previews', () {
    final manifest = ContentManifest.fromJson({
      'version': 7,
      'minAppVersion': '1.3.0',
      'categories': [
        {
          'id': 'sea',
          'title': {'en': 'Sea'},
          'puzzles': [
            {
              'id': 'sea_turtle',
              'title': {'en': 'Turtle'},
              'free': true,
              'asset': 'images/free/sea_turtle.webp',
              'thumb': 'thumbs/sea_turtle.webp',
            },
            {
              'id': 'sea_seal',
              'title': {'en': 'Seal'},
              'url': 'pictures/sea_seal-abababab.webp',
              'sha256': hash,
              'bytes': 312345,
              'thumbUrl': 'thumbs/sea_seal.webp',
            },
          ],
        },
      ],
    });
    expect(manifest.version, 7);
    expect(manifest.minAppVersion, '1.3.0');
    final turtle = manifest.puzzleById('sea_turtle')!;
    expect(turtle.assetPath, 'assets/images/free/sea_turtle.webp');
    expect(turtle.thumbAssetPath, 'assets/thumbs/sea_turtle.webp');
    expect(turtle.url, isNull);
    final seal = manifest.puzzleById('sea_seal')!;
    expect(seal.free, isFalse);
    expect(seal.assetPath, isNull);
    expect(seal.url, 'pictures/sea_seal-abababab.webp');
    expect(seal.sha256, hash);
    expect(seal.bytes, 312345);
    expect(seal.thumbAssetPath, isNull);
    expect(seal.thumbUrl, 'thumbs/sea_seal.webp');
  });

  test('minAppVersion defaults to 1.0.0', () {
    expect(parse(const []).minAppVersion, '1.0.0');
  });

  test('a url without sha256 is rejected', () {
    expect(
      () => parse([
        {
          'id': 'x',
          'title': {'en': 'X'},
          'url': 'pictures/x.webp',
        },
      ]),
      throwsFormatException,
    );
    expect(
      () => parse([
        {
          'id': 'x',
          'title': {'en': 'X'},
        },
      ]),
      throwsFormatException,
    );
  });

  test('ids that are not safe file names are rejected', () {
    for (final id in ['../x', 'Sea', 'a b', '', 'a/b']) {
      expect(
        () => parse([
          {
            'id': id,
            'title': {'en': 'X'},
            'asset': 'images/free/x.webp',
          },
        ]),
        throwsFormatException,
        reason: id,
      );
      expect(
        () => ContentManifest.fromJson({
          'version': 1,
          'categories': [
            {
              'id': id,
              'title': {'en': 'X'},
              'puzzles': const [],
            },
          ],
        }),
        throwsFormatException,
        reason: id,
      );
    }
  });

  test('malformed CDN addresses resolve to null', () {
    expect(resolveCdnUrl('https://cdn.test', 'http://[::1'), isNull);
    expect(resolveCdnUrl('http://[::1', 'pictures/a.webp'), isNull);
  });

  test('relative CDN paths resolve against the base URL', () {
    expect(
      resolveCdnUrl('https://cdn.test/content', 'pictures/a.webp').toString(),
      'https://cdn.test/content/pictures/a.webp',
    );
    expect(
      resolveCdnUrl('https://cdn.test/content/', '/manifest.json').toString(),
      'https://cdn.test/content/manifest.json',
    );
    expect(
      resolveCdnUrl('', 'https://other.test/a.webp').toString(),
      'https://other.test/a.webp',
    );
    expect(resolveCdnUrl('', 'pictures/a.webp'), isNull);
  });
}
