# Ramen Bar

Plugin tested and confirmed working on Omarchy 4.0.3-1 

A clean, pillbox-style status bar for Omarchy, forked from the stock
`omarchy.bar` layout engine.<br>
Every widget floats in its own rounded pill,
and the bar ships with disk, memory, and CPU utilization readouts built in.

<img width="1920" height="36" alt="screenshot-2026-09-13_17-17-20" src="https://github.com/user-attachments/assets/16f54d83-52f9-4204-a6c6-284e85925a37" />
<img width="1920" height="36" alt="image" src="https://github.com/user-attachments/assets/de8a6924-a04c-42d7-aff7-d48528037c0c" />
<img width="1920" height="36" alt="image" src="https://github.com/user-attachments/assets/2cf1253c-b326-4115-b69e-4c7cd45b8efc" />

## Signature features

Ramen started as the stock `omarchy.bar` with a pillbox makeover, but a handful
of behaviors are genuinely unique to this bar.

**Drag-and-drop reordering, rendered-space aware.** Grab any pill and drop it
before or after any neighbor; an accent drop-marker tracks the live slot as
you drag. Drops resolve against what the bar is actually *rendering*, not just
what's persisted in `shell.json` — so you can park a widget directly to the
right of the auto-injected CPU/disk/mem readouts that never existed in your
config. The first drag of an injected pill pins the whole arrangement to the
config file; from then on it moves like any other widget.

**A light/dark "print" toggle.** Double-left-click empty bar space to flip the
pill surfaces between the translucent theme pill ("light" look) and a stark
black surface ("dark" look). Text and icons stay on the light side in both
modes, so glyph contrast never breaks no matter which wallpaper you're on. The
change rolls across the bar as a coordinated wave — left → right away, right →
left on the way back — because every pill runs its own wave offset from its
position in the row.

**Edge docking with a preview.** Press-and-hold on empty bar space and glide
toward an edge: the strongest candidate (a diagonal screen split decides)
lights up as a ghost slab, and releasing docks the bar there. Hiding the bar
parks it just past the edge instead of destroying the surface, so revealing it
again costs ~20 ms, not a full teardown.

**Bundled widgets that follow the widget, not its vendor.** Workspaces
(Chinese numerals 一…九), an inward-opening tray drawer, red-accented
indicators, warm battery colors, and the accent-tinted menu glyph ship inside
this plugin and trigger on the dot-suffix of whatever widget id a layout
mentions — stock ids, clones, or anything else.

**Live system stats, injected first.** `disk`, `mem`, and `cpu` always appear
in the left section on a 5-second cadence and open `gdu`/`btop` when clicked.
When the bar is pinned to a screen edge, they reflow into a stacked,
center-aligned icon-above-percentage column instead of a squeezed single line.

**Package install, on tap.** An injected button opens Arch-repo, AUR, and
Flatpak install TUIs straight from the bar — every row gated on what's
actually installed, so the Flatpak option quietly disappears where flatpak
isn't.

Install with:

```bash
omarchy plugin add https://github.com/chapaghetti/ramen-bar.git --enable
omarchy restart shell
```

Remove with:

```bash
omarchy plugin remove ramen.bar
omarchy refresh shell
```

`kind: "bar"` means enabling it makes it the active bar; the layout comes
from your `~/.config/omarchy/shell.json` as usual.

### Layout adoption

When Ramen Bar loads while you are still on the **stock** Omarchy bar layout,
it adopts its own layout (widgets, position, transparency, gap) and persists
the change to `~/.config/omarchy/shell.json` through the shell's own config
API, stamping `ramenAdopted: true` under `bar:`. This is what makes
`omarchy refresh shell` followed by the install above land right back on the
Ramen setup. Adoption is **one-shot**: once it has run, widget reorders and
moves you make on the bar are left alone and persist. If your layout is
customized in any way — a command widget, or a left section that doesn't
start with `omarchy.menu` — the bar respects it and changes nothing.

The auto-injected install button (and the cpu/mem/disk readouts) can be
dragged to a new spot like any other widget; the first drag records that
placement in `shell.json`, after which it moves exactly like the rest.

