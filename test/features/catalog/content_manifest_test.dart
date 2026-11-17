import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/catalog/domain/content_manifest.dart';

void main() {
  final manifest = ContentManifest.fromJson(
    jsonDecode(File('assets/manifest.json').readAsStringSync()),
  );

  test('bundled manifest has unique ids and existing pictures', () {
    final ids = manifest.puzzles.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final puzzle in manifest.puzzles) {
      if (puzzle.free) {
        expect(File(puzzle.assetPath!).existsSync(), isTrue, reason: puzzle.id);
      } else {
        expect(puzzle.url, isNotNull, reason: puzzle.id);
        expect(puzzle.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      }
      final thumb = puzzle.thumbAssetPath;
      if (thumb != null) {
        expect(File(thumb).existsSync(), isTrue, reason: thumb);
      }
    }
  });

  test('every title is translated to uk, en and ru', () {
    for (final category in manifest.categories) {
      for (final text in [
        category.title,
        ...category.puzzles.map((p) => p.title),
      ]) {
        final values = {
          for (final code in ['uk', 'en', 'ru']) text.resolve(code),
        };
        expect(values, isNotEmpty);
      }
    }
    final turtle = manifest.puzzleById('sea_turtle')!.title;
    expect(turtle.resolve('uk'), 'Морська черепаха');
    expect(turtle.resolve('de'), 'Sea turtle');
  });

  test('next puzzle stays in the category and wraps around', () {
    final twoPerCategory = ContentManifest.fromJson({
      'version': 1,
      'categories': [
        for (final category in ['sea', 'farm'])
          {
            'id': category,
            'title': {'en': category},
            'puzzles': [
              for (final n in [1, 2])
                {
                  'id': '${category}_$n',
                  'title': {'en': '$n'},
                  'asset': 'images/free/x.png',
                },
            ],
          },
      ],
    });
    expect(twoPerCategory.nextPuzzle('sea_1')!.id, 'sea_2');
    expect(twoPerCategory.nextPuzzle('sea_2')!.id, 'sea_1');
    expect(twoPerCategory.nextPuzzle('missing'), isNull);
    // Filtered: skips pictures that fail, null when none other passes.
    expect(
      twoPerCategory.nextPuzzle('sea_1', where: (p) => p.id != 'sea_2'),
      isNull,
    );
    // A category with one picture has no next one.
    final onePicture = ContentManifest.fromJson({
      'version': 1,
      'categories': [
        {
          'id': 'sea',
          'title': {'en': 'sea'},
          'puzzles': [
            {
              'id': 'sea_1',
              'title': {'en': '1'},
              'asset': 'images/free/x.png',
            },
          ],
        },
      ],
    });
    expect(onePicture.nextPuzzle('sea_1'), isNull);
  });

  test('a puzzle without asset or url is rejected', () {
    expect(
      () => ContentManifest.fromJson({
        'version': 1,
        'categories': [
          {
            'id': 'sea',
            'title': {'en': 'Sea'},
            'puzzles': [
              {
                'id': 'x',
                'title': {'en': 'X'},
              },
            ],
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
