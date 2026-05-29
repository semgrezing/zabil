# Стадии 3 и 4 — дизайн-результат collab_notes

> Сводный отчёт по итогам Стадий 3 (UX flow в FigJam) и 4 (отрисовка экранов в Figma Design).
> Дата: 2026-05-27

---

## 1. Что сделано (TL;DR)

- **FigJam** с тремя диаграммами: Main UX Flow, Auth Session State и Data Model ER. Это карта продукта одним взглядом.
- **Figma Design** — 15 frame-ов в page «From code» (node 28:35): auth (mobile + desktop), 7 экранов главного shell mobile, 4 модалки/диалога.
- Все frame-ы построены на дизайн-токенах из кода (Stage 2, `lib/shared/theme/`) — единый кинематографичный тёмный язык, тот же, что в auth.
- Пройдена утверждённая последовательность пункты 3 и 4 из [PRODUCT_INTERVIEW.md](PRODUCT_INTERVIEW.md) (блок E).

---

## 2. Ссылки на дизайн-артефакты

| Артефакт | Ссылка |
|---|---|
| FigJam — UX flow и диаграммы | https://www.figma.com/board/Ww1o9PNT9Bx8J0cR0hLlFE |
| Figma Design — экраны | https://www.figma.com/design/FG0OQ2LcuJob7QCMbtAYVX/Untitled?node-id=28-35 |
| Auth-камертон (источник стиля) | https://www.figma.com/design/FG0OQ2LcuJob7QCMbtAYVX/Untitled?node-id=12-633 |

FigJam создан в команде SVCH (личная команда владельца). Figma Design — существующий файл проекта, новые экраны добавлены в page «From code».

---

## 3. FigJam: что внутри

Три диаграммы в одном файле — продуктовое, состояние и данные.

### 3.1 Main UX Flow
Полная карта переходов между экранами после Стадий 1-2. Точка входа (Launch → проверка сессии → auth или main shell), auth-flow, 5 вкладок bottom nav (Notes, Search, Groups, Invitations, Settings), все sheet-ы и диалоги. Цветовые группы: sheets (тёмно-серый), dialogs (тёмный), auth (чёрный) — визуально читается тип навигации.

**Зачем**: единый источник правды по навигации, основа для Stage 4 (какие экраны рисовать) и Stage 5 (куда вешать push).

### 3.2 Auth Session State
State-машина авторизации с четырьмя состояниями (`Unauthenticated`, `CheckingSession`, `Authenticated`, `RefreshingToken`). Документирует ключевой фикс Стадии 1 — переход `RefreshingToken → Authenticated` при **сетевой** ошибке (не разлогинивать зря) против `RefreshingToken → Unauthenticated` только при 401 от сервера.

**Зачем**: эта логика — критическая для UX (раздражение №1 владельца было «сессия не сохраняется»). Без диаграммы регрессия легко проскользнёт.

### 3.3 Data Model (ER)
ER-диаграмма базы: `USER ↔ GROUP ↔ NOTE ↔ INVITATION ↔ CHECKLIST_ITEM ↔ NOTE_IMAGE`. Показывает связи и ключевые поля (например, `members[].role` = 'owner' / 'admin' / 'member').

**Зачем**: подсказка для дизайна — какие данные доступны для отображения на каждом экране.

---

## 4. Figma Design: что внутри

15 frame-ов, выложены на page «From code» в четыре ряда. Mobile frames — 393×852 (iPhone-class), desktop — 1440×900, модалки — 393×600.