### Bundled widgets

Ramen Bar does not rely on extra plugins for its look. Workspaces, tray,
indicators, and power are **bundled inside this plugin** (`widgets/bundle/`)
and always render their Ramen variants no matter which widget id a layout
references — `omarchy.workspaces`, `acme.workspaces`, or anything else with
the same suffix:

| Family | Ramen variant |
|--------|---------------|
| `menu` | omarchy glyph tinted with the theme accent color |
| `workspaces` | Chinese numerals 一…九 instead of 1…9 |
| `tray` | drawer that reveals **inward** (away from the bar edge) |
| `indicators` | red-accented indicator theme |
| `power` | warm battery colors with percentage emphasized |

Because the override is keyed on the widget's dot-suffix, these work on the
stock first-party widgets, on any clones you have installed, and on a fresh
system with nothing but this plugin. The clock, audio, network, and the
other interactive widgets keep using their normal installed versions.

### Full-fidelity setup (idle + layout, portable)

The bar adoption covers the bar subtree and the bundled widgets cover the
custom look. To also restore your idle lock/screensaver timers, apply the
plugin's own `shell.json` capture, which references only stock `omarchy.*`
widgets and the plugin's own `scripts/`:

```bash
cp ~/.config/omarchy/plugins/ramen.bar/shell.json ~/.config/omarchy/shell.json
omarchy restart shell
```

That file is portable: it works on a stock Omarchy install and needs nothing
but this plugin installed.

- `manifest.json` declares the plugin (`id: ramen.bar`, `kind: bar`) and points at `Bar.qml` as the entry point.
- `Bar.qml` is the bar engine (a modified fork of the Omarchy bar); it also injects the bundled widgets and the system utilization readouts.
- `scripts/` holds the disk/memory/CPU utilization exec scripts baked into the bar.
- `widgets/bundle/` holds the customized workspaces/tray/indicators/power widget sources.
- The bar receives its config from the host shell as a `barConfig` property; the host loads it from `~/.config/omarchy/shell.json`.

## System utilization widgets

`disk`, `mem`, and `cpu` are command modules that run the scripts in
`scripts/` every 5 seconds and are guaranteed to appear in the bar's left
section. You don't need to add them to `shell.json` — the bar injects them
at layout time. If you already have entries with the same ids in your
layout, they win (so you can move them or change their settings).

| Widget | Script | Click |
|--------|--------|-------|
| `disk` | `scripts/disk-usage` — `df -P /` used % | opens `gdu` |
| `mem`  | `scripts/mem-usage` — `free` used % | opens `btop` |
| `cpu`  | `scripts/cpu-usage` — `top` load % | opens `btop` |

The scripts emit `\U000F02CA` / `\U0000EFC5` / `\uf2db` icon glyphs via a
font that covers those codepoints.

Because each readout pairs an icon glyph with a double-digit percentage, they
reflow on vertical (left/right-pinned) bars: the glyph stacks above the number,
both center-aligned, instead of squeezing into a cramped single line. Top and
bottom bars keep the flat `<glyph> <NN>%` label.

To drop the widgets, delete the `ensureSystemStats` injection in `Bar.qml`.

## Package install menu (Flatpak / AUR / repo)

Built into the plugin — no setup. Installing the bar adds a package-button
that opens a popup with three install TUIs:

- **Package (Arch repo)** → the stock `omarchy-pkg-install`
- **AUR** → the stock `omarchy-pkg-aur-install`
- **Flatpak** → the bundled `scripts/omarchy-pkg-flatpak-install` TUI
  (`FLATPAK_INSTALL_REMOTE` overrides the default `flathub` remote)

The bar injects the button into `bar.layout.left` at render time when your
layout has no `pkg-install` entry (place your own anywhere to take over), and
it ships the module and script inside the plugin so no files need copying or
`PATH` tweaks. Rows are gated on what's actually installed (`command -v`), so
the Flatpak option disappears on machines without flatpak and everything
still works.

