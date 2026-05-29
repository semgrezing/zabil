# SF Pro fonts

Положи сюда файлы шрифта:

- `SFPro-Regular.otf` — weight 400
- `SFPro-Medium.otf` — weight 500
- `SFPro-Semibold.otf` — weight 600
- `SFPro-Bold.otf` — weight 700

## Где взять

Apple раздаёт SF Pro бесплатно, но через DMG (macOS):
https://developer.apple.com/fonts/

Шаги:
1. Скачать `SF-Pro.dmg`
2. Открыть на маке или распаковать через 7zip на Windows
3. Внутри: `SF-Pro-Display-Regular.otf` и пр. → переименовать (убрать `Display-`/`Text-`)
4. Положить сюда (`assets/fonts/`)

## После добавления файлов

Раскомментируй блок `fonts:` в `pubspec.yaml`:

```yaml
fonts:
  - family: SF Pro
    fonts:
      - asset: assets/fonts/SFPro-Regular.otf
      - asset: assets/fonts/SFPro-Medium.otf
        weight: 500
      - asset: assets/fonts/SFPro-Semibold.otf
        weight: 600
      - asset: assets/fonts/SFPro-Bold.otf
        weight: 700
```

Затем `flutter pub get && flutter clean && flutter build`.

## Лицензия

Apple SF Pro лицензировано **только** для использования в приложениях работающих на платформах Apple. Использование на Android/Windows формально нарушает условия. Для production-распространения замени на свободный аналог — Inter (https://rsms.me/inter/) визуально неотличим.

## Текущий fallback

Без этих файлов `fontFamily: 'SF Pro'` падает на системный шрифт:
- Android → Roboto
- Windows → Segoe UI
- iOS/macOS → нативный SF Pro

Никакого краша — UI просто чуть другой.
