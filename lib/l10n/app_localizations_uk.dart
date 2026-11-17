// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Animosaic';

  @override
  String get chooseDifficulty => 'Оберіть складність';

  @override
  String get difficultyEasy => 'Легкий';

  @override
  String get difficultyMedium => 'Середній';

  @override
  String get difficultyHard => 'Складний';

  @override
  String get difficultyExpert => 'Експерт';

  @override
  String pieceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шматочка',
      many: '$count шматочків',
      few: '$count шматочки',
      one: '$count шматочок',
    );
    return '$_temp0';
  }

  @override
  String get puzzleCompleted => 'Молодець!';

  @override
  String get playAgain => 'Ще раз';

  @override
  String get nextPuzzle => 'Далі';

  @override
  String get back => 'Назад';

  @override
  String get loadError => 'Не вдалося завантажити картинку';

  @override
  String get retry => 'Спробувати ще';

  @override
  String difficultyOption(String level, String pieces) {
    return '$level · $pieces';
  }

  @override
  String get catalogLoadError => 'Не вдалося завантажити картинки';

  @override
  String get settings => 'Налаштування';

  @override
  String get soundEffects => 'Звуки';

  @override
  String get music => 'Музика';

  @override
  String get pictureHint => 'Підказка-картинка на полі';

  @override
  String get handHintSetting => 'Підказки рукою';

  @override
  String get language => 'Мова';

  @override
  String get languageSystem => 'Як на пристрої';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String collectedCount(int done, int total) {
    return '$done з $total';
  }

  @override
  String bestDifficulty(String level) {
    return 'Зібрано: $level';
  }

  @override
  String get categoryMissing => 'Ця категорія недоступна';

  @override
  String downloadingPicture(int percent) {
    return 'Завантажуємо картинку… $percent%';
  }

  @override
  String get pictureOffline =>
      'Немає інтернету. Підключіться до інтернету, щоб завантажити цю картинку.';

  @override
  String get pictureCorrupt =>
      'Картинка завантажилася з помилкою. Спробуйте ще раз.';

  @override
  String get pictureUnavailable =>
      'Цю картинку зараз не вдається завантажити. Спробуйте пізніше.';

  @override
  String get lockedPicture => 'У повній версії';

  @override
  String get parentalGateTitle => 'Для дорослих';

  @override
  String parentalGateQuestion(int a, int b) {
    return 'Скільки буде $a × $b? Введіть відповідь цифрами.';
  }

  @override
  String get parentalGateAnswer => 'Відповідь';

  @override
  String get parentalGateCooldown =>
      'Зачекайте кілька секунд і спробуйте ще раз.';

  @override
  String get cancel => 'Скасувати';

  @override
  String get ok => 'OK';

  @override
  String get fullVersionTitle => 'Повна версія';

  @override
  String fullVersionIncludes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Усі $count картинок в усіх категоріях, а також нові, щойно вони з\'являться',
      few:
          'Усі $count картинки в усіх категоріях, а також нові, щойно вони з\'являться',
      one:
          'Усі $count картинка в усіх категоріях, а також нові, щойно вони з\'являться',
    );
    return '$_temp0';
  }

  @override
  String get oneTimePurchase => 'Разова покупка, без підписки';

  @override
  String buyFor(String price) {
    return 'Купити за $price';
  }

  @override
  String get restorePurchases => 'Відновити покупки';

  @override
  String get testStore => 'Тестовий магазин: гроші не списуються';

  @override
  String get priceLoadError => 'Не вдалося зв\'язатися з магазином';

  @override
  String get purchaseCancelled => 'Покупку скасовано';

  @override
  String get purchaseFailed => 'Покупка не вдалася. Спробуйте ще раз.';

  @override
  String get purchasePending =>
      'Оплата очікує підтвердження. Повна версія відкриється, щойно вона завершиться.';

  @override
  String get nothingToRestore => 'Немає покупок для відновлення';

  @override
  String get purchasesRestored => 'Повну версію відновлено';

  @override
  String get restoreFailed => 'Не вдалося відновити покупки. Спробуйте ще раз.';

  @override
  String get fullVersionUnlocked => 'Повну версію відкрито';

  @override
  String get privacyPolicy => 'Політика конфіденційності';

  @override
  String get termsOfUse => 'Умови використання';

  @override
  String get pictureLocked => 'Ця картинка є в повній версії';

  @override
  String get about => 'Про застосунок';

  @override
  String appVersion(String version) {
    return 'Версія $version';
  }

  @override
  String get contactUs => 'Написати нам';

  @override
  String get credits => 'Подяки';

  @override
  String get creditsPictures =>
      'Картинки створено за допомогою генерації зображень штучним інтелектом.';

  @override
  String get creditsSounds => 'Звуки й музику синтезовано.';

  @override
  String get haveAccessCode => 'У мене є код доступу';

  @override
  String get accessCodeTitle => 'Код доступу';

  @override
  String get accessCodeField => 'Код';

  @override
  String get accessCodeInvalid => 'Цей код не підходить';
}
