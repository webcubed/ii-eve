# AGENTS.md — ii-eve Quickshell Dotfiles

Working guide for AI models editing this codebase. Read this before making changes.

**IMPORTANT: When you discover new patterns, conventions, or gotchas — or when new services/features are added — UPDATE THIS FILE. It is a living document. Future models depend on it being accurate and current.**

## Quick Reference

| What | Where |
|------|-------|
| Shell entry | `shell.qml` |
| Config singleton | `modules/common/Config.qml` → `Config.options.*` |
| Paths | `modules/common/Directories.qml` |
| Services | `services/*.qml` (72+ singletons) |
| Bar components | `modules/ii/bar/BarComponent.qml` + `modules/ii/bar/*.qml` |
| Component registry | `modules/common/BarComponentRegistry.qml` |
| Extensions | `services/ExtensionManager.qml`, `~/.config/illogical-impulse/extensions/` |
| Settings app | `settings.qml`, `modules/settings/` |
| Scripts | `scripts/` (bash/python, called via `Process`) |

## Architecture

```
shell.qml
  ├─ MaterialThemeLoader.reapplyTheme()
  ├─ FirstRunExperience.load()
  ├─ ConflictKiller.load()
  └─ PanelFamilyLoader ("ii" or "waffle")
       └─ IllogicalImpulseFamily.qml
            ├─ Bar.qml → BarContent.qml → BarComponent.qml (Repeater)
            ├─ SidebarPolicies (left: AI, booru, translator)
            ├─ SidebarDashboard (right: notifications, toggles, wifi, BT)
            ├─ Background, Overlay, OSD, Dock, Lock, Overview...
            └─ ...all other panels
```

## File Conventions

### Services (`services/*.qml`)

Every service is a singleton:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common    // Config, Directories, Appearance, Translation
import qs.services          // Other services (Audio, Network, etc.)
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // Reactive config binding:
    property bool myEnabled: Config.options?.mySection?.enabled ?? false

    // Process for external commands:
    Process {
        id: myProc
        stdout: StdioCollector {
            onStreamFinished: root.handleOutput(this.text)
        }
    }

    // Fire-and-forget:
    Quickshell.execDetached(["notify-send", "title", "body"])

    // Init:
    Component.onCompleted: { /* ... */ }
}
```

**Naming**: PascalCase filename matches the singleton name. `Audio.qml` → `Audio`, `BatteryService.qml` → `BatteryService`.

### Adding a New Service

1. Create `services/MyService.qml` with the singleton pattern above.
2. Add config section in `Config.qml` if needed.
3. Touch it in `shell.qml` `Component.onCompleted` if it must initialize early.
4. Reference it anywhere as `MyService.property` (auto-imported via `qs.services`).

### Bar Components

**To add a new bar widget:**

1. Create the QML file in `modules/ii/bar/MyWidget.qml` (horizontal). Optionally create `modules/ii/verticalBar/VerticalMyWidget.qml`.

2. Register in `BarComponentRegistry.qml`:
   ```qml
   { id: "my_widget", icon: "icon_name", title: "My Widget" }
   ```

3. Add to `BarComponent.qml`:
   ```qml
   // In compMap:
   "my_widget": [myWidgetComp, myWidgetCompVert],

   // Component definitions:
   Component { id: myWidgetComp; MyWidget { vertical: rootItem.vertical } }
   Component { id: myWidgetCompVert; Vertical.MyWidget {} }
   ```

4. Optionally add default position in `Config.qml` under `bar.layouts`.

**compMap array order**: `[horizontal, vertical, expressiveHorizontal, expressiveVertical, minimalHorizontal, minimalVertical]`

### Extensions

Extensions live in `~/.config/illogical-impulse/extensions/installed/<name>/`. Each has an `extension.json`:

```json
{
  "name": "My Extension",
  "version": "1.0.0",
  "contributes": {
    "barComponents": [{ "identifier": "ext_widget", "qml": "Widget.qml" }],
    "services": [{ "id": "ext_service", "qml": "Service.qml" }],
    "overlayWidgets": [{ "identifier": "ext_overlay", "qml": "Overlay.qml" }]
  }
}
```

Extension components are loaded dynamically via `ExtensionManager.loadExtensionQmlComponent("file://" + path + "?_t=" + Date.now())`. The `?_t=` cache-buster is required.

### Config (`Config.qml`)

Config is a `FileView` + `JsonAdapter` wrapping `~/.config/illogical-impulse/config.json`.

**To add a new config section:**

```qml
// Inside the root JsonAdapter block:
property JsonObject mySection: JsonObject {
    property bool enabled: false
    property string someValue: "default"
    property int someNumber: 42
}
```

**Reference in code:**
```qml
property bool isEnabled: Config.options?.mySection?.enabled ?? false
```

**Write config:**
```qml
Config.options.mySection.enabled = true   // Auto-debounced write (75ms)
```

Config writes are debounced. The `ready` property must be true before reading.

### Scripts (`scripts/`)

Called from QML via `Process`:

```qml
Process {
    id: myProc
    command: ["python3", FileUtils.trimFileProtocol(`${Directories.scriptPath}/my_script.py`), arg1, arg2]
    stdout: StdioCollector { onStreamFinished: { /* this.text */ } }
}
```

Scripts are standalone bash/python files. Use `Quickshell.shellPath("scripts/relative/path")` to resolve paths.

## Critical Gotchas

### 1. Qt Key Handlers — Use Arrow Function Syntax

```qml
// CORRECT:
Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Escape) { /* ... */ }
    event.accepted = true
}

