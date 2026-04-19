# Image-Based Character Customization UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the text-based dropdown character customization system with a modern tabbed interface displaying visual grid selection, similar to MyCareer UI from 2K games.

**Architecture:** The new UI splits into three components: (1) **TabBar** at top for switching between Body/Hairstyle/Eyes/Accessory/Outfit, (2) **ComponentGrid** in center-left showing 4x4 grid of preview thumbnails with hover effects and selection indicator, (3) **PreviewPanel** on right showing 4-direction preview of selected items. The system reuses existing character sprite atlases and GameState integration while completely replacing the OptionButton dropdown hierarchy.

**Tech Stack:** Godot 4.x, GDScript 2.0, existing CharacterAssets.gd data structure, AtlasTexture for sprite regions.

---

## File Structure

**Modified:**
- `scripts/CharacterCustomize.gd` - Complete rewrite to use tab-based navigation instead of dropdowns
- Keep existing preview logic (4 directions, atlas regions, layer ordering)

**Created:**
- `scripts/ComponentGrid.gd` - Reusable grid widget (5 columns, scrollable, 64x64 thumbnails)
- `scripts/TabBar.gd` - Tab navigation (Body/Hairstyle/Eyes/Accessory/Outfit with active indicator)
- None - all UI built procedurally like existing code

**No new scenes** - Maintain procedural UI construction pattern

---

## Implementation Tasks

### Task 1: Create ComponentGrid Widget

**Files:**
- Create: `scripts/ComponentGrid.gd`

**Description:** A reusable grid widget that displays character component options in a scrollable 5-column layout. Each cell shows a 64x64 thumbnail of the component variant with hover/selection states.

- [ ] **Step 1: Create ComponentGrid.gd with grid layout**

```gdscript
# scripts/ComponentGrid.gd
extends PanelContainer

class_name ComponentGrid

# Grid layout constants
const GRID_COLUMNS := 5
const CELL_SIZE := 64  # 64x64 thumbnail
const CELL_SPACING := 4
const PADDING := 8

# Data
var textures: Array = []  # Array of texture paths
var atlas_regions: Dictionary = {}  # Maps to DIR_ATLAS equivalent
var selected_index: int = -1

# UI references
var grid_container: GridContainer
var cells: Array[TextureButton] = []

# Signal
signal selection_changed(index: int)

func _ready() -> void:
	_build_grid()

func _build_grid() -> void:
	# Panel styling
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.25, 0.25)
	sb.border_color = Color(0.15, 0.15, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", sb)

	# Scroll container for grid
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(5 * CELL_SIZE + 4 * CELL_SPACING + 2 * PADDING, 300)
	add_child(scroll)

	# Grid container
	grid_container = GridContainer.new()
	grid_container.columns = GRID_COLUMNS
	grid_container.add_theme_constant_override("h_separation", CELL_SPACING)
	grid_container.add_theme_constant_override("v_separation", CELL_SPACING)
	grid_container.offset.x = PADDING
	grid_container.offset.y = PADDING
	scroll.add_child(grid_container)

func set_options(texture_paths: Array) -> void:
	"""Populate grid with texture options."""
	textures = texture_paths
	selected_index = 0

	# Clear existing cells
	for cell in cells:
		cell.queue_free()
	cells.clear()

	# Create cells
	for i in range(textures.size()):
		var cell := TextureButton.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.texture_normal = load(textures[i])
		cell.modulate = Color.WHITE
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid_container.add_child(cell)
		cells.append(cell)

	# Select first
	_set_selected(0)

func _on_cell_pressed(index: int) -> void:
	_set_selected(index)
	selection_changed.emit(index)

func _set_selected(index: int) -> void:
	if selected_index >= 0 and selected_index < cells.size():
		cells[selected_index].modulate = Color.WHITE

	selected_index = index
	if selected_index < cells.size():
		cells[selected_index].modulate = Color.YELLOW

func get_selected_index() -> int:
	return selected_index
```

- [ ] **Step 2: Verify ComponentGrid loads and displays correctly**

In CharacterCustomize, temporarily add a test grid to verify it works.

---

### Task 2: Create TabBar Navigation Widget

**Files:**
- Create: `scripts/TabBar.gd`

**Description:** Horizontal tab bar showing the 5 customization categories (Body, Hairstyle, Eyes, Accessory, Outfit). Tracks active tab with visual indicator (color change, bottom border, or background).

- [ ] **Step 1: Create TabBar.gd with tab buttons**

