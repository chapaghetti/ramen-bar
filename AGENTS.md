# Ramen Bar — Agent Maintenance Handbook

Verbose, operational guide for making agent-assisted changes to this repo and
to the Omarchy environment it runs in. Supersedes guesswork: read before
editing. The user-facing README describes *what* the bar does; this file is
about *where things live, how the machinery behaves, and how to verify*.

---

## 1. Two checkouts — know which one is live

| Role | Path | Notes |
|------|------|-------|
| Source repo (this one) | `~/git/ramen-bar` | upstream `git@github.com:chapaghetti/ramen-bar.git` |
| Installed plugin (live) | `~/.config/omarchy/plugins/ramen.bar/` | its **own git repo**, same remote, usually dirty |

The **live bar runs from the installed clone**, not from `~/git/ramen-bar`.

**Deploy loop (do this every time you change `Bar.qml`, `BarModel.js`, a
bundled widget, or `scripts/`):**

```bash
cp <edited file> ~/.config/omarchy/plugins/ramen.bar/<same path>
omarchy restart shell
```

**Commit loop:** commit in `~/git/ramen-bar` (local only — the owner pushes
upstream and then pulls in the clone). The clone stays dirty with deployed
content that is already committed upstream; `git -C
~/.config/omarchy/plugins/ramen.bar pull` still works because the content
matches the upstream commits.

Do NOT commit secrets. No pushes unless the owner explicitly asks.

> **Old-code race (important).** `omarchy restart shell` reloads the shell
> *in-process* (same quickshell PID). A bar instance that is still running an
> older `Bar.qml` will react to live `~/.config/omarchy/shell.json` edits and
> can **adopt-over** your entries (see §5). If an entry "disappears", check
> `shell.json` first, deploy matching code, then restart.

---

## 2. Repo layout map

```
Bar.qml                 the bar engine (fork of stock omarchy.bar) — the core file
BarModel.js             pure-JS layout helpers: row parsing, entrySettings,
                        customModuleType, customModulePath, adoption diffs
manifest.json           plugin manifest (id ramen.bar, kind bar, entry Bar.qml)
README.md               user-facing: install, adoption, module catalogue, samples
AGENTS.md               this file — agent-facing operating manual
shell.json              portable full-fidelity layout capture (stock widget ids +
                        scripts/) — used by the "Full-fidelity setup" README step
scripts/
  cpu-usage mem-usage disk-usage   exec commands for the built-in util widgets
  omarchy-pkg-flatpak-install      contrib: flatpak install TUI (see §6)
widgets/                           first-party plugin widgets
  ActiveWindow.qml ... Workspaces.qml   plus *.manifest.json siblings
  bundle/                          Ramen's lookalike overrides (workspaces/tray/
                                    indicators/power) keyed on dot-suffix ids
contrib/                           secondary features (see §6)
  bar-modules/pkg-install.qml      bar module for the pkg-install button — auto-
                                    injected via Bar.qml ensurePkgInstaller
  menu-extensions/omarchy-menu.jsonc  manual opt-in: "Flatpak" in Install submenu
```

Everything shipped by the omarchy plugin system resolves ids in the form
`omarchy.<name>` (first-party/bundled) or bare ids (`disk`, `pkg-install`) for
custom modules.

---

## 3. The bar engine (`Bar.qml`) — key machinery

### Config plumbing
- The host shell pushes the `bar:` subtree of `~/.config/omarchy/shell.json`
  into the bar as `barConfig`. `barConfig.layout.left/center/right` are arrays
  of **entries**.
- `entrySettings(entry)` (BarModel.js) = all keys **except `id`**. Flat.
- `entryId(entry)` = the `id`.
- `applyBarConfig()` rebuilds slot rows from `barConfig.layout.<region>`.

### Layout adoption — do not break this
- `ramenBarLayout` = Ramen's canonical layout (stock ids + util widgets).
- `hasCustomLayout()` returns true when (a) any slot row has a non-empty
  `exec` **or** a non-empty `customModuleType()` (that covers `type:"command"`
  and `type:"qml"`), or (b) `omarchy.menu` is not in `left`.
- `isRamenLayout()` = `objectsEqual(config.layout, ramenBarLayout.layout)`
  (one-directional deep equality on canonical keys).
- `isRamenAdopted()` = `barConfig.ramenAdopted === true`. The marker does not
  render anything; it rides inside the `bar:` subtree of `shell.json`, which
  `mutateShellConfig` clones verbatim (it preserved `bar.id`), so it survives
  every shell persist. It is not consumed by the host's config model.
