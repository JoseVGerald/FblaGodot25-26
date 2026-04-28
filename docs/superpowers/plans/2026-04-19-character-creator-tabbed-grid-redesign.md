# Character Creator Tabbed-Grid Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `CharacterCustomize` to match the Anthropic design: left-side single-character preview with a 4-direction carousel, right-side tabbed thumbnail grid for picking Body / Hair / Accessory / Outfit / Eyes, keeping the existing bottom bar (name, back, randomize, visibility toggles, continue).

**Architecture:** Procedural UI (no new `.tscn` sub-scenes) consistent with the current file. The screen is a `HBoxContainer` split: **LeftPanel** owns the big preview (48×96 composited sprite at large scale) + 4 mini direction thumbnails + a `◀ FRONT ▶` direction carousel. **RightPanel** owns a horizontal tab strip (5 tabs) followed by a `ScrollContainer` holding a thumbnail grid for the active category. Selecting a thumbnail writes into `selections[category]` and refreshes only the preview sprite for that layer (same data flow already in the file). Grid thumbnails reuse the existing 48×48 PNGs that already live in `Parts/<Category>/48x48/` — filename maps 1:1 to the sprite-sheet filename in `PREVIEW_TEXTURES`.

**Tech Stack:** Godot 4.x, GDScript 2.0. Existing `CharacterAssets.PREVIEW_TEXTURES` (data), `AtlasTexture` (sprite-sheet regions), `GameState` autoload (persistence), `SceneManager` autoload (transitions). No new dependencies.

---

## Visual Reference

Target (from design PNG):

```
┌─────────────────────────  CHARACTER CREATOR  ─────────────────────────┐
│                                                                       │
│  ┌──────────────┐     ┌ BODY ┐┌ HAIR ┐┌ ACCESS ┐┌ OUTFIT ┐┌ EYES ┐   │
│  │              │     └──────┘└──────┘└────────┘└────────┘└──────┘   │
│  │   big        │     ┌──────┐┌──────┐┌──────┐┌─────────┐           │
│  │   preview    │     │ tile ││ tile ││ tile ││ SELECTED│           │
│  │              │     │  01  ││  02  ││  03  ││ BODY 01 │           │
│  └──────────────┘     └──────┘└──────┘└──────┘└─────────┘           │
│   [🐵][🐵][🐵][🐵]    ┌──────┐┌──────┐┌──────┐┌──────┐               │
│     ◀  FRONT  ▶       │  05  ││  06  ││  07  ││  08  │               │
│                        └──────┘└──────┘└──────┘└──────┘               │
│                                                                       │
│─────────────────────────── Bottom Bar ───────────────────────────────│
│ NAME: [___]   BACK  RANDOMIZE                       CONTINUE          │
└───────────────────────────────────────────────────────────────────────┘
```

Colors locked in (sampled from the target screenshot + existing code):

| Element                       | Color (RGB 0–1)                  | Notes                       |
| ----------------------------- | -------------------------------- | --------------------------- |
| Blue checker (existing)       | `(0.247,0.584,0.776)` / `(0.208,0.529,0.722)` | keep current shader |
| Title text                    | `WHITE` with black shadow        | keep                        |
| Tab inactive bg               | `(0.42,0.48,0.54)`               | same as existing dropdown   |
| Tab active bg (orange)        | `(0.92,0.62,0.08)`               | same as Randomize button    |
| Tab border                    | `(0.32,0.36,0.40)`               |                             |
| Grid tile normal bg           | `(0.60,0.65,0.70)`               | light slate                 |
| Grid tile hover bg            | `(0.70,0.75,0.80)`               |                             |
| Grid tile selected bg         | `(0.18,0.20,0.24)`               | near-black with yellow border |
| Grid tile selected border     | `(0.92,0.78,0.12)`               | highlight ring              |
| Selected-tile label bg strip  | `(0.18,0.20,0.24)` — transparent 90% | bottom strip inside tile   |
| Selected-tile label text      | `WHITE`                          | e.g. "BODY 01"              |
| Bottom bar bg (existing)      | `(0.75,0.75,0.75)`               | keep                        |

---

## File Structure

**Modified:**