```gdscript
# scripts/TabBar.gd
extends HBoxContainer

class_name TabBar

const TABS := ["Body", "Hairstyle", "Eyes", "Accessory", "Outfit"]
const PIXEL_FONT_PATH := "res://assets/fonts/Minecraft.ttf"

var buttons: Array[Button] = []
var active_tab: int = 0
var pixel_font: Font

signal tab_changed(tab_name: String, index: int)

func _ready() -> void:
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		pixel_font = load(PIXEL_FONT_PATH)

	add_theme_constant_override("separation", 0)
	alignment = BoxContainer.ALIGNMENT_CENTER

	for i in range(TABS.size()):
		var btn := Button.new()
		btn.text = TABS[i].to_upper()
		btn.custom_minimum_size = Vector2(150, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.toggle_mode = false

		if pixel_font:
			btn.add_theme_font_override("font", pixel_font)

		btn.pressed.connect(_on_tab_pressed.bind(i))
		add_child(btn)
		buttons.append(btn)

	_set_active_tab(0)

func _on_tab_pressed(index: int) -> void:
	_set_active_tab(index)
	tab_changed.emit(TABS[index], index)

func _set_active_tab(index: int) -> void:
	active_tab = index

	for i in range(buttons.size()):
		var btn := buttons[i]
		var sb: StyleBoxFlat

		if i == active_tab:
			# Active tab: white background
			btn.add_theme_color_override("font_color", Color.BLACK)
			sb = StyleBoxFlat.new()
			sb.bg_color = Color.WHITE
			sb.set_corner_radius_all(0)
			sb.set_border_width_all(0)
		else:
			# Inactive tab: dark grey
			btn.add_theme_color_override("font_color", Color.WHITE)
			sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.45, 0.48, 0.52)
			sb.set_border_width_all(0)

		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)

func get_active_tab() -> String:
	return TABS[active_tab] if active_tab < TABS.size() else ""
```

- [ ] **Step 2: Verify TabBar displays correctly and switches tabs**

---

### Task 3: Refactor CharacterCustomize.gd to use TabBar + ComponentGrid

**Files:**
- Modify: `scripts/CharacterCustomize.gd`

**Description:** Replace the entire dropdown-based UI with the new tab + grid system. Keep all existing preview logic (4-direction preview, atlas regions, GameState integration).

- [ ] **Step 1: Rewrite _build_ui() to use TabBar and ComponentGrid**

Replace lines 67-143 (the old dropdown-based UI) with:

```gdscript
func _build_ui() -> void:
	# ── Background (blue checker) ──
	var checker := _create_checker_bg()
	add_child(checker)

	# ── Main vertical layout ──
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 0)
	add_child(main)

	# Top padding
	var top_pad := Control.new()
	top_pad.custom_minimum_size.y = 20
	main.add_child(top_pad)

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
	main.add_child(title)

	# Small gap
	var gap1 := Control.new()
	gap1.custom_minimum_size.y = 20
	main.add_child(gap1)

	# ── Tab Bar ──
	tab_bar = TabBar.new()
	var tab_center := CenterContainer.new()
	tab_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_center.add_child(tab_bar)
	main.add_child(tab_center)
	tab_bar.tab_changed.connect(_on_tab_changed)

	# Small gap
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 20
	main.add_child(gap2)

	# ── Content area (Grid + Preview) ──
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 30)
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_hbox)

	# Padding container for content
	var content_pad := MarginContainer.new()
	content_pad.add_theme_constant_override("margin_left", 30)
	content_pad.add_theme_constant_override("margin_right", 30)
	content_hbox.add_child(content_pad)

	# Left side: Component grid
	var grid_container := VBoxContainer.new()
	content_pad.add_child(grid_container)

	var grid_label := Label.new()
	grid_label.text = "SELECT OPTION"
	grid_label.add_theme_font_size_override("font_size", 18)
	grid_label.add_theme_color_override("font_color", Color.WHITE)
	if pixel_font:
		grid_label.add_theme_font_override("font", pixel_font)
	grid_container.add_child(grid_label)

	component_grid = ComponentGrid.new()
	grid_container.add_child(component_grid)
	component_grid.selection_changed.connect(_on_grid_selection_changed)

	# Right side: 4-direction preview
	var preview_center := CenterContainer.new()
	content_hbox.add_child(preview_center)

	var preview_hbox := HBoxContainer.new()
	preview_hbox.add_theme_constant_override("separation", 40)
	preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_center.add_child(preview_hbox)

	for dir in DIRECTIONS:
		var col := _create_preview_column(dir)
		preview_hbox.add_child(col)

	# ── Flexible spacer before bottom ──
	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(flex)

	# ── Bottom bar ──
	var bar := _create_bottom_bar()
	main.add_child(bar)
```

- [ ] **Step 2: Add TabBar and ComponentGrid references to class**

Add to top of CharacterCustomize.gd after existing var declarations:

```gdscript
var tab_bar: TabBar
var component_grid: ComponentGrid
var current_category: String = "Body"
```

- [ ] **Step 3: Remove old dropdown creation functions**

