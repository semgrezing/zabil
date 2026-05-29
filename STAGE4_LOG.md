# Стадия 4 — Code-to-Figma всех экранов

> Лог действий по Стадии 4.
> Дата: 2026-05-27

## Цель
Создать в Figma Design (файл `FG0OQ2LcuJob7QCMbtAYVX`, page `28:35` «From code») визуальные представления всех экранов приложения collab_notes на основе кода после Стадий 1-2. Дизайнерская развёртка — основа для дальнейшей работы над UI.

## Цель достигнута
**15 frame-ов создано** в page «From code» через Figma Plugin API (`use_figma`):
- 4 auth-экрана (Login/Register × mobile/desktop)
- 7 экранов главного shell (mobile): NotesList, NoteEditor, Search, GroupsList, GroupDetail, Invitations, Settings
- 4 модалки/диалога: CreateGroupSheet, InviteMemberSheet, PickGroupSheet, ConfirmLogoutDialog

## Ссылка
**Figma Design**: https://www.figma.com/design/FG0OQ2LcuJob7QCMbtAYVX/Untitled?node-id=28-35

## Layout grid

```
Y=0   (mobile auth)   [Login-M  ][Register-M]
                       0,0       453,0

Y=900 (desktop auth)  [    Login-Desktop 1440×900    ][   Register-Desktop 1440×900  ]
                       0,900                          1500,900

Y=1900 (main shell)   [NotesList][NoteEditor][Search][GroupsList][GroupDetail][Invitations][Settings]
                       0,1900    453,1900    906     1359        1812          2265         2718

Y=2900 (modals)       [CreateGroup][InviteMember][PickGroup][ConfirmLogout]
                       0,2900       453,2900      906,2900   1359,2900
```

Все mobile frames: **393×852** (iPhone-class viewport, тот же что у auth-экранов в Figma 12-633).
Desktop frames: **1440×900**.
Модалки: **393×600** (мобильный контекст с видимым sheet внизу или dialog по центру).

## Дизайн-токены (источник — Stage 2)

Все frames используют те же цветовые и размерные токены, что в Flutter-коде:

| Token | Hex / RGBA | Применение |
|---|---|---|
| `bg` | `#161616` | Screen background |
| `surface` | `#1C1C1C` / `#1F1F1F` | Card / sheet background |
| `surfaceGlass` | `rgba(255,255,255,0.15)` | Inputs, avatars, secondary surfaces |
| `text` | `#FCFFFF` | Primary text |
| `textMuted` | `#A8A8A8` | Hints, secondary text |
| `primaryFill` | `#FFFFFF` | Primary CTA bg |
| `primaryText` | `#333333` | Text on primary CTA |
| `error` | `#C93838` | Error states, logout |
| Radius | 16 (inputs/buttons), 20 (sheet top), 999 (chips, pill) | |
| Heights | 56 (input/button), 80 (bottom nav), variable (cards) | |
| Typography | Inter Regular/Medium/Semi Bold — 40/22/17/16/15/13/12 px | |

## Action log

| # | Действие | Результат |
|---|---|---|
| 1 | `get_metadata` page 28:35 | Подтверждено: page «From code» пустая |
| 2 | `use_figma` POC — Login Mobile | 1 frame создан, подход валидирован |
| 3 | `use_figma` — Register-M + Login-D + Register-D | 4 frame в auth-секции |
| 4 | `use_figma` — 7 экранов main shell mobile | 11 frame суммарно |
| 5 | `use_figma` — 4 модалки/диалога | 15 frame суммарно |
| 6 | Создан STAGE4_LOG.md | Полная документация |

## Содержимое каждого frame