- `scripts/CharacterCustomize.gd` — rewrite `_build_ui()` and preview logic. Keep: constants, `CharacterAssets` preload, `selections`/`visibility` state, `_apply_saved()`, all signal handlers for Continue/Back/Randomize, and `_create_checker_bg()`. Remove: `_create_dropdown()`, `_get_option_label()`, the 4-direction preview columns. Add: `_build_tab_bar()`, `_build_thumb_grid()`, `_build_main_preview()`, `_build_direction_carousel()`, `_thumbnail_path_for()`, `_on_tab_pressed()`, `_on_tile_pressed()`, `_on_direction_changed()`, `_refresh_grid()`, `_refresh_main_preview()`.
- `scenes/CharacterCustomize.tscn` — unchanged structurally (root Control + script). No edits needed unless the script rewrite forces a signal rewire — it does not, because all UI is still procedural.

**Not created:** no new files. Everything lives in the existing one script, consistent with current style.

**Rationale for no split:** Grid/tab/preview helpers are all tightly coupled to the scene's `selections` dictionary and preview sprites. Splitting would force public APIs across files for no reuse benefit — the grid isn't reused elsewhere. Current file grows from ~540 → ~700 lines, still well-scoped. If a later task reuses the grid (shop, wardrobe), extract it then.

---

## State Model (unchanged, re-asserted for clarity)

```gdscript
const CATEGORIES := ["Body", "Hairstyle", "Accessory", "Outfit", "Eyes"]  # REORDERED to match tabs
const DIRECTIONS := ["left", "down", "up", "right"]                        # unchanged

var selections := { "Body": 1, "Eyes": 1, "Outfit": 1, "Hairstyle": 1, "Accessory": 1 }
var visibility := { "Body": true, "Eyes": true, "Outfit": true, "Hairstyle": true, "Accessory": true }

# NEW:
var active_category: String = "Body"   # which tab is open
var active_direction: String = "down"  # which facing is shown in big preview
```

Display labels per tab (what the user sees on the tab button):

```gdscript
const TAB_LABELS := {
    "Body": "BODY", "Hairstyle": "HAIR", "Accessory": "ACCESSORIES",
    "Outfit": "OUTFIT", "Eyes": "EYES",
}
```

---

## Implementation Tasks

### Task 1: Reorder CATEGORIES and add new state/constants

**Files:**

- Modify: `scripts/CharacterCustomize.gd:11` (CATEGORIES constant)
- Modify: `scripts/CharacterCustomize.gd:33-36` (selections dict — no change needed, just verify)
- Modify: `scripts/CharacterCustomize.gd` top of file (add new constants and state)

- [ ] **Step 1: Change CATEGORIES ordering and add new constants**

Open `scripts/CharacterCustomize.gd`. Replace the `CATEGORIES` constant and add new constants / state variables right below it.

```gdscript
# Categories in TAB display order (left→right, matches design)
const CATEGORIES := ["Body", "Hairstyle", "Accessory", "Outfit", "Eyes"]

# User-facing labels per category (for tab buttons + selected-tile footer)
const TAB_LABELS := {
    "Body": "BODY",
    "Hairstyle": "HAIR",
    "Accessory": "ACCESSORIES",
    "Outfit": "OUTFIT",
    "Eyes": "EYES",
}

# Direction carousel order — left→front→back→right cycles with the arrows
const DIRECTION_ORDER := ["left", "down", "up", "right"]
const DIRECTION_LABELS := {"left": "LEFT", "down": "FRONT", "up": "BACK", "right": "RIGHT"}

# Grid sizing
const GRID_COLUMNS := 4
const TILE_SIZE := 120           # px per thumbnail tile
const TILE_SPACING := 10
```

Keep the `DIRECTIONS` constant as-is (still used by `_update_preview_for_category`).

- [ ] **Step 2: Add active_category / active_direction state vars**

Right after the existing `var visibility := { ... }` dictionary, add:

```gdscript
# NEW — which tab & direction are currently showing
var active_category: String = "Body"
var active_direction: String = "down"
```

- [ ] **Step 3: Replace `dropdowns` and `preview_sprites` declarations**

In the "UI references" block, replace:

```gdscript
var dropdowns := {} # String(category) → OptionButton
var preview_sprites := {} # String(direction) → { String(category) → Sprite2D }
```

with:

```gdscript
# NEW UI refs
var tab_buttons := {}          # String(category) → Button
var grid_container: GridContainer  # holds tile buttons; rebuilt per category
var tile_buttons := []         # Array[Button] for the currently-displayed tiles
var main_preview_sprites := {} # String(category) → Sprite2D (single composited preview)
var main_preview_root: Control # parent of main_preview_sprites, for resizing
var direction_label: Label     # carousel label
var selected_tile_label: Label # shown under grid or overlayed — see Task 3
```

