# Реализация и проверка

3 октября 2026. Текущий объём: этапы 1–3 для macOS. Будущие дополнения
отложены по решению пользователя; см. ROADMAP.md.

## Реализовано

- Перед заменой проверяются приложение, поле, источник ввода, отсутствие
  выделения, курсор и точный текст. Перед отправкой событий выполняется повторная
  сверка. Полный набор синтетических событий создаётся до удаления текста и
  отправляется в проверенный процесс. При недоступном контексте замена пропускается.
- Мышь, навигация, смена приложения/поля, защищённый ввод и новая печать
  инвалидируют старый контекст. Восстановление двойным Shift ограничено
  подтверждённым контекстом и 15 секундами; на диск исправления не записываются.
- Валидные слова сохраняются перед поиском похожего имени. В орфографии
  нормализация имени применяется только к словам с заглавной начальной буквой.
- Отказ перехвата больше не вызывает рекурсивный запуск. Автоматические попытки
  ограничены пятью с задержками; доступ и работа мониторинга разделены.
- Настройки и строка меню используют единое состояние готовности. Подписи
  переключателей и выбор sidebar представлены программно. Несохранённые
  слова-исключения фиксируются при завершении ввода, переходе и скрытии окна.
- Подсказка доступна до нового ввода/смены контекста/закрытия; двойной Shift
  применяет её после сверки. Есть закрытие и исключение слова, accessibility
  announcement. Устаревшие отложенные показы отменяются.
- Есть локальный пример первого успеха; он явно отделён от проверки внешнего
  редактора. Пустые исключения объяснены; удаление без выбора недоступно.
- Ограничены tokens и отрицательный cache; словарные вызовы не делаются для
  слишком длинных слов. Текстовые карточки могут расти; окно допускает 760×540.
- Учтён Reduce Motion. Ошибки обновления не считаются успешной проверкой;
  повтор ограничен пятиминутной задержкой. Копия приватности и документация уточнены.
- Polish выполнен в текущей идентичности: общие размеры/отступы, состояния,
  тексты, выделение навигации, минимальные размеры и обратная связь.

## Подтверждено

- Регрессионный набор: LanguageEngineTests: OK. Добавлены сценарии valid word →
  name, несовпадающий текст/курсор, выделение, nil-контекст, UTF-16 emoji,
  ограниченные retry и состояния ready/paused/failed/permission.
- Typecheck всех Swift-файлов прошёл. Универсальная сборка прошла; lipo
  подтверждает x86_64 и arm64.
- 24 offscreen AppKit-render для шести разделов × две темы × два размера
  (760×540, 960×670); после исправления конфликта иерархии constraints запуск
  завершился без исключений. Выполнен один подтверждающий пакет.
- git diff --check прошёл. Пакет локальной сборки: build/KeySwitch-local.zip.

## Ограничения проверки

- Глобальный перехват не запускался; Accessibility-разрешение не запрашивалось.
  Совместимость синтетических событий с реальными редакторами, гонки между
  проверкой и обработкой событий, физическая клавиатура и полноценный VoiceOver
  остаются непроверенными. Предварительная сверка не является транзакцией редактора.
- В regression script системный словарь отключён; поведение реального
  NSSpellChecker и worst-case задержки AX/словаря не измерены. Ограничения ресурсов
  проверены по реализации; заявления об ускорении не делаются.
- Offscreen-render подтверждает построение и основную геометрию views,
  но не воспроизводит системный compositor/blur, фокус и все состояния активного
  окна. По этим изображениям нельзя сертифицировать контраст или вид материала.
  Последующее изменение панели подсказки на контентную высоту проверено сборкой,
  а не дополнительной визуальной сессией.
- Impeccable launcher недоступен (permission denied); автоматический detector,
  snapshot/trend и закрытие snapshot не применялись. Для AppKit web detector
  не применим. Повторная численная оценка без live-проверки не выставлялась.