### Auth (4 frame)
- **Login Mobile (393×852)** — глоу-эллипс + чёрный фон, форма прижата к низу, заголовок «авторизация» 40px, подзаголовок, инпуты «Никнейм» и «Пароль» (glass 15%), белая кнопка «войти», ссылка «нет аккаунта? зарегистрироваться».
- **Register Mobile (393×852)** — то же + back-кнопка 56×56 (glass), три инпута (никнейм/пароль/пароль снова), кнопка «зарегистрироваться», ссылка «уже есть аккаунт».
- **Login Desktop (1440×900)** — субтильный глоу за центром, без фотофона. Форма 361px центрирована.
- **Register Desktop (1440×900)** — то же + back-кнопка top-left.

### Main Shell Mobile (7 frame)
- **NotesList** — AppBar «Заметки» + archive icon, search bar, чипы контекста (Личное selected + группы), 3 карточки заметок, FAB «+ Новая заметка», bottom nav (Заметки active).
- **NoteEditor** — AppBar «Редактирование*» + back + save icon, заголовок, контент, чеклист (2 done + 2 pending), кнопка «Прикрепить изображение».
- **Search** — AppBar «Поиск», search input с введённым «гречка», чипы фильтра по группам, результаты с подсветкой группы, bottom nav (Поиск active).
- **GroupsList** — AppBar «Группы» + refresh, 3 карточки групп с аватаром + название + count, FAB «+ Новая группа», bottom nav (Группы active).
- **GroupDetail** — AppBar «Семья» + back + person_add, список участников с ролями (Создатель / Участник), FAB «Заметки группы». Без bottom nav (full screen detail).
- **Invitations** — AppBar «Приглашения» + refresh, 2 карточки с группой + sender + кнопками Отклонить (outlined) и Принять (primary), bottom nav (Приглашения active).
- **Settings** — AppBar «Настройки», профиль `@semva`, секция «Тема» с пунктом «Тёмная», разделитель, обновления + версия, разделитель, «Выйти» (красным), bottom nav (Настройки active).

### Модалки и диалоги (4 frame)
- **CreateGroupSheet** — bottom sheet с drag handle, заголовок «Новая группа», input с placeholder «Например: Семья», кнопка «Создать».
- **InviteMemberSheet** — bottom sheet с drag handle, заголовок «Пригласить в «Семья»», input с placeholder «например: alex», кнопка «Отправить приглашение».
- **PickGroupSheet** — bottom sheet с drag handle, заголовок «Выберите группу», список из 4 групп (Личное + 3) с аватарами.
- **ConfirmLogoutDialog** — центрированный модал 320px, заголовок «Выйти?», текст «Вы будете разлогинены.», кнопки «Отмена» (muted) и «Выйти» (text).

## Что НЕ покрыто (известные ограничения)

- **Иконки** — placeholder-Unicode символы (≡, ⌕, ◯, ✉, ⚙, ↻, ‹, ›, ↓, ↗). В реальном UI это Material Icons из flutter_lints. Дизайнер заменит на правильные иконки в Figma.
- **Фоновые фотографии auth** — заменены на градиентный эллипс с blur 80px (имитация Depth glow). Реальные фото `bg_chandelier.webp` и `bg_papers.webp` — для замены вручную или импорта в Figma как изображения.
- **Image placeholders в Note Editor** — не показаны (отсутствуют в дефолтной заметке). При наличии фото — отрисовать в реальном дизайне.
- **Empty / Loading states** — каждый экран нарисован с данными. Empty (нет заметок, нет групп, нет приглашений) и loading-состояния можно добавить как варианты позднее (Stage 4 расширение или дизайнер вручную).
- **Error-state** — не отрисованы.
- **Variants для тем (light)** — все frame показывают dark-режим. Light-вариант — отдельная задача (не входит в текущий scope).
- **Auto-layout responsive** — frame созданы как точечные мокапы. Полноценный responsive (resize → пересборка) требует более сложной структуры компонентов.

## Связанные документы
- [STAGE3_LOG.md](STAGE3_LOG.md) — UX flow в FigJam (Стадия 3)
- [CHANGELOG.md](CHANGELOG.md) — все код-изменения по Стадиям 1-2
- [PRODUCT_INTERVIEW.md](PRODUCT_INTERVIEW.md) — продуктовое интервью
