# Стадия 6 — Figma sync + Solar Icons + сборки

> Сводный отчёт по итогам Стадии 6 проекта collab_notes.
> Дата: 2026-05-28. Версия: `1.4.0+5`.

---

## 1. TL;DR

- Figma-переменные и ui-kit (page «From code», обновлены пользователем) перенесены в код **один-в-один**: имена цветов и типографических стилей совпадают с Figma; общие виджеты переписаны под Figma-варианты.
- Все Material- и Unicode-иконки заменены на **Solar Icons** (Bold для активных, Outline для inactive в Bottom Nav).
- Mobile auth-фон перенесён **пиксель-в-пиксель** по Figma-узлу `41:50` — добавлены 3 новых ассета, `AuthBackground` переписан под трёхслойную структуру.
- `flutter analyze` — **0 issues**, `flutter test` — **1/1 passed** (после фикса overflow в `AppButton`).
- Собраны release-артефакты Android APK и Windows EXE.

---

## 2. Артефакты сборки

| Платформа | Путь | Размер | Режим |
|---|---|---|---|
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` | 52.2 MB | release, debug keystore (Flutter default) |
| Windows EXE | `build/windows/x64/runner/Release/` (директория со всеми зависимостями) | — | release |

Android APK подписан стандартным debug-ключом Flutter — для публикации потребуется собственный keystore (вне scope Stage 6).

---

## 3. Figma sync — что синхронизировано

### 3.1 Цветовые переменные

Канонические имена Figma → `AppColors` (lib/shared/theme/app_colors.dart). Старые имена сохранены как `@Deprecated` алиасы — миграция без массовых сломов.

| Figma var | Hex | Dart |
|---|---|---|
| `bg-1` | `#161616` | `AppColors.bg1` |
| `bg-2` | `#1F1F1F` | `AppColors.bg2` |
| `bg-3` | `#393939` | `AppColors.bg3` |
| `white` | `#FFFFFF` | `AppColors.white` |
| `white-hover` | `#F0F0F0` | `AppColors.whiteHover` |
| `fg-container` | `#333333` | `AppColors.fgContainer` |
| `fg-soft` | `#A8A8A8` | `AppColors.fgSoft` |
| `negative` | `#FC502C` | `AppColors.negative` |

Deprecated алиасы: `darkBackground`, `darkText`, `darkTextMuted`, `darkPrimaryFill`, `darkPrimaryText`, `error` и др. — резолвятся на новые имена.

### 3.2 Типографические стили

| Figma style | Параметры | Dart |
|---|---|---|
| `h1` | Inter SemiBold 40 / line 1.0 / tracking **-5** | `AppTypography.h1` |
| `body` | Inter Regular 16 / line 1.3 | `AppTypography.body` |
| `body-s` | Inter SemiBold 16 / line 1.0 | `AppTypography.bodyS` |
| `extra-l` | Inter Regular 14 / line 1.0 | `AppTypography.extraL` |

Шрифт: Figma SF Pro → код Inter (metric-compatible, кросс-платформенная замена; SF Pro лицензионно ограничен на Windows/Android).

### 3.3 ui-kit компоненты

Figma `ui kit` (node `41:72`) → Flutter widgets:

| Figma component | Dart widget |
|---|---|
| `Button` (primary/secondary × default/hover/pressed) | `AppButton` |
| `Input` (filled/error) | `GlassInput` + `InputDecorationTheme` |
| `Chip` (s/m × default/hover/active) | **`AppChip` (новый)** |
| `Back` (default/variant2/pressed) | `GlassIconButton` + `SolarIconsBold.altArrowLeft` |
| `authButton` (default/hover/pressed) | `AppButton(variant: text)` |

`AppButton` использует `WidgetStateProperty.resolveWith` для интерактивных состояний; pressed-вариант увеличивает высоту до 54 (per Figma).

---

## 4. Solar Icons

Пакет: **`solar_icons: ^0.1.0`** — содержит `SolarIconsBold`, `SolarIconsOutline`, `SolarIconsBroken`. Bold Duotone в этом пакете отсутствует, используется **фолбэк на `SolarIconsBold`** (filled silhouette визуально близок к Duotone в dark theme).

Паттерн в Bottom Nav: **inactive = Outline, active = Bold**.

Топ-10 замен (применено через субагента `a35f3f6b69bf00ac6`, 9 файлов):