| Frame | Координаты (x, y) | Размер | Краткое описание |
|---|---|---|---|
| Login Mobile | 0, 0 | 393×852 | Глоу-эллипс на чёрном, форма прижата к низу, инпуты «Никнейм»/«Пароль», белая CTA «войти» |
| Register Mobile | 453, 0 | 393×852 | Back-кнопка 56×56 (glass), три инпута, CTA «зарегистрироваться» |
| Login Desktop | 0, 900 | 1440×900 | Субтильный глоу за центром, форма 361px центрирована |
| Register Desktop | 1500, 900 | 1440×900 | То же + back-кнопка top-left |
| NotesList | 0, 1900 | 393×852 | AppBar «Заметки» + archive, search, чипы контекста (Личное + группы), 3 карточки, FAB, bottom nav |
| NoteEditor | 453, 1900 | 393×852 | AppBar «Редактирование*» + back/save, заголовок, контент, чеклист (2 done / 2 pending), «Прикрепить изображение» |
| Search | 906, 1900 | 393×852 | Search input с «гречка», чипы-фильтр по группам, результаты с подсветкой группы |
| GroupsList | 1359, 1900 | 393×852 | 3 карточки групп (аватар + название + count), FAB «+ Новая группа» |
| GroupDetail | 1812, 1900 | 393×852 | AppBar «Семья» + person_add, список участников с ролями, FAB «Заметки группы». Full-screen, без bottom nav |
| Invitations | 2265, 1900 | 393×852 | 2 карточки приглашений, кнопки «Отклонить» (outlined) / «Принять» (primary) |
| Settings | 2718, 1900 | 393×852 | Профиль `@semva`, секция «Тема», обновления + версия, «Выйти» (красным) |
| CreateGroupSheet | 0, 2900 | 393×600 | Bottom sheet, drag handle, input «Например: Семья», CTA «Создать» |
| InviteMemberSheet | 453, 2900 | 393×600 | Bottom sheet, input «например: alex», CTA «Отправить приглашение» |
| PickGroupSheet | 906, 2900 | 393×600 | Bottom sheet, список 4 групп (Личное + 3 группы) с аватарами |
| ConfirmLogoutDialog | 1359, 2900 | 393×600 | Центрированный модал 320px, кнопки «Отмена» / «Выйти» |

Mobile-shell desktop-варианты для главных экранов **не отрисованы** — desktop оставлен на следующую итерацию (см. раздел 7).

---

## 5. Дизайн-токены: Figma ↔ код

Все frame-ы используют значения из `lib/shared/theme/` (Stage 2). Это упрощает дальнейшую синхронизацию: если меняется токен в коде — меняется fill в Figma, и наоборот.

| Назначение | Figma fill / value | Код (Flutter) |
|---|---|---|
| Screen background | `#161616` | `AppColors.darkBackground` |
| Card / sheet background | `#1C1C1C` / `#1F1F1F` | `colorScheme.surface` / `surfaceContainerHighest` |
| Glass-поверхности (inputs, аватары) | `rgba(255,255,255,0.15)` | `AppColors.darkSurfaceGlass` |
| Primary text | `#FCFFFF` | `AppColors.darkText` |
| Muted text | `#A8A8A8` | `AppColors.darkTextMuted` |
| Primary CTA bg | `#FFFFFF` | `AppColors.darkPrimaryFill` |
| Primary CTA text | `#333333` | `AppColors.darkPrimaryText` |
| Error / logout | `#C93838` | `colorScheme.error` |
| Radius inputs/buttons | 16 | `AppRadii.md` |
| Radius sheet top | 20 | `AppRadii.lg` |
| Radius chips/pill | 999 | `AppRadii.pill` |
| Input / button height | 56 | `AppSizes.buttonHeight` |
| Form max width (desktop) | 361 | `AppSizes.formMaxWidth` |
| Typography | Inter 40 / 22 / 17 / 16 / 15 / 13 / 12 | `AppTypography.display / titleLarge / titleMedium / bodyLarge / labelLarge / ...` |

Light-тема в Figma не отрисована — в коде она существует как структурная инверсия dark, отдельной визуальной концепции для light пока нет.

---

## 6. Связь FigJam-узлов с Figma-frame

Каждый ключевой узел Main UX Flow привязан к конкретному mock-up.

