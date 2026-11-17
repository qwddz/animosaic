// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Animosaic';

  @override
  String get chooseDifficulty => 'Выберите сложность';

  @override
  String get difficultyEasy => 'Лёгкий';

  @override
  String get difficultyMedium => 'Средний';

  @override
  String get difficultyHard => 'Сложный';

  @override
  String get difficultyExpert => 'Эксперт';

  @override
  String pieceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кусочка',
      many: '$count кусочков',
      few: '$count кусочка',
      one: '$count кусочек',
    );
    return '$_temp0';
  }

  @override
  String get puzzleCompleted => 'Молодец!';

  @override
  String get playAgain => 'Ещё раз';

  @override
  String get nextPuzzle => 'Дальше';

  @override
  String get back => 'Назад';

  @override
  String get loadError => 'Не удалось загрузить картинку';

  @override
  String get retry => 'Попробовать снова';

  @override
  String difficultyOption(String level, String pieces) {
    return '$level · $pieces';
  }

  @override
  String get catalogLoadError => 'Не удалось загрузить картинки';

  @override
  String get settings => 'Настройки';

  @override
  String get soundEffects => 'Звуки';

  @override
  String get music => 'Музыка';

  @override
  String get pictureHint => 'Подсказка-картинка на поле';

  @override
  String get handHintSetting => 'Подсказки рукой';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как на устройстве';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String collectedCount(int done, int total) {
    return '$done из $total';
  }

  @override
  String bestDifficulty(String level) {
    return 'Собрано: $level';
  }

  @override
  String get categoryMissing => 'Эта категория недоступна';

  @override
  String downloadingPicture(int percent) {
    return 'Загружаем картинку… $percent%';
  }

  @override
  String get pictureOffline =>
      'Нет интернета. Подключитесь к интернету, чтобы загрузить эту картинку.';

  @override
  String get pictureCorrupt =>
      'Картинка загрузилась с ошибкой. Попробуйте ещё раз.';

  @override
  String get pictureUnavailable =>
      'Эту картинку сейчас не получается загрузить. Попробуйте позже.';

  @override
  String get lockedPicture => 'В полной версии';

  @override
  String get parentalGateTitle => 'Для взрослых';

  @override
  String parentalGateQuestion(int a, int b) {
    return 'Сколько будет $a × $b? Введите ответ цифрами.';
  }

  @override
  String get parentalGateAnswer => 'Ответ';

  @override
  String get parentalGateCooldown =>
      'Подождите несколько секунд и попробуйте ещё раз.';

  @override
  String get cancel => 'Отмена';

  @override
  String get ok => 'OK';

  @override
  String get fullVersionTitle => 'Полная версия';

  @override
  String fullVersionIncludes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Все $count картинок во всех категориях, а также новые, как только они появятся',
      few:
          'Все $count картинки во всех категориях, а также новые, как только они появятся',
      one:
          'Все $count картинка во всех категориях, а также новые, как только они появятся',
    );
    return '$_temp0';
  }

  @override
  String get oneTimePurchase => 'Разовая покупка, без подписки';

  @override
  String buyFor(String price) {
    return 'Купить за $price';
  }

  @override
  String get restorePurchases => 'Восстановить покупки';

  @override
  String get testStore => 'Тестовый магазин: деньги не списываются';

  @override
  String get priceLoadError => 'Не удалось связаться с магазином';

  @override
  String get purchaseCancelled => 'Покупка отменена';

  @override
  String get purchaseFailed => 'Покупка не прошла. Попробуйте ещё раз.';

  @override
  String get purchasePending =>
      'Платёж ожидает подтверждения. Полная версия откроется, как только он завершится.';

  @override
  String get nothingToRestore => 'Нет покупок для восстановления';

  @override
  String get purchasesRestored => 'Полная версия восстановлена';

  @override
  String get restoreFailed =>
      'Не удалось восстановить покупки. Попробуйте ещё раз.';

  @override
  String get fullVersionUnlocked => 'Полная версия открыта';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get termsOfUse => 'Условия использования';

  @override
  String get pictureLocked => 'Эта картинка есть в полной версии';

  @override
  String get about => 'О приложении';

  @override
  String appVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get contactUs => 'Написать нам';

  @override
  String get credits => 'Благодарности';

  @override
  String get creditsPictures =>
      'Картинки созданы с помощью генерации изображений искусственным интеллектом.';

  @override
  String get creditsSounds => 'Звуки и музыка синтезированы.';

  @override
  String get haveAccessCode => 'У меня есть код доступа';

  @override
  String get accessCodeTitle => 'Код доступа';

  @override
  String get accessCodeField => 'Код';

  @override
  String get accessCodeInvalid => 'Этот код не подходит';
}