Optional extra: `contrib/menu-extensions/omarchy-menu.jsonc` → copy to
`~/.config/omarchy/extensions/omarchy-menu.jsonc` to also add *Flatpak* to the
Install **submenu**. See `AGENTS.md` §6.

## Customizing

The bar config lives under the `bar:` key of [`~/.config/omarchy/shell.json`](../../README.md#shelljson-shape). Out of the box the shell uses [`config/omarchy/shell.json`](../../../config/omarchy/shell.json). Once you customize anything via the bar gestures, `omarchy bar ...`, or by editing shell.json directly, your file is canonical — there is no deep-merge.

The bar is configured directly on the bar itself: drag empty bar space (or click-and-hold) to move the bar to another screen edge, double-left-click empty center-bar space to toggle the pill surfaces between the translucent theme pill ("light" look) and stark black ("dark" look) — text/icons stay light in both modes so glyph contrast always holds, and the change sweeps the bar left → right and recedes right → left on the way back; widgets with fixed colors (indicators, battery, the accent-tinted menu glyph) are unaffected), and drag widgets to reorder them. Use `omarchy bar position`, `omarchy bar transparent`, `omarchy bar move`, and `omarchy bar set` from scripts. Enable or disable widgets with `omarchy plugin enable` and `omarchy plugin disable` (widget ids come from `omarchy plugin list`).

Example `shell.json` (bar subtree only shown):

```json
{
  "version": 1,
  "bar": {
    "position": "top",
    "transparent": false,
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left": [
        { "id": "omarchy.menu" },
        { "id": "omarchy.spacer", "size": 12 },
        { "id": "omarchy.workspaces" }
      ],
      "center": [
        { "id": "omarchy.media" },
        { "id": "omarchy.clock", "format": "HH:mm" }
      ],
      "right": [
        { "id": "omarchy.audio" },
        { "id": "omarchy.power" }
      ]
    }
  }
}
```

`centerAnchor` pins one center module to the exact horizontal/vertical center and flanks others around it. Set to an empty string to disable anchoring (the center list is centered as a group).

## Module catalogue

### First-party interactive widgets

| Name | What it does | Interactions |
|---|---|---|
| `omarchy.menu` | Omarchy menu launcher | left = menu · right = terminal |
| `omarchy.workspaces` | Hyprland workspace switcher | left = focus workspace |
| `omarchy.clock` | Date/time label + popup with a month grid, ISO week numbers, and month stepping | left = popup · right = cycle label format · middle = timezone selector |
| `omarchy.media` | MPRIS now-playing — scrolling track + artist, cover-art popup | left = play/pause · middle = next · scroll = prev/next · right = popup |
| `omarchy.indicators` | Manual state indicators | left = indicator action |
| `omarchy.system-update` | Available update indicator | left = update |
| `omarchy.tray` | System tray | hover = reveal drawer · right on chevron = manage |
| `omarchy.weather` | Weather icon + popup with forecast | left = popup · right = full notification |
| `omarchy.microphone` | Mic icon + scroll volume | left = mute toggle · middle = audio panel · scroll = source volume |

| `omarchy.audio` | Volume icon + popup with master slider, output-device picker, per-app mixer | left = popup · right = mute · middle = popup · scroll = volume |
| `omarchy.network` | Wi-Fi/Ethernet icon + popup with Wi-Fi scan, signal, connect, DNS provider selection | left = popup |
| `omarchy.tailscale` | Tailscale status, connection switcher, machine browser, and copy actions | left = popup · right = toggle · middle = refresh |
| `omarchy.agents` | AI coding agent limits with pace, today, last week, and all-time model breakdown | left = panel · right = launch agent · middle = next subscription |
| `omarchy.power` | Battery/AC icon + popup with battery stats, power profiles, and system info | left = popup · right = toggle percentage |
| `omarchy.bluetooth` | Bluetooth icon + popup with device list, connect/disconnect, battery | left = popup · right = toggle radio |
| `omarchy.monitor` | Brightness and laptop display controls | left = popup |

