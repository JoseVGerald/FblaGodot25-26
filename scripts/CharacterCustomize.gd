# COMMIT: Achievements and Catch Minigame Update
extends Control

## Character customization screen inspired by the Character-Generator-2.0 UI.
## Features dropdown selectors, 4-directional preview, component visibility toggles,
## and a pixel-art themed bottom bar.

const CharacterAssets = preload("res://scripts/CharacterAssets.gd")

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
const TILE_SIZE := 110           # tile width in px (kept as TILE_SIZE for other callers)
const TILE_HEIGHT := 160         # tile height in px — portrait, matches HTML mockup
const TILE_SPACING := 10
const TILE_LABEL_H := 22         # bottom label strip height when selected
const TILE_PAD := 4              # inner padding around the thumbnail

# The 4 preview directions (matches the screenshot layout: left, front, back, right)
const DIRECTIONS := ["left", "down", "up", "right"]

const PIXEL_FONT_PATH := "res://assets/fonts/Minecraft.ttf"

# Atlas regions for idle frame 0 in each direction.
# Each sprite sheet row at y=96 contains: idle_right(6) → idle_up(6) → idle_left(6) → idle_down(6)
# Frame size is 48×96.
const DIR_ATLAS := {
	"left": Rect2(576, 96, 48, 96),
	"down": Rect2(864, 96, 48, 96),
	"up": Rect2(288, 96, 48, 96),
	"right": Rect2(0, 96, 48, 96),
}

# Scale factor for the 48×96 sprites (makes them ~240×480 at scale 5)
const SPRITE_SCALE := 7.5

var PREVIEW_TEXTURES: Dictionary = CharacterAssets.PREVIEW_TEXTURES

# Current selection per category (1-based index into PREVIEW_TEXTURES arrays)
var selections := {
	"Body": 1, "Eyes": 1, "Outfit": 1, "Hairstyle": 1, "Accessory": 1,
}

# Whether each component layer is visible in the preview
var visibility := {
	"Body": true, "Eyes": true, "Outfit": true, "Hairstyle": true, "Accessory": true,
}

# NEW — which tab & direction are currently showing
var active_category: String = "Body"
var active_direction: String = "down"

# ─── UI references (populated in _build_ui) ───
# NEW UI refs
var tab_buttons := {}          # String(category) → Button
var grid_container: GridContainer  # holds tile buttons; rebuilt per category
var tile_buttons := []         # Array[Button] for the currently-displayed tiles
var main_preview_sprites := {} # String(category) → Sprite2D (single composited preview)
var main_preview_root: Control # parent of main_preview_sprites, for resizing
var direction_label: Label     # carousel label
var selected_tile_label: Label # shown under grid or overlayed — see Task 3
var vis_checks := {} # String(category) → CheckBox
var name_input: LineEdit
var continue_btn: Button
var back_btn: Button
var randomize_btn: Button
var pixel_font: Font


func _ready() -> void:
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		pixel_font = load(PIXEL_FONT_PATH)
	_build_ui()
	_apply_saved()
	_refresh_tab_styles()
	_refresh_grid()
	_sync_all_previews()
	_update_continue()


# ═══════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════

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


