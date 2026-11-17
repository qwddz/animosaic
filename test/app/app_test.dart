import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/audio/audio_controller.dart';
import 'package:puzzles/app/app.dart';
import 'package:puzzles/app/router.dart';
import 'package:puzzles/core/json_file_store.dart';
import 'package:puzzles/app/widgets/book_button.dart';
import 'package:puzzles/app/widgets/paper_background.dart';
import 'package:puzzles/features/catalog/catalog_grid.dart';
import 'package:puzzles/features/catalog/categories_screen.dart';
import 'package:puzzles/features/catalog/data/manifest_provider.dart';
import 'package:puzzles/features/catalog/domain/content_manifest.dart';
import 'package:puzzles/features/progress/data/progress_controller.dart';
import 'package:puzzles/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_audio_backend.dart';

void main() {
  final manifest = ContentManifest.fromJson(
    jsonDecode(File('assets/manifest.json').readAsStringSync()),
  );
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('app_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpApp(
    WidgetTester tester,
    List<Locale> deviceLocales, {
    Map<String, Object> preferences = const {},
  }) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = deviceLocales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    SharedPreferences.setMockInitialValues(preferences);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          // rootBundle caches loads across tests; read the file directly.
          manifestProvider.overrideWith((ref) async => manifest),
          progressStoreProvider.overrideWithValue(
            JsonFileStore(() async => dir, 'progress.json'),
          ),
        ],
        child: const PuzzlesApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PictureCard), findsWidgets);
  }

  testWidgets('categories in English with collected counters', (tester) async {
    await pumpApp(tester, const [Locale('en', 'US')]);
    expect(find.text('Animosaic'), findsOneWidget);
    expect(find.text('Sea friends'), findsOneWidget);
    final seaSize = manifest.categoryById('sea')!.puzzles.length;
    expect(find.text('0 of $seaSize'), findsWidgets);
  });

  testWidgets('catalog screens draw the paper background', (tester) async {
    await pumpApp(tester, const [Locale('en', 'US')]);
    expect(find.byType(PaperBackground), findsOneWidget);
    await tester.tap(find.text('On the farm'));
    await tester.pumpAndSettle();
    expect(find.byType(PaperBackground), findsWidgets);
    expect(find.text('Piglet'), findsOneWidget);
  });

  testWidgets('first launch opens the catalog straight away', (tester) async {
    await pumpApp(tester, const [Locale('en', 'US')]);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(PuzzlesApp)),
    ).read(routerProvider);
    expect(router.state.matchedLocation, '/');
    expect(find.byType(CategoriesScreen), findsOneWidget);
  });

  testWidgets('device language Ukrainian', (tester) async {
    await pumpApp(tester, const [Locale('uk', 'UA')]);
    expect(find.text('Animosaic'), findsOneWidget);
    expect(find.text('Морські мешканці'), findsOneWidget);
  });

  testWidgets('unsupported device language falls back to English', (
    tester,
  ) async {
    await pumpApp(tester, const [Locale('de', 'DE')]);
    expect(find.text('Animosaic'), findsOneWidget);
  });

  testWidgets('language chosen in settings beats the device language', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const [Locale('en', 'US')],
      preferences: {'settings.language': 'ru'},
    );
    expect(find.text('Animosaic'), findsOneWidget);
    expect(find.text('Морские жители'), findsOneWidget);
  });

  testWidgets('category opens its pictures, a picture asks for difficulty', (
    tester,
  ) async {
    await pumpApp(tester, const [Locale('en', 'US')]);
    await tester.tap(find.text('On the farm'));
    await tester.pumpAndSettle();
    expect(find.text('Piglet'), findsOneWidget);
    await tester.tap(find.text('Piglet'));
    await tester.pumpAndSettle();
    expect(find.text('Choose difficulty'), findsOneWidget);
    expect(find.text('Easy · 6 pieces'), findsOneWidget);
    expect(find.text('Expert · 48 pieces'), findsOneWidget);
  });

  testWidgets('settings screen switches the language', (tester) async {
    await pumpApp(tester, const [Locale('en', 'US')]);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same as device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Українська').last);
    await tester.pumpAndSettle();
    expect(find.text('Налаштування'), findsOneWidget);
    expect(find.text('Мова'), findsOneWidget);
  });

  testWidgets('an unknown category offers a way back', (tester) async {
    await pumpApp(tester, const [Locale('en', 'US')]);
    ProviderScope.containerOf(tester.element(find.byType(PuzzlesApp)))
        .read(routerProvider)
        .push('/category/nope');
    await tester.pumpAndSettle();
    expect(find.text('This category is not available'), findsOneWidget);
    await tester.tap(find.widgetWithText(BookButton, 'Back'));
    await tester.pumpAndSettle();
    expect(find.text('Sea friends'), findsOneWidget);
  });
}
