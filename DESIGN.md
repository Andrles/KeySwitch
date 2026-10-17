---
name: KeySwitch
description: Lightweight native macOS utility for Russian and English typing.
typography:
  headline:
    fontFamily: SF Pro
    fontSize: 24pt
    fontWeight: 600
  title:
    fontFamily: SF Pro
    fontSize: 15pt
    fontWeight: 600
  body:
    fontFamily: SF Pro
    fontSize: 13pt
    fontWeight: 400
  detail:
    fontFamily: SF Pro
    fontSize: 12pt
    fontWeight: 400
  footer:
    fontFamily: SF Pro
    fontSize: 11pt
    fontWeight: 400
  metadata:
    fontFamily: SF Pro
    fontSize: 10pt
    fontWeight: 400
  suggestion:
    fontFamily: SF Pro
    fontSize: 21pt
    fontWeight: 500
rounded:
  surface: 12pt
  sidebar-selection: 10pt
spacing:
  content: 24pt
  section: 20pt
  group-horizontal: 20pt
  group-top: 18pt
  group-bottom: 16pt
  group-stack: 10pt
  popup-stack: 8pt
components:
  settings-window:
    width: 820pt
    height: 620pt
  settings-sidebar:
    width: 200pt
  material-group:
    rounded: '{rounded.surface}'
    padding: 18pt 20pt 16pt
  spelling-suggestion:
    width: 330pt
    rounded: '{rounded.surface}'
    padding: 16pt 18pt
---

# Design System: KeySwitch

## Overview

**Creative North Star: "A quiet language key"**

KeySwitch is a lightweight native macOS RU/EN utility. Its approved direction is light, modern and simple enough for a beginner: SF system typography, SF Symbols, the user's macOS accent and dynamic neutral materials. The A/Я language-key identity with its integrated switching symbol belongs to KeySwitch; the Caramba reference informs lighter surfaces and simpler wording without replacing that identity.

This is an AppKit settings window, not a marketing page. Transparency belongs to real system materials behind fully legible content. System, light and dark appearance apply to the whole window. The former purple gradient and glossy identity are replaced by restrained native surfaces. Existing design dials remain DESIGN_VARIANCE 3, MOTION_INTENSITY 2 and VISUAL_DENSITY 3; these are direction metadata, not runtime animation tokens.

**Key Characteristics:**
- Native controls, SF typography and SF Symbols.
- Shared translucent surfaces with opaque accessibility fallbacks.
- Short Russian outcome labels and visible current state.
- A compact suggestion with explicit replace, skip and ignore actions.

## Colors

The palette follows macOS appearance and the user's accent. Dynamic NSColor values are authoritative; fixed hex approximations and synthetic tonal ramps are not part of this system. Native roles are recorded in the sidecar because they cannot truthfully be encoded as CSS color primitives.

### Primary

- **System accent** (`NSColor.controlAccentColor`): selected sidebar background, with alpha (0.16). Native controls supply their own system states.

### Neutral

- **Primary text** (`NSColor.labelColor`): headings, labels, sidebar text and suggestion text.
- **Secondary text** (`NSColor.secondaryLabelColor`): explanatory copy, metadata, footers and decorative section icons.
- **Shared group tint** (`NSColor.controlBackgroundColor`, alpha 0.35): groups over the shared window material in the normal transparency mode.
- **Opaque group** (`NSColor.controlBackgroundColor`): groups when Reduce Transparency or Increase Contrast is enabled.
- **Opaque window** (`NSColor.windowBackgroundColor`): window, sidebar and popup fallback when either accessibility option is enabled.
- **Contrast border** (`NSColor.separatorColor`): a one-point border only with Increase Contrast.

### Named Rules

**The System Color Rule.** Resolve semantic colors in the effective appearance; never freeze them to screenshot-derived hex values.

**The Meaningful Status Rule.** Reserve warning and success semantics for actual status. Section symbols stay neutral; color is never the only state signal.

## Typography

**Body and heading font:** macOS system font through `NSFont.systemFont`, rendered as SF on supported systems. SF Symbols supply interface imagery; no added display face or icon font.