Delete these functions (they're replaced):
- `_create_dropdown()` (lines 169-211)
- `_get_option_label()` (lines 214-230)
- Lines 106-115 (old dropdown population loop)

- [ ] **Step 4: Add new tab and grid signal handlers**

```gdscript
func _on_tab_changed(tab_name: String, _index: int) -> void:
	current_category = tab_name
	var textures: Array = PREVIEW_TEXTURES.get(tab_name, [])
	component_grid.set_options(textures)

	# Select previously selected option for this category
	var selected_idx = selections[tab_name] - 1
	component_grid._set_selected(selected_idx)

func _on_grid_selection_changed(index: int) -> void:
	selections[current_category] = index + 1
	_update_preview_for_category(current_category)
```

- [ ] **Step 5: Update _apply_saved() to work with grid**

Replace lines 431-439 with:

```gdscript
func _apply_saved() -> void:
	var saved := GameState.get_character_components()
	for cat in CATEGORIES:
		var option: int = saved.get(cat.to_lower(), 1)
		selections[cat] = option

	# Populate grid with first category (Body)
	current_category = "Body"
	var textures: Array = PREVIEW_TEXTURES.get("Body", [])
	component_grid.set_options(textures)
	var selected_idx = selections["Body"] - 1
	component_grid._set_selected(selected_idx)

	name_input.text = GameState.player_name
```

- [ ] **Step 6: Verify CharacterCustomize still loads without errors**

Test in Godot editor.

---

### Task 4: Refine ComponentGrid Visual Design

**Files:**
- Modify: `scripts/ComponentGrid.gd`

**Description:** Add hover effects, better styling, and preview text labels. Make grid cells feel interactive with visual feedback.

- [ ] **Step 1: Enhance cell styling with hover states**

Replace `_build_grid()` method:

```gdscript
func _build_grid() -> void:
	# Panel styling
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.25, 0.25)
	sb.border_color = Color(0.15, 0.15, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", sb)

	# Scroll container for grid
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(5 * CELL_SIZE + 4 * CELL_SPACING + 2 * PADDING, 350)
	add_child(scroll)

	# Grid container
	grid_container = GridContainer.new()
	grid_container.columns = GRID_COLUMNS
	grid_container.add_theme_constant_override("h_separation", CELL_SPACING)
	grid_container.add_theme_constant_override("v_separation", CELL_SPACING)
	grid_container.offset.x = PADDING
	grid_container.offset.y = PADDING
	scroll.add_child(grid_container)
```

- [ ] **Step 2: Add tooltip showing variant name**

Update `set_options()` method to include tooltips:

```gdscript
func set_options(texture_paths: Array) -> void:
	"""Populate grid with texture options."""
	textures = texture_paths
	selected_index = 0

	# Clear existing cells
	for cell in cells:
		cell.queue_free()
	cells.clear()

	# Create cells
	for i in range(textures.size()):
		var cell := TextureButton.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.texture_normal = load(textures[i])
		cell.modulate = Color.WHITE
		cell.pressed.connect(_on_cell_pressed.bind(i))

		# Add tooltip with variant name
		var filename := textures[i].get_file().get_basename()
		cell.tooltip_text = filename

		grid_container.add_child(cell)
		cells.append(cell)

	# Select first
	_set_selected(0)
```

- [ ] **Step 3: Add mouse filter to enable hover effects**

Update `_set_selected()` to be more visually distinct:

```gdscript
func _set_selected(index: int) -> void:
	if selected_index >= 0 and selected_index < cells.size():
		cells[selected_index].modulate = Color.WHITE
		cells[selected_index].self_modulate = Color.WHITE

	selected_index = index
	if selected_index < cells.size():
		cells[selected_index].modulate = Color.YELLOW
		cells[selected_index].self_modulate = Color(1.2, 1.2, 1.0)  # Slight yellow tint
```

- [ ] **Step 4: Test grid hover and selection**

---

### Task 5: Polish Preview Panel Layout

**Files:**
- Modify: `scripts/CharacterCustomize.gd`

**Description:** Adjust spacing and sizing of the 4-direction preview to match new grid-based layout better. The preview should sit beside the grid at equal visual weight.

- [ ] **Step 1: Update preview column sizing in _create_preview_column()**

```gdscript
func _create_preview_column(direction: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Direction label
	var dir_label := Label.new()
	var dir_names := {"left": "LEFT", "down": "FRONT", "up": "BACK", "right": "RIGHT"}
	dir_label.text = dir_names.get(direction, direction.to_upper())
	dir_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dir_label.add_theme_font_size_override("font_size", 16)
	dir_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	if pixel_font:
		dir_label.add_theme_font_override("font", pixel_font)
	col.add_child(dir_label)

	# Sprite container
	var sprite_w := int(48 * SPRITE_SCALE)
	var sprite_h := int(96 * SPRITE_SCALE)
	var container := Control.new()
	container.custom_minimum_size = Vector2(sprite_w, sprite_h)
	container.clip_contents = true
	col.add_child(container)

	preview_sprites[direction] = {}

	# Layer order: Body → Eyes → Outfit → Hairstyle → Accessory
	var layer_order := ["Body", "Eyes", "Outfit", "Hairstyle", "Accessory"]
	for i in range(layer_order.size()):
		var cat: String = layer_order[i]
		var sprite := Sprite2D.new()
		sprite.name = cat
		sprite.centered = false
		sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		sprite.z_index = i
		container.add_child(sprite)
		preview_sprites[direction][cat] = sprite

	return col
```

- [ ] **Step 2: Test 4-direction preview displays correctly alongside grid**

---

### Task 6: Update Randomize Button to Work with New Grid

**Files:**
- Modify: `scripts/CharacterCustomize.gd`

**Description:** Fix the randomize function to work with the grid selection system instead of dropdowns.

- [ ] **Step 1: Update _on_randomize_pressed()**

```gdscript
func _on_randomize_pressed() -> void:
	for cat in CATEGORIES:
		var textures: Array = PREVIEW_TEXTURES.get(cat, [])
		var max_opts := maxi(1, textures.size())
		var random_opt := randi_range(0, max_opts - 1)
		selections[cat] = random_opt + 1

		# Update grid if this is the current category
		if cat == current_category:
			component_grid._set_selected(random_opt)

		_update_preview_for_category(cat)
```

- [ ] **Step 2: Test randomize button**

---

### Task 7: Integration Testing & Polish

**Files:**
- Test: `scripts/CharacterCustomize.gd`

**Description:** Full end-to-end testing of the new UI system.

- [ ] **Step 1: Test all 5 tabs load correct options**

1. Run project
2. Open CharacterCustomize scene
3. Click each tab (Body, Hairstyle, Eyes, Accessory, Outfit)
4. Verify grid populates with correct textures
5. Verify correct count of options per tab

- [ ] **Step 2: Test grid selection updates preview**

1. Click various grid cells
2. Verify 4-direction preview updates in real-time
3. Verify selected cell stays highlighted (yellow)

- [ ] **Step 3: Test tab persistence**

1. Select an option in Body tab
2. Switch to Hairstyle tab, select an option
3. Switch back to Body tab
4. Verify previous selection is still selected

- [ ] **Step 4: Test randomize**

1. Click Randomize button
2. Verify grid shows new selection
3. Verify preview updates
4. Click Randomize multiple times
5. Verify selections are different each time

- [ ] **Step 5: Test Continue button**

1. Enter a name
2. Click Continue
3. Verify GameState saves selections correctly
4. Verify scene changes to PetSelect

- [ ] **Step 6: Test Back button**

1. Click Back
2. Verify returns to IntroCutscene

- [ ] **Step 7: Test saved selections load**

1. Complete character creation and save
2. Return to CharacterCustomize
3. Verify all selections are restored

---

### Task 8: Commit Changes

**Files:**
- Modified: `scripts/CharacterCustomize.gd`
- Created: `scripts/ComponentGrid.gd`
- Created: `scripts/TabBar.gd`

- [ ] **Step 1: Stage all files**

```bash
git add scripts/CharacterCustomize.gd scripts/ComponentGrid.gd scripts/TabBar.gd
```

- [ ] **Step 2: Commit with message**

```bash
git commit -m "feat: replace dropdown UI with image-based tabbed character customization

- Replace OptionButton dropdowns with TabBar navigation (Body/Hairstyle/Eyes/Accessory/Outfit)
- Add ComponentGrid for 5-column scrollable grid of preview thumbnails
- Maintain existing 4-direction preview and GameState integration
- Visual grid with hover/selection states matching modern character creator design"
```

- [ ] **Step 3: Verify commit**

```bash
git log --oneline -1
```

---

## Verification Checklist

Before marking complete:

- [ ] All 5 tabs appear in TabBar
- [ ] Grid displays textures for each category (not missing textures)
- [ ] Selection updates preview in real-time for all 4 directions
- [ ] Tab switching preserves previous selections
- [ ] Randomize updates grid and preview
- [ ] Continue saves to GameState correctly
- [ ] Back returns to previous scene
- [ ] No console errors or warnings
- [ ] Character preview renders correctly (no missing layers)
- [ ] Saved selections restore on return visit

---

## Known Limitations & Future Enhancements

- Grid fixed to 5 columns - could be made responsive per category
- No drag-to-rotate preview (reference image has it)
- No favorite/bookmarking system
- No preset combinations
- Tooltips show filename only - could show prettier names

These are out of scope for this phase.