- [ ] **Step 4: Run Godot editor to verify the script still parses**

Run: open the Godot editor, load the project, open `CharacterCustomize.gd`.
Expected: no parse errors (the old `_build_ui` still references `dropdowns`/`preview_sprites`, which are now undeclared — **it will fail**). That's expected; it confirms we've staged the rename. Next tasks rewrite `_build_ui`.

- [ ] **Step 5: Commit**

```bash
git add scripts/CharacterCustomize.gd
git commit -m "refactor(char-creator): reorder categories and add tab/direction state

Preparing for tabbed-grid redesign. Renames var declarations and
introduces active_category/active_direction; build functions in
next commit.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: Rewrite `_build_ui()` with split-panel layout

**Files:**

- Modify: `scripts/CharacterCustomize.gd` (`_build_ui` function, roughly lines 67–143)

- [ ] **Step 1: Replace `_build_ui` with two-panel split**

Replace the entire `_build_ui()` function (everything from `func _build_ui() -> void:` through the first line that is not part of the function — i.e. before `func _create_checker_bg`) with:

```gdscript
func _build_ui() -> void:
    # ── Background (blue checker) ──
    add_child(_create_checker_bg())

    # ── Root vertical: title, middle split, bottom bar ──
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 0)
    add_child(root)

    # top padding
    var top_pad := Control.new()
    top_pad.custom_minimum_size.y = 30
    root.add_child(top_pad)

    # ── Title ──
    var title := Label.new()
    title.text = "CHARACTER CREATOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 52)
    title.add_theme_color_override("font_color", Color.WHITE)
    title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
    title.add_theme_constant_override("shadow_offset_x", 3)
    title.add_theme_constant_override("shadow_offset_y", 3)
    if pixel_font:
        title.add_theme_font_override("font", pixel_font)
    root.add_child(title)

    # gap under title
    var gap := Control.new()
    gap.custom_minimum_size.y = 18
    root.add_child(gap)

    # ── Middle split: preview (left) | tabs+grid (right) ──
    var split := HBoxContainer.new()
    split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.add_theme_constant_override("separation", 40)
    split.alignment = BoxContainer.ALIGNMENT_CENTER
    root.add_child(split)

    # left side
    var left := _build_left_panel()
    split.add_child(left)

    # right side
    var right := _build_right_panel()
    split.add_child(right)

    # ── Bottom bar (unchanged) ──
    root.add_child(_create_bottom_bar())
```

- [ ] **Step 2: Add left-panel builder**

Add this new function below `_build_ui`:

```gdscript
# ── Left panel: main preview + direction carousel ──
func _build_left_panel() -> VBoxContainer:
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    col.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    col.add_theme_constant_override("separation", 12)

    # ── Big composited preview (one direction) ──
    var preview_w := int(48 * SPRITE_SCALE)
    var preview_h := int(96 * SPRITE_SCALE)
    main_preview_root = Control.new()
    main_preview_root.custom_minimum_size = Vector2(preview_w, preview_h)
    main_preview_root.clip_contents = true
    col.add_child(main_preview_root)

    var layer_order := ["Body", "Eyes", "Outfit", "Hairstyle", "Accessory"]
    for i in range(layer_order.size()):
        var cat: String = layer_order[i]
        var sp := Sprite2D.new()
        sp.name = cat
        sp.centered = false
        sp.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
        sp.z_index = i
        main_preview_root.add_child(sp)
        main_preview_sprites[cat] = sp

    # shadow ellipse
    var shadow := Panel.new()
    shadow.custom_minimum_size = Vector2(preview_w * 0.7, 14)
    shadow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var shadow_sb := StyleBoxFlat.new()
    shadow_sb.bg_color = Color(0, 0, 0, 0.25)
    shadow_sb.set_corner_radius_all(8)
    shadow.add_theme_stylebox_override("panel", shadow_sb)
    col.add_child(shadow)

    # ── Row of 4 tiny direction thumbnails (decorative — no click) ──
    var mini_row := HBoxContainer.new()
    mini_row.alignment = BoxContainer.ALIGNMENT_CENTER
    mini_row.add_theme_constant_override("separation", 6)
    col.add_child(mini_row)
    for d in DIRECTION_ORDER:
        var mini := _build_mini_direction_preview(d)
        mini_row.add_child(mini)

    # ── Direction carousel: ◀ FRONT ▶ ──
    var carousel := HBoxContainer.new()
    carousel.alignment = BoxContainer.ALIGNMENT_CENTER
    carousel.add_theme_constant_override("separation", 18)
    col.add_child(carousel)

    var prev_dir := _create_styled_button("<", Color(0.42, 0.48, 0.54))
    prev_dir.custom_minimum_size = Vector2(52, 52)
    prev_dir.add_theme_font_size_override("font_size", 28)
    prev_dir.pressed.connect(_on_direction_step.bind(-1))
    carousel.add_child(prev_dir)

    direction_label = Label.new()
    direction_label.text = DIRECTION_LABELS[active_direction]
    direction_label.add_theme_font_size_override("font_size", 28)
    direction_label.add_theme_color_override("font_color", Color.WHITE)
    direction_label.custom_minimum_size.x = 140
    direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if pixel_font:
        direction_label.add_theme_font_override("font", pixel_font)
    carousel.add_child(direction_label)

    var next_dir := _create_styled_button(">", Color(0.42, 0.48, 0.54))
    next_dir.custom_minimum_size = Vector2(52, 52)
    next_dir.add_theme_font_size_override("font_size", 28)
    next_dir.pressed.connect(_on_direction_step.bind(1))
    carousel.add_child(next_dir)

    return col


