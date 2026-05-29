---
name: figma-to-flutter
description: Figma → Flutter Token Mapping (collab_notes project)
---

# Figma → Flutter · collab_notes

**Figma file:** `https://www.figma.com/design/FG0OQ2LcuJob7QCMbtAYVX/`  
**Token source:** `lib/shared/theme/app_colors.dart`, `lib/shared/theme/app_theme.dart`

---

## AppColors (project tokens)

### Dark theme
| Figma Hex | AppColors token | Usage |
|-----------|-----------------|-------|
| `#191919` | `AppColors.darkBackground` | Scaffold background |
| `#252525` | `AppColors.darkSurface` | Cards, bottom bar |
| `#2F2F2F` | `AppColors.darkSurfaceVariant` | Elevated surfaces |
| `#383838` | `AppColors.darkBorder` | Borders, dividers |
| `#ECECEC` | `AppColors.darkText` | Primary text |
| `#9B9B9B` | `AppColors.darkTextSecondary` | Secondary text |
| `#666666` | `AppColors.darkTextMuted` | Hints, muted |
| `#2383E2` | `AppColors.darkAccent` | Primary action (blue) |

### Light theme
| Figma Hex | AppColors token | Usage |
|-----------|-----------------|-------|
| `#FFFFFF` | `AppColors.lightBackground` | Scaffold background |
| `#F7F7F5` | `AppColors.lightSurface` | Cards |
| `#EFEFEF` | `AppColors.lightSurfaceVariant` | Elevated surfaces |
| `#E9E9E7` | `AppColors.lightBorder` | Borders |
| `#1A1A1A` | `AppColors.lightText` | Primary text |
| `#787774` | `AppColors.lightTextSecondary` | Secondary text |
| `#B2B2AE` | `AppColors.lightTextMuted` | Hints, muted |
| `#2383E2` | `AppColors.lightAccent` | Primary action (blue) |

### Semantic
| Figma Hex | AppColors token | Usage |
|-----------|-----------------|-------|
| `#EB5757` | `AppColors.error` | Errors |
| `#0F7B6C` | `AppColors.success` | Success |
| `#DFAB01` | `AppColors.warning` | Warnings |

---

## Auth screen tokens (Figma → inline constants)

Эти токены используются только в auth-экранах и пока не вынесены в AppColors:

| Figma значение | Dart | Использование |
|----------------|------|---------------|
| `#161616` | `Color(0xFF161616)` | Auth screen background |
| `rgba(255,255,255,0.15)` | `Color(0x26FFFFFF)` | Glassmorphism input fill |
| `#A8A8A8` | `Color(0xFFA8A8A8)` | Input placeholder / hint |
| `#333333` | `Color(0xFF333333)` | Primary button text |
| `#FCFFFF` | `Color(0xFFFCFFFF)` | Auth title color |
| `#C93838` | `Color(0xFFC93838)` | Auth error color |
| `rgba(255,255,255,0.70)` | `Color(0xB3FFFFFF)` | Subtitle (70% white) |
| `rgba(255,255,255,0.50)` | `Color(0x80FFFFFF)` | Disabled button bg |
| `rgba(255,255,255,0.30)` | `Color(0x4DFFFFFF)` | Focused input border |

---

## Sizes (auth screens, от Figma)
| px | Использование |
|----|---------------|
| `56` | Высота input / кнопки |
| `16` | Border-radius input / кнопки |
| `361` | Ширина контента (desktop) |
| `768` | Desktop breakpoint |
| `40` | Letter-spacing заголовка: `-2` |

---

## Opacity → Hex (quick ref)
| % | Hex | Пример |
|---|-----|--------|
| 15% | `0x26` | `Color(0x26FFFFFF)` |
| 30% | `0x4D` | `Color(0x4DFFFFFF)` |
| 50% | `0x80` | `Color(0x80FFFFFF)` |
| 70% | `0xB3` | `Color(0xB3FFFFFF)` |
| 85% | `0xD9` | `Color(0xD9FFFFFF)` |

---

## Паттерны

### Glassmorphism input (auth screens)
```dart
TextFormField(
  style: const TextStyle(color: Colors.white, fontSize: 16),
  decoration: InputDecoration(
    hintText: 'Placeholder',
    hintStyle: const TextStyle(color: Color(0xFFA8A8A8), fontSize: 16),
    filled: true,
    fillColor: const Color(0x26FFFFFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x4DFFFFFF), width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFC93838), width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFC93838), width: 1),
    ),
    errorStyle: const TextStyle(color: Color(0xFFC93838), fontSize: 12, height: 1.5),
  ),
)
```

### Primary button (белый на тёмном фоне)
```dart
SizedBox(
  height: 56,
  width: double.infinity,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF333333),
      disabledBackgroundColor: const Color(0x80FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    onPressed: isLoading ? null : onPressed,
    child: isLoading
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Color(0xFF333333))))
        : const Text('label', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  ),
)
```

### Secondary / link кнопка
```dart
TextButton(
  style: TextButton.styleFrom(
    foregroundColor: const Color(0xFFA8A8A8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  ),
  onPressed: onPressed,
  child: const Text('текст', style: TextStyle(fontSize: 16)),
)
```

### Glassmorphism back button (56×56)
```dart
GestureDetector(
  onTap: () => context.go('/login'),
  child: Container(
    width: 56, height: 56,
    decoration: BoxDecoration(
      color: const Color(0x26FFFFFF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
  ),
)
```

### Responsive breakpoint
```dart
LayoutBuilder(
  builder: (context, constraints) => constraints.maxWidth >= 768
      ? _desktopLayout()  // Center + SizedBox(width: 361) + form
      : _mobileLayout(),  // Stack + gradient bg + ListView
)
```

### Mobile background (gradient + glow)
```dart
Stack(fit: StackFit.expand, children: [
  Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0.4, -0.5), radius: 1.6,
        colors: [Color(0xFF2E2F48), Color(0xFF1C1C2C), Color(0xFF161616)],
        stops: [0.0, 0.5, 1.0],
      ),
    ),
  ),
  // Purple glow (top-right): BoxShadow color: Color(0x554F42D0), blur: 120
  // Teal glow   (top-left):  BoxShadow color: Color(0x351B9BA4), blur: 90
])
```

---

## Типографика
- Шрифт: `'Inter'` (`AppTheme._fontFamily`)
- Auth заголовок: `fontSize: 40, fontWeight: FontWeight.w600, letterSpacing: -2`
- Body: `fontSize: 16`

---

## Поиск токенов в проекте
```powershell
# Все AppColors
Select-String -Path "lib/**/*.dart" -Pattern "AppColors\."

# Все inline hex-цвета в auth
Select-String -Path "lib/features/auth/**/*.dart" -Pattern "Color\(0x"
```