- CLT linker предупреждает об отсутствии x86_64 в libswiftCompatibilityPacks.a,
  но универсальный executable создан. Сборка на Intel и минимальной macOS 13
  в реальной среде не запускалась.
- Локальная сборка не устанавливалась, не публиковалась и не проходила
  notarization; изменения остаются в KeySwitch-review. Исходная версия 3.0.1
  сохранена; изменения записаны в Unreleased.

## Ручная проверка перед релизом

В TextEdit, Notes и браузере проверить RU/EN, новый ввод после исправления,
двойной Shift (конвертация/восстановление/подсказка), смену поля мышью,
выделение и стрелки, отказ/отзыв доступа, secure/unsupported поля. Проверить
VoiceOver, Tab, уменьшение движения, обе темы и минимальное окно. Rich-text
проблему из KNOWN_ISSUES.md сравнить с выключенным KeySwitch до отдельного исправления.

## Исправление доступа: подпись локального ZIP

После сообщения пользователя выявлено: предыдущий build/KeySwitch-local.zip
содержал bundle без полноценной подписи. Бинарник имел только linker ad-hoc
подпись с Identifier=KeySwitch-arm64, Info.plist не был привязан, resources
не были запечатаны; codesign --verify --deep --strict завершался ошибкой.
Это ошибка подготовки выданного артефакта, а не доказательство сбоя AX API.

Исправлены build.sh и package.sh: весь bundle подписывается с Identifier=
local.keyswitch.app и проверяется. Возможна передача KEYSWITCH_SIGN_IDENTITY;
по умолчанию ad-hoc, без подделки стабильного designated requirement.

Повторные тесты и universal build прошли. Исправленный ZIP распакован в
build/access-signature-check; strict/deep проверка извлечённого bundle прошла.
Новая подпись включает Info.plist и Sealed Resources. Артефакт:
build/KeySwitch-access-fix.zip; прежняя ссылка KeySwitch-local.zip тоже обновлена.

Ad-hoc designated requirement привязан к cdhash: после изменения сборки старое
разрешение может не соответствовать новому коду. Нужно вручную добавить новую
копию в системный список и перезапустить её. Для постоянной идентичности релизов
нужна подходящая стабильная Apple signing identity; её здесь нет.

В разделе разрешений добавлены открытие нужной страницы macOS, показ фактической
копии в Finder и инструкция повторного добавления. Системные разрешения не
сбрасывались и не выдавались автоматически. Запущенная копия KeySwitch на этом
хосте не обнаружена; фактическое предоставление доступа не подтверждено.


## 3.0.2: window and installer fix

- Reproduced launch failure in the actual optimized executable: controller=true,
  window=false, visible=false. The no-argument constructor resolved to inherited
  NSWindowController.init(), bypassing the UI constructor with a default argument.
- AppDelegate now explicitly calls SettingsWindowController(initialSection: 0).
  Removed the misleading default argument. Main keeps AppDelegate alive across
  the run loop; menu actions have explicit targets. Window shows before monitoring
  and network services, restores after hiding and recenters if offscreen.
- Added --launch-check: bypasses input monitoring, permission prompts and network;
  checks initial creation and hides/reopens using the actual settings menu action.
  Actual executable result: controller=true, window=true, visible=true; final
  windowVisible=true (exit 0). Requires access to WindowServer outside sandbox.
- LanguageEngineTests: OK. Intel + Apple Silicon universal build; strict bundle
  signature check passed. Existing CLT compatibility archive warning remains.
- PKG 3.0.2 build 29 replaces /Applications/KeySwitch.app. Preinstall stops only
  processes whose app bundle has local.keyswitch.app identifier. Postinstall
  verifies the new signature before deleting other direct .app copies in
  /Applications with that same identifier (including KeySwitch 2.app). Symlinks
  and unrelated identifiers are skipped. Downloads and user Applications are
  not scanned or removed. UserDefaults and Accessibility grants are untouched.