# ── 4 small non-interactive direction thumbnails under the big preview ──
func _build_mini_direction_preview(direction: String) -> Control:
    var mini := Control.new()
    mini.custom_minimum_size = Vector2(48, 96)  # 1× scale

    var layer_order := ["Body", "Eyes", "Outfit", "Hairstyle", "Accessory"]
    for i in range(layer_order.size()):
        var cat: String = layer_order[i]
        var sp := Sprite2D.new()
        sp.centered = false
        sp.z_index = i
        var tex: Texture2D = _atlas_for(cat, direction)
        if tex:
            sp.texture = tex
        mini.add_child(sp)
    # yellow highlight box around current direction
    var highlight := Panel.new()
    highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var hsb := StyleBoxFlat.new()
    hsb.bg_color = Color(0, 0, 0, 0)
    hsb.border_color = Color(0.92, 0.78, 0.12) if direction == active_direction else Color(0, 0, 0, 0)
    hsb.set_border_width_all(2)
    highlight.add_theme_stylebox_override("panel", hsb)
    mini.add_child(highlight)
    mini.set_meta("highlight_panel", highlight)
    mini.set_meta("direction", direction)
    return mini
```

- [ ] **Step 3: Add right-panel builder (tabs + grid)**

Right after `_build_mini_direction_preview`, add:

```gdscript
# ── Right panel: tab bar + scrollable thumbnail grid ──
func _build_right_panel() -> VBoxContainer:
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.custom_minimum_size.x = (TILE_SIZE + TILE_SPACING) * GRID_COLUMNS + 40
    col.add_theme_constant_override("separation", 12)

    # ── Tab strip ──
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 6)
    col.add_child(tabs)
    for cat in CATEGORIES:
        var tab := _create_tab_button(cat)
        tabs.add_child(tab)
        tab_buttons[cat] = tab

    # ── Scrollable grid ──
    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    col.add_child(scroll)

    grid_container = GridContainer.new()
    grid_container.columns = GRID_COLUMNS
    grid_container.add_theme_constant_override("h_separation", TILE_SPACING)
    grid_container.add_theme_constant_override("v_separation", TILE_SPACING)
    grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(grid_container)

    return col


func _create_tab_button(category: String) -> Button:
    var btn := Button.new()
    btn.text = TAB_LABELS[category]
    btn.custom_minimum_size = Vector2(0, 48)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.add_theme_font_size_override("font_size", 22)
    btn.add_theme_color_override("font_color", Color.WHITE)
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    btn.add_theme_color_override("font_pressed_color", Color.WHITE)
    if pixel_font:
        btn.add_theme_font_override("font", pixel_font)

    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.42, 0.48, 0.54)
    sb.border_color = Color(0.32, 0.36, 0.40)
    sb.set_border_width_all(3)
    sb.set_corner_radius_all(4)
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 6
    sb.content_margin_bottom = 6
    btn.add_theme_stylebox_override("normal", sb)

    var sb_hover: StyleBoxFlat = sb.duplicate()
    sb_hover.bg_color = Color(0.50, 0.56, 0.62)
    btn.add_theme_stylebox_override("hover", sb_hover)

    # store a pre-built "active" stylebox as meta so _refresh_tab_styles can swap it in
    var sb_active: StyleBoxFlat = sb.duplicate()
    sb_active.bg_color = Color(0.92, 0.62, 0.08)
    sb_active.border_color = Color(0.70, 0.45, 0.05)
    btn.set_meta("active_stylebox", sb_active)
    btn.set_meta("inactive_stylebox", sb)
    btn.set_meta("category", category)

    btn.pressed.connect(_on_tab_pressed.bind(category))
    return btn
