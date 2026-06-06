# needs_menu.gd
# Pet Needs Panel — displays Hunger, Thirst, Energy, and Health stat bars.
# Styled with the game's navy-blue / sky-blue pixel-art identity.
#
# Features:
#   - Panel background: navy #1a2a4a, 2px sky-blue #4A90D9 border
#   - Header strip: lighter navy #1e3a6e behind "Needs" title
#   - Fully opaque (self_modulate.a = 1.0) — no world bleed-through
#   - Colour-coded stat bars: orange (hunger), blue (thirst), yellow (energy), green (health)
#   - "X / 100" value format
#   - Flashing red warning when any stat drops below 30
#   - "!" indicator next to critical stat names
extends CanvasLayer

# ── Colour palette ─────────────────────────────────────────────────────────────
const CLR_NAVY       := Color("#1a2a4a")   # Panel background
const CLR_NAVY_LIGHT := Color("#1e3a6e")   # Header strip background
const CLR_NAVY_DEEP  := Color("#0d1b36")   # Bar track (deep)
const CLR_SKY        := Color("#4A90D9")   # Panel border + accent
const CLR_WHITE      := Color.WHITE        # Text colour
const CLR_DANGER     := Color("#EF5350")   # Flash red for critical stats

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
	var map = load("res://New Ui/FINAL PET NEEDS/Map.tscn").instantiate()
	map.scale = Vector2(7.5, 7.5)
	if map.has_node("Layer_1_0"):
		map.get_node("Layer_1_0").queue_free()
	
	var bg = Node2D.new()
	bg.name = "Backdrop"
	bg.add_child(map)
	panel.add_child(bg)
	panel.move_child(bg, 0)
	
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	UITheme.apply_overlay_theme(self)
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

## Restyle "Needs" title as cyan, stat labels uppercase + dim, close button red compact.
func _style_title_bar() -> void:
	var title := get_node_or_null("PanelContainer/VBoxContainer/TitleHBox/Title")
	if title is Label:
		title.text = "Pet Needs"
		title.add_theme_color_override("font_color", UITheme.CLR_INK)
		title.add_theme_font_size_override("font_size", 52)
	var close_btn := get_node_or_null("PanelContainer/VBoxContainer/TitleHBox/CloseButton")
	if close_btn is Button:
		close_btn.text = "X"
		close_btn.custom_minimum_size = Vector2(64, 64)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("#ef5350")
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		close_btn.add_theme_stylebox_override("normal", sb)
		close_btn.add_theme_stylebox_override("hover", sb)
		close_btn.add_theme_stylebox_override("pressed", sb)
		UITheme._do_juice_on(close_btn)
	# Dim + uppercase the four stat labels
	for stat in ["Hunger", "Thirst", "Energy", "Health"]:
		var l := get_node_or_null("PanelContainer/VBoxContainer/GridContainer/" + stat + "/Label")
		if l is Label:
			l.text = stat.to_upper()
			l.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)

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
	bar.value = stat_value
	val_label.text = "%d/100" % int(round(stat_value))
	val_label.add_theme_color_override("font_color", UITheme.CLR_INK)
	
	var fg = StyleBoxFlat.new()
	fg.bg_color = Color("#ef5350") if stat_value < LOW_THRESHOLD else base_color
	fg.set_corner_radius_all(0)
	fg.border_color = UITheme.CLR_INK
	fg.set_border_width_all(4)
	bar.add_theme_stylebox_override("fill", fg)
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0,0,0,0)
	bar.add_theme_stylebox_override("background", bg)
	
	if name_label:
		if stat_value < LOW_THRESHOLD:
			name_label.add_theme_color_override("font_color", Color("#ef5350"))
			if not name_label.text.ends_with("!"):
				name_label.text = name_label.text.rstrip(" !") + " !"
		else:
			name_label.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
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

## Apply the navy-blue panel style with sky-blue border, fully opaque.
func _apply_panel_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_NAVY
	sb.border_color = CLR_SKY
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	# Force full opacity — fix world bleeding through
	panel.modulate.a        = 1.0
	panel.self_modulate.a   = 1.0

## Style the header strip behind the panel title in lighter navy.
func _style_header_strip() -> void:
	var title_hbox = get_node_or_null("PanelContainer/VBoxContainer/TitleHBox")
	if not title_hbox:
		return
	# Add a ColorRect behind the title row
	var header_bg := ColorRect.new()
	header_bg.color = CLR_NAVY_LIGHT
	header_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_bg.show_behind_parent = true
	title_hbox.add_child(header_bg)
	title_hbox.move_child(header_bg, 0)

# Updated on 2026-04-19
