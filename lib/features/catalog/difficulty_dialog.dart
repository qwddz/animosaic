import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/book_button.dart';
import '../../app/widgets/book_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../puzzle/difficulty_labels.dart';
import '../puzzle/domain/puzzle_layout.dart';
import '../puzzle/puzzle_screen.dart';
import 'domain/content_manifest.dart';

/// Lets the child pick a difficulty that fits this screen, then opens the
/// puzzle.
Future<void> showDifficultyDialog(BuildContext context, PuzzleEntry entry) {
  final l10n = AppLocalizations.of(context);
  final media = MediaQuery.of(context);
  // The game is full screen, so only side cutouts take space from it.
  final insets = media.viewPadding;
  final playArea = Size(
    media.size.width - insets.left - insets.right,
    media.size.height,
  );
  final difficulties = PuzzleLayout.compute(playArea).availableDifficulties;
  return showBookDialog<void>(
    context: context,
    builder: (dialogContext) => BookDialog(
      title: l10n.chooseDifficulty,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final difficulty in difficulties)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: BookButton(
                kind: BookButtonKind.secondary,
                label: l10n.difficultyOption(
                  difficulty.label(l10n),
                  l10n.pieceCount(difficulty.pieceCount),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.push(puzzleRoute(entry.id, difficulty));
                },
              ),
            ),
        ],
      ),
    ),
  );
}