```

- [ ] **Step 4: Verify parse**

Run: open Godot, reload `CharacterCustomize.gd`.
Expected: parse errors pointing at references to `dropdowns` / `preview_sprites` / `_create_dropdown` / `_get_option_label` / `_create_preview_column` / `_sync_all_previews` / `_update_preview_for_category` / `_on_dropdown_changed` / `_atlas_for` — these are now undefined or orphaned. We will remove/replace them in Task 3 & 4.

- [ ] **Step 5: Commit (WIP)**

```bash
git add scripts/CharacterCustomize.gd
git commit -m "wip(char-creator): add new left/right panel builders

Panels are defined but not yet wired; next commit removes dead
dropdown code and adds tab/grid/direction handlers.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: Delete dead dropdown code, add atlas helper and preview/refresh logic

**Files:**

- Modify: `scripts/CharacterCustomize.gd` — remove `_create_dropdown`, `_get_option_label`, `_create_preview_column`; replace `_sync_all_previews` and `_update_preview_for_category`; add `_atlas_for`, `_refresh_main_preview`, `_refresh_mini_previews`, `_refresh_tab_styles`, `_refresh_grid`.

- [ ] **Step 1: Delete the three dead helpers**

Remove these three functions entirely from the file:

1. `func _create_dropdown(category: String) -> OptionButton:` (and its body, ~40 lines)
2. `func _get_option_label(category: String, path: String) -> String:` (~16 lines)
3. `func _create_preview_column(direction: String) -> VBoxContainer:` (~50 lines)

- [ ] **Step 2: Replace `_sync_all_previews` and `_update_preview_for_category`**

Find the section headed `#  STATE & PREVIEW LOGIC` and replace the two existing preview functions (`_sync_all_previews` and `_update_preview_for_category`) with this block. **Also add the new helpers at the end of the block.**

