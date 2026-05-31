# Collab Notes Figma Migration Manifest

This manifest is the single source of truth for transferring Flutter UI to Figma with code-aligned naming.

## Scope
- Source app: collab_notes_app (Flutter)
- Target Figma file: Collab-notes (page: From code)
- Goal: 100% route and state coverage with reusable components

## Naming Convention
- Screen frames: Screen/<Feature>/<ClassName>/<Variant>
- Modal frames: Modal/<Feature>/<Name>/<Variant>
- Component sets: Component/<Name>
- Variables: token/<category>/<name>

Examples:
- Screen/Notes/NotesListScreen/default
- Screen/Chats/ChatScreen/group
- Modal/Groups/InviteMemberSheet/default
- Component/AppButton
- token/color/bg1

## Route -> Frame Mapping
- /login -> Screen/Auth/LoginScreen/mobile, Screen/Auth/LoginScreen/desktop
- /register -> Screen/Auth/RegisterScreen/mobile, Screen/Auth/RegisterScreen/desktop
- /notes -> Screen/Notes/NotesListScreen/default
- /notes/new -> Screen/Notes/NoteEditorScreen/new
- /notes/:id -> Screen/Notes/NoteEditorScreen/edit
- /chats -> Screen/Chats/ChatsListScreen/default
- /settings -> Screen/Settings/SettingsScreen/default
- /invitations -> Screen/Invitations/InvitationsScreen/default
- /search -> Screen/Search/SearchScreen/default
- /activity -> Screen/Activity/ActivityFeedScreen/default
- /groups -> Screen/Groups/GroupsListScreen/default
- /groups/:id -> Screen/Groups/GroupDetailScreen/default
- /chats/group/:groupId -> Screen/Chats/ChatScreen/group
- /chats/personal/:userId -> Screen/Chats/ChatScreen/personal
- /chats/note/:noteId -> Screen/Chats/ChatScreen/note

## Required Screen Variants

### Auth
- Screen/Auth/LoginScreen/mobile
- Screen/Auth/LoginScreen/mobile-loading
- Screen/Auth/LoginScreen/mobile-error
- Screen/Auth/LoginScreen/desktop
- Screen/Auth/RegisterScreen/mobile
- Screen/Auth/RegisterScreen/mobile-loading
- Screen/Auth/RegisterScreen/mobile-error
- Screen/Auth/RegisterScreen/desktop

### Notes
- Screen/Notes/NotesListScreen/default
- Screen/Notes/NotesListScreen/grid
- Screen/Notes/NotesListScreen/list
- Screen/Notes/NotesListScreen/search-active
- Screen/Notes/NotesListScreen/empty
- Screen/Notes/NotesListScreen/error
- Screen/Notes/NotesListScreen/loading
- Screen/Notes/NoteEditorScreen/new
- Screen/Notes/NoteEditorScreen/edit
- Screen/Notes/NoteEditorScreen/saving
- Screen/Notes/NoteEditorScreen/checklist-complete
- Screen/Notes/NoteEditorScreen/presence
- Screen/Notes/ImageViewerScreen/default
- Screen/Notes/ImageViewerScreen/delete-confirm

### Chats
- Screen/Chats/ChatsListScreen/default
- Screen/Chats/ChatsListScreen/personal-tab
- Screen/Chats/ChatsListScreen/groups-tab
- Screen/Chats/ChatsListScreen/empty
- Screen/Chats/ChatsListScreen/error
- Screen/Chats/ChatScreen/group
- Screen/Chats/ChatScreen/personal
- Screen/Chats/ChatScreen/note
- Screen/Chats/ChatScreen/sending
- Screen/Chats/ChatScreen/uploading-images
- Screen/Chats/ChatScreen/typing-indicator
- Screen/Chats/ChatImageViewerScreen/default

### Groups
- Screen/Groups/GroupsListScreen/default
- Screen/Groups/GroupsListScreen/empty
- Screen/Groups/GroupsListScreen/error
- Screen/Groups/GroupDetailScreen/default
- Screen/Groups/GroupDetailScreen/member-list
- Screen/Groups/GroupDetailScreen/avatar-history
- Screen/Groups/GroupDetailScreen/popup-menu

### Other
- Screen/Invitations/InvitationsScreen/default
- Screen/Invitations/InvitationsScreen/item-loading
- Screen/Invitations/InvitationsScreen/empty
- Screen/Search/SearchScreen/default
- Screen/Search/SearchScreen/searching
- Screen/Search/SearchScreen/no-results
- Screen/Settings/SettingsScreen/default
- Screen/Settings/SettingsScreen/theme-selector
- Screen/Settings/SettingsScreen/edit-profile
- Screen/Settings/SettingsScreen/avatar-history
- Screen/Activity/ActivityFeedScreen/default
- Screen/Activity/ActivityFeedScreen/empty
- Screen/Activity/ActivityFeedScreen/loading
- Screen/Updates/ForceUpdateScreen/default

## Required Modal/Overlay Frames
- Modal/Groups/CreateGroupSheet/default
- Modal/Groups/InviteMemberSheet/default
- Modal/Notes/PickGroupSheet/default
- Modal/Notes/MoveContextSheet/default
- Modal/Notes/ColorPickerSheet/default
- Modal/Chats/GroupsManagerSheet/default
- Modal/Chats/UserSearchSheet/default
- Modal/Chats/ImagePickerSheet/default
- Modal/Settings/EditProfileSheet/default
- Modal/Settings/ConfirmLogoutDialog/default
- Modal/Groups/ConfirmDeleteGroupDialog/default
- Modal/Groups/ConfirmLeaveGroupDialog/default
- Modal/Groups/ConfirmRemoveMemberDialog/default
- Modal/Notes/ConfirmDeleteNoteDialog/default
- Modal/Notes/ConfirmDeleteImageDialog/default

## Existing in Figma (already present)
- NotesList, NoteEditor, Search, GroupsList, GroupDetail, Invitations, Settings
- Login (mobile + desktop), Register (mobile + desktop)
- CreateGroupSheet, InviteMemberSheet, PickGroupSheet, ConfirmLogoutDialog
- Base primitives Input, Chip, Button

## Missing Priority (create first)
1. All Chats frames (ChatsListScreen, ChatScreen modes, ChatImageViewerScreen)
2. ActivityFeedScreen
3. ForceUpdateScreen
4. ImageViewerScreen variants
5. Loading/empty/error variants for each top-level screen
6. Modal coverage for notes/groups/chats/settings edge flows

## Definition of Done
- Every route has at least one default frame
- Every route has loading/empty/error frame where applicable
- Every modal in code has a modal frame
- Every repeated widget is an instance of a component set, not detached copies
- Variables and text styles are used (no raw local styles in production frames)