| Узел FigJam | Figma frame |
|---|---|
| Launch → Auth (нет сессии) | Login Mobile / Login Desktop |
| Login → Register | Register Mobile / Register Desktop |
| Main Shell → Notes tab | NotesList |
| FAB «Новая заметка» (одна группа) | NoteEditor |
| FAB «Новая заметка» (несколько групп) | PickGroupSheet → NoteEditor |
| Tap карточку заметки | NoteEditor |
| Main Shell → Search tab | Search |
| Main Shell → Groups tab | GroupsList |
| FAB «Новая группа» | CreateGroupSheet |
| Tap карточку группы | GroupDetail |
| AppBar «Пригласить» в группе | InviteMemberSheet |
| Main Shell → Invitations tab | Invitations |
| Main Shell → Settings tab | Settings |
| Logout из Settings | ConfirmLogoutDialog → Login |

Узлы Auth Session State и Data Model не имеют прямого соответствия в Figma — это служебные диаграммы (поведение и данные, не UI).

---

## 7. Известные ограничения

- **Иконки** — в Figma стоят Unicode-плейсхолдеры (≡, ⌕, ◯, ✉, ⚙, ↻, ‹, ›, ↓, ↗). В Flutter это Material Icons. Перед хэндовером дизайнеру нужно заменить вручную или подключить Material Symbols в Figma.
- **Фоновые фотографии auth** заменены на градиентный эллипс с blur 80px. Реальные `bg_chandelier.webp` и `bg_papers.webp` нужно импортировать в Figma вручную, если потребуется пиксельная точность auth-mockup.
- **Image placeholders в Note Editor** — не показаны (нет фото в дефолтной заметке).
- **Empty / Loading / Error states** — отрисован только «happy path» с данными. Состояния пустых списков (нет заметок, нет групп, нет приглашений), скелетоны и ошибки — отдельная задача (можно расширить Stage 4 или оставить на дизайнерскую доработку).
- **Light-вариант** — все 15 frame-ов в dark. Light в коде есть как инверсия токенов, но визуально не подтверждён.
- **Desktop для главных экранов** — отрисованы только auth-desktop. Notes/Search/Groups/Settings desktop — следующий шаг. Это противоречит позиции владельца «Android и Windows равномерно» (см. A2 в PRODUCT_INTERVIEW.md) — точка для довода.
- **Auto-layout responsive** — frame-ы созданы как точечные мокапы, не как responsive-компоненты с auto-layout. Полноценный component-set с вариантами — отдельная инициатива.
- **Variants / Components в Figma** — карточки заметок, карточки групп, инпуты, кнопки не оформлены как переиспользуемые компоненты. Сейчас это inline-узлы внутри каждого frame. Преобразование в библиотеку компонентов — задача дизайн-системы.
- **Mobile vs Desktop layout различия** для главных экранов в FigJam отмечены комментариями, но детальной сравнительной карты нет (неясно из логов, нужна ли отдельная).

---

## 8. Что дальше

**Ближайшее** — Stage 5 (push-уведомления) согласно блоку E [PRODUCT_INTERVIEW.md](PRODUCT_INTERVIEW.md). Четыре события: приглашение в группу, новая заметка в группе, тик в общем чеклисте, изменение совместной заметки. Sequence-диаграммы push-flow логично добавить в существующий FigJam как 4-ю диаграмму.

**Постоянная задача — синхронизация Figma ↔ код**:
1. При изменении токена в `lib/shared/theme/` — обновить соответствующее значение в Figma (см. таблицу в разделе 5).
2. При добавлении нового экрана — отрисовать frame на page «From code» и добавить узел в FigJam Main UX Flow.
3. Перевести inline-узлы Figma в библиотеку компонентов с вариантами — снизит стоимость поддержки.

**Желательно до Stage 5**:
- Закрыть desktop-варианты для главных экранов (хотя бы NotesList, NoteEditor, Settings).
- Отрисовать empty / loading / error состояния как варианты компонентов.
- Заменить Unicode-плейсхолдеры на Material Symbols в Figma.

---

### Связанные документы
- [STAGE3_LOG.md](STAGE3_LOG.md) — детальный лог Стадии 3
- [STAGE4_LOG.md](STAGE4_LOG.md) — детальный лог Стадии 4
- [PRODUCT_INTERVIEW.md](PRODUCT_INTERVIEW.md) — продуктовый контекст
- [CHANGELOG.md](CHANGELOG.md) — код-изменения Стадий 1-2