```gdscript
# ═══════════════════════════════════════════════════════════════════
#  PREVIEW REFRESH
# ═══════════════════════════════════════════════════════════════════

func _atlas_for(category: String, direction: String) -> Texture2D:
    var textures: Array = PREVIEW_TEXTURES.get(category, [])
    if textures.is_empty():
        return null
    var idx := clampi(selections[category] - 1, 0, textures.size() - 1)
    var tex_path: String = textures[idx]
    var full_tex: Texture2D = load(tex_path)
    if not full_tex:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = full_tex
    atlas.region = DIR_ATLAS[direction]
    return atlas


func _sync_all_previews() -> void:
    _refresh_main_preview()
    _refresh_mini_previews()


func _refresh_main_preview() -> void:
    for cat in CATEGORIES:
        if not main_preview_sprites.has(cat):
            continue
        var sp: Sprite2D = main_preview_sprites[cat]
        var tex := _atlas_for(cat, active_direction)
        sp.texture = tex
        sp.visible = visibility[cat] and tex != null


func _refresh_mini_previews() -> void:
    # Mini previews live under the big preview in a fixed HBox built by
    # _build_mini_direction_preview. Walk that row and refresh.
    var mini_row: HBoxContainer = _find_mini_row()
    if mini_row == null:
        return
    for mini in mini_row.get_children():
        if not (mini is Control):
            continue
        var dir: String = mini.get_meta("direction", "")
        if dir == "":
            continue
        # Rebuild sprite textures in-place (cheap — 5 AtlasTextures)
        var i := 0
        for child in mini.get_children():
            if not (child is Sprite2D):
                continue
            var layer_order := ["Body", "Eyes", "Outfit", "Hairstyle", "Accessory"]
            if i >= layer_order.size():
                break
            var cat: String = layer_order[i]
            child.texture = _atlas_for(cat, dir)
            child.visible = visibility[cat] and child.texture != null
            i += 1
        # update yellow highlight
        var hp: Panel = mini.get_meta("highlight_panel", null)
        if hp:
            var sb: StyleBoxFlat = hp.get_theme_stylebox("panel").duplicate()
            sb.border_color = Color(0.92, 0.78, 0.12) if dir == active_direction else Color(0, 0, 0, 0)
            hp.add_theme_stylebox_override("panel", sb)


func _find_mini_row() -> HBoxContainer:
    # main_preview_root is inside the left VBox; mini row is the next HBoxContainer sibling
    if main_preview_root == null:
        return null
    var parent: Node = main_preview_root.get_parent()
    if parent == null:
        return null
    for child in parent.get_children():
        if child is HBoxContainer:
            # Skip the carousel HBox (has the direction_label). Mini row has no Label children.
            var has_label := false
            for c in child.get_children():
                if c is Label:
                    has_label = true
                    break
            if not has_label:
                return child
    return null


func _refresh_tab_styles() -> void:
    for cat in CATEGORIES:
        if not tab_buttons.has(cat):
            continue
        var b: Button = tab_buttons[cat]
        var sb: StyleBoxFlat = b.get_meta("active_stylebox") if cat == active_category else b.get_meta("inactive_stylebox")
        b.add_theme_stylebox_override("normal", sb)


func _refresh_grid() -> void:
    # Clear existing tiles
    for c in grid_container.get_children():
        c.queue_free()
    tile_buttons.clear()

    var textures: Array = PREVIEW_TEXTURES.get(active_category, [])
    for i in range(textures.size()):
        var tile := _build_tile(active_category, i, textures[i])
        grid_container.add_child(tile)
        tile_buttons.append(tile)


func _build_tile(category: String, index_0: int, tex_path: String) -> Button:
    var btn := Button.new()
    btn.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
    btn.focus_mode = Control.FOCUS_NONE
    btn.toggle_mode = false
    btn.clip_contents = true

    var is_selected := (index_0 + 1) == selections[category]

    # Tile background
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.18, 0.20, 0.24) if is_selected else Color(0.60, 0.65, 0.70)
    sb.border_color = Color(0.92, 0.78, 0.12) if is_selected else Color(0.40, 0.44, 0.48)
    sb.set_border_width_all(3)
    sb.set_corner_radius_all(4)
    btn.add_theme_stylebox_override("normal", sb)

    var sb_hover: StyleBoxFlat = sb.duplicate()
    if not is_selected:
        sb_hover.bg_color = Color(0.70, 0.75, 0.80)
    btn.add_theme_stylebox_override("hover", sb_hover)
    btn.add_theme_stylebox_override("pressed", sb_hover)

    # Thumbnail icon on top
    var thumb := TextureRect.new()
    thumb.texture = _thumbnail_texture_for(category, tex_path)
    thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    thumb.offset_top = 6
    thumb.offset_bottom = -22 if is_selected else -6
    thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(thumb)

    # Selected tiles show a bottom strip with "BODY 01" style label
    if is_selected:
        var label := Label.new()
        label.text = "%s %02d" % [TAB_LABELS[category], index_0 + 1]
        label.add_theme_font_size_override("font_size", 14)
        label.add_theme_color_override("font_color", Color.WHITE)
        if pixel_font:
            label.add_theme_font_override("font", pixel_font)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        label.offset_top = -20
        label.offset_bottom = -2
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(label)

    btn.pressed.connect(_on_tile_pressed.bind(category, index_0))
    return btn


func _thumbnail_texture_for(category: String, tex_path: String) -> Texture2D:
    # Prefer the dedicated 48×48 thumbnail in Parts/<Category>/48x48/ if present,
    # else fall back to the first-frame atlas region of the main sheet.
    var folder_map := {
        "Body": "Bodies",
        "Hairstyle": "Hairstyles",
        "Accessory": "Accessories",
        "Outfit": "Outfits",
        "Eyes": "Eyes",
    }
    var base := tex_path.get_file().get_basename() # e.g. "Body_01"
    var thumb_path := "res://Parts/%s/48x48/%s.png" % [folder_map[category], base]
    if ResourceLoader.exists(thumb_path):
        return load(thumb_path)
    # fallback: atlas of down-facing frame
    var full: Texture2D = load(tex_path)
    if full == null:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = full
    atlas.region = DIR_ATLAS["down"]
    return atlas
```

