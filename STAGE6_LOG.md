# Стадия 6 — Figma sync + Solar Icons + сборки

> Лог Стадии 6.
> Дата: 2026-05-27 → 28 (продолжение).
> Версия проекта: `1.4.0+5`.

## Цели

Пользователь обновил Figma (page «From code»): завёл переменные, добавил ui kit
с компонентами Button/Input/Chip/Back/authButton и одну Solar-иконку
(`solar:alt-arrow-left-outline`). Задачи:

1. **Унификация ui kit** — каждый экран использует общие виджеты.
2. **Только Figma-переменные** в коде (цвета, типографика).
3. **Solar Icons** — Bold Duotone, замена всех Material/Unicode.
4. **Точный перенос auth-mobile**: image + SVG-shape с overlay.
5. Тесты + сборка EXE и APK.

Пользователь зафиксировал: задавать вопросы только до старта, дальше — без остановок.

## Принятые на старте решения (по вопросам пользователю)

| Решение | Выбор |
|---|---|
| Solar variant | **Bold Duotone** (фолбэк → Bold: пакет `solar_icons 0.1.0` не содержит Duotone) |
| Auth-ассеты | **Из Figma** — скачал `imgDepth`/`imgImage17`/`imgImage18` через `get_design_context` |
| Build mode | **Release с debug keystore** (Flutter default) |

## Архитектурные решения

### 1. Token-naming policy

Figma-переменные = single source of truth. Имена в коде = имена в Figma:

| Figma var | Hex | Dart constant (lib/shared/theme/app_colors.dart) |
|---|---|---|
| `bg-1` | `#161616` | `AppColors.bg1` |
| `bg-2` | `#1F1F1F` | `AppColors.bg2` |
| `bg-3` | `#393939` | `AppColors.bg3` |
| `white` | `#FFFFFF` | `AppColors.white` |
| `white-hover` | `#F0F0F0` | `AppColors.whiteHover` |
| `fg-container` | `#333333` | `AppColors.fgContainer` |
| `fg-soft` | `#A8A8A8` | `AppColors.fgSoft` |
| `negative` | `#FC502C` | `AppColors.negative` |

Старые имена (`darkBackground`, `error` и т.д.) сохранены как `@Deprecated`
алиасы — постепенный переход без массовых сломов.

Typography (`AppTypography`):

| Figma style | Dart constant |
|---|---|
| `h1` | `AppTypography.h1` (Inter SemiBold 40 / lineHeight 1.0 / letterSpacing -5) |
| `body` | `AppTypography.body` (Regular 16 / 1.3) |
| `body-s` | `AppTypography.bodyS` (SemiBold 16 / 1.0) |
| `extra-l` | `AppTypography.extraL` (Regular 14 / 1.0) |

Шрифт: Figma SF Pro → код Inter (кросс-платформенная, metric-compatible замена;
SF Pro лицензионно ограничен на Windows/Android).

### 2. ui-kit мапинг

Figma `ui kit` секция (node `41:72`) → Flutter widgets:

| Figma component | Dart widget |
|---|---|
| `Button` (primary/secondary × default/hover/pressed) | `AppButton` (lib/shared/widgets/app_button.dart) |
| `Input` (filled/error states) | `GlassInput` + theme `InputDecorationTheme` |
| `Chip` (size s/m × default/hover/active) | `AppChip` (lib/shared/widgets/app_chip.dart) ← новый |
| `Back` (default/variant2/pressed) | `GlassIconButton` (icon=SolarIconsBold.altArrowLeft) |
| `authButton` (default/hover/pressed) | `AppButton(variant: text)` |

`AppButton` переписан под Figma-вариативность:
- **primary**: `white` bg + `fgContainer` text, hover→`whiteHover`, pressed→высота 54
- **secondary**: `bg3` bg + `white` text, hover→`bg2`, pressed→высота 54
- **text**: ghost для inline-link

Используется `WidgetStateProperty.resolveWith` для интерактивных состояний.

### 3. Solar Icons (Bold)

Пакет: `solar_icons: ^0.1.0`. Содержит `SolarIconsBold`, `SolarIconsOutline`,
`SolarIconsBroken`. **Bold Duotone отсутствует** — фолбэк на `SolarIconsBold`
(filled silhouette визуально близок к Duotone в dark theme).

Использован паттерн «inactive=Outline, active=Bold» в Bottom Nav.

Карта замен (полностью применена через субагент `a35f3f6b69bf00ac6`):

