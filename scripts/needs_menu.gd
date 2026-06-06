# needs_menu.gd
# Pet Needs Panel — displays Hunger, Thirst, Energy, and Health stat bars.
# Styled with the maroon/cream pixel-art identity.
extends CanvasLayer

# ── Colour palette (maroon pixel-art) ──────────────────────────────────────────
const CLR_PANEL_BG   := UITheme.CLR_CREAM      # Panel background
const CLR_HEADER_BG  := UITheme.CLR_MAROON_D    # Header strip background
const CLR_BORDER     := UITheme.CLR_INK         # Panel border
const CLR_TEXT       := UITheme.CLR_INK         # Text colour
const CLR_DANGER     := Color("#EF5350")        # Flash red for critical stats

# Stat bar fill colours (kept from original — they look good)
const CLR_HUNGER := Color("#FF8C00")       # Warm orange
const CLR_THIRST := Color("#1E90FF")       # Bright blue
const CLR_ENERGY := Color("#FFD700")       # Yellow
const CLR_HEALTH := Color("#32CD32")       # Bright green

## Stats below this threshold flash red as a warning.
const LOW_THRESHOLD  := 30.0
## Seconds between flash toggles for critical stat bars.
const FLASH_INTERVAL := 0.45

# ── Scene node refs ────────────────────────────────────────────────────────────
@onready var panel      = $PanelContainer
@onready var hunger_bar = $PanelContainer/VBoxContainer/GridContainer/Hunger/HBox/ProgressBar
@onready var hunger_val = $PanelContainer/VBoxContainer/GridContainer/Hunger/HBox/Value
@onready var thirst_bar = $PanelContainer/VBoxContainer/GridContainer/Thirst/HBox/ProgressBar
@onready var thirst_val = $PanelContainer/VBoxContainer/GridContainer/Thirst/HBox/Value
@onready var energy_bar = $PanelContainer/VBoxContainer/GridContainer/Energy/HBox/ProgressBar
@onready var energy_val = $PanelContainer/VBoxContainer/GridContainer/Energy/HBox/Value
@onready var health_bar = $PanelContainer/VBoxContainer/GridContainer/Health/HBox/ProgressBar
@onready var health_val = $PanelContainer/VBoxContainer/GridContainer/Health/HBox/Value

# ── Internal state ─────────────────────────────────────────────────────────────
var target_dog   : Node2D        # The dog node to read stats from
var _flash_timer : float = 0.0   # Counts up until FLASH_INTERVAL
var _flash_state : bool  = false # true = show danger colour

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Apply cream panel style with ink border
	_apply_panel_style()
	# Style the header strip behind the "Needs" title
	_style_header_strip()
	# Apply global UITheme fonts to children
	UITheme.apply_overlay_theme(self)
	# Restyle the title + close button per the redesign spec
	_style_title_bar()
	# Start hidden — show_menu() is called by the world script / HUD
	panel.hide()
	# Enforce minimum bar height (≥24px for visibility)
	for bar in [hunger_bar, thirst_bar, energy_bar, health_bar]:
		if bar:
			bar.custom_minimum_size.y = 24
	# Wire the close button
	$PanelContainer/VBoxContainer/TitleHBox/CloseButton.pressed.connect(
		func() -> void:
			if GameState.is_day_one and not GameState.is_tutorial_complete:
				return
			panel.hide()
	)

## Restyle "Needs" title in maroon-deep, close button red with ink border.
func _style_title_bar() -> void:
	var title := get_node_or_null("PanelContainer/VBoxContainer/TitleHBox/Title")
	if title is Label:
		title.text = "Pet Needs"
		title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
		title.add_theme_font_size_override("font_size", 52)
	var close_btn := get_node_or_null("PanelContainer/VBoxContainer/TitleHBox/CloseButton")
	if close_btn is Button:
		close_btn.text = "✕"
		close_btn.custom_minimum_size = Vector2(64, 64)
		UITheme.style_close_button(close_btn)
	# Uppercase the four stat labels in ink colour
	for stat in ["Hunger", "Thirst", "Energy", "Health"]:
		var l := get_node_or_null("PanelContainer/VBoxContainer/GridContainer/" + stat + "/Label")
		if l is Label:
			l.text = stat.to_upper()
			l.add_theme_color_override("font_color", UITheme.CLR_INK)

# ── Public API ─────────────────────────────────────────────────────────────────

## Called by world / HUD scripts when the player opens the needs menu.
func show_menu(dog: Node2D) -> void:
	target_dog = dog
	panel.show()
	update_ui()

