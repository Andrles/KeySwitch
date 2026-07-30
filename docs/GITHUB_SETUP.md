# Публикация KeySwitch на GitHub

## Рекомендуемые параметры репозитория

**Название:** `KeySwitch`

**Описание:**

> Native offline Russian ↔ English keyboard layout switcher for macOS

**Topics:**

`macos`, `swift`, `appkit`, `keyboard-layout`, `russian`, `english`, `menu-bar`, `offline`, `productivity`

## Первый push

```sh
git init
git add .
git commit -m "Initial public release"
git branch -M main
git remote add origin <URL-РЕПОЗИТОРИЯ>
git push -u origin main
```

## Первый релиз

1. Загрузите исходный код в ветку `main`.
2. Создайте тег:

```sh
git tag v2.0.2
git push origin v2.0.2
```

3. Workflow `Draft release` соберёт приложение и создаст черновик релиза.
4. Проверьте вложения и текст, затем опубликуйте релиз вручную.

Перед широким распространением подпишите приложение сертификатом Apple Developer ID и выполните notarization.

## Настройки GitHub

- Включите **Issues** и **Discussions**.
- Включите **Private vulnerability reporting** в разделе Security.
- Защитите ветку `main`: pull request и успешный workflow `Build`.
- Добавьте социальное изображение на основе `docs/assets/banner.svg`.