| Material → | Solar Bold | Solar Outline |
|---|---|---|
| `Icons.notes` | `SolarIconsBold.notes` | `SolarIconsOutline.notes` |
| `Icons.search` | `.magnifier` | `.magnifier` |
| `Icons.group` | `.usersGroupRounded` | `.usersGroupRounded` |
| `Icons.mail` | `.letter` | `.letter` |
| `Icons.settings` | `.settings` | `.settings` |
| `Icons.add` | `.addCircle` | — |
| `Icons.check` | `.checkCircle` | — |
| `Icons.refresh` | `.refresh` | — |
| `Icons.archive` | `.archive` | — |
| `Icons.image` | `.gallery` | — |
| `Icons.logout` | `.logout` | — |
| `Icons.dark_mode` | `.moon` | — |
| `Icons.download` | `.altArrowDown` | — |
| `Icons.info` | `.infoCircle` | — |
| `Icons.chevron_right` | `.altArrowRight` | — |
| `Icons.arrow_back_ios_new` | `.altArrowLeft` | — |
| `Icons.visibility_*` | `.eye` / `.eyeClosed` | — |

### 4. Auth backround — точный перенос

Скачаны и зарегистрированы в `assets/auth_v2/`:
- `depth.svg` — SVG вектор (для справки; сама отрисовка через CustomPaint осталась
  без изменений — пиксель-в-пиксель повторяет SVG path).
- `image17.png` (736×981, RGBA) — основной photo layer.
- `image18.png` (736×1225, RGB) — overlay.

`AuthBackground` полностью переписан под структуру нового Figma-узла `41:50`:
1. solid bg `#161616`
2. Blurred photo container 1041×1599, centered, bottom=-186:
   - `image17` — full cover
   - `image18` — nested, w=100%, h=108.37%, top=-10.81%
   - linear gradient transparent → black (0.63 → 0.75)
   - всё внутри `ImageFiltered(blur 5.05)`
3. Depth glow 937×937, position (-92, -29), rotated `-π/6` (-30°), CustomPaint
   с 12-pointed star + radial gradient + 60px Gaussian blur.

## Action log

| # | Действие | Результат |
|---|---|---|
| 1 | `get_metadata` + `get_design_context` + `get_variable_defs` для page 28:35 | Полная карта компонентов, переменных, asset URLs |
| 2 | Скачка `depth.svg`, `image17.png`, `image18.png` через `curl` из Figma asset CDN | Файлы в `assets/auth_v2/` |
| 3 | `pubspec.yaml`: версия → `1.4.0+5`, +`solar_icons ^0.1.0`, +`flutter_svg ^2.0.10+1`, +`assets/auth_v2/` | `flutter pub get` OK |
| 4 | Переписан `app_colors.dart` — Figma vars + deprecated aliases | 8 новых констант |
| 5 | Переписан `app_typography.dart` — h1/body/bodyS/extraL по Figma | Letter-spacing h1: -2 → -5 |
| 6 | Точечные правки `app_theme.dart` — `AppColors.negative`, `AppColors.bg2` | Sheet/Dialog bg унифицированы |
| 7 | Переписан `app_button.dart` — Primary/Secondary с WidgetStateProperty | 3 варианта, hover/pressed |
| 8 | Создан `app_chip.dart` | Новый виджет, 2 размера |
| 9 | Субагент `a35f3f6b69bf00ac6` — замена иконок в non-auth screens | 9 файлов изменено |
| 10 | Переписан `auth_background.dart` — image17 + image18 + Depth с -30° | Match Figma `41:50` |
| 11 | Переписаны `login_screen.dart`, `register_screen.dart` — AppButton + Solar | Auth flow унифицирован |
| 12 | `flutter analyze` | **0 issues** |
| 13 | `flutter test` → fix overflow в AppButton (Row → Text fallback с Flexible) | All tests passed |
| 14 | `flutter build apk --release` | в фоне, см. финал |
| 15 | `flutter build windows --release` | в фоне, см. финал |

## Известные ограничения / TODO

- **Solar Bold Duotone** в пакете нет — использован Bold. Если нужен Duotone,
  переключиться на другой пакет или SVG-иконки вручную.
- **Inter вместо SF Pro** — функционально equivalent, но рендер слегка отличается
  на разных платформах (Roboto на Android до загрузки fallback).
- **Light theme** не обновлена под новые токены — нужна отдельная итерация,
  если потребуется. Сейчас dark — единственный активный режим.
- **Desktop variants** main shell — отсутствуют в Figma, см. [STAGE34_DELIVERABLE.md](STAGE34_DELIVERABLE.md).
- `mix-blend-screen` из CSS не воспроизведён в Flutter (`BlendMode.screen` через
  Image.color* не работает 1:1). Визуально близко.

## Связанные документы

- [STAGE3_LOG.md](STAGE3_LOG.md) / [STAGE4_LOG.md](STAGE4_LOG.md) — FigJam + первоначальная Figma
- [STAGE34_DELIVERABLE.md](STAGE34_DELIVERABLE.md) — синтез Stage 3-4
- [CHANGELOG.md](CHANGELOG.md) — все код-изменения