The frontmatter records the reusable point sizes and weights. Page headings use the headline role; group and status headings use title; main copy and navigation use body; supporting copy uses detail; footers and small identity metadata use their respective smaller roles. Suggestion text uses its separate semibold role. Sidebar selection changes body weight from regular to semibold. The sidebar app name is also semibold (16 pt). Native text fields and buttons keep AppKit defaults where code does not set a font.

**The Plain Label Rule.** Name outcomes in short familiar Russian: “Раскладка”, “Опечатки”, “Мой словарь”, “Горячие клавиши”, “Исключения”, “Доступ macOS”, “Вид и запуск”, “О приложении”. Avoid monitoring/engine jargon, decorative metrics and repeated feature summaries.

Wrapping explanatory labels resist vertical compression. Let text determine content height rather than shrinking type to fit.

## Layout

Settings open at the frontmatter window size and resize down to a minimum (760 × 560 pt). A fixed-width sidebar sits next to a scrollable content column; both begin below the transparent title region (28 pt). The content column fills the remaining width. Section children fill the column; longer pages scroll vertically.

The frontmatter owns the current content margin, section gap and group inset values. The former recorded 16-point vertical group gap has been reconciled to the implemented section spacing. Group heights follow their content; the `card(height:)` argument currently imposes no fixed height. Do not derive minimum heights from those unused arguments.

The first “Раскладка” view presents current state and the “Исправлять раскладку” NSSwitch, then the safe local example. Double-Shift help and sound follow. Advanced settings live on their own pages; this is the current settings composition, not a universal layout for every future surface.

The spelling panel stays in the top-right corner of the editor's display with a 12 pt inset from the usable screen area. It does not follow the caret. Width is 330 pt, bounded by the visible screen; the minimum height is 132 pt and grows vertically from fitting content. The stack uses the popup spacing token and the action row uses a gap (10 pt). Long suggestions wrap instead of widening the panel.

## Elevation & Depth

Real `NSVisualEffectView` materials provide depth. The window uses `.underWindowBackground` with `.behindWindow` blending; the sidebar uses `.sidebar` with `.withinWindow`; the suggestion uses `.popover` with `.behindWindow`. All effects use `.active` state.

Groups use the shared group tint over the window instead of stacking blur layers: their `.contentBackground` effect is configured but hidden. Groups have no shadows. The floating suggestion panel uses the native `NSPanel.hasShadow`; AppKit owns its geometry, with no invented shadow token.

**The Shared Material Rule.** Use one shared window backdrop and tinted groups; do not layer an independent blur inside every group.

**The Opaque Accessibility Rule.** Reduce Transparency or Increase Contrast hides material effects and removes the translucent group tint. Use opaque semantic fallback colors; Increase Contrast also adds the separator border. Refresh on accessibility-display changes and effective-appearance changes. Content remains fully opaque.

## Shapes

Groups use the 12 pt surface radius; suggestion and quick-panel surfaces use 16 pt and clip to bounds. Popover surfaces have a subtle half-point semantic border; Increase Contrast uses one point. The window and sidebar material views do not add a custom corner radius. Selected sidebar rows use their own softer rounded inset (2 pt on each side). Native window chrome, buttons, fields, switches and segmented controls retain their AppKit shapes.

The flat language-key A/Я mark retains KeySwitch's integrated switching symbol. The menu bar uses template switching arrows when ready, a pause symbol when paused and a warning symbol when permission or monitoring is unavailable.

## Components

### Buttons and switches

Native and direct. Use `NSButton` with system rounded bezels for actions; preserve platform keyboard focus, disabled behavior and control sizing. Persistent binary settings use regular-size `NSSwitch`, paired with a visible row label and an accessibility label. Application feature profiles remain native checkboxes. Do not restyle switches as custom web controls.

### Cards / Containers

Quiet tinted groups with the frontmatter radius and insets. Use `MaterialSurface(role: .group)` and content-driven vertical stacks. Separate related controls with native separators where implemented. No decorative group shadows.

### Inputs / Fields

Native `NSTextField` for the local example and native editors for vocabulary and correction rules. The example starts with `ghbdtn`; “Исправить” displays a local result and explains that it does not test external editors. Keep this permission boundary explicit.

