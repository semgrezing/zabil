# Changelog

## [1.6.0+7] — 2026-05-29

### Added
- **Личное пространство заметок**: персональный контекст заметок (`Личное`) с полной приватностью.
- **Перенос заметок между контекстами**: `group -> group`, `group -> personal`, `personal -> group` из карточки и из редактора заметки.
- **Цветовые метки заметок**: 12 preset-цветов + режим "без метки" (карточка и редактор).
- **Режимы списка заметок**: Сетка/Список с сохранением последнего выбора.
- **Чат-медиа**: отправка изображений в чат (множественный выбор, режимы сжатия/без сжатия).
- **Связка note-chat/group-chat в UI**: маркер происхождения сообщения из заметки и переход из group-chat в note-chat.
- **Групповые настройки**: изменение названия, исключение участников (с ограничениями ролей), управление аватаркой группы.
- **Аватарки (пользователь + группа)**: fullscreen просмотр истории аватарок, удаление текущей и удаление из истории.
- **Кадрирование аватарки**: круг 1:1 перед загрузкой.

### Changed
- **Чаты > Группы**: в списке групп показывается последнее сообщение (`Автор: текст + время`) вместо количества участников.
- **Навигация**: функционал групп перенесен в хэдер вкладки `Чаты` (иконка `Группы` + manager sheet), отдельной tab `Группы` в navbar нет.
- **Notes header**: поиск перенесен в иконку с inline-строкой в хэдере.
- **Navbar**: нижняя навигация стала floating с сильным blur, 16px радиусом, 8px отступом, без тени.
- **Chips (Заметки)**: активный текст стал черным, checkmark у выбранной chip отсутствует.

### Backend
- Prisma-схема расширена:
  - `Group`: `isPersonal`, `avatarUrl`.
  - `Note`: `colorLabel`.
  - `GroupChatMessage` / `PersonalMessage`: поля медиа (`imageUrl`, `imageMimeType`, `imageSize`, `imageCompressed`).
  - новая модель `AvatarHistory`.
- Новые/расширенные API:
  - `PATCH /notes/:id/move`.
  - `GET /groups/personal-context`.
  - `PATCH /groups/:id`, `DELETE /groups/:id/members/:userId`.
  - `POST/DELETE /groups/:id/avatar`, `GET/DELETE /groups/:id/avatar/history/*`.
  - `DELETE /users/me/avatar`, `GET/DELETE /users/me/avatar/history/*`.
  - `POST /uploads/chat-image?compressed=true|false`.
- Push-эвенты расширены: добавлены события изменения заметки/чеклиста.

### Fixed
- **Push reliability**: регистрация device token теперь вызывается и после восстановленной сессии.
- **Update module build**: восстановлена зависимость `open_filex` для установки APK/EXE из экрана обновлений.

### Notes
- Для backend-изменений необходима миграция БД (новые поля/модели Prisma) перед выкладкой.

## [1.5.0+6] — 2026-05-29

### Added
- **Профиль**: редактирование никнейма и аватара, новые эндпоинты `/users/me` и `/users/me/avatar`.
- **Поля пользователя**: `displayName` и `avatarUrl` в ответах авторизации/поиска/чатов/приглашений/групп, чтобы UI показывал отображаемое имя и аватар.

### Notes
- **Миграция БД**: примените Prisma миграцию для новых полей `displayName` и `avatarUrl` в `User`.

### Fixed
- **Приглашения**: accept/decline стали идемпотентными — уже обработанные инвайты возвращают успех, UI показывает корректный статус.
- **Чаты**: поиск пользователя теперь использует `username` и корректно парсит ответ; добавлена поясняющая подсказка в поиске; парсинг дат сообщений стал устойчивее.
- **Архив**: фильтр теперь всегда отправляет `archived=true/false`, архивные заметки не остаются в обычном списке; добавлен тост об успешной архивации/разархивации.
- **Навигация заметок**: переход из «Заметки группы» теперь синхронизирует `groupId` в фильтре.
- **Группы**: удаление группы теперь очищает связанные данные в транзакции (membership, чаты, заметки, вложения), чтобы избежать ошибок FK.
- **UI**: активные `AppChip` больше не теряют цвет иконки; в карточках заметок появились превью-миниатюры изображений (с «скелетом» второй картинки).
- **Toast-спам**: очередь SnackBar очищается при повторной проверке обновлений.

## [1.4.0+5] — 2026-05-28 (Stage 6 — Figma sync + Solar Icons + сборки)

