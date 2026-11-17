# Play Console: черновик ответов

Черновик для разделов «Policy and programs → App content» и «Store settings» в Google Play Console. Ответы построены по фактическому поведению сборки 1.0.0 (код, `pubspec.yaml`, слитый релизный манифест) и по `site/privacy.html`. Всё, в чём есть сомнение, помечено **проверить**.

Что приложение делает с данными (проверено):

- Зависимости с сетью: `purchases_flutter` (RevenueCat), `dio` (скачивание картинок с `cdn.animosaic.app`, Cloudflare R2), `url_launcher` (ссылки из «О приложении», за родительской проверкой). Firebase, аналитики, крэш-репортера и рекламных SDK нет.
- RevenueCat вызывается только так: `configure`, `getOfferings`, `getCustomerInfo`, `purchase`, `restorePurchases`, слушатель `CustomerInfo`. Ни `logIn` со своим ID, ни `setAttributes` / `setEmail`, ни `collectDeviceIdentifiers`, ни интеграций атрибуции — значит, RevenueCat работает с анонимным `$RCAnonymousID`, созданным на устройстве.
- Разрешения в слитом релизном манифесте: `INTERNET`, `ACCESS_NETWORK_STATE`, `com.android.vending.BILLING`, служебное `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. **`AD_ID` нет** — это важно для политики для семей.
- Прогресс, незаконченный пазл и настройки хранятся только на устройстве.

## Основное

| Поле | Ответ |
|---|---|
| Privacy policy URL | https://animosaic.app/privacy |
| Contact e-mail | pirate.dmitry@gmail.com |
| Website | https://animosaic.app (**проверить**, что главная страница открывается; если нет — оставить пустым) |
| Phone | не указывать (необязательно) |
| App or game | Game |
| Free or paid | Free (с внутриигровой покупкой) |
| Category | Puzzle |
| Tags (до 5, из списка Play) | Jigsaw, Puzzle, Casual, Kids, Animals — **проверить**: набор тегов в Play Console фиксированный, взять ближайшие доступные (часто есть «Jigsaw puzzle», «Family», «Casual», «Offline», «Single player») |
| In-app product | `full_version`, разовая (one-time, non-consumable), US$4.99; цены для других стран — автоматический пересчёт Play, потом просмотреть UAH/EUR вручную. Должен быть **активен** до отправки на ревью |
| Countries | Только страны, где доступна оплата в Google Play (см. PLAN.md). **проверить** при выборе стран |

## App access

- **Да, есть закрытые разделы.** Новая форма Play прямо относит к ним «платежи, например за контент для однократных покупок», а 242 из 297 картинок открываются только покупкой `full_version`.
- Решение (2026-11-17): вместо промокодов Play — код доступа в приложении. На экране «Full version» есть кнопка «I have an access code»; код `REVIEW_CODE` из `.env`, в сборку попадает только его sha256 (`REVIEW_CODE_SHA256`, см. «Release build» в `CLAUDE.md`). Кнопка есть начиная со сборки 26111710.
- Заполнено в Play Console: имя набора `Full version access code`, логин и пароль пусты, галочка «обеспечивают полный доступ, включая платный» стоит. Инструкция (Any other information, ≤ 500 символов):

```
No account or login is needed. 55 pictures are free. The rest unlock with a one-time
in-app purchase ("Full version"), so we provide an access code that unlocks them
without paying:
1. Open any category and tap a picture with a lock icon.
2. Parental gate: type the product of the two numbers shown (e.g. 7 × 8 = 56), tap OK.
3. On the "Full version" screen tap "I have an access code".
4. Enter the code <REVIEW_CODE из .env> and tap OK. All pictures are now unlocked.
```

- При смене кода или сборке без `REVIEW_CODE_SHA256` эту декларацию нужно обновить вместе с новой сборкой.

## Ads

- **Does your app contain ads? — No.**
- Advertising ID declaration: **No**, приложение не использует рекламный идентификатор (в манифесте нет `com.google.android.gms.permission.AD_ID`). После любой новой зависимости проверять слитый манифест заново.

## Content rating (IARC)

Категория анкеты: **Game** (игра).

| Вопрос анкеты (суть) | Ответ |
|---|---|
| Violence (насилие, кровь, нападения животных) | No |
| Fear / horror (пугающие сцены) | No — пауки, змеи и акулы нарисованы дружелюбно, мультяшно. **проверить** по картинкам категорий «Пауки», «Змеи», «Акулы»: нет оскала, крови, охоты |
| Sexuality / nudity | No |
| Language (ругательства, грубость) | No |
| Controlled substances (алкоголь, табак, наркотики) | No |
| Crude humor | No |
| Gambling / simulated gambling, лутбоксы | No |
| Does the app allow users to interact or exchange content? | No (нет чатов, профилей, обмена) |
| Does the app share the user's current physical location? | No |
| Does the app allow users to purchase digital goods? | **Yes** (разовая покупка полной версии) |
| Does the app contain unrestricted internet access / web browser? | No (ссылки наружу только за родительской проверкой и открываются во внешнем браузере) |
| Is the app primarily a news / educational reference? | No |

Ожидаемый результат: IARC 3+, PEGI 3, ESRB Everyone, USK 0, с пометкой «In-App Purchases». **проверить** итог после отправки анкеты.

## Target audience and content

- **Target age groups:** «5 and under» и «6–8». **проверить**: можно добавить «9–12», если картинки на 48 кусочков задуманы и для школьников; возрасты 13+ не отмечать — смешанная аудитория потребует экрана выбора возраста.
- **Could the store listing unintentionally appeal to children?** — не задаётся, раз дети и есть целевая аудитория.
- Последствия: приложение попадает под **Families Policy** (политика Google Play для семей). Что это значит и как приложение ей соответствует:
  - Реклама — только через Families Self-Certified Ads SDK. У нас рекламы нет вообще.
  - Нельзя передавать от детей AAID, Android ID, IMEI, SIM serial, MAC и т. п. — не передаём (`AD_ID` в манифесте отсутствует, RevenueCat без device identifiers).
  - Нельзя запрашивать местоположение, контакты и т. п. — не запрашиваем.
  - Покупки и ссылки наружу должны быть защищены от случайного нажатия ребёнком — родительская проверка есть.
  - Политика конфиденциальности должна описывать обращение с данными детей — раздел «Children» в `site/privacy.html` есть.
  - Контент — подходящий для детей (IARC 3+).
  - SDK, работающие в детском приложении, должны соблюдать Families policy. RevenueCat — платёжная инфраструктура, не реклама и не аналитика для таргетинга. **проверить**, не потребует ли ревью дополнительного заявления по RevenueCat.
- **Teacher Approved** — по желанию, после релиза.

## Data safety

### Обзор

| Вопрос | Ответ |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (RevenueCat и CDN — только HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — по e-mail pirate.dmitry@gmail.com; удаление клиента делается в дашборде RevenueCat (Customer → Delete customer) |
| Data deletion URL | Не требуется: в приложении нет учётных записей. Если Play всё же спросит — https://animosaic.app/privacy (раздел «Your rights») |
| Independent security review | No |
| Committed to Families Policy | Yes |

### Типы данных

Основание — официальная памятка RevenueCat «Google Play's Data Safety» (https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety). По ней обязательно только одно: **Financial info → Purchase history** (collected by RevenueCat, не ephemeral, обязательно, цели App functionality и Analytics, шифруется при передаче). Personal info (имя/e-mail) — только при использовании customer attributes с контактами (у нас нет). Device or other IDs — только при интеграциях с рекламным ID (`gpsAdId`, `androidId`; у нас нет).

| Категория → тип | Collected | Shared | Ephemeral | Required | Purposes |
|---|---|---|---|---|---|
| Financial info → **Purchase history** | Yes | No | No | Required | App functionality; Analytics (так рекомендует RevenueCat: данные используются в графиках дашборда RevenueCat) |
| Device or other IDs | **проверить**: по памятке RevenueCat — не объявлять. Осторожный вариант — объявить: анонимный ID пользователя RevenueCat похож на «app-specific identifier» из определения Play (пример там — Firebase installation ID). Если объявлять: Collected Yes, Shared No, Ephemeral No, Required, App functionality | — | — | — | — |

Не объявляем (с пояснением):

- **Shared — No** во всех строках: RevenueCat и Cloudflare обрабатывают данные от нашего имени как поставщики услуг (service providers), а это по определению Play не считается «sharing».
- Технические данные RevenueCat (версия приложения и ОС, страна/валюта для цен) — памятка RevenueCat их не требует; это не «App info and performance» (крэш-логи, диагностика), которых мы не собираем.
- IP-адрес при скачивании картинок с CDN — его обрабатывает Cloudflare для доставки файлов, мы его не собираем, не храним и не выводим из него местоположение. Location не объявляем. **проверить**, если позже включится аналитика Cloudflare Web Analytics или логирование запросов в R2.
- Personal info, Location, Messages, Photos/Videos, Audio, Files, Calendar, Contacts, App activity, Web browsing, Health, App info and performance — не собираются.

Важно: при добавлении Firebase, Crashlytics, аналитики или `Purchases.logIn` / атрибутов раздел нужно пересмотреть (в PLAN.md упоминается Firebase — в текущей сборке его нет).

## Прочие декларации App content

| Раздел | Ответ |
|---|---|
| News app | No |
| COVID-19 contact tracing / status | No |
| Government app | No |
| Financial features | My app doesn't provide any financial features |
| Health apps | No health features |
| Data safety → Account creation | My app does not allow users to create an account |
