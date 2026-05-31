# Collab Notes Design System Spec (Figma)

This spec maps Flutter tokens and widgets to Figma variables, text styles, and components with code-matching names.

## 1) Variables

### Color Variables
- token/color/bg1 = #161616
- token/color/bg2 = #1F1F1F
- token/color/bg3 = #393939
- token/color/white = #FFFFFF
- token/color/whiteHover = #F0F0F0
- token/color/fgContainer = #333333
- token/color/fgSoft = #A8A8A8
- token/color/negative = #FC502C
- token/color/success = #4FAE82
- token/color/warning = #DFAB01
- token/color/surfaceGlass = #26FFFFFF
- token/color/surfaceGlassStrong = #40FFFFFF
- token/color/border = #4DFFFFFF
- token/color/borderSubtle = #1AFFFFFF
- token/color/textSecondary = #B3FFFFFF
- token/color/titleWhite = #FCFFFF

### Light Theme Variables
- token/color/lightBackground = #FAFAF9
- token/color/lightSurface = #FFFFFF
- token/color/lightSurfaceGlass = #0F000000
- token/color/lightBorder = #33000000
- token/color/lightBorderSubtle = #14000000
- token/color/lightText = #161616
- token/color/lightTextSecondary = #B3000000
- token/color/lightTextMuted = #6F6F6F
- token/color/lightPrimaryFill = #161616
- token/color/lightPrimaryText = #FFFFFF
- token/color/lightPrimaryFillDisabled = #80161616

### Spacing Variables
- token/space/xs = 4
- token/space/sm = 8
- token/space/md = 12
- token/space/lg = 16
- token/space/xl = 24
- token/space/xxl = 32
- token/space/xxxl = 48

### Radius Variables
- token/radius/xs = 8
- token/radius/sm = 12
- token/radius/md = 16
- token/radius/lg = 20
- token/radius/pill = 999

### Size Variables
- token/size/buttonHeight = 56
- token/size/inputHeight = 56
- token/size/formMaxWidth = 361
- token/size/bottomNavHeight = 64

## 2) Text Styles
- text/h1: SF Pro, 40, Semibold, line 100%, letter -5
- text/body: SF Pro, 16, Regular, line 130%
- text/bodyS: SF Pro, 16, Semibold, line 100%
- text/extraL: SF Pro, 14, Regular, line 100%
- text/titleLarge: SF Pro, 22, Semibold, line 120%, letter -0.5
- text/titleMedium: SF Pro, 17, Semibold, line 125%
- text/titleSmall: SF Pro, 15, Semibold, line 130%
- text/labelMedium: SF Pro, 13, Semibold, line 120%
- text/bodySmall: SF Pro, 13, Regular, line 140%

## 3) Component Sets

### Component/AppButton
Axes:
- kind: primary | secondary | text
- state: default | hover | pressed | disabled | loading
- widthMode: hug | fill

Rules:
- Height is always token/size/buttonHeight
- Radius is token/radius/md

### Component/AppInput
Axes:
- state: default | focused | error | disabled
- type: singleLine | password | multiline
- label: withLabel | noLabel

Rules:
- Height singleLine/password = token/size/inputHeight
- Border and glass fills from token/color/*

### Component/AppChip
Axes:
- size: s | m
- state: default | hover | active | disabled
- leading: yes | no

Sizes:
- s height 29
- m height 44

### Component/AppLoader
Axes:
- tone: default | subtle

### Component/AppEmptyState
Axes:
- action: yes | no

### Component/AppErrorState
Axes:
- action: retry | none

### Component/GroupAvatar
Axes:
- source: image | initials
- size: sm | md | lg

### Component/NoteCard
Axes:
- view: grid | list
- state: default | hover | pressed | swipe-left | swipe-right
- checklist: none | partial | done
- image: none | single | multi
- pinned: off | on

### Component/BottomNavItem
Axes:
- item: notes | chats | settings
- state: active | inactive

### Component/TypingIndicator
Axes:
- state: active

### Component/NotePresenceBar
Axes:
- viewers: 1 | 2 | 3plus

## 4) Frame Construction Rules
- Do not use detached copies of buttons/inputs/chips/cards in final screens.
- Use only instances from Component/* sets.
- Use only text styles from text/*.
- Use only variable references from token/*.
- Keep naming identical to Flutter classes and routes from manifest.

## 5) Suggested Figma Page Structure
- 00 Tokens
- 01 Components
- 02 Screens Mobile
- 03 Screens Desktop
- 04 Modals and Overlays
- 05 Flows

## 6) Current Gaps to Close
- Add ChatsListScreen and ChatScreen family with all modes.
- Add ActivityFeedScreen and ForceUpdateScreen.
- Add ImageViewerScreen and ChatImageViewerScreen.
- Add explicit loading/empty/error variants for every top-level screen.

## 7) Acceptance Checklist
- Every route in router has matching Screen/* frame.
- Every showModalBottomSheet/showDialog has Modal/* frame.
- No local color style in production frames.
- No local text style in production frames.
- Main flows clickable in prototype mode:
  - auth -> notes
  - notes -> note editor
  - groups -> group detail -> group chat
  - settings -> invitations/search/activity