| Material | Solar Bold | Solar Outline |
|---|---|---|
| `Icons.notes` | `.notes` | `.notes` |
| `Icons.search` | `.magnifier` | `.magnifier` |
| `Icons.group` | `.usersGroupRounded` | `.usersGroupRounded` |
| `Icons.mail` | `.letter` | `.letter` |
| `Icons.settings` | `.settings` | `.settings` |
| `Icons.add` | `.addCircle` | — |
| `Icons.check` | `.checkCircle` | — |
| `Icons.refresh` | `.refresh` | — |
| `Icons.archive` | `.archive` | — |
| `Icons.arrow_back_ios_new` | `.altArrowLeft` | — |

Полная карта (всего 17 семейств) — в [STAGE6_LOG.md](STAGE6_LOG.md) §3.

---

## 5. Auth-экраны mobile — точный перенос

### 5.1 Новые ассеты (`assets/auth_v2/`)

| Файл | Назначение |
|---|---|
| `depth.svg` | Векторный референс глоу-формы (12-pointed star) |
| `image17.png` (736×981, RGBA) | Основной photo layer |
| `image18.png` (736×1225, RGB) | Overlay слой |

Подключены в `pubspec.yaml`, версия проекта обновлена до `1.4.0+5`.

### 5.2 Структура `AuthBackground` (соответствие Figma `41:50`)

1. **Solid bg** — `#161616` (`AppColors.bg1`).
2. **Blurred photo container** 1041×1599, по центру, bottom = -186:
   - `image17` (full cover).
   - `image18` (nested, w=100%, h=108.37%, top=-10.81%).
   - Linear gradient: transparent → black (0.63 → 0.75).
   - Всё внутри `ImageFiltered(blur 5.05)`.
3. **Depth glow** 937×937, position (-92, -29), rotation `-π/6` (-30°), `CustomPaint`: 12-pointed star + radial gradient + 60px Gaussian blur. Обёрнут в `RepaintBoundary`.

---

## 6. Тестирование

| Команда | Результат |
|---|---|
| `flutter analyze` | **0 issues** |
| `flutter test` | **1/1 passed** |
| `flutter build apk --release` | OK, 52.2 MB |
| `flutter build windows --release` | OK |

В ходе test-прогона воспроизведён overflow в `AppButton` (`Row` ломался при длинном label в text-варианте). Фикс: переход на единый `Text` с `Flexible`/fallback — теперь label корректно усекается.

---

## 7. Известные ограничения

- **Solar Bold Duotone недоступен** в `solar_icons 0.1.0`. Если потребуется именно Duotone — переключиться на альтернативный пакет или подключить SVG-иконки вручную.
- **Inter вместо SF Pro** — функционально equivalent, но рендер слегка отличается на Android (Roboto fallback до загрузки) и Windows.
- **Light theme не обновлена** под новые токены — dark остаётся единственным активным режимом. Light — отдельная итерация по запросу.
- **`mix-blend-screen`** из CSS-стека Figma не воспроизводится 1:1 в Flutter (`BlendMode.screen` через `Image.color*` ведёт себя иначе). Визуально близко, но не идентично.
- **Desktop-варианты** главного shell в Figma по-прежнему отсутствуют — наследие Stage 3-4, см. [STAGE34_DELIVERABLE.md](STAGE34_DELIVERABLE.md) §7.

---

## 8. Что дальше

- **Stage 5 — push-уведомления** (4 события согласно блоку E PRODUCT_INTERVIEW.md): приглашение в группу, новая заметка в группе, тик в чеклисте, изменение совместной заметки. Sequence-диаграммы — в существующий FigJam.
- **Периодическая синхронизация Figma ↔ код** — token-naming policy уже зафиксирована; при изменении переменной в Figma обновлять одноимённую константу в `AppColors`/`AppTypography`.
- **Опционально — Solar Bold Duotone** через альтернативный пакет, если визуально потребуется глубина duotone-стиля (текущий Bold subjectively достаточен).
- **Опционально — light theme** под новые токены (`bg1`/`white`/`fgContainer` инверсия), если появится сценарий дневного режима.

---

### Связанные документы

- [STAGE6_LOG.md](STAGE6_LOG.md) — детальный лог Стадии 6
- [STAGE34_DELIVERABLE.md](STAGE34_DELIVERABLE.md) — синтез Стадий 3-4
- [CHANGELOG.md](CHANGELOG.md) — все код-изменения
- [PRODUCT_INTERVIEW.md](PRODUCT_INTERVIEW.md) — продуктовый контекст
