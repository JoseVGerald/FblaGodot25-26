# My Little Buddy — New UI → Godot Implementation Guide

**Target:** Godot 4.6.2 · GDScript 2
**Goal:** Apply the maroon pixel-art frames from `/new ui/` to all 12 menus, keep the game's existing words & assets, and add the missing button feedback (pixel-press + hover + click sound).

> This document is the build spec that matches the interactive prototype
> (`My Little Buddy - New UI Prototype.html`). Open the prototype alongside this
> file to see the visual target for each menu.

---

## Table of Contents

1. [Integration Strategy](#1-integration-strategy)
2. [Colour Palette](#2-colour-palette)
3. [Project Pixel Setup](#3-project-pixel-setup)
   - 3.5 [Screen Sizing & Menu Dimensions](#35-screen-sizing--menu-dimensions)
4. [Shared Code (build these first)](#4-shared-code)
   - 4.1 `Sfx.gd` autoload
   - 4.2 `JuicyButton.gd`
   - 4.3 `UITheme` hook
   - 4.4 `style_pixel_button()`
5. [Tilemap Background Pattern](#5-tilemap-background-pattern)
6. [Per-Menu Implementation](#6-per-menu-implementation)
   - Opening · Dog Chooser · Pet Name · Pet Needs · Pet Supplies · Taxi · Notifications · Financial Hub · Settings · Pause · Game Overview · Character Creator
7. [Per-Menu Checklist](#7-per-menu-checklist)

---

## 1. Integration Strategy

The `/new ui/` folder holds **11 tilemap scenes** (`Map.tscn` + `Layer_*.tscn` TileMapLayers). Each is a **visual-only** pixel-art frame: maroon panel, orange-bracket corners, cream title plaque, baked button shapes — but **no interactive nodes, no text, no scripts**.

**Approach:** keep your existing Control-tree menus, use the tilemap art purely as a backdrop.

1. Instance each `Map.tscn` as a **backdrop** (`Node2D`, scaled up, nearest-filtered).
2. **Toggle off** the baked button TileMapLayers (the shapes that need to be clickable).
3. Place your real `Button` / `Label` nodes over the art, styled with `style_pixel_button()` so they look identical.
4. Add the juice (`JuicyButton` / `_do_juice_on`) so they press, hover, and play sound.

> The **Character Creator** (#12) is the exception — it's built 100% in code with no
> `Map.tscn`. Re-skinning it is a colour/stylebox swap inside the script (see §6.12).

---

## 2. Colour Palette

Sampled directly from the tileset PNGs. Use these in every `StyleBoxFlat` / `Label` override.

| Token        | Hex       | Use                                   |
|--------------|-----------|---------------------------------------|
| `ink`        | `#493333` | All borders, text, outlines           |
| `maroon`     | `#b75b5f` | Panel background (full-screen menus)  |
| `maroon_deep`| `#9c4351` | Darker sections, dividers, grid trays |
| `cream`      | `#ffd7a8` | Title plaque bg, overlay panel bg     |
| `cream_light`| `#ffe3c6` | Highlight line inside plaque          |
| `tan`        | `#e5b67f` | Primary button fill                   |
| `tan_dark`   | `#c7895d` | Primary button inner-bottom shade     |
| `gray`       | `#c6b09b` | Secondary / disabled button           |
| `gray_dark`  | `#8a7868` | Gray button inner-bottom shade        |
| `orange`     | `#ffa34d` | Corner brackets, accent bars, active tab |
| `gold`       | `#ffd071` | Corner highlight, selection outline   |
| `pink`       | `#f29485` | Display / chart background area       |

Stat-bar colours (kept from `needs_menu.gd`): Hunger `#ff8c00` · Thirst `#1e90ff` · Energy `#ffd700` · Health `#32cd32`.

```gdscript
# Add to UITheme.gd as named constants:
const CLR_INK       := Color("#493333")
const CLR_MAROON    := Color("#b75b5f")
const CLR_MAROON_D  := Color("#9c4351")
const CLR_CREAM     := Color("#ffd7a8")
const CLR_CREAM_LT  := Color("#ffe3c6")
const CLR_TAN       := Color("#e5b67f")
const CLR_TAN_HI    := Color("#f0cb97")
const CLR_TAN_DRK   := Color("#c7895d")
const CLR_GRAY      := Color("#c6b09b")
const CLR_GRAY_HI   := Color("#e8d0b9")
const CLR_GRAY_DRK  := Color("#8a7868")
const CLR_ORANGE    := Color("#ffa34d")
const CLR_GOLD      := Color("#ffd071")
```

---

## 3. Project Pixel Setup

The tilesets use **16×16 px tiles**. Keep them crisp:

1. **Project → Project Settings → Rendering → Textures → Default Texture Filter** = `Nearest`.
2. Import each `tileset.png` with **Filter = Nearest** in the Import dock (re-import if needed).
3. When instancing a `Map.tscn` backdrop, set the parent `Node2D` scale to fill its target size (see §3.5). At 16 px tiles and the 1280×832 base, **integer scale 5–8** is the right range — tweak per menu so the panel matches its measured size.l fills the screen without clipping.

The TileSet resource already has `tile_size = Vector2i(16,16)` — no changes needed.

---

## 3.5 Screen Sizing & Menu Dimensions

### Target display — MacBook Air 13" M4

| Spec | Value |
|------|-------|
| Native panel | **2560 × 1664** (Liquid Retina, 2× HiDPI) |
| Default logical ("looks like") | **1280 × 832** |
| Aspect ratio | **16 : 10** (≈ 1.54 : 1) |

Design the game at the **1280 × 832** logical resolution; macOS renders it at 2× on the Retina panel automatically.

### Project Settings → Display → Window

```
Viewport Width        = 1280
Viewport Height       = 832
Mode                  = Maximized (or Fullscreen for shipping)
Stretch Mode          = canvas_items     # scales UI smoothly to any window size
Stretch Aspect        = expand           # uses the full 16:10 area, no letterbox
stretch/scale         = 1.0
dpi/allow_hidpi       = true             # crisp on Retina
```

> **Why `canvas_items` + `expand`:** the menus mix pixel-art tilemaps with `Control`
> text/buttons. `canvas_items` keeps the Control UI sharp at any size, while
> `expand` lets full-screen menus fill the whole 16:10 screen instead of
> letterboxing. Keep each tilemap **`Node2D` backdrop at an _integer_ scale**
> (5×, 6×, 7×) so the 16 px pixel art never blurs — the surrounding maroon fills
> the rest of the screen.

### The persistent HUD (always on screen — restyle it too)

Before the menus: the game keeps a **persistent HUD** visible during normal play (see screenshots). It is **not** in `/new ui/`, so it needs the same maroon restyle by hand:

- **Top-right context buttons** (~48 px tall each): on the house map → **Finances · Mail · Pause**; on the road map → **Note · Mail · More (…)**. Style each with `style_pixel_button()` (tan) + `_do_juice_on()`.
- **Bottom HUD bar** (full width, ~**72 px** tall at 1280×832): `$150.00` + pathway label on the left, **"Monday Week 1"** centered, **Supplies · Needs · Taxi** buttons on the right. Re-skin the bar as a maroon/ink strip; the 3 buttons get `style_pixel_button(btn, true)`.

> These two HUD elements frame every in-game overlay. The overlays open **anchored
> relative to this HUD**, not centered on the raw screen.

### Three menu classes — they are NOT the same size

The screenshots show three distinct behaviours. Build each class with the right anchor:

#### A) Corner-docked HUD popups — small, bottom-right, **NO dimming**

**Taxi · Pet Needs · Pet Supplies**

These dock to the **bottom-right corner**, just above the bottom HUD bar, and the **game stays fully visible behind them** (no dark overlay — confirmed in-game). They are small and each a **different size**.

```
CanvasLayer  (over the HUD)
└─ Control "Panel"
     # NO dim ColorRect — gameplay shows through
     anchors_preset = PRESET_BOTTOM_RIGHT
     # nudge in from the right edge and up above the 72px HUD bar:
     offset_right  = -16
     offset_bottom = -88          # 72 (HUD) + 16 margin
     offset_left   = -(panel_w + 16)
     offset_top    = -(88 + panel_h)
     ├─ Node2D "Backdrop"   # Map.tscn frame at integer scale to match panel_w/h
     └─ <content>
```

Measured proportions (from the screenshots) and target sizes at **1280 × 832**:

| Popup        | % of screen (W×H) | Target px (W×H) | Layout note |
|--------------|-------------------|-----------------|-------------|
| **Taxi**       | ~14% × ~29%   | **190 × 250**  | Title+✕, then 4 rows (Home/Store/Vet/Park) each with `$10` right-aligned in green |
| **Pet Needs**  | ~30% × ~28%   | **390 × 240**  | Title+✕, then a **2×2 grid**: HUNGER \| THIRST (top), ENERGY \| HEALTH (bottom). Each cell = label + small bar + `100/100` |
| **Pet Supplies** | ~24% × ~17% | **300 × 150**  | Title+✕, then 3 text lines: `Food: N days left` · `Water: N days left` · `Medication: …` |

> **Pet Needs has a docked hint box.** A second `Control` (~**390 × 110**) sits
> *directly below* the panel with tutorial text ("This tells you the needs of your
> little buddy…"). Anchor it to the panel's bottom edge so the two move together.
> The Needs popup is the **widest** of the three because of its two-column grid;
> Supplies is the **shortest**. They are deliberately different sizes — don't
> normalise them.

#### B) Centered modal panels — dimmed background

**Pause · Notifications**

These open centered with a **dim ColorRect** behind them (the game pauses/blurs out of focus).

```
CanvasLayer  (layer 10+, Notifications uses 12)
├─ ColorRect "Dim"     # black, alpha ~0.45, anchor FULL_RECT
└─ Control "Panel"     # anchor = CENTER, fixed size
```

| Modal         | % of screen (W×H) | Target px (W×H) | Shape |
|---------------|-------------------|-----------------|-------|
| **Pause**         | ~28% × ~58%   | **360 × 480**  | narrow column, 5 stacked buttons (Settings/Help/Achievements/Resume/Quit) |
| **Notifications** | ~50% × ~50%   | **640 × 420**  | wide list, title + "N Notifications" + dismissible rows |

#### C) Full-screen menus — fill the entire 1280 × 832

**Financial Hub · Settings · Opening · Dog Chooser · Pet Name · Character Creator · Game Overview**

The standalone scenes (Opening, Dog Chooser, Pet Name, Character Creator, Game Overview) **and** the two big in-game systems (**Financial Hub** fills the screen edge-to-edge; **Settings** is full-screen/large) take over the whole viewport.

The tilemaps are ~14×10 tiles — a different aspect than 16:10 — so back them with a full-bleed `ColorRect` and center the framed art:

```
Control "Root"  (anchor = FULL_RECT)
├─ ColorRect "Bg"      # maroon #b75b5f (or navy→maroon for Finance), FULL_RECT
├─ Node2D "Backdrop"   # Map.tscn frame at integer scale, CENTERED
│     # position = (viewport - panel_px) / 2
└─ <centered content>  # title plaque, tabs, buttons — anchored to centre
```

> **Why a full-bleed `ColorRect`:** it guarantees no black bars when the tilemap's
> aspect doesn't match the screen. Keep the tilemap `Node2D` at an **integer scale**
> (5×/6×/7×) so the 16 px pixel art never blurs; the `ColorRect` fills the rest.

### Notch & safe area

In fullscreen, macOS keeps game content **below the camera notch**, so the usable area is clean 16:10 — no special handling needed. Just don't pin critical UI to the extreme top-center, and you're safe on any Mac.

---

## 4. Shared Code

> Build these four pieces first. Every menu depends on them.

### 4.1 `Sfx.gd` — AutoLoad singleton

Create `res://scripts/Sfx.gd`, register it as autoload **`Sfx`** (Project → Project Settings → AutoLoad). Drop a short click WAV at `res://assets/sfx/click.wav` (16-bit mono, <100 ms).

```gdscript
# Sfx.gd  — AutoLoad singleton named "Sfx"
extends Node

var _player : AudioStreamPlayer
var _click  : AudioStream = null

func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.bus = "Master"
    add_child(_player)
    var p := "res://assets/sfx/click.wav"
    if ResourceLoader.exists(p):
        _click = load(p)

func click(pitch : float = 1.0) -> void:
    if _click == null: return
    _player.stream = _click
    _player.pitch_scale = randf_range(0.94, 1.08) * pitch
    _player.volume_db = -6.0
    _player.play()
```

> Gracefully no-ops if the WAV is missing, so you can ship the juice code before
> you have the sound asset.

### 4.2 `JuicyButton.gd` — drop-in button feedback

Hover scale-up + pixel press-down (squash) + click sound. Uses `scale` (which containers don't touch), so it's safe inside `VBoxContainer` / `GridContainer`.

```gdscript
# JuicyButton.gd
# Usage: set this as a Button's script, OR call UITheme._do_juice_on(btn) from code.
class_name JuicyButton
extends Button

@export var press_squash : float = 0.88   # Y scale on press
@export var hover_scale  : float = 1.05   # uniform scale on hover
@export var anim_secs    : float = 0.07
@export var play_sound   : bool  = true

var _tw : Tween

func _ready() -> void:
    _centre_pivot()
    resized.connect(_centre_pivot)
    mouse_entered.connect(_hover)
    mouse_exited.connect(_unhover)
    button_down.connect(_down)
    button_up.connect(_up)

func _centre_pivot() -> void:
    pivot_offset = size * 0.5

func _go(target : Vector2, trans := Tween.TRANS_BACK, ease := Tween.EASE_OUT) -> void:
    if _tw: _tw.kill()
    _tw = create_tween().set_trans(trans).set_ease(ease)
    _tw.tween_property(self, "scale", target, anim_secs)

func _hover() -> void:
    if not disabled: _go(Vector2.ONE * hover_scale)

func _unhover() -> void:
    _go(Vector2.ONE, Tween.TRANS_EXPO)

func _down() -> void:
    if play_sound: Sfx.click()
    _go(Vector2(1.03, press_squash), Tween.TRANS_QUAD, Tween.EASE_IN)

func _up() -> void:
    _go(Vector2.ONE * (hover_scale if is_hovered() else 1.0))
```

### 4.3 `UITheme` hook — one change, every menu

`UITheme.gd` already walks every node via `_style_children_recursive`. Add the juice call so all existing and future buttons get it for free.

```gdscript
# In UITheme.gd — _style_children_recursive()
elif node is Button:
    style_button(node, _auto_button_color(node))
    _juice_button(node)          # ← ADD THIS LINE

# Add this static helper:
static func _juice_button(btn : Button) -> void:
    if btn.has_meta("juiced"): return
    btn.set_meta("juiced", true)
    btn.call_deferred("_do_juice_proxy")   # deferred so size is known

# Because Button has no _do_juice_proxy, wire via a deferred lambda instead:
static func _juice_button(btn : Button) -> void:    # (use THIS version)
    if btn.has_meta("juiced"): return
    btn.set_meta("juiced", true)
    btn.call_deferred(func(): UITheme._do_juice_on(btn))

# The actual juice (runs after layout so pivot is correct):
static func _do_juice_on(btn : Button) -> void:
    btn.pivot_offset = btn.size * 0.5
    btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
    btn.mouse_entered.connect(func():
        if btn.disabled: return
        var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.tween_property(btn, "scale", Vector2.ONE * 1.05, 0.10))
    btn.mouse_exited.connect(func():
        var tw := btn.create_tween()
        tw.tween_property(btn, "scale", Vector2.ONE, 0.08))
    btn.button_down.connect(func():
        Sfx.click()
        var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tw.tween_property(btn, "scale", Vector2(1.03, 0.88), 0.06))
    btn.button_up.connect(func():
        var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.tween_property(btn, "scale", Vector2.ONE, 0.10))
```

### 4.4 `style_pixel_button()` — new palette styling

Replace `UITheme.style_button(btn, color)` with this where you want the full new-UI pixel look. The trick: a thick bottom border that gets thinner on press, so the button visually sinks.

```gdscript
# Add to UITheme.gd
static func style_pixel_button(btn : Button, secondary : bool = false) -> void:
    var f := get_pixel_font()
    if f: btn.add_theme_font_override("font", f)
    btn.add_theme_color_override("font_color",         CLR_INK)
    btn.add_theme_color_override("font_hover_color",   CLR_INK)
    btn.add_theme_color_override("font_pressed_color", CLR_INK)

    var fill     := CLR_GRAY     if secondary else CLR_TAN
    var fill_hi  := CLR_GRAY_HI  if secondary else CLR_TAN_HI
    var fill_drk := CLR_GRAY_DRK if secondary else CLR_TAN_DRK

    btn.add_theme_stylebox_override("normal",   _pxsb(fill,                 fill_drk, 8))
    btn.add_theme_stylebox_override("hover",    _pxsb(fill_hi,              fill_drk, 8))
    btn.add_theme_stylebox_override("pressed",  _pxsb(fill.darkened(0.06),  fill_drk, 2))
    btn.add_theme_stylebox_override("disabled", _pxsb(fill.darkened(0.30),  fill_drk, 0))

static func _pxsb(fill : Color, shadow : Color, depth : int) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color            = fill
    sb.border_color        = CLR_INK
    sb.border_width_top    = 3
    sb.border_width_left   = 3
    sb.border_width_right  = 3
    sb.border_width_bottom = 3 + depth          # thick bottom = 3-D base
    sb.anti_aliasing       = false              # crisp pixel edges
    sb.set_corner_radius_all(0)                 # sharp = pixel art
    sb.content_margin_left   = 18
    sb.content_margin_right  = 18
    sb.content_margin_top    = 12
    sb.content_margin_bottom = 12 + (8 - depth) # shrinks on press = sinks
    return sb
```

---

## 5. Tilemap Background Pattern

Each menu folder contains: `Map.tscn` (root composer), 2–4 `Layer_*.tscn` (TileMapLayers), `tileset.tres`, `tileset.png`.

**Draw order:** higher filename suffix = bottom-most layer. e.g. `Layer_0_2` is drawn first (back), `Layer_2_0` last (front).

**Node structure to adopt in every menu:**

```
CanvasLayer                  # your existing root (overlays) or Control (full-screen)
└─ Control "Root"            # anchor_preset = FULL_RECT
   ├─ Node2D "Backdrop"      # ← NEW: instance of new ui/<MENU>/Map.tscn
   │     scale = Vector2(7, 7)        # tweak 6–8 to fit
   │     position = Vector2(ox, oy)   # nudge so panel is centred
   └─ <your existing content container>   # Labels, Buttons (now styled)
```

**Coordinate alignment example (Opening Menu):** the title plaque spans tiles `(1,1)–(12,2)`. At scale 8 that's pixels `(128,128)–(960,160)`. Anchor your title `Label` to match. Hover elements in the prototype to read each region.

**To hide a baked button layer:** open `Map.tscn`, select the `TileMapLayer` whose shapes you're replacing (named below per menu), and uncheck **Visible** (or `queue_free()` it at runtime). Your real styled Buttons sit where those shapes were.

---

## 6. Per-Menu Implementation

> Format per menu: **New UI source** → **Game target** → **layers to hide** → **node tree** → **content/wiring**.

### 6.1 Opening Menu

- **New UI:** `new ui/FINAL OPENING MENU/Map.tscn`
- **Game target:** `scenes/ui/MainMenu.tscn` · `scripts/MainMenu.gd`
- **Anchor:** full-screen scene (class C, §3.5) — maroon `ColorRect` bg + centered tilemap frame.
- **Layers:** `Layer_0_1` (panel + frame, keep) · `Layer_1_0` (title plaque + 3 button shapes → **hide**)

```
Control "MainMenu"
├─ Node2D "Backdrop"   (Map.tscn, scale ~7)
└─ VBoxContainer       (anchored centre, separation 22)
   ├─ Label "Title"        text="My Little Buddy"  (font_size 100, cream)
   ├─ Button "Continue"    text="Continue Game"
   ├─ Button "StartNew"    text="Start New Game"
   └─ Button "Settings"    text="Settings"
```

```gdscript
# MainMenu.gd  (_ready)
UITheme.style_pixel_button($VBoxContainer/Continue)
UITheme.style_pixel_button($VBoxContainer/StartNew)
UITheme.style_pixel_button($VBoxContainer/Settings, true)   # secondary (gray)
# wiring (unchanged):
$VBoxContainer/Continue.pressed.connect(_on_continue)   # load save → MainGame.tscn
$VBoxContainer/StartNew.pressed.connect(_on_start_new)  # wipe save → IntroCutscene.tscn
$VBoxContainer/Settings.pressed.connect(_on_settings)   # instance SettingsMenu.tscn
```

### 6.2 Dog Chooser

- **New UI:** `new ui/FINAL DOG CHOOSER MENU/Map.tscn`
- **Game target:** `scenes/.../PetSelect.tscn` · `scripts/PetSelect.gd`
- **Anchor:** full-screen scene (class C, §3.5).
- **Layers:** `Background_3` (frame, keep) · `Foreground_2` (banner, keep) · `Buttons_1` (◀▶ + bottom bar → **hide**) · `Decor_0` (top decor, keep)

```
Control "PetSelect"
├─ Node2D "Backdrop"
└─ VBoxContainer
   ├─ Label "Header"   text="Choose Your Buddy"
   ├─ HBoxContainer
   │  ├─ Button "Prev"        text="◀"   (secondary)
   │  ├─ AnimatedSprite2D "Preview"       (plays "<breed_id>_idle")
   │  └─ Button "Next"        text="▶"   (secondary)
   ├─ Label "BreedName"  (font_size 60)
   └─ Button "Choose"   text="Choose This Buddy"
```

```gdscript
# PetSelect.gd
const BREEDS := ["golden","husky","dalmatian","labrador",
                 "rottweiler","argentino","pharaoh","cane_corso"]
var _i := 0
func _step(d:int)->void:
    _i = wrapi(_i + d, 0, BREEDS.size())
    $Preview.animation = BREEDS[_i] + "_idle"
    $Preview.play()
    $BreedName.text = _display_name(BREEDS[_i])
# Prev/Next call _step(-1)/_step(1); Choose → GameState.breed = BREEDS[_i]; goto PetName.tscn
UITheme.style_pixel_button($Choose)
UITheme.style_pixel_button($Prev, true); UITheme.style_pixel_button($Next, true)
```

### 6.3 Pet Name

- **New UI:** `new ui/FINAL PET NAME/Map.tscn`
- **Game target:** `PetName.tscn` · `scripts/PetName.gd`
- **Anchor:** full-screen scene (class C, §3.5).
- **Layers:** `Layer_0_2` (frame, keep) · `Layer_1_1` (cream panel, keep) · `Layer_2_0` (input + button shapes → **hide**)

```
Control "PetName"
├─ Node2D "Backdrop"
└─ VBoxContainer
   ├─ Label "Title"          text="Name Your Buddy"
   ├─ AnimatedSprite2D "Preview"   (loaded from chosen dog.tscn)
   ├─ LineEdit "NameField"   placeholder="Type a name…"  max_length=14
   └─ Button "Continue"      text="Continue"
```

```gdscript
# PetName.gd
$NameField.text_changed.connect(func(t):
    $NameField.text = _strip(t)   # letters + spaces only
    $Continue.disabled = $NameField.text.strip_edges() == "")
$Continue.pressed.connect(func():
    GameState.pet_name = $NameField.text.strip_edges()
    get_tree().change_scene_to_file("res://.../CostCustomization.tscn"))
UITheme.style_pixel_button($Continue)
```

### 6.4 Pet Needs

- **New UI:** `new ui/FINAL PET NEEDS/Map.tscn`
- **Game target:** `scripts/needs_menu.gd`
- **Anchor:** corner-docked bottom-right, **no dim** (class A, §3.5). Widest of the 3 popups (~390×240) + a hint box below.
- **Layers:** `Layer_0_1` (cream panel, keep) · `Layer_1_0` (4 bar placeholders + X → **hide**)

```
CanvasLayer
└─ Control "Root"   (anchor = BOTTOM_RIGHT, above the HUD bar)
   ├─ Node2D "Backdrop"
   ├─ HBoxContainer "TitleRow"
   │  ├─ Label "Title"   text="Pet Needs"
   │  └─ Button "Close"  text="✕"   (red X — see §6.note)
   ├─ GridContainer "Bars"   columns = 2     # ← 2×2 grid, matches the game
   │  ├─ <Hunger cell>  fill #ff8c00     │  <Thirst cell>  fill #1e90ff
   │  └─ <Energy cell>  fill #ffd700     │  <Health cell>  fill #32cd32
   └─ Control "HintBox"   # docked BELOW the panel (~390×110)
        Label  text="This tells you the needs of your little buddy.
                     When food or water is low, take them back home to feed them."
```

Each **cell** = `VBox( Label "HUNGER",  HBox( ProgressBar, Label "72/100" ) )`. Two columns → HUNGER \| THIRST on the top row, ENERGY \| HEALTH on the bottom row (exactly as the screenshot).

```gdscript
# needs_menu.gd  — colour the ProgressBar fill via StyleBoxFlat
func _set_bar(bar:ProgressBar, value:int, col:Color)->void:
    bar.value = value
    var fg := StyleBoxFlat.new()
    fg.bg_color = Color("#ef5350") if value < 30 else col    # flash red when low
    fg.set_corner_radius_all(0); fg.border_color = UITheme.CLR_INK; fg.set_border_width_all(4)
    bar.add_theme_stylebox_override("fill", fg)
# label text "%d/100"; append " !" and turn the name label red when value < 30
```

> The red **✕ close** button: style with a red `StyleBoxFlat` (`#ef5350`, ink border, square corners) and call `UITheme._do_juice_on($Close)`. Same pattern for every menu's close button.

### 6.5 Pet Supplies

- **New UI:** `new ui/FINAL PET SUPPLIES/Map.tscn`
- **Game target:** `scripts/supplies_menu.gd`
- **Anchor:** corner-docked bottom-right, **no dim** (class A, §3.5). Shortest of the 3 popups (~300×150).
- **Layers:** `Layer_0_1` (cream panel + dividers, keep) · `Layer_1_0` (3 row bars + X → **hide**)

```
CanvasLayer
└─ Control "Root"
   ├─ Node2D "Backdrop"
   ├─ HBoxContainer "TitleRow"  (Label "Pet Supplies" + Close ✕)
   └─ VBoxContainer "Rows"
      ├─ HBox: TextureRect(DogFood.png)     Label "Food"        Label "5 days left"
      ├─ HBox: TextureRect(DogWaterBowl.png) Label "Water"       Label "2 days left" (red if <5)
      └─ HBox: TextureRect(DogVitamins.png) Label "Medication"  Label "<state>"
```

```gdscript
# supplies_menu.gd
func _row(lbl:Label, days:int)->void:
    lbl.text = "%d days left" % days
    lbl.add_theme_color_override("font_color",
        Color("#ef5350") if days < 5 else UITheme.CLR_MAROON_D)
# show a warning strip (red-outlined PanelContainer) if food or water < 5
```

Icons: `res://assets/DogPackPaid/DogStuffs/{DogFood,DogWaterBowl,DogVitamins}.png`.

### 6.6 Taxi

- **New UI:** `new ui/FINAL TAXI/Map.tscn`
- **Game target:** `scripts/taxi_menu.gd`
- **Anchor:** corner-docked bottom-right, **no dim** (class A, §3.5). Smallest popup (~190×250).
- **Layers:** `Layer_0_2` (cream panel, keep) · `Layer_1_1` (4 button shapes → **hide**) · `Layer_2_0` (X + title underline, keep)

```
CanvasLayer
└─ PanelContainer
   ├─ Node2D "Backdrop"
   ├─ HBoxContainer "TitleRow"  (Label "Call a Taxi" + Close ✕)
   └─ VBoxContainer "Dests"
      ├─ Button "Home"   (row style: label + "$12" cost on right)
      ├─ Button "Store"
      ├─ Button "Vet"
      └─ Button "Park"
```

```gdscript
# taxi_menu.gd
for d in ["Home","Store","Vet","Park"]:
    var b := _make_row_button(d, "$%d" % GameState.taxi_cost)  # $0 on News-Boy path
    UITheme.style_pixel_button(b, true)   # gray row
    b.pressed.connect(func(): _travel_to(d))
# show "not near road" warning if applicable
```

> **Row buttons** (taxi/pause): left-aligned text + an accent `ColorRect` lead on the left + a cost `Label` pushed right (use `size_flags_horizontal = EXPAND` on a spacer). Same `style_pixel_button(b, true)` gray fill.

### 6.7 Notifications

- **New UI:** `new ui/FINAL NOTIFICATIONS/Map.tscn`
- **Game target:** `scripts/notification_panel.gd`
- **Anchor:** centered modal + dim (class B, §3.5) — wide list (~640×420).
- **Layers:** `Layer_0_2` (cream bg, keep) · `Layer_2_1` (row dividers, keep) · `Layer_3_0` (X + title, keep outline)

```
CanvasLayer (layer 12)
└─ Control "Root"
   ├─ Node2D "Backdrop"
   ├─ HBoxContainer "TitleRow"  (Label "Notifications" + Close ✕)
   ├─ Label "Count"   text="N Notifications"
   └─ ScrollContainer
      └─ VBoxContainer "List"
         └─ <notif row × N>
```

Each row = `HBox( Label icon(!/★/•), VBox( Label type+day, Label message ), Label "→"?, Button dismiss✕ )`.

```gdscript
# notification_panel.gd
func _add_row(n)->void:
    var row := _build_row(n)             # icon colour: warn=#ef5350, achiev=#ffd071, event=#8a7868
    row.gui_input.connect(...)           # click row → taxi dialog / finance / achievements
    var x := row.get_node("Dismiss")
    UITheme._do_juice_on(x)
    x.pressed.connect(func(): row.queue_free(); _recount())
func _recount()->void:
    $Count.text = "%d Notification%s" % [n, "" if n==1 else "s"]
```

### 6.8 Financial Hub

- **New UI:** `new ui/FINAL FINANCIAL HUB/Map.tscn`
- **Game target:** `FinanceMenu.tscn` · `scripts/finance_menu.gd`
- **Anchor:** full-screen (class C, §3.5) — fills the screen edge-to-edge.
- **Layers:** `Layer_0_2` (frame, keep) · `Layer_1_1` (5 tab dashes → keep, or replace with TabBar) · `Layer_2_0` (pie area + close → **hide** buttons)

```
CanvasLayer
└─ Control "Root"
   ├─ Node2D "Backdrop"
   ├─ HBoxContainer "TitleRow"  (Label "Financial Hub" + Label "DAY n · WEEK n" + Close ✕)
   ├─ HBoxContainer "Tabs"      (5 Buttons OR a TabBar)
   └─ PanelContainer "Pane"     (swaps content per tab)
```

Tabs: **Overview · Budget Planner · Weekly Report · Loans · All-Time History** (verbatim from `finance_menu.gd`).

```gdscript
# finance_menu.gd  — tab styling
func _style_tab(b:Button, active:bool)->void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = UITheme.CLR_ORANGE if active else UITheme.CLR_GRAY_DRK
    sb.border_color = UITheme.CLR_INK; sb.set_border_width_all(3); sb.set_corner_radius_all(0)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_color_override("font_color",
        UITheme.CLR_INK if active else Color.WHITE)
# category colours in charts: Food #4caf50 · Vet #4a90d9 · Travel #ffa726
```

### 6.9 Settings

- **New UI:** `new ui/FINAL SETTINGS/Map.tscn`
- **Game target:** `scripts/SettingsMenu.gd`
- **Anchor:** full-screen / large (class C, §3.5).
- **Layers:** `Layer_0_2` (cream side panel, keep) · `Layer_1_1` (dividers + toggle placeholders, keep) · `Layer_2_0` (X + 2 bottom buttons → **hide**)

```
CanvasLayer
└─ Control "Root"
   ├─ Node2D "Backdrop"
   ├─ HBoxContainer "TitleRow"  (Label "Settings" + Close ✕)
   └─ ScrollContainer → VBoxContainer
      ├─ Label "AUDIO"
      │  ├─ <Music Volume>  HSlider
      │  ├─ <SFX>           HSlider
      │  └─ <Mute All>      CheckButton (toggle)
      ├─ Label "GAME"     (Notifications · Inflation Active · Random Events toggles)
      ├─ Label "DISPLAY"  (Tooltips · Fullscreen toggles)
      └─ Label "CONTROLS" → Button "Keybinds"
```

```gdscript
# SettingsMenu.gd — toggle (CheckButton) styling
func _style_toggle(t:CheckButton)->void:
    # off track = #b39a86, on track = #4caf50, knob = cream, ink outline, square corners
    ...
# HSlider: grabber = cream square, fill = orange; section labels in maroon-deep
UITheme.style_pixel_button($Keybinds, true)
```

### 6.10 Pause

- **New UI:** `new ui/FINAL PAUSE/Map.tscn`
- **Game target:** `scripts/PauseMenu.gd`  (buttons wired by `bottom_hud.gd`)
- **Anchor:** centered modal + dim (class B, §3.5) — narrow column (~360×480). *Confirm in-game whether Pause dims the background; if it stays clear, drop the dim `ColorRect`.*
- **Layers:** `Layer_0_2` (cream panel, keep) · `Layer_1_1` (5 row shapes → **hide**) · `Layer_2_0` (X + title strip, keep)

```
CanvasLayer
└─ Control "Root"
   ├─ Node2D "Backdrop"
   ├─ HBoxContainer "TitleRow"  (Label "Paused" + Close ✕)
   └─ VBoxContainer "Buttons"
      ├─ Button "Settings"      (accent lead blue  #4a90d9)
      ├─ Button "Help"          (accent lead cyan  #53d8fb)
      ├─ Button "Achievements"  (accent lead gold  #ffd071)
      ├─ Button "Resume"        (accent lead green #4caf50)
      └─ Button "Quit"          (accent lead red   #ef5350)
```

```gdscript
# PauseMenu.gd — apply theme; bottom_hud.gd keeps the existing pressed connections
for b in $Buttons.get_children():
    UITheme.style_pixel_button(b, true)
# Close ✕ behaves like Resume
$TitleRow/Close.pressed.connect(_on_resume)
```

### 6.11 Game Overview / Final Stats

- **New UI:** `new ui/FINAL GAME OVERVIEW/Map.tscn`
- **Game target:** `scripts/final_stats_screen.gd`
- **Anchor:** full-screen scene (class C, §3.5).
- **Layers:** `Layer_0_2` (frame, keep) · `Layer_1_1` (title plaque + pink chart area, keep) · `Layer_2_0` (3 stat bars + close btn → **hide**)

```
Control "FinalStats"
├─ Node2D "Backdrop"
├─ Label "Title"   text="CONGRATULATIONS!"   (gold, plaque)
├─ Label "Sub"     text="You purchased the home for <pet_name>!"
├─ HBoxContainer
│  ├─ PanelContainer "Stats"   (6 rows: Player Name, Buddy's Name, Days Played,
│  │                            Starting Cash, Ending Cash, Ending Savings)
│  └─ PanelContainer "Chart"   (pink bg, savings line graph — keep existing draw code)
└─ Button "Return"  text="Return to Main Menu"
```

```gdscript
# final_stats_screen.gd
$Title.add_theme_color_override("font_color", UITheme.CLR_GOLD)
UITheme.style_pixel_button($Return)
$Return.pressed.connect(func():
    GameState.reset()
    get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
```

### 6.12 Character Creator / Player Editor

- **New UI:** *(none — built 100% in code)*
- **Game target:** `scripts/CharacterCustomize.gd` · `scripts/CharacterAssets.gd`

There is no `Map.tscn` for this screen. Re-skinning = **colour/stylebox swaps inside the script**. Layout, carousel, grid, name field, and checkboxes keep their exact positions and behaviour.

**A. Maroon background** — in `_create_checker_bg()` swap the shader uniforms:
```gdscript
uniform vec4 color1 : source_color = vec4(0.718, 0.357, 0.373, 1.0); # #b75b5f
uniform vec4 color2 : source_color = vec4(0.612, 0.263, 0.318, 1.0); # #9c4351
```

**B. Title → cream:**
```gdscript
title.add_theme_color_override("font_color", Color("#ffd7a8"))
title.add_theme_color_override("font_shadow_color", Color("#9c4351"))
```

**C. Tabs → tan / orange-active** — in `_create_tab_button()`:
```gdscript
sb.bg_color        = Color("#8a7868"); sb.set_corner_radius_all(0)   # inactive
sb_hover.bg_color  = Color("#9c8975")
sb_active.bg_color = Color("#ffa34d"); sb_active.set_corner_radius_all(0)   # active
# active tab font_color → Color("#493333") so it reads on orange
```

**D. Grid tiles → cream / deep-maroon + gold selection** — in `_build_tile()`:
```gdscript
sb.bg_color     = Color("#493333") if is_selected else Color("#c6b09b")
sb.border_color = Color("#ffd071") if is_selected else Color("#493333")
sb.set_corner_radius_all(0)
# put a deep-maroon (#9c4351) PanelContainer behind the GridContainer as a tray
UITheme._do_juice_on(btn)   # before `return btn`
```

**E. Bottom bar → cream** — in `_create_bottom_bar()`:
```gdscript
sb.bg_color = Color("#ffd7a8"); sb.border_color = Color("#493333"); sb.border_width_top = 6
```

**F. Buttons** — pass new fills into `_create_styled_button()`: BACK `#c6b09b`, RANDOMIZE `#ffa34d`, CONTINUE `#4caf50`. Set `sb.set_corner_radius_all(0)` and `sb.border_width_bottom = 6`, then `UITheme._do_juice_on(btn)`.

**Content reference (unchanged):**

| Element            | Value                                                        |
|--------------------|--------------------------------------------------------------|
| Title              | `CHARACTER CREATOR`                                          |
| Tabs               | BODY · HAIR · ACCESSORIES · OUTFIT · EYES                    |
| Categories (code)  | Body · Hairstyle · Accessory · Outfit · Eyes                 |
| Directions         | LEFT · FRONT · BACK · RIGHT (carousel ◀ ▶)                   |
| Bottom-left        | BACK · RANDOMIZE                                             |
| Bottom-center      | NAME: [LineEdit · letters+spaces · 25 max]                   |
| Bottom-right       | 5 visibility checkboxes + CONTINUE                           |
| Sprites            | `res://assets/sprites/Character Components/{Body,Hairstyle,…}/` — 48×96 frames, atlas `Rect2(864,96,48,96)` = FRONT idle |
| Continue →         | `PetSelect.tscn`  ·  Back → `IntroCutscene.tscn`             |

---

## 7. Per-Menu Checklist

For each of the 12 menus, confirm:

- [ ] `Map.tscn` instanced as `Backdrop` Node2D (scale 6–8, filter Nearest) — *except Character Creator*
- [ ] Baked button TileMapLayer(s) hidden (see per-menu "Layers")
- [ ] Real `Button`/`Label` nodes placed over the art with correct game text
- [ ] `UITheme.style_pixel_button(btn[, secondary])` applied
- [ ] `UITheme._do_juice_on(btn)` wired (or `JuicyButton` script attached)
- [ ] Close ✕ buttons styled red + juiced
- [ ] `Sfx` autoload registered, `click.wav` present
- [ ] Project Default Texture Filter = Nearest

**Global one-time setup:**

- [ ] `Sfx.gd` autoload added (§4.1)
- [ ] `JuicyButton.gd` created (§4.2)
- [ ] `UITheme._juice_button` hook + `_do_juice_on` added (§4.3)
- [ ] `style_pixel_button()` + palette constants added to `UITheme.gd` (§4.4, §2)

---

*Generated from full analysis of the `constanlyupdate/` project · Godot 4.6.2 · GDScript 2. Matches `My Little Buddy - New UI Prototype.html`.*
