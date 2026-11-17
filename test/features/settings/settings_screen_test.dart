import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/app/app.dart';
import 'package:puzzles/app/book_palette.dart';
import 'package:puzzles/core/json_file_store.dart';
import 'package:puzzles/features/catalog/data/manifest_provider.dart';
import 'package:puzzles/features/catalog/domain/content_manifest.dart';
import 'package:puzzles/features/progress/data/progress_controller.dart';
import 'package:puzzles/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final manifest = ContentManifest.fromJson(
    jsonDecode(File('assets/manifest.json').readAsStringSync()),
  );

  Future<ProviderContainer> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final dir = Directory.systemTemp.createTempSync('settings_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          manifestProvider.overrideWith((ref) async => manifest),
          progressStoreProvider.overrideWithValue(
            JsonFileStore(() async => dir, 'progress.json'),
          ),
        ],
        child: const PuzzlesApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PuzzlesApp)));
  }

  testWidgets('settings screen toggles hand hints', (tester) async {
    final container = await openSettings(tester);
    expect(container.read(settingsProvider).handHint, isTrue);
    final row = find.widgetWithText(SwitchListTile, 'Hand hints');
    await tester.scrollUntilVisible(row, 100);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).handHint, isFalse);
  });

  testWidgets('language picker is in the book style', (tester) async {
    await openSettings(tester);
    final dropdown = find.byType(DropdownButton<String?>);
    await tester.scrollUntilVisible(dropdown, 100);
    final button = tester.widget<DropdownButton<String?>>(dropdown);
    expect(button.dropdownColor, BookPalette.card);
    expect(button.borderRadius, BorderRadius.circular(12));
    expect(button.style?.color, BookPalette.text);
    expect(button.style?.fontFamily, 'Nunito');
    final box = tester.widget<DecoratedBox>(
      find.ancestor(of: dropdown, matching: find.byType(DecoratedBox)).first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, BookPalette.paperLight);
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect((decoration.border! as Border).top.color, BookPalette.outline);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский').last);
    await tester.pumpAndSettle();
    expect(find.text('Язык'), findsOneWidget);
  });
}