// WRONG — will silently fail:
Keys.onPressed: {
    if (key === Qt.Key_Escape) { ... }  // `key` undefined
}
```

### 2. Animation Leaks — Never Use Inline NumberAnimation

Shared animation objects leak when triggered rapidly. Always create fresh instances:

```qml
// WRONG — shared object, causes visual glitches:
Behavior on x { NumberAnimation { duration: 200 } }

// CORRECT — fresh instance per trigger:
Behavior on x {
    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
}
```

### 3. Layout.fillWidth in ListView/Repeater Delegates

Does not work — delegates have no fixed parent width to fill:

```qml
// WRONG in a ListView delegate:
Item { Layout.fillWidth: true }

// CORRECT:
Item { width: listView.width }
```

### 4. MouseArea in ColumnLayout Eats Events

A MouseArea inside a ColumnLayout captures all mouse events, blocking siblings:

```qml
// FIX: propagate events
MouseArea {
    acceptedButtons: Qt.NoButton
    propagateComposedEvents: true
    onClicked: (mouse) => mouse.accepted = false
}
```

For click handlers, use `Qt.PointingHandCursor` and wrap in an `Item` with `Layout.preferredHeight`:

```qml
Item {
    Layout.preferredHeight: headerRow.implicitHeight
    RowLayout { id: headerRow; /* content */ }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { /* action */ }
    }
}
```

### 5. Property Name Conflicts

Do not shadow QML built-in properties. `Item` has `enabled`, `visible`, `width`, `height`, `children`, etc.

```qml
// WRONG — overrides Item.enabled:
readonly property bool enabled: Config.options?.foo?.bar ?? false

// CORRECT — use a unique name:
readonly property bool myFeatureEnabled: Config.options?.foo?.bar ?? false
```

### 6. Rectangle Does Not Have topRadius/bottomRadius

```qml
// WRONG:
Rectangle { topRadius: 10; bottomRadius: 5 }

