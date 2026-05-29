# Стадия 3 — UX Flow в FigJam

> Лог действий по Стадии 3.
> Дата: 2026-05-27

## Цель
Создать в FigJam карту экранов и переходов приложения collab_notes — для mobile и desktop. Это основа для Стадии 4 (отрисовка экранов в Figma Design, node 28-35).

## Созданный файл FigJam

**URL**: https://www.figma.com/board/Ww1o9PNT9Bx8J0cR0hLlFE
**fileKey**: `Ww1o9PNT9Bx8J0cR0hLlFE`
**Команда**: SVCH (`team::1074741226428550268`)
**Создан через**: MCP `generate_diagram` (Figma plugin)

## Содержимое FigJam

### Диаграмма 1 — Main UX Flow
Полная карта переходов между экранами после Стадий 1-2.

**Покрывает**:
- Точку входа (Launch → проверка сессии → auth или main shell)
- Auth-flow: LoginScreen ↔ RegisterScreen, оба «always dark» (из Стадии 2)
- Main Shell с 5 вкладками bottom nav: Notes, Search, Groups, Invitations, Settings
- Notes: FAB новая заметка → выбор группы (если несколько) → editor; tap карточку → edit; иконка архива
- Groups (новое в Стадии 1): FAB → CreateGroupSheet, tap → GroupDetailScreen → AppBar invite → InviteMemberSheet, FAB → Notes filtered
- Invitations: accept → группа добавляется; decline → удаляется из списка
- Settings: проверка обновлений → UpdateAvailableDialog; logout → ConfirmLogoutDialog → возврат к Login
- Visual classes: sheets (тёмно-серый), dialogs (тёмный), auth (чёрный)

### Диаграмма 2 — Auth Session State (Stage 1 фикс)
State-машина авторизационной сессии. Документирует ключевой фикс из Стадии 1 — различие сетевой ошибки от невалидного токена.

**Состояния**:
- `Unauthenticated` — нет токенов или пользователь нажал logout
- `CheckingSession` — запуск с токенами, проверяем валидность
- `Authenticated` — пользователь видит main shell
- `RefreshingToken` — токен истёк, пытаемся обновить

**Критический переход (Stage 1)**:
- `RefreshingToken → Authenticated` при **сетевой ошибке** — раньше шёл в Unauthenticated (разлогинивал зря)
- `RefreshingToken → Unauthenticated` только при 401 от сервера (реально невалидный refresh)

### Диаграмма 3 — Data Model (для Stage 4)
ER-диаграмма базы данных. Показывает связи между сущностями USER ↔ GROUP ↔ NOTE ↔ INVITATION ↔ CHECKLIST_ITEM ↔ NOTE_IMAGE.

**Зачем**: при отрисовке экранов в Stage 4 нужно понимать какие поля доступны для отображения (например, в GroupDetail — `members[].role` приходит как 'owner'/'admin'/'member').

## Что НЕ покрыто (out of scope Стадии 3)

- Эмпирическая отрисовка экранов (это Стадия 4)
- Mobile vs Desktop layout различия — отмечено в основной диаграмме комментариями, но детальная сравнительная карта оставлена на Стадию 4
- Empty / loading / error состояния каждого экрана — будут показаны как варианты в Stage 4
- Push notifications flow — Стадия 5

## Action log

| # | Действие | Результат |
|---|---|---|
| 1 | `whoami` — проверка доступа Figma | Подтверждена авторизация, получен список 30+ команд |
| 2 | `generate_diagram` Main UX Flow | Создан FigJam файл `Ww1o9PNT9Bx8J0cR0hLlFE` в команде SVCH |
| 3 | `generate_diagram` Auth Session State в тот же fileKey | Диаграмма добавлена |
| 4 | `generate_diagram` Data Model в тот же fileKey | Диаграмма добавлена |
| 5 | Обновлён STAGE3_LOG.md | Полная документация по стадии |

## Решения и почему

- **Команда SVCH** — личная команда пользователя (по handle «Сёма»). Это default-выбор для draft-материалов. Можно перенести в другую команду при необходимости.
- **Один FigJam файл с тремя диаграммами** вместо трёх отдельных — все три темы относятся к одному проекту, удобнее открывать одно место.
- **Mermaid вместо нативной FigJam-разметки** — `generate_diagram` принимает только Mermaid; для UX flow это адекватный формат.
- **Подсветка цветами в диаграмме 1** — sheets / dialogs / auth-экраны выделены, чтобы визуально читать тип навигации.

## Связанные документы
- [STAGE4_LOG.md](STAGE4_LOG.md) — лог Стадии 4 (создаётся параллельно)
- [PRODUCT_INTERVIEW.md](PRODUCT_INTERVIEW.md) — продуктовое интервью с владельцем
- [CHANGELOG.md](CHANGELOG.md) — все код-изменения по Стадиям 1-2