- `adoptRamenLayout()` writes `bar.position / transparent / gap / layout` to
  the canonical layout via `root.shell.mutateShellConfig(...)` — **only when
  `!hasCustomLayout() && !isRamenAdopted()`**. Canonicalizing persists stamp
  `ramenAdopted: true` in the same write. If the persisted layout already
  equals canonical but the marker is missing, `adoptRamenMark()` writes just
  the marker (no layout touch).
- Fired from `Component.onCompleted` and `onBarConfigChanged`.

**One-shot semantics:** the marker makes adoption fire at most once per
config. After it, an all-stock layout may differ from canonical (exactly what
a drag-to-reorder produces now that custom entries are injected at render
time) and adoption is a no-op, so **reorders and widget moves persist**.
Before the marker, any stock-only non-canonical layout was re-adopted on the
next `onBarConfigChanged` and clawed back to canonical — a drag "wouldn't
stick". Keep the marker check ahead of the layout equality check in
`adoptRamenLayout()`. A user upgrading with a stock-only customized layout is
migrated (canonicalized) once, exactly like a first boot, then protected.

**Consequence (critical):** any entry in `shell.json` that is neither an
`exec`-command nor recognized by `customModuleType()` will be treated as
"stock ramen layout" and **clobbered back to canonical on reload**. Custom
entries *must* declare `type` (`"command"` or `"qml"`) or `exec`. This is why
the pkg-install entry is `{"id":"pkg-install","type":"qml"}` and never bare.

### Module slots (the per-entry wrapper)
`component ModuleSlot` (Bar.qml ~line 2108) is a plain `Item` whose size
derives from the active item:
- `implicitWidth: activeItem.implicitWidth + pillPadX*2`, etc. The slot is
  only as wide/tall as the widget's own implicit size.
- `registered` → `registryLoader` (first-party/bundled widget component).
- `commandCustom` → `componentLoader` with `CustomCommandModule` (a
  `WidgetButton` subclass — carries its own implicit size).
- `qmlCustom` (`customType === "qml"`) → `qmlLoader` with
  `source = root.customModuleSource(entry)`.
- `activeItem` = the loaded item; `panelOpen` = `root.activePopout ===
  activeItem` (open-panel dot indicator).
- `pluginApiId` = `omarchy.<id>` when registered else `"bar-entry:"+id`.

### Default sources for custom modules
`customModuleSource(entry)` (BarModel.js `customModulePath`) resolves:
1. `settings.source` (expand `~`/`$HOME`) if present, else
2. `<homedir>/.config/omarchy/bar/modules/<id>.qml` (entry id must be a safe
   bare name — no `/`, no `..`).

### Property injection (`injectProps`, ~line 2379)
After an item loads the bar sets, **only if the target declares the
property**:
- `bar`     → `root.pluginBarApiFor(...)` for **every** widget (first-party
  and custom alike); for first-party/bundled widgets `api.shell` is set to
  `root.shell` so `bar.shell.updateEntryInline` / `bar.shell.summon` /
  `firstPartyServiceFor` keep working
- `moduleName` (string)
- `settings` (object)