# ── Per-frame update ───────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Advance flash timer for critical stat warning
	_flash_timer += delta
	if _flash_timer >= FLASH_INTERVAL:
		_flash_timer = 0.0
		_flash_state = not _flash_state
	# Keep bars live while visible
	if panel.visible and target_dog:
		update_ui()
	# Close on cancel or click outside
	if panel.visible:
		if GameState.is_day_one and not GameState.is_tutorial_complete:
			# Block manual closing during tutorial (the tutorial controller handles this automatically)
			pass
		else:
			if Input.is_action_just_pressed("ui_cancel"):
				panel.hide()
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_mouse_over_panel():
				panel.hide()

# ── UI update ──────────────────────────────────────────────────────────────────

## Refresh all four stat bars from the current dog node.
func update_ui() -> void:
	if not target_dog:
		return
	# Read live stats from the dog node (dynamic types from Node2D properties)
	var hunger_val_raw  = target_dog.hunger
	var thirst_val_raw  = target_dog.thirst
	var energy_val_raw  = target_dog.energy
	var health_val_raw  = target_dog.health
	# Update each stat row with its dedicated colour
	_update_stat_row(hunger_bar, hunger_val, hunger_val_raw, CLR_HUNGER,
		$PanelContainer/VBoxContainer/GridContainer/Hunger/Label)
	_update_stat_row(thirst_bar, thirst_val, thirst_val_raw, CLR_THIRST,
		$PanelContainer/VBoxContainer/GridContainer/Thirst/Label)
	_update_stat_row(energy_bar, energy_val, energy_val_raw, CLR_ENERGY,
		$PanelContainer/VBoxContainer/GridContainer/Energy/Label)
	_update_stat_row(health_bar, health_val, health_val_raw, CLR_HEALTH,
		$PanelContainer/VBoxContainer/GridContainer/Health/Label)

## Update a single stat row: progress bar fill, value label, and warning icon.
func _update_stat_row(
		bar        : ProgressBar,
		val_label  : Label,
		stat_value : float,
		base_color : Color,
		name_label : Label) -> void:
	if not bar or not val_label:
		return
	# Set the bar value and text display — spec format "75/100" (no spaces)
	bar.value = stat_value
	val_label.text = "%d/100" % int(round(stat_value))
	val_label.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	# Threshold-based bar colour (spec _bar_color): <30 red, <50 orange, else base.
	# Keeps the existing flash behaviour on top so critical stats still pulse.
	var fill_color := _bar_color(stat_value, base_color)
	if stat_value < LOW_THRESHOLD and _flash_state:
		fill_color = CLR_DANGER
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.border_color = UITheme.CLR_INK
	fill_sb.set_border_width_all(2)
	fill_sb.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("fill", fill_sb)
	# Track: light cream bg with ink border
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color     = Color(UITheme.CLR_CREAM_LT.r, UITheme.CLR_CREAM_LT.g, UITheme.CLR_CREAM_LT.b, 0.5)
	track_sb.border_color = UITheme.CLR_INK
	track_sb.set_border_width_all(2)
	track_sb.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background", track_sb)
	# Warning "!" indicator next to stat name when critical
	if name_label:
		if stat_value < LOW_THRESHOLD:
			name_label.add_theme_color_override("font_color", CLR_DANGER)
			if not name_label.text.ends_with("!"):
				name_label.text = name_label.text.rstrip(" !") + " !"
		else:
			name_label.add_theme_color_override("font_color", CLR_TEXT)
			name_label.text = name_label.text.rstrip(" !")

# ── Helpers ────────────────────────────────────────────────────────────────────

## Threshold-based fill colour per spec: <30 red, <50 orange, else base.
func _bar_color(value: float, base: Color) -> Color:
	if value < 30.0: return Color("#EF5350")
	if value < 50.0: return Color("#FFA726")
	return base

## Check if the mouse cursor is within the panel bounds.
func is_mouse_over_panel() -> bool:
	return panel.get_global_rect().has_point(panel.get_global_mouse_position())

## Apply cream panel style with ink border.
func _apply_panel_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_PANEL_BG
	sb.border_color = CLR_BORDER
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	# Force full opacity — fix world bleeding through
	panel.modulate.a        = 1.0
	panel.self_modulate.a   = 1.0

## Style the header strip behind the panel title in maroon-deep.
func _style_header_strip() -> void:
	var title_hbox = get_node_or_null("PanelContainer/VBoxContainer/TitleHBox")
	if not title_hbox:
		return
	# Add a ColorRect behind the title row
	var header_bg := ColorRect.new()
	header_bg.color = UITheme.CLR_MAROON_D
	header_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_bg.show_behind_parent = true
	title_hbox.add_child(header_bg)
	title_hbox.move_child(header_bg, 0)

# Updated on 2026-04-19