The `omarchy.indicators` widget loads individual bar indicators from `indicators/`. Omit `items` (or set it to an empty array) to show all indicators in the default order, or set `items` to a subset such as `["Dnd", "Reminder", "NightLight"]`. Set `alwaysShow` to `true` to keep inactive indicators visible instead of revealing them only on hover. Multiple `omarchy.indicators` instances are allowed, so different sections can show different subsets.

## Orientation

All widgets work in `top`, `bottom`, `left`, and `right` positions. Popups anchor on the side opposite the bar edge, sliding into the workspace. Vertical bars use 28px width; widgets that show text fall back to compact icon-only forms (e.g. `media` hides its scrolling label), while the util readouts switch to a stacked icon-over-percentage column (see [System utilization widgets](#system-utilization-widgets)).

## Custom user modules

The schema accepts arbitrary module ids that you provide. Set `type` to `command` for shell-driven output or `qml` for a custom QML widget. Both still go under `bar.layout.<section>` in `shell.json`.

Command module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "omarchy.tray" },
        { "id": "vpn", "type": "command", "exec": "~/.config/omarchy/bar/scripts/vpn-status", "interval": 5, "tooltip": "VPN", "onClick": "nm-connection-editor" },
        { "id": "omarchy.audio" }
      ]
    }
  }
}
```

The command may print plain text or Waybar-style JSON, for example:

```json
{"text":"󰌆","tooltip":"Work VPN","class":"active"}
```

QML module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "gpu", "type": "qml" },
        { "id": "omarchy.audio" }
      ]
    }
  }
}
```

Then create `~/.config/omarchy/bar/modules/gpu.qml`. If you want to store it elsewhere, add a `source` path.

Custom QML modules should be an `Item` with `implicitWidth` and `implicitHeight`. They may optionally define these properties, which the bar fills after loading:

```qml
import QtQuick

Item {
  property var bar
  property string moduleName
  property var settings

  implicitWidth: 28
  implicitHeight: bar ? bar.barSize : 26

  Text {
    anchors.centerIn: parent
    text: "GPU"
    color: bar ? bar.foreground : "white"
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 12
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (bar) bar.run("omarchy-launch-or-focus-tui btop")
  }
}
```

## Bar properties available to widgets

Widgets receive `bar` (the shell root), `moduleName` (string), and `settings` (object) injected at load time. The bar exposes:

- `bar.foreground`, `bar.background`, `bar.urgent` — theme colors (live-updated)
- `bar.fontFamily` — current monospace family
- `bar.position` — `"top" | "bottom" | "left" | "right"`
- `bar.vertical` — boolean shortcut
- `bar.barSize` — 26 horizontal / 28 vertical
- `bar.run(command)` — fire-and-forget bash exec
- `bar.shellQuote(value)` — safe shell-quote a string
- `bar.showTooltip(target, text)` / `bar.hideTooltip(target)` — shared tooltip popup
- `bar.requestPopout(owner)` / `bar.releasePopout(owner)` — one-popup-at-a-time coordinator

First-party bar widgets are manifest-backed just like third-party widgets.
Simple widgets carry sibling manifests such as `widgets/Workspaces.manifest.json`;
richer popup plugins live in feature directories such as `../panels/audio/`,
`../panels/network/`, and `../agents/`; and feature plugins such as
`omarchy.menu` and `omarchy.media` declare their bar-widget entry points in their own
`manifest.json`. Bar layout ids are namespaced, e.g. `omarchy.audio`,
`omarchy.network`, and `omarchy.clock`. Older UpperCamelCase ids such as
`AudioPanel` and `Clock` are migrated forward; new configs should use the
namespaced ids.

Third-party widgets ship as separate plugins under
`~/.config/omarchy/plugins/<plugin-id>/` with their own `manifest.json`
declaring `kinds: ["bar-widget"]` and a `barWidget` entry point. See
[../../README.md](../../README.md) for the manifest schema. Rescan, enable,
and place third-party plugins with `omarchy-shell shell rescanPlugins`,
`omarchy plugin enable`, and `omarchy bar move`.