func _create_checker_bg() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 color1 : source_color = vec4(0.247, 0.584, 0.776, 1.0);
uniform vec4 color2 : source_color = vec4(0.208, 0.529, 0.722, 1.0);
uniform float tile_size = 48.0;
void fragment() {
	vec2 pos = FRAGCOORD.xy / tile_size;
	float checker = mod(floor(pos.x) + floor(pos.y), 2.0);
	COLOR = mix(color1, color2, checker);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	return rect


func _create_bottom_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 0.75, 0.75)
	sb.border_color = Color(0.55, 0.55, 0.55)
	sb.border_width_top = 4
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	bar.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(row)

	# ── LEFT CLUSTER: BACK + RANDOMIZE ──
	var left_cluster := HBoxContainer.new()
	left_cluster.add_theme_constant_override("separation", 12)
	left_cluster.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(left_cluster)

	back_btn = _create_styled_button("BACK", Color(0.45, 0.48, 0.52))
	back_btn.pressed.connect(_on_back_pressed)
	left_cluster.add_child(back_btn)

	randomize_btn = _create_styled_button("RANDOMIZE", Color(0.92, 0.62, 0.08))
	randomize_btn.pressed.connect(_on_randomize_pressed)
	left_cluster.add_child(randomize_btn)

	# ── CENTER CLUSTER: NAME label + input ──
	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center_wrap)

	var name_box := HBoxContainer.new()
	name_box.add_theme_constant_override("separation", 12)
	center_wrap.add_child(name_box)

	var name_label := Label.new()
	name_label.text = "NAME:"
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	if pixel_font:
		name_label.add_theme_font_override("font", pixel_font)
	name_box.add_child(name_label)

	name_input = LineEdit.new()
	name_input.custom_minimum_size = Vector2(340, 48)
	name_input.placeholder_text = "Enter Name"
	name_input.max_length = 25
	name_input.add_theme_font_size_override("font_size", 24)
	name_input.add_theme_color_override("font_color", Color.BLACK)
	name_input.add_theme_color_override("font_placeholder_color", Color(0.45, 0.45, 0.45))
	if pixel_font:
		name_input.add_theme_font_override("font", pixel_font)
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = Color.WHITE
	input_sb.border_color = Color(0.4, 0.45, 0.5)
	input_sb.set_border_width_all(3)
	input_sb.set_corner_radius_all(4)
	input_sb.content_margin_left = 12
	input_sb.content_margin_right = 12
	input_sb.content_margin_top = 6
	input_sb.content_margin_bottom = 6
	name_input.add_theme_stylebox_override("normal", input_sb)
	var input_sb_focus: StyleBoxFlat = input_sb.duplicate()
	input_sb_focus.border_color = Color(0.85, 0.80, 0.2)
	input_sb_focus.border_width_bottom = 4
	name_input.add_theme_stylebox_override("focus", input_sb_focus)
	name_input.text_changed.connect(_on_name_changed)
	name_box.add_child(name_input)

	# ── RIGHT CLUSTER: visibility checkboxes + CONTINUE ──
	var right_cluster := HBoxContainer.new()
	right_cluster.add_theme_constant_override("separation", 10)
	right_cluster.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(right_cluster)

	for cat in CATEGORIES:
		var check := CheckBox.new()
		check.text = TAB_LABELS[cat]
		check.button_pressed = true
		check.add_theme_font_size_override("font_size", 18)
		check.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
		if pixel_font:
			check.add_theme_font_override("font", pixel_font)
		check.toggled.connect(_on_visibility_toggled.bind(cat))
		right_cluster.add_child(check)
		vis_checks[cat] = check

	continue_btn = _create_styled_button("CONTINUE", Color(0.30, 0.68, 0.38))
	continue_btn.pressed.connect(_on_continue_pressed)
	right_cluster.add_child(continue_btn)

	return bar


