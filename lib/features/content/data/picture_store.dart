import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/content_manifest.dart';
import '../content_config.dart';

enum PictureLoadFailure {
  /// The CDN could not be reached and there is no cached copy.
  network,

  /// The CDN answered with an error (404, 403, 5xx), or this build has
  /// neither the bundled picture nor a CDN address for it.
  unavailable,

  /// The downloaded file does not match its checksum.
  corrupt,
}

class PictureLoadException implements Exception {
  const PictureLoadException(this.failure, [this.cause]);

  final PictureLoadFailure failure;
  final Object? cause;

  @override
  String toString() => 'PictureLoadException($failure, $cause)';
}

/// Picture bytes for a puzzle: bundled assets as they are, CDN pictures from
/// a disk cache that is checked against the manifest checksum on every open.
class PictureStore {
  PictureStore({
    required this._dio,
    required this._directory,
    required this._cdnBaseUrl,
    AssetBundle? bundle,
    Future<Set<String>> Function()? bundledAssets,
  }) : _bundle = bundle ?? rootBundle,
       _loadBundledAssets = bundledAssets;

  final Dio _dio;
  final Future<Directory> Function() _directory;
  final String _cdnBaseUrl;
  final AssetBundle _bundle;
  final Future<Set<String>> Function()? _loadBundledAssets;

  /// Asset paths this build ships, loaded once; a failed load is retried
  /// on the next open.
  Future<Set<String>>? _bundledAssets;

  Future<Set<String>> _assetList() => _bundledAssets ??= () async {
    try {
      return await (_loadBundledAssets?.call() ?? loadBundledAssets(_bundle));
    } on Object {
      _bundledAssets = null;
      rethrow;
    }
  }();

  /// The pictures folder, opened once per app start.
  Future<Directory>? _folder;

  /// Loads in progress by puzzle id and checksum, so two opens of the same
  /// picture share one download.
  final _loads = <String, _Load>{};

  /// [onProgress] gets the downloaded share from 0 to 1; it is not called
  /// for bundled or cached pictures.
  Future<Uint8List> load(
    PuzzleEntry entry, {
    void Function(double progress)? onProgress,
  }) async {
    final assetPath = entry.assetPath;
    if (assetPath != null && (await _assetList()).contains(assetPath)) {
      final data = await _bundle.load(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    if (entry.url == null || entry.sha256 == null) {
      throw const PictureLoadException(PictureLoadFailure.unavailable);
    }
    final key = '${entry.id}:${entry.sha256}';
    final running = _loads[key];
    if (running != null) {
      if (onProgress != null) running.listeners.add(onProgress);
      return running.future;
    }
    final load = _Load();
    if (onProgress != null) load.listeners.add(onProgress);
    _loads[key] = load;
    try {
      return await (load.future = _loadCached(entry, load));
    } finally {
      _loads.remove(key);
    }
  }

  /// Creates the folder and drops `.part` files left by downloads that
  /// were cut off when the app was killed.
  Future<Directory> _openFolder() async {
    try {
      final folder = Directory('${(await _directory()).path}/pictures');
      await folder.create(recursive: true);
      await for (final file in folder.list()) {
        if (file is File && file.path.endsWith('.part')) await file.delete();
      }
      return folder;
    } on Object {
      _folder = null;
      rethrow;
    }
  }

  Future<Uint8List> _loadCached(PuzzleEntry entry, _Load load) async {
    final folder = await (_folder ??= _openFolder());
    final file = File('${folder.path}/${entry.id}.webp');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (_matches(entry, bytes)) return bytes;
      await file.delete();
    }
    final uri = resolveCdnUrl(_cdnBaseUrl, entry.url!);
    if (uri == null) {
      throw const PictureLoadException(PictureLoadFailure.unavailable);
    }
    final temp = File('${file.path}.part');
    try {
      try {
        await _dio.downloadUri(
          uri,
          temp.path,
          onReceiveProgress: (received, total) {
            final size = total > 0 ? total : entry.bytes ?? 0;
            if (size <= 0) return;
            final progress = (received / size).clamp(0.0, 1.0);
            for (final listener in load.listeners) {
              listener(progress);
            }
          },
        );
      } on DioException catch (e) {
        throw PictureLoadException(
          e.type == DioExceptionType.badResponse
              ? PictureLoadFailure.unavailable
              : PictureLoadFailure.network,
          e,
        );
      }
      final bytes = await temp.readAsBytes();
      if (!_matches(entry, bytes)) {
        throw const PictureLoadException(PictureLoadFailure.corrupt);
      }
      await temp.rename(file.path);
      return bytes;
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
      } on FileSystemException {
        // Left for the next start's cleanup in [_openFolder].
      }
    }
  }

  static bool _matches(PuzzleEntry entry, Uint8List bytes) {
    final size = entry.bytes;
    if (size != null && bytes.length != size) return false;
    return sha256.convert(bytes).toString() == entry.sha256?.toLowerCase();
  }
}

class _Load {
  final listeners = <void Function(double progress)>[];
  late Future<Uint8List> future;
}

final pictureStoreProvider = Provider<PictureStore>(
  (ref) => PictureStore(
    dio: ref.watch(dioProvider),
    directory: ref.watch(contentDirectoryProvider),
    cdnBaseUrl: ref.watch(cdnBaseUrlProvider),
    bundledAssets: () => ref.read(bundledAssetsProvider.future),
  ),
);

/// Download progress of one picture from 0 to 1, null when not downloading.
class PictureDownloadProgress extends Notifier<double?> {
  PictureDownloadProgress(this.puzzleId);

  final String puzzleId;

  @override
  double? build() => null;

  /// Whole percents only, so a download rebuilds the screen at most 100 times.
  void report(double? progress) {
    final rounded = progress == null ? null : (progress * 100).floor() / 100;
    if (rounded != state) state = rounded;
  }
}

final pictureDownloadProgressProvider =
    NotifierProvider.family<PictureDownloadProgress, double?, String>(
      PictureDownloadProgress.new,
    );