### Added
- **`solar_icons ^0.1.0`** — пакет Solar Icons (Bold / Outline / Broken варианты).
- **`flutter_svg ^2.0.10+1`** — для работы с SVG-референсом auth-фона.
- **`shared/widgets/app_chip.dart`** (`AppChip`) — новый виджет, соответствует Figma `Chip` (size s/m × default/hover/active).
- **`assets/auth_v2/`** — новая директория ассетов auth-фона, скачаны из Figma:
  - `depth.svg` — векторный референс глоу-формы.
  - `image17.png` (736×981, RGBA) — основной photo layer.
  - `image18.png` (736×1225, RGB) — overlay.
- **Figma-token-имена в `AppColors`**: `bg1` (#161616), `bg2` (#1F1F1F), `bg3` (#393939), `white`, `whiteHover` (#F0F0F0), `fgContainer` (#333333), `fgSoft` (#A8A8A8), `negative` (#FC502C). Источник истины — Figma-переменные с одноимёнными ключами.
- **Figma-token-имена в `AppTypography`**: `h1`, `body`, `bodyS`, `extraL` — точное соответствие стилям page «From code».
- **Stage 6 docs**: `STAGE6_LOG.md` (детальный лог) и `STAGE6_DELIVERABLE.md` (сводный отчёт).

### Changed
- **`AuthBackground`** полностью переписан под Figma-узел `41:50`: трёхслойная структура (solid `#161616` + blurred photo container 1041×1599 с `image17` + nested `image18` + linear gradient внутри `ImageFiltered(blur 5.05)` + Depth glow 937×937 с rotation `-π/6` через `CustomPaint`). Заменяет прежнюю реализацию на базе `bg_chandelier.webp` / `bg_papers.webp`.
- **`AppButton`** переписан под Figma-варианты: `primary` (white bg + `fgContainer` text, hover → `whiteHover`, pressed → высота 54), `secondary` (`bg3` bg + white text, hover → `bg2`, pressed → высота 54), `text` (ghost для inline-link, использовалось в auth). Интерактивные состояния через `WidgetStateProperty.resolveWith`.
- **Все Material-иконки → Solar**: `Icons.notes/search/group/mail/settings` → `SolarIconsBold.*` / `SolarIconsOutline.*` для Bottom Nav (паттерн inactive=Outline, active=Bold); `Icons.add/check/refresh/archive/image/logout/dark_mode/download/info/chevron_right/arrow_back_ios_new/visibility_*` → соответствующие `SolarIconsBold.*`. Применено в 9 файлах через субагента. Bold Duotone недоступен в пакете — фолбэк на Bold.
- **`AppTypography.h1`** letter-spacing **-2 → -5** (per Figma h1-style).
- `app_theme.dart` — точечные правки: `colorScheme.error` → `AppColors.negative`, sheet/dialog background → `AppColors.bg2`.
- Auth-экраны `login_screen.dart` / `register_screen.dart` перевыстроены под новый `AppButton` + Solar back-кнопку.

### Fixed
- **`AppButton` Row overflow** при длинном label в text-варианте: ломался `Row` с child-овой `Text` без `Flexible`. Исправлено упрощением layout (единый `Text` с фолбэком) — `flutter test` снова зелёный.

### Deprecated
- `AppColors.darkBackground` → `AppColors.bg1`.
- `AppColors.darkText` / `darkTextSecondary` / `darkTextMuted` → `AppColors.white` / `whiteHover` / `fgSoft`.
- `AppColors.darkPrimaryFill` → `AppColors.white`.
- `AppColors.darkPrimaryText` → `AppColors.fgContainer`.
- `AppColors.darkSurfaceGlass` → использовать `AppColors.white.withValues(alpha: 0.15)`.
- `AppColors.error` / `lightError` → `AppColors.negative`.

Все deprecated-алиасы сохранены и резолвятся на новые имена — массовых сломов в коде нет, миграция идёт постепенно.

### Результат
- `flutter analyze`: **0 issues**.
- `flutter test`: **1/1 passed**.
- `flutter build apk --release`: OK, `build/app/outputs/flutter-apk/app-release.apk` (52.2 MB).
- `flutter build windows --release`: OK, `build/windows/x64/runner/Release/`.

### Известные ограничения
- Solar Bold Duotone в пакете отсутствует — использован Bold.
- Inter вместо Figma SF Pro (metric-compatible замена, лицензионные ограничения SF Pro).
- Light theme не обновлена под новые токены — dark остаётся единственным активным режимом.
- `mix-blend-screen` из CSS не воспроизведён в Flutter 1:1.

---

## [1.3.0] — 2026-05-27 (Stage 2 — единая дизайн-система)

### Дизайн-токены (новая централизованная структура)
- **`shared/theme/app_colors.dart`** полностью переписан. Источник истины — auth-экраны из Figma 12-633.
  - Dark: `darkBackground` #161616, `darkSurfaceGlass` (white 15%), `darkText` #FCFFFF, `darkTextSecondary` (white 70%), `darkTextMuted` #A8A8A8, `darkPrimaryFill` #FFFFFF, `darkPrimaryText` #333333.
  - Light: структурная инверсия (`lightBackground` #FAFAF9, `lightPrimaryFill` #161616, и т.д.) — те же радиусы, типографика, размеры, но «свет».
- **`shared/theme/app_dimensions.dart`** (новый): `AppRadii` (xs 8, sm 12, md 16, lg 20, pill 999), `AppSpacing` (4-8-12-16-24-32-48), `AppSizes` (buttonHeight 56, formMaxWidth 361).
- **`shared/theme/app_typography.dart`** (новый): `display` (40/-2/600), `titleLarge` (22/-0.5/600), `titleMedium` (17/600), `bodyLarge` (16/400), `labelLarge` (15/600) и др.

### Тема
- **`shared/theme/app_theme.dart`** полностью переписан. Использует Material 3 surface-палитру (`surface`, `surfaceContainerHighest` вместо устаревших `background`, `surfaceVariant`). Палитра вынесена в `_Palette`-абстракцию с `_DarkPalette` / `_LightPalette` — DRY между dark/light.
- Покрыты все основные темы виджетов: `inputDecorationTheme`, `elevatedButtonTheme`, `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`, `floatingActionButtonTheme`, `cardTheme`, `bottomNavigationBarTheme`, `bottomSheetTheme`, `chipTheme`, `progressIndicatorTheme`, `snackBarTheme`, `dialogTheme`, `listTileTheme`.
- Primary CTA — белая кнопка на тёмном (`darkPrimaryFill` #FFFFFF + `darkPrimaryText` #333333) — единый язык с auth.

### Новые общие виджеты
- **`shared/widgets/glass_input.dart`**: `GlassInput` (полупрозрачное поле ввода, аналог `_AuthInput`, переиспользуется во всём приложении) + `GlassIconButton` (квадратная иконка-кнопка с glass-фоном, как back-кнопка в register).
- **`shared/widgets/group_avatar.dart`**: `GroupAvatar` — унифицированный кружок с первой буквой названия.
- **`shared/widgets/app_button.dart`** полностью переписан: enum `AppButtonVariant` (primary/secondary/text), `expanded`-флаг, корректное использование темы.
- **`shared/widgets/app_loader.dart`**: `AppLoader` упрощён, добавлены `AppEmptyState` (с `hint`) и `AppErrorState` (с `onRetry`).

### Миграция auth-экранов
- **`login_screen.dart`** и **`register_screen.dart`** теперь обёрнуты в `Theme(data: AppTheme.dark, ...)` — auth всегда кинематографичный тёмный, независимо от системной темы или настройки пользователя.
- Удалены локальные `_k*` константы (`_kBg`, `_kInputFill`, ...) — всё через `AppColors.dark*`, `AppTypography.*`, `AppSpacing.*`, `AppRadii.*`, `AppSizes.*`.
- Удалён локальный `_AuthInput` (заменён на shared `GlassInput`).
- Back-кнопка в register заменена на `GlassIconButton`.

### Фиксы хардкодов
- **`invitations_screen.dart`**: `Colors.grey` → `AppEmptyState`. Empty-state теперь имеет иконку, заголовок и подсказку. Карточки приглашений используют `theme.textTheme.titleMedium`/`bodySmall`.
- **`settings_screen.dart`**: 
  - `Colors.red` на кнопке выхода → `colorScheme.error`.
  - Inline `TextStyle(fontWeight: w600)` для секции «Тема» → `_SectionHeader` widget с `theme.textTheme.labelMedium`.
  - **Удалён дублирующий UI групп** (`_showCreateGroupDialog`, `_GroupsManagedSection`) — теперь это живёт в новой вкладке «Группы» из Стадии 1. Удалён хардкодный URL `/api/v1/invitations` и пятиэтажный `AlertDialog` с DioException обработкой — всё уже есть в `InvitationsService`.
  - User avatar теперь использует `theme.textTheme.titleMedium` и `colorScheme.surfaceContainerHighest`.
- **`notes_list_screen.dart`**: 
  - Empty-state inline `TextStyle.withOpacity(0.5)` → `theme.textTheme.bodyMedium`.
  - Bottom-sheet «Выберите группу»: inline `TextStyle(fontWeight: w600)` → `theme.textTheme.titleMedium`, добавлен `showDragHandle: true`.
- **`search_screen.dart`**: тот же фикс для bottom-sheet группы.
- **`group_detail_screen.dart`**: убран `TextStyle(fontSize: 12)` в `_roleChip` — теперь использует `chipTheme.labelStyle` из темы.
- **`groups_list_screen.dart`**: `BorderRadius.circular(12)` → `AppRadii.md`, кастомный avatar заменён на `GroupAvatar`, кастомные `_EmptyView`/`_ErrorView` заменены на `AppEmptyState`/`AppErrorState`, padding через `AppSpacing.*`.

### Deprecations убраны
- `withOpacity(...)` → `withValues(alpha: ...)` в 4 местах (notes_list, note_editor, note_card).
- `colorScheme.surfaceVariant` → `surfaceContainerHighest` в `note_editor_screen` (Image errorBuilder).
- `onPopInvoked` → `onPopInvokedWithResult` в `note_editor_screen` (PopScope).

### Минорные фиксы
- `auth_models.dart`: `AuthState.loggedIn(UserModel user) : user = user` → `AuthState.loggedIn(this.user)` (initializing formal).
- `note_model.dart`: `${_baseUrl}/...` → `$_baseUrl/...` (unnecessary braces).
- `settings_screen.dart`: `_SectionHeader(...)` → `const _SectionHeader(...)`.

### Результат
- **`flutter analyze`**: 20 issues → **0 issues**. Полностью чистый код.
- Все экраны автоматически наследуют новый стиль через `Theme.of(context)`.
- Auth-экраны больше не «выделяются» — они визуальный камертон, остальное к ним подтянуто.

### Известные ограничения для Стадии 3+
- Стиль главных экранов (notes list / note editor / search) автоматически перешёл на тёмный кинематографичный через тему. Тонкая настройка композиции (хедеры, заголовки секций, расстановка иерархии) — задача Стадии 3 (UX flow + проработка mockup в Figma).
- Light-тема — структурная инверсия, не отдельный дизайн-язык. Если потребуется отдельная визуальная концепция для light — задача Стадии 4.

---

## [1.2.0] — 2026-05-27 (Stage 1)

### Исправления
- **Персистентность сессии**: При запуске приложение разлогинивало пользователя при любой ошибке восстановления сессии, включая временную потерю сети. Теперь `restoreSession()` различает сетевые ошибки от невалидного токена — при отсутствии сети сохраняет залогиненное состояние с кэшированными данными из JWT, чистит токены только если сервер реально отверг refresh.
- **AuthInterceptor**: По той же причине interceptor в `api_client.dart` при 401 + сбоe refresh-запроса очищал токены даже при сетевой ошибке. Теперь токены чистятся только при подтверждённом отказе сервера. Helper `isNetworkError` вынесен в `core/api/network_error.dart`.
- **Создание групп**: В приложении полностью отсутствовал UI для создания группы — был только `GroupDetailScreen` без ввода точки в роутер. Добавлен новый экран `GroupsListScreen` с FAB и модалкой `CreateGroupSheet`.
- **Приглашения в группу**: В `GroupDetailScreen` не было кнопки приглашения участника, хотя `InvitationsService.sendInvitation` уже существовал. Добавлено действие в AppBar и модалка `InviteMemberSheet`.

### Улучшения производительности
- **Лаги auth-экранов**: Тяжёлый стек эффектов (`ImageFiltered` blur 5px + два `Positioned` с overscale 2.65×2.04 + `CustomPaint` с blur 60px) рендерился без изоляции, перерисовываясь при любом изменении формы и появлении клавиатуры.
  - `AuthBackground` обёрнут в `RepaintBoundary` — GPU теперь кэширует blur-композицию между фреймами.
  - `_DepthGlowPainter` также обёрнут в `RepaintBoundary`.
  - Добавлен `cacheWidth` к `Image.asset` (вычисляется по DPR + ширине экрана, clamp 400–2000) — снижает память декодирования.
  - `filterQuality: FilterQuality.low` для фоновых изображений (под 5px blur детали не важны).

### Новые экраны
- **`GroupsListScreen`** (`/groups`): список групп с FAB «Новая группа», `RefreshIndicator`, пустое и ошибочное состояния, плюрализация количества участников.
- **`CreateGroupSheet`**: модальный bottom-sheet с одним полем «Название», валидация ≥ 2 символов, лимит 60.
- **`InviteMemberSheet`**: модальный bottom-sheet для приглашения, распознаёт «не найден» / «уже в группе» / общую ошибку.

### Навигация
- **Нижняя навигация**: добавлена вкладка «Группы» (иконка `Icons.group_outlined`). 5 вкладок → выставлен `BottomNavigationBarType.fixed`, чтобы все лейблы оставались видимыми.
- **Роут `/groups`**: добавлен внутри `ShellRoute` (со shell). `/groups/:id` остался снаружи (full-screen detail без bottom nav).
- **GroupDetailScreen**: AppBar action «Пригласить участника» (`Icons.person_add_outlined`), FAB остался «Заметки группы».

### Известные ограничения (для Stage 2+)
- `?groupId=` query в `context.go('/notes?groupId=...')` из GroupDetailScreen не парсится `NotesListScreen` — фильтр живёт в `notesFilterProvider`, не в URL. Pre-existing, не регрессия. Чинится либо парсингом query, либо записью в провайдер перед навигацией.
- Дизайн новых экранов групп использует существующую `AppTheme` (Notion-style), Stage 2 переведёт всё на тёмный кинематографичный язык auth-экранов.
- Инвайты end-to-end требуют ручной верификации (Fix 4) — код полностью на месте, но прошлая жалоба «приглашённый не мог принять/отклонить» возможно была серверным багом.

---

## [1.1.0] — 2026-05-27

### Исправления
- **Авторизация**: Исправлен URL API — значение по умолчанию было заглушкой `api.yourdomain.com` вместо реального `api.achiemvemer.ru/api/v1`. Вход и регистрация теперь работают.
- **Сеть (Android)**: Добавлено разрешение `INTERNET` в `AndroidManifest.xml` — в release-сборке приложение не имело доступа к сети.
- **Ошибка соединения**: Исправлено определение ошибки подключения в `_parseError` — проверка теперь регистронезависимая.
- **Архив (LateInitializationError)**: Исправлена ошибка `LateInitializationError: Field '_service' has already been initialized` при переключении между Заметками и Архивом. Причина: `late final NotesService _service` переинициализировался при каждом вызове `build()` в `NotesNotifier`. Заменён на getter `NotesService get _service => ref.read(notesServiceProvider)`.
- **Версия приложения**: Обновлена с `1.0.0+1` до `1.1.0+2` — теперь проверка обновлений корректно сообщает, что установлена актуальная версия.

### Улучшения
- **Фон экранов авторизации**: Переработан виджет `AuthBackground` по макету Figma (node 12:633):
  - Изображение `bg_chandelier` теперь позиционируется корректно (Figma CSS: `left: -82.44%, top: -86.12%, width: 264.89%, height: 203.39%`) вместо `BoxFit.cover`.
  - Градиент перемещён внутрь слоя `ImageFiltered` (как в Figma).
  - Размеры рассчитываются через `LayoutBuilder` (используются реальные `w` и `h`), а не `MediaQuery.size`.
- **Адаптивная высота**: Экраны входа и регистрации теперь используют `SingleChildScrollView(reverse: true)` + `Align(bottomCenter)` вместо `LayoutBuilder + ConstrainedBox`. Форма всегда прижата к нижней части экрана без лишнего скролла на любом устройстве.
- **Оптимизация изображений**: Фоновые PNG сконвертированы в WebP (quality 80):
  - `bg_papers.webp`: 731 KB → 48 KB (−93%)
  - `bg_chandelier.webp`: 423 KB → 32 KB (−93%)
  - Удалён неиспользуемый SVG-файл
  - Итого: экономия ~1.07 MB из ресурсов приложения
- **Зависимости**: Обновлены `custom_lint` (`^0.6.7` → `^0.7.6`) и `riverpod_lint` (`^2.3.5` → `^2.6.5`) для совместимости с текущим Dart SDK.

---

## [1.0.0] — 2026-05-26

### Начальный релиз
- MVP: заметки, группы, архив, инвайты
- Экраны авторизации и регистрации с фоном из Figma
- Настройки: тема, управление группами, проверка обновлений
- Backend: Node.js + PostgreSQL, развёрнут на `achiemvemer.ru`