// CORRECT — use uniform radius:
Rectangle { radius: 10 }
// Or use a custom Shape for asymmetric corners.
```

### 7. Singleton Lazy Loading

Singletons load on first reference. To force early init, touch a property in `shell.qml`:

```qml
Component.onCompleted: {
    PolkitService.agent  // Forces load
}
```

### 8. Config Read Timing

Do not read `Config.options.*` before `Config.ready === true`. Guard with:

```qml
readonly property bool myValue: Config.ready ? Config.options?.mySection?.value ?? false : false
```

### 9. Import Paths

Modules resolve from directory structure automatically (no `qmldir` files). Import `qs.modules.ii.bar` to access types in `modules/ii/bar/`.

Sub-subdirectories (like `modules/ii/bar/cards/`) are imported by their parent:
```qml
import "../cards"   // from modules/ii/bar/weather/WeatherPopup.qml
import "./cards"    // from modules/ii/bar/BatteryPopup.qml
```

### 10. Reuse Process for Sequential Operations

Store pending context as properties, not closures:

```qml
Process {
    id: proc
    property string _pendingId: ""
    onExited: (code, _) => { handleResult(_pendingId) }
}
proc._pendingId = "item-1"
proc.exec(["cmd", args])
```

### 11. Background Widget Culling

Background widgets (`modules/ii/background/widgets/`) are always loaded when enabled. To reduce GPU/CPU usage, use the cull-on-occlude feature:

- **Config**: `Config.options.background.widgets.cullWhenOccluded` (bool)
- **State**: `GlobalStates.widgetsOccluded` (true when overview, app launcher, search, lock screen, OSK, etc. are open)
- When cull is enabled, `FadeLoader.shown` bindings in `Background.qml` add `&& !bgRoot.widgetsOccluded`
- `AbstractBackgroundWidget.qml` opacity also checks this, so even extension-loaded widgets are culled

### 12. Background Widget Grid Placement

Widgets can be snapped to a grid instead of free-positioned:

- **Config**:
  - `Config.options.background.widgets.grid.enabled` (bool)
  - `Config.options.background.widgets.grid.columns` (int, default 6)
  - `Config.options.background.widgets.grid.rows` (int, default 4)
- Each widget config entry also has `gridColumn` and `gridRow` for initial placement
- When grid is enabled and widgets are unlocked, a grid overlay (dashed white lines) appears while dragging widgets
- The grid overlay is drawn on a `Canvas` inside `WidgetCanvas` with `z: 100` to render above widgets
- A `Connections` handler on `bgRoot.draggingWidget` triggers immediate repaint when dragging starts/ends
- A polling `Timer` (200ms) keeps the overlay repainted while visible
- Widget hitbox (cell highlight) appears at the current drag position
- **Now enabled**: config has `cullWhenOccluded: true`. Additionally, bar
  widgets that tick every second (`BarComponent.liveUpdateIds`: clock, date,
  system_monitor, network_speed, music_player, timer) unload entirely while
  `GlobalStates.fullscreenActive` (the bar is covered in fullscreen).
- When grid is enabled, widgets snap to grid cells on release
- `AbstractBackgroundWidget.qml` computes `gridCellWidth`/`gridCellHeight` from `scaledScreenWidth`/`scaledScreenHeight`
- Grid position is saved back to config (`configEntry.gridColumn`/`gridRow`) on drag release

### 13. AI Attachments Go Through `scripts/ai/attach.py`

Every file the AI panel touches runs `python3 scripts/ai/attach.py <cmd>`:
`probe <path>` (metadata JSON), `extract <path>` (text JSON), `inject <body> <spec>`
(write base64/text/extract into the request body at `@@II_ATT_n@@` markers),
`search <rootsJson> <query> <limit> <kindsJson>`, `peek <path> <maxChars>`.
If this file is missing, stdout is empty, `JSON.parse` throws in `Ai.qml`, and
every attach fails with "Could not read that file." — **always print JSON on
stdout for probe/extract/search/peek** (errors as `{"error": ...}`, `inject`
exits non-zero with a plain message instead).

Screen snip → attach chain: `AiChat` emits `GlobalStates.snipForAiRequested()`
→ `RegionSelector.askAI()` sets `action = AskAI` and opens → `RegionSelection.snip()`
pipes the crop to `wl-copy` and calls `Ai.handleClipboardAndAttach()` → cliphist
entry decoded → `Ai.attachFile()`. `GlobalStates` carries signals, not just
booleans — cross-component requests go through it.

Snip → annotate chain (built-in editor): entry via `SnipAction.Edit` (toolbar
`draw` toggle in `OptionsToolbar`, RMB during a Copy snip, ipc `region annotate`,
or GlobalShortcut `regionAnnotate`) → `RegionSelection.cropForAnnotation()`
**copies the FULL screen capture** (`cp` — not a crop) to
`screenshotTemp/annotate-<ts>.png` and emits
`annotationReady(path, screen, region)` with the selected rect in image
(physical) px → `RegionSelector` sets path/screen/`annotateRegion`, dismisses
the selector first, and opens `AnnotationEditor` on the next tick
(`Qt.callLater`) — layer-shell surfaces must never coexist (same reason as
Translate). The editor seeds a draggable `crop` (image px, `initCrop()` on
image Ready + region change + visible) shown as a `cropOverlay` **sibling of
`view`** (never a child — `grabToImage` must not bake the chrome in): dim
rects outside the crop, border, 8 handles (4 corners + 4 sides, min 80 image
px). Tools: pen/highlight/arrow/line/dash/dot/rect/ellipse/triangle/text on a
`Canvas`; export (`withExported`) grabs the whole view, then a reused Process
magick-crops it to `crop` (skipped when crop ≈ full) — `doCopy`/`doSave`/
`doExternal` all go through it, so the external editor (satty via
`useSatty ? satty : swappy`) receives the cropped, annotated result. RMB→Edit
no longer remaps Edit→Copy on LMB: only `Copy + RMB` flips to Edit.
Drop-ups: `property string openMenu` (`"" | "shape" | "arrow"`) drives ONE
full-screen `menuHost` (z:11) that owns both menus + its close-backdrop —
menus overflow the toolbar Row, and QML hit-testing only descends into items
whose ANCESTORS contain the point, so a menu parented under the toolbar is
unclickable (learned the hard way). `shapeList` = rect/ellipse/triangle
(ellipse drawn as 4 beziers — Qt Canvas has no `ctx.ellipse`); `lineList` =
arrow/line/dashed/dotted (dashes via `ctx.setLineDash`, reset after).
Per-session reset: `resetState()` runs on `visible` AND `imagePath` change,
clears shapes/draft/openMenu/crop, and MUST call `canvas.requestPaint()` —
the Canvas bitmap survives hide/show, so without the repaint the previous
snip's drawings stay on screen over the new capture.

### 14. ToolbarTabBar Sizes Unstretched Toolbars via `implicitWidth`

`ToolbarTabBar.implicitWidth` must stay `contentItem.implicitWidth` (natural
tab width), never `0`: `Toolbar` derives its pill width from
`toolbarLayout.implicitWidth`, so a 0 collapses the pill in toolbars that are
NOT externally stretched (region selector Row, cheatsheet) — the tab Flickable
gets ~0 width (tabs invisible) and the unclipped `activeIndicator` spills over
neighboring buttons (e.g. the selector's close Fab). Stretched contexts (sidebar
`Layout.fillWidth`) are driven by the parent layout and unaffected by this
value. If tabs look clipped or a phantom pill appears behind a neighbor, check
this first.

### 15. Hyprland Events Are Native — No socat Needed

`Connections { target: Hyprland; function onRawEvent(event) {...} }` streams
socket2 events as `event.name`/`event.data` (precedent: `Brightness.qml`).
The `fullscreen` event (data `0/1`) drives `GlobalStates.fullscreenActive`,
startup-synced via `hyprctl activewindow -j`. Per-second work is gated on it:
`ResourceUsage.pollingVisible` (bar open + not locked + not fullscreen, or the
background resources widget visible, or dashboard open),
`WorldClock.widgetVisible` (enable flag + `widgetsVisible` + not fullscreen),
and `BarComponent.cullLiveUpdates`. `DateTime`'s uptime timer runs at 60 s
with `triggeredOnStart` — never tie it to `resources.updateInterval`.
ResourceUsage merges its temp+GPU probes into one `hwProbeProc` fork.

## Module Import Reference

```
qs                          → Root ii/ directory
qs.services                 → services/
qs.modules.common           → modules/common/
qs.modules.common.widgets   → modules/common/widgets/
qs.modules.common.functions → modules/common/functions/
qs.modules.ii.bar           → modules/ii/bar/
qs.modules.ii.bar.weather   → modules/ii/bar/weather/
qs.modules.ii.bar.dynamicIsland → modules/ii/bar/dynamicIsland/
qs.modules.ii.sidebarDashboard  → modules/ii/sidebarDashboard/
qs.modules.ii.sidebarPolicies   → modules/ii/sidebarPolicies/
qs.modules.ii.verticalBar   → modules/ii/verticalBar/
qs.modules.ii.background    → modules/ii/background/
qs.modules.ii.overlay       → modules/ii/overlay/
qs.modules.ii.dock          → modules/ii/dock/
qs.modules.ii.overview      → modules/ii/overview/
qs.modules.ii.lock          → modules/ii/lock/
qs.modules.ii.wallpaperSelector → modules/ii/wallpaperSelector/
```

## Key Services Cheat Sheet

| Service | Purpose |
|---------|---------|
| `Config` | Read/write `config.json` |
| `Persistent` | Read/write `states.json` (runtime state) |
| `Appearance` | Colors, fonts, rounding, animations, sizing |
| `Directories` | All filesystem paths |
| `Translation` | i18n via JSON locale files |
| `GlobalStates` | Panel open/close booleans |
| `GlobalFocusGrab` | Click-outside-to-close via Hyprland |
| `BarComponentRegistry` | Available bar components |
| `ExtensionManager` | Extension lifecycle |
| `Notifications` | Notification storage + popup |
| `Audio` | PipeWire volume control |
| `Network` | nmcli wifi/ethernet |
| `BluetoothStatus` | Bluetooth adapter + device state |
| `Battery` | UPower battery info |
| `HyprlandData` | Hyprland IPC window/monitor data |
| `MprisController` | Media player control |
| `Weather` | Weather data (wttr.in / open-meteo) |
| `Cliphist` | Clipboard history |
| `LauncherSearch` | Search results (apps, math, commands, web) |
| `AppSearch` | Desktop entry search |
| `TailscaleService` | Tailscale VPN management (connect/disconnect, exit nodes, peers) |
| `DockerService` | Docker container management (start/stop/restart, events, memory) |
| `VpnService` | Multi-provider VPN (NetworkManager, NordVPN, ProtonVPN) |
| `EmailService` | Gmail OAuth integration (sync, send, mark read, trash) |
| `NotesService` | File-based JSON notes (add/update/delete) |
| `TimerService` | Pomodoro cycles, persisted stopwatch (laps via `stopwatchRecordLap()`), and standalone countdown timer (`countdownSet(minutes)`, `countdownToggle()`, `countdownReset()`) |
| `CalendarService` | khal/CalDAV calendar integration (Google Calendar via vdirsyncer). Events loaded via `khal list --json`. Provides `getTasksByDate(date)` and `addItem(item)`/`removeItem(item)`. |
| `Todo` | File-based todo list (`todo.json`). Supports optional `deadline` field for calendar integration. `addTask(desc, deadline)`, `getTasksWithDeadline(date)`. |

## Google Calendar Integration

Calendar events sync via **vdirsyncer** → **khal** → **CalendarService**.

**Setup:**
1. `uv tool install vdirsyncer khal` (or `sudo pacman -S vdirsyncer khal`)
2. Configure `~/.config/vdirsyncer/config` with Google OAuth credentials
3. Run `vdirsyncer discover` (opens browser for auth)
4. Run `vdirsyncer sync` to pull events
5. Configure `~/.config/khal/config` with calendar paths

**Config files:**
- `~/.config/vdirsyncer/config` — vdirsyncer pairing config (Google ↔ local ICS)
- `~/.config/khal/config` — khal calendar discovery config
- `~/.vdirsyncer/google_token` — OAuth token (auto-generated)

**Auto-sync:** Add to crontab: `*/15 * * * * vdirsyncer sync >> /tmp/vdirsyncer.log 2>&1`

**Gotcha:** CalendarService uses `dd.MM.yyyy` date format for khal. The khal `longdateformat` must match.

## Sidebar Pages (Left Sidebar Tabs)

The left sidebar (`SidebarPoliciesContent.qml`) has tabs controlled by config flags:

| Tab | Config Flag | Icon | Component |
|-----|-------------|------|-----------|
| AI | `Config.options.policies.ai !== 0` | `neurology` | `AiChat.qml` |
| Translator | `Config.options.policies.translator !== 0` | `translate` | `Translator.qml` |
| Media | `Config.options.policies.player !== 0` | `music_note` | `SidebarPlayerControl.qml` |
| Wallpapers | `Config.options.policies.wallpapers !== 0` | `wallpaper` | `WallpaperBrowserUI.qml` |
| Anime | `Config.options.policies.weeb !== 0` | `bookmark_heart` | `Anime.qml` |
| Tailscale | `Config.options.policies.tailscale !== 0` | `hub` | `TailscalePage.qml` |
| Docker | `Config.options.policies.docker !== 0` | `inventory` | `DockerPage.qml` |
| VPN | `Config.options.policies.vpn !== 0` | `shield` | `VpnPage.qml` |
| Email | `Config.options.policies.email !== 0` | `mail` | `EmailPage.qml` |
| Notes | `Config.options.policies.notes !== 0` | `sticky_note_2` | `NotesPage.qml` |
| Phone | `Config.options.policies.phone !== 0` | `smartphone` | `phone/Phone.qml` |
| Extensions | Dynamic | Dynamic | Extension-provided |

**Sidebar navigation:**
- `Ctrl+Tab` / `Ctrl+Shift+Tab` — next/prev tab
- `Ctrl+PageDown` / `Ctrl+PageUp` — alternative next/prev
- Tab / Shift+Tab — next/prev (no modifier, when no text input focused or input is empty)
- Left / Right arrows — prev/next tab (same conditions)

**Tab label display:** `maxTextTabs` on `ToolbarTabBar` controls when tabs switch from icon+text to icon-only. Default: 3 (collapsed) / 4 (extended sidebar).

To add a new sidebar tab:
1. Create `modules/ii/sidebarPolicies/MyPage.qml`
2. Add `property bool myPageEnabled: Config.ready && (Config.options.mySection?.enabled ?? false)` to `SidebarPoliciesContent.qml`
3. Add entry to `tabButtonList` array
4. Add `Component { id: myPage; MyPage {} }` block
5. Add to `contentChildren` array

## Cheatsheet Tabs

The cheatsheet (`modules/ii/cheatsheet/Cheatsheet.qml`) has built-in tabs plus extension-contributed tabs.

**Built-in tabs:**
| Tab | Icon | Component |
|-----|------|-----------|
| Timetable | `calendar_month` | `CheatsheetTimetable.qml` — weekly timetable from khal events with time slots, current time indicator, auto-scroll |

**Extension tabs:** Contributions via `ExtensionManager.getContributionPoint("cheatsheet")`.

To add a built-in tab:
1. Create `modules/ii/cheatsheet/MyTab.qml`
2. Add a `Component { id: myTabComponent; MyTab {} }` in `Cheatsheet.qml`
3. Add to `builtInTabs` array: `{ key: "mytab", icon: "icon_name", name: Translation.tr("Tab Name"), component: myTabComponent }`

**Arrow key navigation in cheatsheet:**
- Left/Right arrows: switch tabs
- Ctrl+PageDown/PageUp or Ctrl+Tab/Backtab: switch tabs (alternative)
- Esc: close cheatsheet

## Bottom Widget Group Navigation

The bottom widget group (`modules/ii/sidebarDashboard/BottomWidgetGroup.qml`) has three tabs: Calendar (0), Todo (1), Timer (2).

**Keyboard navigation:**
- **Up/Down arrows:** switch between Calendar/Todo/Timer tabs
- **Left/Right arrows:** when on Timer tab, switch between Pomodoro/Stopwatch/Countdown sub-tabs
- **Ctrl+PageDown/PageUp:** switch main tabs (legacy)

## Testing Changes

## Testing Changes

Quickshell hot-reloads on file changes. To test manually:

```bash
# Start shell (kills existing instance first):
qs -p ~/.config/quickshell/ii &

