# STAGE 8 LOG — Notes/Chats/Groups UX expansion

> Date: 2026-05-29
> Status: implementation complete

## Scope
- Collect decisions for 15 requested product changes.
- Implement only after interview is complete.
- Log each code change with file list and rationale.

## Interview log
- Batch 1 completed (items 1-5, partial clarifications pending):
	- Move notes: any context-to-context move allowed; permissions in groups for any member; preserve note payload 1:1.
	- Personal space: fully private; entry via Personal chip and header shortcut.
	- Chats > Groups preview: author + text + time; empty state CTA "Create first message".
	- Note chat duplication into group chat: keep lightweight marker with note title + color marker; bidirectional navigation confirmed.
	- Groups tab removal: remove tab, move all features into Chats header.
- Batch 2 completed (items 6-10, partial for item 10):
	- Group settings: owner + admins can edit; members cannot kick admin/owner.
	- Avatars (all entities): fullscreen view, history browsing, delete from history/current, unlimited history, placeholder fallback on delete.
	- Avatar crop: circle 1:1 with full standard controls.
	- Notes chips: active text must be black; selected checkmark removed everywhere.
	- Chat images: multi-select + Telegram-like send with and without compression; file limits still to confirm.
- Batch 3 completed (items 11-15 + pending clarifications):
	- Move-note entry points in note screen: both kebab menu and dedicated header action.
	- Chat image limits: product-side no hard limits.
	- Push: Android + Windows, events include invites/notes/checklists/all chat streams, deep-link on tap, sound + badge.
	- Notes search: inline header search field via icon.
	- Floating navbar: strong blur, 16px radius, 8px bottom offset, no shadow, 80% opacity.
	- Notes layout toggle: grid/list with persistent last choice; grid 2 columns on mobile, 3+ desktop.
	- Note color labels: 12-color palette, editable from card kebab and note editor, default none.

## Implementation log
- Backend (Prisma/API):
	- `prisma/schema.prisma`:
		- Added group fields: `avatarUrl`, `isPersonal`.
		- Added note field: `colorLabel`.
		- Added chat message media fields (`imageUrl`, `imageMimeType`, `imageSize`, `imageCompressed`) for `GroupChatMessage` and `PersonalMessage`.
		- Added `AvatarHistory` model.
	- Notes module:
		- `notes/schema.ts`: added `personal` query/body support, color label validation, and move schema.
		- `notes/routes.ts`: added `PATCH /notes/:id/move`.
		- `notes/service.ts`: implemented personal context support, move between group/personal, color label persistence, and checklist/note update push triggers.
	- Groups module:
		- `groups/routes.ts`: added personal-context endpoint, group update, member removal, avatar upload/delete/history endpoints.
		- `groups/service.ts`: implemented owner/admin management checks, member kick constraints (cannot kick owner/admin), group title update, avatar history operations, and personal-group helper.
	- Users module:
		- `users/routes.ts`: added delete avatar, avatar history list/delete endpoints.
		- `users/service.ts`: avatar uploads now tracked in history; added history management operations.
	- Uploads module:
		- `uploads/routes.ts`: added `POST /uploads/chat-image?compressed=true|false`.
		- `uploads/service.ts`: added chat image upload logic with compressed/original modes.
	- Chats module:
		- `chats/routes.ts`: message send now accepts text and/or image payload.
		- `chats/service.ts`: message persistence and WS payloads expanded with media + note metadata.
	- Invitations module:
		- `invitations/service.ts`: forbid invites into personal context.
	- Notifications module:
		- `notifications/service.ts`: added `notifyNoteUpdated` and wired checklist/note change events.

- Flutter (UI/UX):
	- Navigation and shell:
		- `router.dart`: added chat routes (`/chats`, `/chats/group/:id`, `/chats/personal/:id`, `/chats/note/:id`) and standalone `/groups` list route.
		- `shared/widgets/main_shell.dart`: added Chats tab and implemented floating blurred navbar (16px radius, 8px bottom offset, no shadow, 80% opacity).
	- Notes:
		- `notes_list_screen.dart`: header search icon with inline field, Personal context button, All/Personal/Group chips via `AppChip`, grid/list mode toggle with persisted preference, context-aware create flow.
		- `note_editor_screen.dart`: move-note from dedicated button + kebab, note-chat button, color label edit in editor.
		- `note_card.dart`: color marker UI, move action in kebab, 12-color label picker, "no label" reset.
		- `notes_provider.dart` / `notes_service.dart` / `note_model.dart`: personal context filtering, move note API, color label model/update support.
		- `shared/widgets/app_chip.dart`: active chip text/icon color switched to black.
	- Chats:
		- `chats_list_screen.dart`: Groups header icon (left of add-user), embedded groups manager sheet, group row preview switched to last message (`author: text + time`) with empty-state CTA text.
		- `chat_screen.dart`: note/group cross-navigation, note-origin marker (title + color marker), image sending (multi-select + compressed/original mode), image bubble rendering.
		- Added `chat_image_viewer_screen.dart`.
		- `chat_message.dart`, `chats_service.dart`, `chats_provider.dart`: media + note metadata support.
	- Groups:
		- `group_detail_screen.dart`: group settings (rename, avatar update, avatar history, delete current avatar), member kick action for owner/admin, avatar fullscreen/history integration.
		- `group_model.dart`, `groups_service.dart`, `groups_provider.dart`: avatar/personal-context fields and management methods.
	- Settings/Profile:
		- `settings_screen.dart`: avatar crop before upload, fullscreen history viewer, delete current avatar, delete from history.
		- `auth_service.dart`, `auth_provider.dart`: added missing profile/avatar APIs, avatar delete/history methods, push token register on restored session.
	- Shared:
		- Added `shared/widgets/avatar_history_viewer.dart` (fullscreen avatar history with delete action).
	- Notifications:
		- `notification_service.dart`: improved local-notification fallback behavior and session registration reliability.

- Dependencies:
	- `collab_notes_app/pubspec.yaml`: added `image_cropper`, `solar_icons`, `web_socket_channel`, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `open_filex`; bumped version to `1.6.0+7`.

## Validation log
- Backend:
	- `npx prisma generate` — success.
	- `npm run build` (backend) — success, 0 TypeScript errors.
- Flutter:
	- `flutter analyze` — success, `No issues found!`.
- Notes:
	- DB migration/apply still required for new Prisma fields/models before production rollout.