- [ ] **Step 3: Extend `_ready` to also call `_refresh_tab_styles` and `_refresh_grid`**

Find the existing `_ready`:

```gdscript
func _ready() -> void:
    if ResourceLoader.exists(PIXEL_FONT_PATH):
        pixel_font = load(PIXEL_FONT_PATH)
    _build_ui()
    _apply_saved()
    _sync_all_previews()
    _update_continue()
```

Replace its body with:

```gdscript
func _ready() -> void:
    if ResourceLoader.exists(PIXEL_FONT_PATH):
        pixel_font = load(PIXEL_FONT_PATH)
    _build_ui()
    _apply_saved()
    _refresh_tab_styles()
    _refresh_grid()
    _sync_all_previews()
    _update_continue()
```

- [ ] **Step 4: Rewrite `_apply_saved` to drop dropdown references**

Find `_apply_saved` (~line 431) and replace it with:

```gdscript
func _apply_saved() -> void:
    var saved := GameState.get_character_components()
    for cat in CATEGORIES:
        var option: int = saved.get(cat.to_lower(), 1)
        var max_count: int = PREVIEW_TEXTURES.get(cat, []).size()
        selections[cat] = clampi(option, 1, max(1, max_count))
    name_input.text = GameState.player_name
```

- [ ] **Step 5: Verify the editor parses cleanly**

Open Godot, reload the script.
Expected: no parse errors. Undefined-reference errors from Task 2 should now be resolved.

- [ ] **Step 6: Commit**

```bash
git add scripts/CharacterCustomize.gd
git commit -m "refactor(char-creator): replace dropdown preview with tabbed grid logic

Adds _refresh_grid / _refresh_main_preview / _refresh_mini_previews /
_refresh_tab_styles / _build_tile / _thumbnail_texture_for. Removes
dead dropdown helpers.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Wire signal handlers (tab / tile / direction / visibility / randomize)

**Files:**

- Modify: `scripts/CharacterCustomize.gd` — add `_on_tab_pressed`, `_on_tile_pressed`, `_on_direction_step`; update `_on_visibility_toggled`, `_on_randomize_pressed`; remove `_on_dropdown_changed`.

- [ ] **Step 1: Delete `_on_dropdown_changed`**

Remove the entire `_on_dropdown_changed` function.

- [ ] **Step 2: Add the three new handlers**

In the `SIGNAL HANDLERS` section (right above `_on_visibility_toggled`), add:

```gdscript
func _on_tab_pressed(category: String) -> void:
    if category == active_category:
        return
    active_category = category
    _refresh_tab_styles()
    _refresh_grid()


func _on_tile_pressed(category: String, index_0: int) -> void:
    var max_count: int = PREVIEW_TEXTURES.get(category, []).size()
    selections[category] = clampi(index_0 + 1, 1, max(1, max_count))
    _refresh_grid()          # re-styles the new selection
    _refresh_main_preview()
    _refresh_mini_previews()


func _on_direction_step(step: int) -> void:
    var idx := DIRECTION_ORDER.find(active_direction)
    if idx < 0:
        idx = 0
    idx = (idx + step + DIRECTION_ORDER.size()) % DIRECTION_ORDER.size()
    active_direction = DIRECTION_ORDER[idx]
    direction_label.text = DIRECTION_LABELS[active_direction]
    _refresh_main_preview()
    _refresh_mini_previews()
```

- [ ] **Step 3: Update `_on_visibility_toggled` to use the new preview model**

Replace the existing body:

```gdscript
func _on_visibility_toggled(toggled: bool, category: String) -> void:
    visibility[category] = toggled
    _refresh_main_preview()
    _refresh_mini_previews()
```

- [ ] **Step 4: Update `_on_randomize_pressed`**

Replace with:

```gdscript
func _on_randomize_pressed() -> void:
    for cat in CATEGORIES:
        var textures: Array = PREVIEW_TEXTURES.get(cat, [])
        var max_opts := maxi(1, textures.size())
        selections[cat] = randi_range(1, max_opts)
    _refresh_tab_styles()
    _refresh_grid()
    _refresh_main_preview()
    _refresh_mini_previews()
```

- [ ] **Step 5: Verify parse + signal wiring**

Open Godot, run the project (or open the MainMenu and click through to character creator).
Expected: screen loads with the new layout. (No automated unit test exists for this scene — verification is visual.)

- [ ] **Step 6: Commit**

```bash
git add scripts/CharacterCustomize.gd
git commit -m "feat(char-creator): wire tab, tile, and direction-step handlers

