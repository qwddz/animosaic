import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/catalog/domain/content_manifest.dart';
import 'package:puzzles/features/content/data/picture_store.dart';

import 'fake_cdn.dart';

/// Serves every asset key as the same [bytes].
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.bytes);

  final List<int> bytes;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(bytes));
}

Matcher failsWith(PictureLoadFailure failure) => throwsA(
  isA<PictureLoadException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  const path = '/pictures/sea_seal-1a2b3c4d.webp';
  final picture = List<int>.generate(50000, (i) => i * 7 % 256);
  final entry = PuzzleEntry(
    id: 'sea_seal',
    categoryId: 'sea',
    title: const LocalizedText({'en': 'Seal'}),
    free: false,
    url: 'pictures/sea_seal-1a2b3c4d.webp',
    sha256: sha256.convert(picture).toString(),
    bytes: picture.length,
  );
  late Directory dir;
  late FakeCdn cdn;
  late PictureStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('picture_store');
    cdn = FakeCdn()..files[path] = picture;
    store = PictureStore(
      dio: cdn.dio,
      directory: () async => dir,
      cdnBaseUrl: 'https://cdn.test/',
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File cached() => File('${dir.path}/pictures/sea_seal.webp');
  List<String> pictureFiles() => [
    for (final file in Directory('${dir.path}/pictures').listSync())
      file.uri.pathSegments.last,
  ];

  test('downloads once, then opens from the cache offline', () async {
    final progress = <double>[];
    expect(await store.load(entry, onProgress: progress.add), picture);
    expect(cdn.requests, [path]);
    expect(progress.last, 1.0);
    expect(cached().readAsBytesSync(), picture);

    cdn.offline = true;
    final again = <double>[];
    expect(await store.load(entry, onProgress: again.add), picture);
    expect(cdn.requests, hasLength(1));
    expect(again, isEmpty);
  });

  test('a corrupted cached file is downloaded again', () async {
    await store.load(entry);
    cached().writeAsBytesSync([1, 2, 3]);
    expect(await store.load(entry), picture);
    expect(cdn.requests, hasLength(2));
    expect(cached().readAsBytesSync(), picture);
  });

  test('a download with the wrong checksum is rejected and not kept', () async {
    cdn.files[path] = [...picture.take(picture.length - 1), 0];
    await expectLater(
      store.load(entry),
      throwsA(
        isA<PictureLoadException>().having(
          (e) => e.failure,
          'failure',
          PictureLoadFailure.corrupt,
        ),
      ),
    );
    expect(pictureFiles(), isEmpty);
  });

  test('offline without a cached copy fails with a network error', () async {
    cdn.offline = true;
    await expectLater(
      store.load(entry),
      throwsA(
        isA<PictureLoadException>().having(
          (e) => e.failure,
          'failure',
          PictureLoadFailure.network,
        ),
      ),
    );
    expect(pictureFiles(), isEmpty);
  });

  test('two opens at once share one download', () async {
    final first = <double>[], second = <double>[];
    final results = await Future.wait([
      store.load(entry, onProgress: first.add),
      store.load(entry, onProgress: second.add),
    ]);
    expect(results, [picture, picture]);
    expect(cdn.requests, hasLength(1));
    expect(first.last, 1.0);
    expect(second.last, 1.0);
    expect(pictureFiles(), ['sea_seal.webp']);
  });

  test('without a CDN address a downloadable picture is unavailable', () {
    final offlineStore = PictureStore(
      dio: cdn.dio,
      directory: () async => dir,
      cdnBaseUrl: '',
    );
    expect(offlineStore.load(entry), failsWith(PictureLoadFailure.unavailable));
  });

  test('a CDN error answer is unavailable, not a network error', () async {
    cdn.files.remove(path);
    await expectLater(
      store.load(entry),
      failsWith(PictureLoadFailure.unavailable),
    );
    expect(pictureFiles(), isEmpty);
  });

  test('leftover partial downloads are removed on first use', () async {
    Directory('${dir.path}/pictures').createSync();
    File('${dir.path}/pictures/sea_fish.webp.part').writeAsBytesSync([1]);
    File('${dir.path}/pictures/sea_fish.webp').writeAsBytesSync([2]);
    await store.load(entry);
    expect(pictureFiles()..sort(), ['sea_fish.webp', 'sea_seal.webp']);
  });

  group('a picture with both bundled and CDN sources', () {
    final bundled = List<int>.filled(10, 9);
    final both = PuzzleEntry(
      id: entry.id,
      categoryId: entry.categoryId,
      title: entry.title,
      free: true,
      asset: 'images/free/sea_seal.webp',
      url: entry.url,
      sha256: entry.sha256,
      bytes: entry.bytes,
    );
    PictureStore storeWith(Set<String> assets) => PictureStore(
      dio: cdn.dio,
      directory: () async => dir,
      cdnBaseUrl: 'https://cdn.test/',
      bundle: _FakeBundle(bundled),
      bundledAssets: () async => assets,
    );

    test('opens the bundled copy when this build ships it', () async {
      final store = storeWith({'assets/images/free/sea_seal.webp'});
      expect(await store.load(both), bundled);
      expect(cdn.requests, isEmpty);
    });

    test(
      'downloads from the CDN when the asset is not in this build',
      () async {
        expect(await storeWith({}).load(both), picture);
        expect(cdn.requests, [path]);
      },
    );

    test('is unavailable without either source', () {
      final bundledOnly = PuzzleEntry(
        id: both.id,
        categoryId: both.categoryId,
        title: both.title,
        free: true,
        asset: both.asset,
      );
      expect(
        storeWith({}).load(bundledOnly),
        failsWith(PictureLoadFailure.unavailable),
      );
    });
  });
}
