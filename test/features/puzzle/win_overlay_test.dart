import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/app/book_palette.dart';
import 'package:puzzles/app/widgets/book_button.dart';
import 'package:puzzles/app/widgets/passe_partout.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_layout.dart';
import 'package:puzzles/features/puzzle/win_overlay.dart';
import 'package:puzzles/l10n/app_localizations.dart';

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<List<String>> pumpOverlay(
    WidgetTester tester, {
    bool reducedMotion = false,
    bool hasNext = true,
    Rect? board,
  }) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: WinOverlay(
            onPlayAgain: () => taps.add('again'),
            onNext: hasNext ? () => taps.add('next') : null,
            onBack: () => taps.add('back'),
            board: board,
          ),
        ),
      ),
    );
    return taps;
  }

  Finder confetti() => find.descendant(
    of: find.byType(WinOverlay),
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ConfettiPainter,
    ),
  );

  testWidgets('vibrates once, throws confetti, buttons still work', (
    tester,
  ) async {
    final taps = await pumpOverlay(tester);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(confetti(), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    // Confetti never blocks the buttons, even mid-flight.
    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Play again'));
    await tester.tap(find.text('Back'));
    expect(taps, ['next', 'again', 'back']);
    await tester.pumpAndSettle();
    expect(haptics, hasLength(1));
  });

  testWidgets('no confetti with reduced motion', (tester) async {
    await pumpOverlay(tester, reducedMotion: true);
    expect(confetti(), findsNothing);
    expect(find.text('Well done!'), findsOneWidget);
  });

  BookButtonKind kindOf(WidgetTester tester, String label) =>
      tester.widget<BookButton>(find.widgetWithText(BookButton, label)).kind;

  testWidgets('next is primary when there is a next picture', (tester) async {
    await pumpOverlay(tester);
    expect(kindOf(tester, 'Next'), BookButtonKind.primary);
    expect(kindOf(tester, 'Play again'), BookButtonKind.secondary);
    expect(kindOf(tester, 'Back'), BookButtonKind.text);
  });

  testWidgets('play again is primary without a next picture', (tester) async {
    await pumpOverlay(tester, hasNext: false);
    expect(find.text('Next'), findsNothing);
    expect(kindOf(tester, 'Play again'), BookButtonKind.primary);
  });

  testWidgets('confetti uses the book palette', (tester) async {
    await pumpOverlay(tester);
    final painter =
        tester.widget<CustomPaint>(confetti()).painter! as ConfettiPainter;
    expect(painter.colors, isNotEmpty);
    expect(BookPalette.confetti, containsAll(painter.colors));
  });

  for (final size in const [Size(915, 412), Size(1280, 800)]) {
    testWidgets('win banner sits low and centred on the picture at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final layout = PuzzleLayout.compute(size);
      await pumpOverlay(tester, reducedMotion: true, board: layout.board);
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(PassePartout));
      expect(card.contains(layout.board.center), isFalse);
      expect(card.height, lessThanOrEqualTo(layout.board.height * 0.35));
      expect((card.center.dx - layout.board.center.dx).abs(), lessThan(1));
      expect(layout.board.contains(card.topLeft), isTrue);
      expect(layout.board.contains(card.bottomRight), isTrue);
      // All three buttons share one row.
      final next = tester.getCenter(find.text('Next'));
      final again = tester.getCenter(find.text('Play again'));
      expect((next.dy - again.dy).abs(), lessThan(1));
    });
  }
}
