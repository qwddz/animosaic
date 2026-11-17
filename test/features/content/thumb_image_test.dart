import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/catalog/domain/content_manifest.dart';
import 'package:puzzles/features/content/content_config.dart';
import 'package:puzzles/features/content/thumb_image.dart';

void main() {
  const entry = PuzzleEntry(
    id: 'sea_seal',
    categoryId: 'sea',
    title: LocalizedText({'en': 'Seal'}),
    free: true,
    asset: 'images/free/sea_seal.webp',
    thumb: 'thumbs/sea_seal.webp',
    thumbUrl: 'thumbs/sea_seal.webp',
  );
  const base = 'https://cdn.test';

  test('the bundled thumb is used when this build ships it', () {
    expect(
      thumbImage(entry, base, {'assets/thumbs/sea_seal.webp'}),
      isA<AssetImage>(),
    );
  });

  test('a thumb missing from this build falls back to the CDN', () {
    final image = thumbImage(entry, base, {});
    expect(
      (image! as NetworkImage).url,
      'https://cdn.test/thumbs/sea_seal.webp',
    );
    expect(thumbImage(entry, '', {}), isNull);
    expect(thumbImage(entry, base, null), isNull);
  });

  test('release builds need a CDN address', () {
    expect(
      () => checkCdnConfigured(release: true, baseUrl: ''),
      throwsStateError,
    );
    checkCdnConfigured(release: false, baseUrl: '');
    checkCdnConfigured(release: true, baseUrl: base);
  });
}