func _create_styled_button(label_text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 55)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = bg_color.darkened(0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed: StyleBoxFlat = sb.duplicate()
	sb_pressed.bg_color = bg_color.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", sb_pressed)

	var sb_disabled: StyleBoxFlat = sb.duplicate()
	sb_disabled.bg_color = Color(0.5, 0.5, 0.5, 0.6)
	sb_disabled.border_color = Color(0.4, 0.4, 0.4)
	btn.add_theme_stylebox_override("disabled", sb_disabled)

	return btn


# ═══════════════════════════════════════════════════════════════════
#  STATE & PREVIEW LOGIC
# ═══════════════════════════════════════════════════════════════════

func _apply_saved() -> void:
	var saved := GameState.get_character_components()
	for cat in CATEGORIES:
		var option: int = saved.get(cat.to_lower(), 1)
		var max_count: int = PREVIEW_TEXTURES.get(cat, []).size()
		selections[cat] = clampi(option, 1, max(1, max_count))
	name_input.text = GameState.player_name


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
	var mini_row: HBoxContainer = _find_mini_row()
	if mini_row == null:
		return
	for mini in mini_row.get_children():
		if not (mini is Control):
			continue
		var dir: String = mini.get_meta("direction", "")
		if dir == "":
			continue
		var i := 0
		var layer_order := ["Body", "Eyes", "Outfit", "Hairstyle", "Accessory"]
		for child in mini.get_children():
			if not (child is Sprite2D):
				continue
			if i >= layer_order.size():
				break
			var cat: String = layer_order[i]
			child.texture = _atlas_for(cat, dir)
			child.visible = visibility[cat] and child.texture != null
			i += 1
		var hp: Panel = mini.get_meta("highlight_panel", null)
		if hp:
			var sb: StyleBoxFlat = hp.get_theme_stylebox("panel").duplicate()
			sb.border_color = Color(0.92, 0.78, 0.12) if dir == active_direction else Color(0, 0, 0, 0)
			hp.add_theme_stylebox_override("panel", sb)


func _find_mini_row() -> HBoxContainer:
	if main_preview_root == null:
		return null
	var parent: Node = main_preview_root.get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HBoxContainer:
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
	btn.custom_minimum_size = Vector2(TILE_SIZE, TILE_HEIGHT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = false
	btn.clip_contents = true

	var is_selected: bool = (index_0 + 1) == int(selections[category])

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

	var thumb := TextureRect.new()
	thumb.texture = _thumbnail_texture_for(category, tex_path)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb.offset_left = TILE_PAD
	thumb.offset_right = -TILE_PAD
	thumb.offset_top = TILE_PAD
	thumb.offset_bottom = -(TILE_LABEL_H if is_selected else TILE_PAD)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(thumb)

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


func _thumbnail_texture_for(_category: String, tex_path: String) -> Texture2D:
	var full: Texture2D = load(tex_path)
	if full == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = full
	atlas.region = DIR_ATLAS["down"]
	atlas.filter_clip = true
	return atlas


# ═══════════════════════════════════════════════════════════════════
#  SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════

func _on_tab_pressed(category: String) -> void:
	if category == active_category:
		return
	active_category = category
	_refresh_tab_styles()
	_refresh_grid()


func _on_tile_pressed(category: String, index_0: int) -> void:
	var max_count: int = PREVIEW_TEXTURES.get(category, []).size()
	selections[category] = clampi(index_0 + 1, 1, max(1, max_count))
	_refresh_grid()
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


func _on_visibility_toggled(toggled: bool, category: String) -> void:
	visibility[category] = toggled
	_refresh_main_preview()
	_refresh_mini_previews()


func _on_name_changed(_new_text: String) -> void:
	_update_continue()


func _update_continue() -> void:
	continue_btn.disabled = name_input.text.strip_edges().is_empty()


func _on_continue_pressed() -> void:
	if name_input.text.strip_edges().is_empty():
		return
	continue_btn.disabled = true
	GameState.save_player_name(name_input.text.strip_edges())

	# Hat Collector: track hat-type accessories
	var acc_idx: int = selections.get("Accessory", 1)
	if acc_idx in GameState.HAT_ACCESSORY_INDICES and not GameState.hats_collected.has(acc_idx):
		GameState.hats_collected.append(acc_idx)

	# Identity Crisis: all 5 components changed from previous save
	if GameState.uses_component_system:
		var all_changed: bool = (
			selections["Body"]      != GameState.char_body      and
			selections["Hairstyle"] != GameState.char_hairstyle and
			selections["Outfit"]    != GameState.char_outfit    and
			selections["Eyes"]      != GameState.char_eyes      and
			selections["Accessory"] != GameState.char_accessory
		)
		if all_changed:
			GameState.full_look_changes += 1
	GameState.check_achievements()

	GameState.save_character_components(
		selections["Body"],
		selections["Hairstyle"],
		selections["Outfit"],
		selections["Eyes"],
		selections["Accessory"]
	)
	SceneManager.change_scene("res://scenes/ui/PetSelect.tscn", {"pattern": "curtains"})


func _on_back_pressed() -> void:
	back_btn.disabled = true
	SceneManager.change_scene("res://scenes/ui/IntroCutscene.tscn", {"pattern": "curtains"})


func _on_randomize_pressed() -> void:
	for cat in CATEGORIES:
		var textures: Array = PREVIEW_TEXTURES.get(cat, [])
		var max_opts := maxi(1, textures.size())
		selections[cat] = randi_range(1, max_opts)
	_refresh_tab_styles()
	_refresh_grid()
	_refresh_main_preview()
	_refresh_mini_previews()

# Updated on 2026-04-19
