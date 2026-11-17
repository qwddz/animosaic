import '../../l10n/app_localizations.dart';
import 'domain/difficulty.dart';

extension DifficultyLabel on Difficulty {
  String label(AppLocalizations l10n) => switch (this) {
    Difficulty.easy => l10n.difficultyEasy,
    Difficulty.medium => l10n.difficultyMedium,
    Difficulty.hard => l10n.difficultyHard,
    Difficulty.expert => l10n.difficultyExpert,
  };
}