The personal dictionary retains its searchable row editor. Saving a rule is explicit; invalid rule drafts block navigation and remain visible. Invalid dictionary drafts block navigation/export and remain available for correction. Snippets reuse this editor with a global switch, dedicated field labels, phrase-specific validation and visible saved/disabled/error feedback; they do not add a navigation section.

### Navigation

A native sidebar with SF Symbols and the current labels from the Plain Label Rule. The selected item uses the system accent tint, semibold text and native on/off state; text remains primary neutral. “О приложении” and version information sit at the foot. Page content scrolls independently. Changing spelling mode updates its explanatory caption in place and preserves keyboard focus.

Menu-bar-only presentation remains the default, including while settings are visible. Optional Dock presence follows its persistent setting in “Вид и запуск”. Closing or minimizing settings hides the window rather than quitting the app.

### Application rules and manual actions

Application rules distinguish full legacy exclusions from partial automatic feature profiles. Preserve the selected application's identity after edits. Manual commands remain in their separate menu and configurable “Горячие клавиши” page; visual refresh does not change command eligibility or safety checks.

### Spelling suggestion

A nonactivating floating native panel. Show the word and suggestion, then contextual keyboard help, then two actions: “Заменить” and “Пропустить”. A labelled overflow control opens a native menu containing “Не предлагать это слово”. Menu tracking preserves the pending suggestion without activating the editor's document or bypassing suffix validation. Do not capture a default Return key equivalent for Replace.

Double Shift applies a suggestion only when that configured mode permits it; Esc skips. Help communicates that replacing remains available only until subsequent input. Result states hide the action row and use clear success or unconfirmed-replacement copy. Ignore offers “Отменить исключение”; undo restores future checking. Announce suggestion and result changes through native accessibility announcements. Successful replacement feedback dismisses after 2 seconds; unconfirmed replacement feedback after 6 seconds.

## Do's and Don'ts

### Do:

- **Do** use dynamic AppKit colors, real native materials and SF system typography.
- **Do** preserve opaque Reduce Transparency and Increase Contrast fallbacks.
- **Do** keep the first settings view focused on current state, its switch and the local example.
- **Do** let supporting text and suggestions wrap and grow vertically.
- **Do** keep permission, invalid-draft, disabled and replacement-result states explicit.
- **Do** preserve KeySwitch's A/Я identity and its native menu-bar state symbols.

### Don't:

- **Don't** convert semantic NSColor values into fixed screenshot colors or fake CSS materials.
- **Don't** stack independent blur layers inside groups or add group shadows.
- **Don't** fade content to make a surface look translucent.
- **Don't** restore the superseded purple gradient and glossy identity.
- **Don't** imply that the safe local example verifies external editor compatibility.
- **Don't** change product logic, permission boundaries or keyboard navigation as a styling shortcut.

## Approved glass refinement — 17 October 2026

The selected web study is translated into AppKit, using real system materials and the user's existing appearance setting. The sidebar presents a larger A/Я mark above navigation. The first page uses “Печатайте свободно.”, the current truthful readiness state, layout/sound switches and “Попробуйте сами”. All eight settings pages remain available.

A primary click on the status icon opens a transient native NSPopover with live readiness, a persistent layout switch, an actionable permission button when needed, settings and “Ещё действия…”. A secondary click retains the complete original menu. Opening the quick panel explicitly invalidates any pending edit; automatic spelling feedback continues to use a nonactivating NSPanel and never opens the quick panel.

While the quick panel is open, local and global mouse-down monitors explicitly close it for clicks outside the panel and status button, including the desktop. Events pass through unchanged. The status button retains its own mouse-up toggle to avoid reopening on the same click. Monitors are removed when the popover finishes closing or the application terminates.

Panel placement does not authorize an edit. The existing current-field, suffix, caret, input-source and readback checks still determine whether a replacement is allowed. The panel does not acquire key focus when it appears. Escape and double Shift retain the user's configured behavior. Feedback remains in the same top-right corner after a result changes the panel size.

The surface honors Reduce Transparency and Increase Contrast; quick-panel animation honors Reduce Motion. Native AppKit controls and accessibility announcements remain in use.