The per-slot facade is what makes the foreground sweep (§"Foreground flip
sweep") able to stagger first-party pills: each widget's `bar.foreground`
binding reads that pill's own wave offset instead of the shared root color.

**The injected `bar` for a custom module is a `PluginBarApi` facade, not the
Bar.** It exposes (see `/usr/share/omarchy/shell/Ui/PluginBarApi.qml`):
- bound style props: `foreground`, `barForeground`, `background`, `urgent`,
  `fontFamily`, `position`, `vertical`, `barSize`, `transparent`
- methods: `run(cmd)`, `showTooltip(target, text)`, `hideTooltip(target)`,
  `requestPopout(owner)`, `releasePopout(owner)`, `switchPanelFrom(...)`,
  `registerClickTarget(target)`, `unregisterClickTarget(target)`,
  `moduleWidgets(id)`, `targetBelongsToWindow(...)`
- `activePopout` (limited to own), `clickTargets`, `layoutConfig`

Do not write custom modules that reach for Bar-only APIs (that path exists
only for first-party widgets).

### Foreground flip sweep
Double-clicking empty bar space calls `toggleForegroundInversion()`:
- All pills share one wave clock (`flipSweepClock`, a `NumberAnimation`
  0→1); each pill's glyph color is `mix(from, to, flipProgressFor(index))`
  where the per-pill start offset comes from its left→right position in the
  rendered layout (`capturePluginBarOrder`, :: `flipOrder`).
- **Toward inverted sweeps left→right; the return to base polarity recedes
  right→left** (`flipDirection = nextInverted ? 1 : -1`).
- `foreground`/`barForeground` route through the same helpers
  (`sweptColorFor`/`sweptBarColorFor`), and the existing `Behavior on
  barForeground` (420ms) is gated off while a sweep runs
  (`foregroundFlipEpoch === 0`), so it cannot fight the wave.
- **The pill surfaces toggle between the theme pill and stark black**
  (`sweptPillColorFor` per slot): text/icons stay **light in both modes** so
  the glyph/pill contrast always holds — default "light" look = the translucent
  theme pill (`Color.popups.background`), inverted "dark" look = stark black
  (`#000000`). Each pill uses the same wave offset as its own glyph
  (`flipOrderIndexOf(pluginApiId)`), so the pill change reads as a coordinated
  L→R / R→L wash alongside the subtle theme→white text shimmer.
- `applyBarConfig` early-returns when the normalized layout is identical to
  the live one (deep equality). A pure `foregroundInverted` flip therefore
  does **not** reassign `layoutConfig` / bump `barConfigSerial`, so no slot
  rebuild and no "second fade" of the custom modules. This is what removed
  the old root-first / ramen-second double-fade.
- When `foregroundAnimationEnabled` is false (transparent-flicker guard) the
  flip is applied instantly (`flipSweepClock = 1`).

---

## 4. Authoring custom bar widgets

### 4a. Command module (`type: "command"`)
Entry keys: `exec` (path), `interval` (sec), `tooltip`, `onClick`,
`onRightClick`, `onMiddleClick`, `keepSpace`, `fontSize`, `horizontalMargin`.
Output may be plain text or Waybar JSON `{"text":..,"tooltip":..,"class":"active"}`.
Runs every `interval` via `exec`. Click handlers are bashed with the widget's
`text` available. Reference usage: `scripts/cpu-usage` + README example.

### 4b. QML module (`type: "qml"`)
Flow: entry `{ "id", "type": "qml", ... }` → file at
`~/.config/omarchy/bar/modules/<id>.qml` (or `source` override) → `Loader`.
The module file's root **must** be (or act like) an `Item`.

**THE sizing gotcha:** a plain QML `Item` has **implicit width/height 0** (it
does not auto-compute from children, unlike `WidgetButton`/`PopupCard`). The
slot sizes itself from `activeItem.implicitWidth/Height`, so a custom root
that only sets `width`/`height` (or nothing) collapses to 0 and draws
nothing. Always set on the root:

```qml
implicitWidth: button.implicitWidth
implicitHeight: button.implicitHeight
```

(Symptom: module logs `item?=true` / loader status Ready, but nothing is on
screen; `root.width` goes `38.5 → 0` one event-loop tick after load.)

Declare the injectable properties on the root so injection lands:

```qml
property var bar: null
property string moduleName: ""
property var settings: ({})
```

Real working pattern used by `contrib/bar-modules/pkg-install.qml`:

- `WidgetButton { bar: root.bar; text: "<glyph>"; tooltipText: "..."; onPressed: ... }`
  — carries its own implicit size, renders the glyph, shares the ramen tooltip.
- `PopupCard` for the popup (see §4c).
- Availability gating via `Process` (`import Quickshell.Io`) + `SplitParser`;
  rows show unless the check reports them missing **explicitly** (mirrors the
  menu `when:` semantics: only an explicit fail hides a row). Re-run the check
  on `popup.onOpenChanged`. This is how the Flatpak row disappears on machines
  without flatpak.
- Launching TUIs: `bar.run("xdg-terminal-exec --app-id=org.omarchy.terminal <script>")`.

### 4c. PopupCard pattern (from `widgets/bundle/tray/Tray.qml`)
```qml
PopupCard {
  id: popup
  anchorItem: root            // widget whose position the popup flanks
  owner: root                 // becomes the popup coordinator owner
  bar: root.bar               // needed for position/requestPopout — the facade has these
  triggerMode: "click"        // outside-click dismisses (focus grab)
  padding: Style.space(6)
  contentWidth: fittedContentWidth(Style.space(250))
  contentHeight: fittedContentHeight(menuColumn.implicitHeight)
  Column { spacing: Style.space(2); /* rows */ }
}
```
`PopupCard` internally calls `bar.requestPopout(owner)` when `open` turns
true and `releasePopout` on close; the bar shows the open-panel dot on the
widget while `root.activePopout === owner`. Set `open = false` before running
an action. Rows are `qs.Ui Button { iconText, text, foreground, leftAlign,
fontSize, horizontalPadding, verticalPadding, onClicked }`.

### 4d. Glyphs
- Bar font = `Style.font.family` (alias `monospace`) → resolves to
  **JetBrainsMono Nerd Font** on this system. Any glyph must exist there.
- **QML and JSON `\u` escapes are exactly 4 hex digits.** Codepoints above
  `U+FFFF` (all Nerd Font glyphs, e.g. `U+F03D3`) must be written as the
  **literal UTF-8 character**, not `\uf03d3` (parses as `\uf03d` + `"3"`).
  `U000F02CA`-style escapes in README samples are illustrative only.
- Verify presence: `fc-match monospace` then `fc-query --format="%{charset}\n" <font>`
  and check membership (python).

Known glyphs in use: package `󰏓` = `U+F03D3`, arch `󰣇` = `U+F08C7`,
flatpak logo `U+F0213`. Stock menu/indicators reuse these.

---

## 5. Persistence pitfalls (survival guide)

- **Entry vanished from `shell.json`** → adoption ran because the row wasn't
  recognized as custom (§3) or an *old* bar instance reacted to a live file
  edit (§1 race). Restore the entry with `type`, ensure matching `Bar.qml` is
  deployed, restart, confirm via log.
- **`[Bar.qml …] Property value set multiple times`** → same object got two
  `Component.onCompleted` (or duplicate property). Real failure mode: the log
  then says `bar option ramen.bar failed to load, falling back to
  omarchy.bar`, and the **stock** bar renders (custom modules and bundled
  overrides silently gone). Always grep the log after a control edit.
- **Drag reorder "won't stick" / widgets stuck in place** → pre-marker
  adoption: an all-stock non-canonical layout was re-adopted and clawed back
  to canonical on every config change. `bar.ramenAdopted === true` must be
  present in `shell.json`; the drag writes via
  `materializeInjectedModuleInConfig` → `mutateShellConfig` (atomic in the
  shell, survives). Restore/verify the marker; do not hand-edit the file
  non-atomically (see below).
- **JSON edits from python**: write `ensure_ascii=False` if the file embeds
  glyph chars, or the glyphs are replaced by `\u` escapes and break/change.
  Stage + `os.replace` (atomic); a non-atomic `open(p,"w")` can race the
  shell's FileView reload, the parse fails, `shellConfig` falls back to
  builtin defaults mid-flight, and a later persist clones the defaults —
  signature: `bar.id` vanishes + layout resets to canonical. Real shell writes
  are atomic, so only external hand-edits hit this.
- Keep the deployed clone and repo byte-identical before concluding anything
  (`cmp`).

---

## 6. The package-install feature (out of the box)

Wired into the bar automatically; a **fresh install gets the full feature**
(bar button + Flatpak TUI) with zero manual steps. All three pieces ship
inside the plugin directory:

1. **`scripts/omarchy-pkg-flatpak-install`** — fzf TUI mirroring
   `omarchy-pkg-install` (stock, in `/usr/share/omarchy/bin/`) for Flatpaks.
   `flatpak remote-ls --columns=application,name,description "$remote" |
   sort -fu | fzf --multi` with preview `flatpak remote-info {1}`, then
   `xargs flatpak install --assumeyes --noninteractive`. Remote overridable
   via `FLATPAK_INSTALL_REMOTE` (default `flathub`). Ends with
   `omarchy-show-done`. Launched by absolute path from the module, so no
   `$HOME/.local/bin` copy or `PATH` change is required (that old install
   method still works for standalone use).

2. **`Bar.qml` auto-injection** — `ensurePkgInstaller` (mirrors
   `ensureSystemStats`) injects an entry
   `{id:"pkg-install", type:"qml", source: barModuleDir+"/pkg-install.qml",
   installers:{package,aur,flatpak}}` into rendered `left` **only when no
   `pkg-install` entry exists anywhere** in the layout (`layoutHasId` scans
   left/center/right). Existing entries win: users keep placement/settings.
   The `source` (absolute, inside the plugin) means no
   `~/.config/omarchy/bar/modules/` copy is needed either. `barModuleDir`
   and `sysStatsScriptDir` both hardcode
   `~/.config/omarchy/plugins/ramen.bar/...` (omarchy's install convention).
   Do not rename the plugin id (`ramen.bar`).

3. **`contrib/bar-modules/pkg-install.qml`** — resolves its three launch
   commands from injected `settings.installers` (falls back to bare stock
   names when absent, e.g. a user-placed standalone copy). Flatpak row also
   requires the `flatpak` binary. `command -v` on an absolute path works.

Manual opt-in left: `contrib/menu-extensions/omarchy-menu.jsonc` → copy to
`~/.config/omarchy/extensions/omarchy-menu.jsonc` (adds *Flatpak* to the
Install submenu). `when: command -v flatpak`; merge mechanics live in
`/usr/share/omarchy/shell/plugins/menu/MenuModel.js` (`mergeMenuSources`):
user file keyed by id, derived parent, user rows appended last, user fields
override defaults.

`hasCustomLayout()` never clobbers the injected entry: it is applied at
render time (like the util widgets), and adoption only ever rewrites the
*persisted* layout. If a user hands you a layout "missing" the button, it is
rendered regardless — check `layoutHasId` presence instead of `shell.json`.

**Injected entries are draggable.** A drop position is defined by the
*rendered* layout, not `shell.json` (the source/target pill may be an
auto-injected neighbor such as cpu/mem/disk that has never been
persisted), so `dropBarModule` resolves every drop with
`materializeInjectedModuleInConfig` against `layoutConfig`, never against
the persisted rows. The source is removed from its rendered region and
inserted into the destination at the rendered index of `beforeName`, then
**both involved regions are persisted verbatim from their rendered
content** — surgical persistence would leave cpu unwritten, the injectors
`ensureSystemStats`/`ensurePkgInstaller` re-add still-missing stats at the
region end, and a drop placed "after CPU" would silently land before it.
The full-row persist pins the whole arrangement on the first drag of an
injected entry; after that the entries are ordinary persisted rows and
`hasCustomLayout` keeps adoption from clawing the row back. This is also why
`ensureSystemStats` takes the full layout — a stat dragged to another region
is seen as present there and must not be re-injected into `left`.

---

## 7. Verification & debugging workflow

**Log location** (binary, use `strings`):

```bash
f=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1)
strings "$f" | grep -a "<pattern>" | tail
```

**Healthy-restart checks:**
- no `bar option ramen.bar failed to load, falling back to omarchy.bar`
- no QML error referencing `Bar.qml` other than the known benign teardown line
- `shell.json` `bar.layout.left` still contains your entry after restart

**Known-benign log noise** (do not chase):
- `QML IpcHandler … another handler is registered for target omarchy.bar`
- `portal … Could not register app ID` and `org.bluez … QDBusError`
- `QQmlVMEMetaObject: Internal error …` + `TypeError: Property
  'pluginBarApiFor' … delayed function evaluation` — teardown of a custom
  module's `PluginBarApi`'s live bindings on shell reload. One line per
  reload, no crash, same PID.

**Logging from QML:** `console.info` from `Bar.qml` and from custom modules
lands in the qslog. Instrument deliberately and strip before committing;
never add a second `Component.onCompleted` (see §5).

**Screen checks without image reading:**
```bash
grim /tmp/s.png
# region scan for a color/ink (example: bright icons in the left bar band):
magick /tmp/s.png -crop 220x40+0+0 +repage txt:- | grep -c "srgb(2"
```
or OCR: `magick /tmp/s.png -crop <geo> +repage -resize 300% /tmp/o.png &&
tesseract /tmp/o.png -`. Composable pixel-diffs (`magick A B -compose
difference -composite -format "%@" info:`) are useful to locate a changed
region before/after a change.

**Glyph check snippets** (§4d) and **gating logic** can be tested outside the
shell with `python3`/`node` — extract the exact bash/JS and drive it.

---

## 8. Standard workflows (copy-paste)

**Change Bar.qml → live:**
```bash
# edit repo Bar.qml
cp ~/git/ramen-bar/Bar.qml ~/.config/omarchy/plugins/ramen.bar/Bar.qml
omarchy restart shell; sleep 3
f=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog|head -1)
strings "$f" | grep -a "failed to load\|TypeError" | tail
```

**Add a new menu-extension row:** add an `id.label` object to
`contrib/menu-extensions/omarchy-menu.jsonc`, copy to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, restart. `when:` uses
bash expressions (e.g. `command -v flatpak`).

**Add a new custom bar module:** copy
`contrib/bar-modules/pkg-install.qml` to `~/.config/omarchy/bar/modules/`,
edit, add `{"id":"<name>","type":"qml"}` to `shell.json`, restart. Keep the
root `implicitWidth/Height` bindings and the three injectable properties.

**Commit (local only):**
```bash
cd ~/git/ramen-bar
git add -A
git commit -m "describe"
# owner: git push && git -C ~/.config/omarchy/plugins/ramen.bar pull && omarchy restart shell
```

---

## 9. Conventions
- No code comments unless asked; match the existing terse QML/JS style.
- `omarchy restart shell` (in-process reload) is the reload primitive; only
  the owner decides on pushing/publishing.
- Keep `README.md` user-facing; keep operational knowledge here in
  `AGENTS.md`.
- When in doubt about the running bar being stock vs ramen: grep the log for
  `failed to load, falling back`.