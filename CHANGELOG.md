# История изменений

## Unreleased

- Исправлена подпись локальной сборки: подписывается весь bundle с правильным идентификатором, подпись проверяется перед выдачей. Раздел разрешений открывает настройки macOS и показывает используемую копию приложения.

- Проверка поля, курсора и исходного текста перед заменой; защищённые и неподдерживаемые поля пропускаются.
- Восстановление последнего исправления двойным Shift до следующего ввода, смены контекста или 15 секунд.
- Исправлены замена валидных слов на имена и рекурсивный запуск после отказа перехвата.
- Правдивые состояния готовности, доступные имена controls и контентные размеры настроек.
- Управляемые подсказки, локальный пример, сохранение исключённых слов, bounded caches и retries; Reduce Motion.
- Голос, AI и новые ОС отложены в ROADMAP.md.

Все заметные изменения KeySwitch фиксируются в этом файле.

## 3.0.1 — 2026-07-31

### Изменено

- создана новая иконка приложения в стиле Liquid Glass с символами `A / Я`;
- новая иконка используется в Finder, Dock и внутри окна настроек.

### Исправлено

- устранена большая пустая область над заголовком раздела настроек;
- содержимое прокручиваемых разделов теперь всегда начинается у верхнего края.

## 3.0.0 — 2026-07-31

### Добавлено

- полностью обновлённое окно настроек с боковой навигацией и лёгким
  интерфейсом в стиле macOS;
- системная, светлая и тёмная темы; на macOS 26 используется системный
  Liquid Glass, на macOS 13–15 — совместимый материал AppKit;
- три режима орфографии: выключено, подсказки и автоисправление;
- раздел «О приложении» с номером версии, ручной проверкой обновлений и
  отключаемой ежедневной проверкой GitHub Releases;
- команда проверки обновлений в меню строки состояния.

### Изменено

- окно подсказки об опечатке создаётся только в режиме «Подсказки», поэтому
  выключенная орфография и автоисправление не держат лишнее окно;
- политика приватности уточняет, что текст обрабатывается локально, а сетевой
  доступ используется только для необязательной проверки версии.

## 2.2.0 — 2026-07-31

### Добавлено

- универсальное распознавание латинских моделей с цифрами и дефисами:
  `X3`, `Q7`, `CX-5`, `GLE450`;
- нормализация распространённых автомобильных марок, включая `BMW`, `Audi`,
  `Mercedes`, `Toyota`, `Geely` и другие;
- вариант №8 для строки меню: `A/Я` внутри круговых стрелок с короткой
  анимацией после исправления.

### Исправлено

- цифры больше не разрывают буквенно-цифровое обозначение до его проверки;
- распознаётся пользовательский пример `,hspujdbrb → брызговики`;
- обычные сочетания вроде `версия3` и `дом15` не считаются моделями.

## 2.1.3 — 2026-07-31

### Исправлено

- после автоматического исправления больше не дублируется первая буква слова;
- пробел и другие завершающие клавиши возвращаются после исправленного слова
  в правильном порядке.

### Добавлено

- в README отображается общее число загрузок файлов из GitHub Releases.

## 2.1.2 — 2026-07-30

### Добавлено

- номер установленной версии отображается в нижнем левом углу настроек;
- номер версии и сборки доступен в меню строки состояния.

## 2.1.1 — 2026-07-30

### Исправлено

- релиз после успешных тестов публикуется автоматически, поэтому команда
  терминальной установки сразу видит последнюю версию.

## 2.1.0 — 2026-07-30

### Добавлено

- установка последнего опубликованного релиза одной командой в Терминале;
- стабильные имена `KeySwitch.pkg` и `KeySwitch.zip` в GitHub Releases.

### Исправлено

- установочный PKG теперь создаётся при каждой сборке, независимо от доступности
  создания DMG.

## 2.0.5 — 2026-07-30

### Исправлено

- добавлен расширенный набор русских и английских предлогов;
- добавлена автоматическая двусторонняя проверка 113 предлогов, набранных
  в неправильной раскладке;
- устранены пропуски коротких, производных и дефисных предлогов.

## 2.0.4 — 2026-07-30

### Исправлено

- одиночные русские предлоги и союзы больше не блокируются английскими
  сокращениями системного словаря (`d → в`);
- кавычки и скобки вокруг ошибочно набранного слова сохраняются при исправлении.

## 2.0.3 — 2026-07-30

### Исправлено

- добавлено распознавание слов из последнего пользовательского теста;
- физический пробел больше не подменяется при исправлении раскладки;
- тесты языкового движка больше не зависят от набора словарей GitHub Actions;
- генератор иконки использует установленный macOS SDK без жёстко заданного пути;
- копия `.app` в установочных артефактах очищается, подписывается и проверяется
  во время упаковки.

## 2.0.2 — 2026-07-30

### Исправлено

- устранено падение окна настроек при создании нижнего индикатора доступа;
- проверена совместимость сборки с Apple Silicon и Intel.

## 2.0.1 — 2026-07-30

### Добавлено

- распознавание односимвольных слов;
- исправление имён через орфографический движок;
- индикатор доступа перенесён в нижнюю часть настроек.

## 2.0.0 — 2026-07-30

### Добавлено

- системные офлайн-словари русского и английского языков;
- проверка орфографии и необязательное автоисправление;
- визуальный индикатор найденной опечатки;
- корректная обработка пунктуационных клавиш русской раскладки.

## 1.7.0 — 2026-07-30

### Добавлено

- добавление активного приложения в исключения из меню в строке меню;
- названия и иконки приложений в списке исключений.


## 3.0.2 — window and installation hotfix

- Fix settings controller initialization that created no window on launch.
- Open settings before background services; explicitly route tray menu actions.
- Add an isolated launch/reopen check without input monitoring or network.
- Installer replaces the canonical app, stops verified KeySwitch processes and
  removes older same-identifier copies in /Applications while preserving preferences.

- Installer hotfix: handle zero running processes under macOS Bash 3.2; add
  regression coverage for the live-volume preinstall branch.


## 3.1.0

- Simplify settings with neutral native surfaces, readable captions and plain labels.
- Focus the main screen on layout correction and a safe local example.
- Replace the glossy app icon with flat A/Я keys and use a native keyboard symbol
  in the menu bar; remove rotating letter animations.
- Add persistent menu-bar-only mode, enabled by default. Opening settings no longer
  adds a Dock icon. Keep an optional Dock toggle under appearance/startup settings.
- Add isolated UI preview and launch checks; verify hide/reopen and Dock switching.

## 3.1.1

- Protect correct vocabulary, proper names, technical terms, abbreviations and identifiers before layout conversion.
- Remove approximate name rewriting and preserve case when converting brands. Restrict automatic model recognition to established model families.
- Use curated common typo rules for automatic spelling; keep ambiguous spell-check guesses as explicit suggestions.
- Cache case-neutral guesses and apply capitalization per request, including ALL CAPS.
- Share punctuation parsing between spelling and layout; fix spelling inside quotes/brackets and recognize Tab as a word boundary.
- Skip automatic edits at address/path/code separators, protect drive prefixes and long Unicode event buffers.
- Add offline vocabulary, deterministic stress audit and strict regressions for the reproduced defects.