Tile click updates selection and re-renders preview; tab click
swaps the visible grid; arrows cycle the preview direction.
Randomize and visibility toggles now drive the new refresh path.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: Visual verification & polish pass

**Files:** no code changes unless issues surface.

- [ ] **Step 1: Launch game & navigate to Character Creator**

Run: open the project in Godot editor → press F5 (or ▶) → from the main menu walk through to the character creator.
Expected visual checklist — compare against the design PNG:

- [ ] Title "CHARACTER CREATOR" centered, white with shadow
- [ ] Blue checkerboard background covers full screen
- [ ] Tab strip (BODY / HAIR / ACCESSORIES / OUTFIT / EYES) sits at the top of the right panel
- [ ] Active tab is **orange**, inactive tabs are slate-grey
- [ ] Clicking a tab re-populates the grid below with that category's thumbnails
- [ ] Grid shows 4 columns of 120×120 tiles with light-slate backgrounds
- [ ] Selected tile has dark background, yellow border, and "BODY 01"-style label at the bottom
- [ ] Left side shows ONE big character preview (not four)
- [ ] Below preview: 4 small direction thumbnails, current direction outlined in yellow
- [ ] Below that: `<  FRONT  >` carousel; arrows cycle through LEFT→FRONT→BACK→RIGHT
- [ ] Clicking a tile updates ALL five of main preview / 4 minis / tile styles
- [ ] Bottom bar unchanged: NAME input, BACK, RANDOMIZE (orange), 5 checkboxes, CONTINUE
- [ ] Randomize button shuffles all 5 layers and refreshes everything
- [ ] Continue button saves and transitions to PetSelect
- [ ] Back button transitions to IntroCutscene
- [ ] Visibility checkboxes toggle layers on main preview AND minis

- [ ] **Step 2: Check debugger output for errors**

Look at Godot Output panel. Expected: no errors. If warnings about missing 48×48 thumbnails appear, they are silently handled by the atlas fallback in `_thumbnail_texture_for` — acceptable.

- [ ] **Step 3: Run existing game-state flows**

Manual test:

1. Pick a body, hair, outfit, eyes, accessory combination.
2. Type a name → Continue → confirm that PetSelect opens.
3. Return, click BACK → confirm IntroCutscene opens.
4. Re-enter the creator → confirm the saved selections re-load correctly (Task 3 Step 4 logic).

- [ ] **Step 4: Save the session and commit a final "polish" commit only if you adjusted values**

If you tweaked any constants (TILE_SIZE, SPRITE_SCALE, separations, colors) during verification, commit them; otherwise skip this step.

```bash
git add scripts/CharacterCustomize.gd
git commit -m "polish(char-creator): visual adjustments from end-to-end test

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 5: Mark plan complete**

Plan implementation is done. Move on to any follow-up the user requests.

---

## Out of Scope (explicit non-goals)

- No changes to `CharacterAssets.PREVIEW_TEXTURES` (data unchanged — only display changes).
- No changes to `GameState` persistence format (still saves body/hairstyle/outfit/eyes/accessory as 1-based ints).
- No changes to in-game character rendering (only the customization screen).
- No new scene files. Root `.tscn` stays as-is.
- No new dependencies or addons.
- No translation/i18n — strings stay English, matching the rest of the project.

## Self-Review Notes

- Spec coverage: design screenshot features (title, tab strip, grid with selected-tile label, big preview, 4 minis with direction highlight, direction carousel, bottom bar unchanged) each have a task step.
- No placeholders — every code block is complete.
- Naming consistency: `_refresh_grid`, `_refresh_main_preview`, `_refresh_mini_previews`, `_refresh_tab_styles`, `_build_tile`, `_build_mini_direction_preview`, `_build_left_panel`, `_build_right_panel`, `_thumbnail_texture_for`, `_atlas_for`, `_on_tab_pressed`, `_on_tile_pressed`, `_on_direction_step` — all used consistently across tasks.
- Active direction initial value `"down"` matches the default FRONT in `DIRECTION_LABELS`, and `DIRECTION_ORDER` cycles LEFT→FRONT→BACK→RIGHT as on-screen.
- `_thumbnail_texture_for` gracefully falls back when Parts/ 48×48 files are missing, so plan is safe even if some accessory/outfit variants don't have thumbnails yet.