# Check for errors:
qs -p ~/.config/quickshell/ii 2>&1 | grep ERROR

# The shell logs to: /run/user/1000/quickshell/by-id/<id>/log.qslog
```

Configuration loads on startup. If the shell fails to start, the error chain shows exactly which file and line has the problem.

## Git Workflow

The git repo is at `/home/webcubed/Projects/ii-eve/`, synced to `~/.config/quickshell/ii/`. The local branch is typically 30+ commits ahead of `upstream/main` (`github.com/djOB2EOTWQW1/ii-eve`).

Always check `git status` and `git diff` before committing. Never commit secrets or API keys.

## Updating This File

## Hermes Agent (AI Coding Assistant)

Installed at `/home/webcubed/.hermes/hermes-agent/` (v0.20.4). Config at `/home/webcubed/.hermes/config.yaml`.

**Providers configured:**
- **Google Gemini** (default): `gemini-2.5-flash` via `GOOGLE_API_KEY` in `.env`
- **Groq** (STT + fallback): `whisper-large-v3-turbo` for STT, `llama-3.3-70b-versatile` for chat
- **Cerebras** (fast fallback): `gpt-oss-120b` via `CEREBRAS_API_KEY` in `.env`

**Model aliases:**
| Alias | Model | Provider | Limits (free) |
|-------|-------|----------|---------------|
| `flash` | gemini-2.5-flash | Gemini | 1,500 req/day |
| `pro` | gemini-2.5-pro | Gemini | 50 req/day |
| `llama` | llama-3.3-70b-versatile | Groq | 1,000 req/day |
| `cerebras` | gpt-oss-120b | Cerebras | 1M tokens/day, 5 RPM |
| `gpt-oss` | openai/gpt-oss-120b | Groq | 1,000 req/day |

**Usage:**
- Start interactive chat: `hermes chat`
- Switch model: `hermes model` or `/model flash` in chat
- Working directory: `~` (home directory)

---

**This file is a living document.** Every model that works on this codebase should update it when:

- **New services** are added → add them to the Key Services table
- **New gotchas** are discovered → add them to Critical Gotchas
- **New patterns** are used → document them in the relevant section
- **New config sections** are added → list them in the Config section
- **New module paths** are used → add them to Module Import Reference
- **Files move** → update the Quick Reference table

Format: append to the relevant section, or create a new section if nothing fits. Keep entries concise — one line per item with a code example if helpful.