- Installer cleanup fixture passed: renamed same-ID apps removed, unrelated app
  and symlink preserved. PKG expanded; both executable scripts and upgrade-bundle
  configuration verified. Extracted payload strict signature verified.
- No system-wide installation performed here. Package is locally built, unsigned
  as an installer; app is ad-hoc signed, not Developer ID signed or notarized.
  macOS may require explicit approval for installation and Accessibility access
  must be granted to the replacement app by the user.


## Installer hotfix after failed installation (22:07, 3 October 2026)

- /var/log/install.log identifies the exact failure: preinstall line 25,
  `pids[@]: unbound variable`, PKInstallErrorDomain 112. No running KeySwitch
  processes meant an empty array; macOS /bin/bash 3.2 rejects that expansion with
  nounset enabled. The earlier fixture used an alternate volume and therefore
  skipped the live-volume preinstall branch.
- Added isolated live-volume branch fixtures with a fake process inventory and
  canonical bundle path, never touching real processes or /Applications. Before
  the fix, the zero-process test reproduced the same line-25 error.
- Fixed conditional array expansion for Bash 3.2. System /bin/bash tests now pass
  for zero processes, an unrelated process, an already exited KeySwitch process,
  and rejection of an unrelated canonical bundle. Cleanup tests also pass.
- Rebuilt PKG; expanded the final package, compared both embedded scripts with
  their source and verified the extracted app's strict signature. App payload
  version remains 3.0.2 (29); no application code changes in this installer fix.
- Delivered KeySwitch-3.0.2-installer-fix.pkg; original 3.0.2 PKG also refreshed.
  Full privileged system installation has not been rerun here.


## 3.1.0: simple settings and menu-bar-only presentation

- Baseline inspected in the installed 3.0.2 application's actual window and AX tree.
  Retired gradient status banner, glossy icon, repeated summaries and oversized
  group heights. Native AppKit controls and six sections remain. DESIGN.md records
  the chosen Operate direction and native scope; web marketing checks are inapplicable.
- Actual 3.1.0 UI inspected in all six sections in both light and dark appearances.
  A first inspection identified low-contrast captions, excessive minimum heights,
  and Add/GitHub labels hidden by image-only buttons. Fixed together; a final round
  confirmed readable custom caption colors, content-driven heights and visible labels.
- Local example button tested through the UI: ghbdtn -> привет. The preview skips
  monitor startup and automatic network checks and uses a separate preference suite.
  This does not establish global input correction or real Accessibility authorization.
- Launch check passed: controller=true, window=true, windowVisible=true,
  menuBarOnly=true, dockToggle=true. This covers accessory/regular activation policy,
  hiding and reopening through the actual settings menu. UI checkbox also toggled
  both ways; presentation preference defaults and persistence tests pass.
- Universal build x86_64/arm64, language-engine tests and diff whitespace checks pass.
  Installer fixtures pass first install, zero/unrelated/exited/running instances,
  rejection of foreign canonical app, same-ID cleanup and preservation of symlinks
  and unrelated apps. Tests use /bin/bash 3.2 and a disposable subprocess, no live
  KeySwitch processes or real /Applications entries are affected.
- Full privileged install/upgrade, Intel execution, VoiceOver and global editor
  injection have not been rerun here. Existing CLT x86_64 compatibility-archive
  warning remains; universal executable is produced. Installer remains unsigned,
  app ad-hoc signed; no Developer ID/notarization or permission resets performed.

Final 3.1.0 PKG expanded: embedded pre/postinstall scripts match source, strict app
signature verifies, payload architectures are x86_64 + arm64 and LSUIElement=true.
Updated committed icon artwork and documentation icon to match the shipped mark.

## 3.1.1

See RELEASE_3.1.1.md for safeguards, regression/stress results, installer validation and the explicit limits of global-input, Intel and full OS installation testing.
