// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Animosaic';

  @override
  String get chooseDifficulty => 'Choose difficulty';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyExpert => 'Expert';

  @override
  String pieceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieces',
      one: '$count piece',
    );
    return '$_temp0';
  }

  @override
  String get puzzleCompleted => 'Well done!';

  @override
  String get playAgain => 'Play again';

  @override
  String get nextPuzzle => 'Next';

  @override
  String get back => 'Back';

  @override
  String get loadError => 'Couldn\'t load the picture';

  @override
  String get retry => 'Try again';

  @override
  String difficultyOption(String level, String pieces) {
    return '$level · $pieces';
  }

  @override
  String get catalogLoadError => 'Couldn\'t load the pictures';

  @override
  String get settings => 'Settings';

  @override
  String get soundEffects => 'Sounds';

  @override
  String get music => 'Music';

  @override
  String get pictureHint => 'Picture hint on the board';

  @override
  String get handHintSetting => 'Hand hints';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Same as device';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String collectedCount(int done, int total) {
    return '$done of $total';
  }

  @override
  String bestDifficulty(String level) {
    return 'Completed: $level';
  }

  @override
  String get categoryMissing => 'This category is not available';

  @override
  String downloadingPicture(int percent) {
    return 'Downloading the picture… $percent%';
  }

  @override
  String get pictureOffline =>
      'No internet connection. Connect to the internet to download this picture.';

  @override
  String get pictureCorrupt =>
      'The picture didn\'t download correctly. Try again.';

  @override
  String get pictureUnavailable =>
      'This picture can\'t be downloaded right now. Try again later.';

  @override
  String get lockedPicture => 'In the full version';

  @override
  String get parentalGateTitle => 'For grown-ups';

  @override
  String parentalGateQuestion(int a, int b) {
    return 'How much is $a × $b? Type the answer in digits.';
  }

  @override
  String get parentalGateAnswer => 'Answer';

  @override
  String get parentalGateCooldown => 'Please wait a few seconds and try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get fullVersionTitle => 'Full version';

  @override
  String fullVersionIncludes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'All $count pictures in every category, and new ones as they arrive',
      one: 'All $count picture in every category, and new ones as they arrive',
    );
    return '$_temp0';
  }

  @override
  String get oneTimePurchase => 'One-time purchase, no subscription';

  @override
  String buyFor(String price) {
    return 'Buy for $price';
  }

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get testStore => 'Test store: nothing is charged';

  @override
  String get priceLoadError => 'Couldn\'t reach the store';

  @override
  String get purchaseCancelled => 'Purchase cancelled';

  @override
  String get purchaseFailed => 'The purchase didn\'t go through. Try again.';

  @override
  String get purchasePending =>
      'Payment is pending. The full version opens as soon as it completes.';

  @override
  String get nothingToRestore => 'No purchases to restore';

  @override
  String get purchasesRestored => 'Full version restored';

  @override
  String get restoreFailed => 'Couldn\'t restore purchases. Try again.';

  @override
  String get fullVersionUnlocked => 'Full version unlocked';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get pictureLocked => 'This picture is in the full version';

  @override
  String get about => 'About';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get contactUs => 'Contact us';

  @override
  String get credits => 'Credits';

  @override
  String get creditsPictures =>
      'Pictures were created with AI image generation.';

  @override
  String get creditsSounds => 'Sounds and music were synthesized.';

  @override
  String get haveAccessCode => 'I have an access code';

  @override
  String get accessCodeTitle => 'Access code';

  @override
  String get accessCodeField => 'Code';

  @override
  String get accessCodeInvalid => 'This code doesn\'t work';
}
