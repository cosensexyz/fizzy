# Settings Panel Redesign

**Date:** 2026-05-26
**Status:** Approved

## Overview

Redesign the SettingsPanel to replace the shortcut recorder with modifier checkboxes, merge key bindings into the Cycle Shortcut section, upgrade Display Mode to card-style selection with thumbnails, and polish Permissions with badge-style status indicators.

## Scope

This is a **rewrite of SettingsPanel.swift** and a **simplification of CycleConfig** (remove `keyCode`). HotkeyManager and CycleSessionController are unchanged — arrow keys are already hardcoded as trigger/navigation keys.

## CycleConfig Changes

Remove `keyCode` field. Arrow keys are fixed, only modifiers are configurable.

```swift
public struct CycleConfig {
    public var modifierFlags: CGEventFlags  // default: [.maskCommand, .maskShift]
    public var displayMode: DisplayMode     // default: .listAndPreview
}
```

UserDefaults keys: `cycleModifierFlags` (UInt64), `cycleDisplayMode` (String). Remove `cycleKeyCode`.

HotkeyManager: remove `config.keyCode` references in `mapEvent`. The idle-state trigger is always Right Arrow (124) or Left Arrow (123) with the configured modifiers. The cycling-state navigation is always arrows 123-126, also requiring modifiers.

## Panel Specifications

**Window:** titled + closable + nonactivatingPanel, floating level. Scrollable content. Width ~500, height sized to content (scrolls if needed).

**Title bar:** "Settings" centered. "Fizzy X.Y.Z" version string right-aligned in the title area (use subtitle or add to title).

**Bottom bar:** Fixed at bottom, outside scroll area. Left: "⌘, to reopen" hint in secondary text. Right: "Done" button (closes panel).

## Section 1: Cycle Shortcut

**Header:** Bold "Cycle shortcut" + subtitle "Hold your modifiers, then use arrow keys to switch between Claude Code sessions."

### Modifier Toggles

A rounded card containing the label "MODIFIERS" on the left, and 4 toggle buttons arranged in a row (wrapping to second row for Ctrl):

Each toggle button is a keycap-styled control:
- Rounded rect with border
- Contains: checkbox (left) + modifier symbol (center) + name (right)
- **Selected:** cyan border, filled checkbox
- **Unselected:** gray border, empty checkbox
- Symbols: ⌘ (Cmd), ⇧ (Shift), ⌥ (Opt), ⌃ (Ctrl)

**Validation:** At least one modifier must be selected. If user unchecks the last one, re-check it (prevent empty modifiers).

**On change:** Update CycleConfig.modifierFlags, save, call HotkeyManager.updateConfig. Key bindings table updates dynamically.

### Key Bindings Table

7 rows, each showing:
- **Left column:** keycap badges for the key combination
- **Center column:** action name (bold)
- **Right column:** context label in gray secondary text

| Keys | Action | Context |
|------|--------|---------|
| [⌘] [⇧] + [→] | **Enter cycling** (forward) | |
| [⌘] [⇧] + [←] | **Enter cycling** (backward) | |
| [→] | **Cycle forward** | while cycling |
| [←] | **Cycle backward** | while cycling |
| [↓] | **Confirm** | while cycling |
| [↑] | **Cancel** | while cycling |
| [Release modifiers] | **Confirm** | release modifiers |

The first two rows dynamically reflect the current modifier selection. The modifier keycap badges match the selected modifiers. The "+" separator is plain text between modifier badges and arrow badge.

The last row uses a text-style badge "Release modifiers" instead of keycap badges.

**Keycap badge style:** Rounded rect (corner radius ~6), light gray background, darker border, centered symbol. Arrow symbols: → ← ↓ ↑. Modifier symbols: ⌘ ⇧ ⌥ ⌃.

## Section 2: Display Mode

**Header:** Bold "Display mode" + subtitle "What appears when you trigger the shortcut."

Two side-by-side card radio buttons, each containing:
- Preview thumbnail image (top) — a stylized screenshot of the mode
- Radio indicator (top-right corner of card)
- Title (bold)
- Description (secondary text, 1-2 lines)

**Card 1 — Switcher + Preview:**
- Title: "Switcher + Preview"
- Description: "Cmd-Tab style row with a live preview of each session."

**Card 2 — Preview only:**
- Title: "Preview only"
- Description: "Just the latest output. Faster, less to read."

**Selected card:** cyan border. Filled radio dot.
**Unselected card:** light gray border. Empty radio dot.

**Thumbnail images:** For the initial implementation, use simple placeholder rectangles with schematic drawings (dark rectangles suggesting terminal windows). These can be replaced with real screenshots later.

**On change:** Update CycleConfig.displayMode, save immediately.

## Section 3: Permissions

**Header:** Bold "Permissions" + subtitle "What macOS lets Fizzy do." + "Open System Settings ↗" button right-aligned on the same line as the header.

5 permission rows, each in a card-style container:

| Target | Description | Category |
|--------|-------------|----------|
| Accessibility | Global keyboard shortcut | SYSTEM |
| System Events | Raise terminal window | SYSTEM |
| Ghostty | Switch terminal tabs | TERMINAL |
| iTerm2 | Switch terminal tabs | TERMINAL |
| Terminal | Switch terminal tabs | TERMINAL |

Each row contains:
- **Left:** Colored dot (green/red/yellow/gray) + target name (bold) + status badge
- **Below name:** Description in secondary text
- **Right:** Category label in gray caps ("SYSTEM" or "TERMINAL")

**Status badges:** Rounded pill shape with colored border and text:
- Granted: green border + green text
- Denied: red border + red text
- Not Asked: yellow border + yellow text
- Not Running: gray border + gray text

**Detection:** Check all permissions when panel opens (same as current implementation).

## Bottom Bar

Fixed bar at the bottom of the panel (not scrolled with content):
- Left: "⌘, to reopen" in secondary/tertiary text
- Right: "Done" button (standard rounded button, closes panel)

## Testing

Pure logic tests remain unchanged (permissionStatus mapping, shortcutDescription — though shortcutDescription can be simplified since keyCode is gone). Add tests for:
- Modifier validation (at least one must be selected)
- CycleConfig without keyCode (load/save round-trip)

UI rendering is verified manually.

## Files Changed

| File | Change |
|------|--------|
| `Sources/FizzyKit/SettingsPanel.swift` | Full rewrite |
| `Sources/FizzyKit/CycleConfig.swift` | Remove keyCode field |
| `Sources/FizzyKit/HotkeyManager.swift` | Remove config.keyCode references, hardcode 124 as forward trigger |
| `Tests/FizzyTests/SettingsPanelTests.swift` | Update for new API |
| `Tests/FizzyTests/CycleConfigTests.swift` | Remove keyCode tests |
| `Tests/FizzyTests/HotkeyManagerTests.swift` | Update custom config tests |
