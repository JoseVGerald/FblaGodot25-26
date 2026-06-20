# SettingsMenu.gd
# Settings overlay — audio volume slider, mute, plus game/display toggles.
# Redesigned 2026-04-22: new sectioned layout (AUDIO · GAME · DISPLAY).
extends CanvasLayer

signal settings_closed

# ── Design tokens (maroon pixel-art identity) ────────────────────────────────
const CLR_BG_DEEP    := UITheme.CLR_MAROON_D
const CLR_BG_CARD    := UITheme.CLR_CREAM
const CLR_BORDER_SKY := UITheme.CLR_MAROON
const CLR_BORDER_DIM := UITheme.CLR_GRAY_DRK
const CLR_CYAN       := UITheme.CLR_ORANGE_PX
const CLR_WHITE      := UITheme.CLR_INK
const CLR_DIM        := UITheme.CLR_GRAY_DRK

# ── Pre-existing scene refs (keep paths identical for tscn compatibility) ────
@onready var volume_slider      : HSlider = $Panel/VBox/VolumeContainer/VolumeSlider
@onready var volume_value_label : Label   = $Panel/VBox/VolumeContainer/VolumeValue
@onready var close_btn          : Button  = $Panel/VBox/CloseBtn

var mute_btn: Button = null
var is_muted: bool = false

# Volume memory for restore-on-unmute.
var _pre_mute_music: float = 70.0
var _pre_mute_sfx:   float = 70.0

# SFX row refs (set by _make_sfx_slider_row).
var sfx_slider:    HSlider = null
var sfx_pct_label: Label   = null

# Toggle state (wired to GameState properties if present).
var _toggles : Dictionary = {}  # name → Button

func _ready() -> void:
	UITheme.apply_overlay_theme(self)

	# Restyle the scene shell to the navy / sky-blue design identity.
	_style_panel_shell()
	_style_existing_header_row()
	_inject_header_close_btn()

	# Initial volume from GameState (preserves existing behaviour).
	var initial_volume = GameState.get("master_volume") if "master_volume" in GameState else 70
	volume_slider.value = initial_volume
	volume_value_label.text = str(int(initial_volume)) + "%"
	_pre_mute_music = initial_volume
	_pre_mute_sfx   = initial_volume
	_style_slider(volume_slider)
	volume_slider.value_changed.connect(_on_volume_changed)

	# Red close button.
	UITheme.style_close_button(close_btn)
	close_btn.pressed.connect(_on_close_pressed)

	# Build expanded sections procedurally so the scene file stays tiny.
	_build_expanded_layout()

	# Default fullscreen to on
	_on_fullscreen_toggled(true)

func _input(event: InputEvent) -> void:
	# ESC closes settings without triggering the pause menu.
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════════════
#  AUDIO LOGIC — unchanged signatures (used by external scripts / tests)
# ══════════════════════════════════════════════════════════════════════════════

func _on_volume_changed(value: float) -> void:
	volume_value_label.text = str(int(value)) + "%"
	if "master_volume" in GameState:
		GameState.master_volume = int(value)
	var db: float = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value == 0)
	# Sliding music up while muted → auto-unmute.
	if is_muted and value > 0:
		is_muted = false
		_update_mute_label()

func _on_close_pressed() -> void:
	settings_closed.emit()
	queue_free()

# Called when the Mute/Unmute button is pressed.
func _on_mute_button_pressed() -> void:
	_set_muted(not is_muted)

func _set_muted(should_mute: bool) -> void:
	is_muted = should_mute
	if is_muted:
		# Save current levels so we can restore on unmute.
		_pre_mute_music = volume_slider.value
		_pre_mute_sfx   = sfx_slider.value if sfx_slider else volume_slider.value
		# Silence both sliders without firing value_changed.
		volume_slider.set_value_no_signal(0)
		if sfx_slider: sfx_slider.set_value_no_signal(0)
		volume_value_label.text = "0%"
		if sfx_pct_label: sfx_pct_label.text = "0%"
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	else:
		# Restore saved levels.
		volume_slider.set_value_no_signal(_pre_mute_music)
		if sfx_slider: sfx_slider.set_value_no_signal(_pre_mute_sfx)
		volume_value_label.text = str(int(_pre_mute_music)) + "%"
		if sfx_pct_label: sfx_pct_label.text = str(int(_pre_mute_sfx)) + "%"
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
		var db: float = linear_to_db(_pre_mute_music / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
		if "master_volume" in GameState:
			GameState.master_volume = int(_pre_mute_music)
	_update_mute_label()

# Kept for backward compatibility — delegates to _set_muted.
func _on_mute_toggled(pressed: bool) -> void:
	_set_muted(pressed)

func _update_mute_label() -> void:
	if not mute_btn: return
	var pf := UITheme.get_pixel_font()
	if is_muted:
		mute_btn.text = "Unmute"
		var sb := StyleBoxFlat.new()
		sb.bg_color     = UITheme.CLR_GREEN
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(0)
		mute_btn.add_theme_stylebox_override("normal",  sb)
		mute_btn.add_theme_stylebox_override("hover",   sb)
		mute_btn.add_theme_stylebox_override("pressed", sb)
		mute_btn.add_theme_color_override("font_color",       Color.WHITE)
		mute_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		mute_btn.text = "Mute"
		var sb := StyleBoxFlat.new()
		sb.bg_color     = UITheme.CLR_CREAM_LT
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(0)
		mute_btn.add_theme_stylebox_override("normal",  sb)
		mute_btn.add_theme_stylebox_override("hover",   sb)
		mute_btn.add_theme_stylebox_override("pressed", sb)
		mute_btn.add_theme_color_override("font_color",       UITheme.CLR_MAROON_D)
		mute_btn.add_theme_color_override("font_hover_color", UITheme.CLR_MAROON_D)
	if pf: mute_btn.add_theme_font_override("font", pf)
	mute_btn.add_theme_font_size_override("font_size", 44)

# ══════════════════════════════════════════════════════════════════════════════
#  STYLING
# ══════════════════════════════════════════════════════════════════════════════

func _style_panel_shell() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node is PanelContainer:
		UITheme.style_cream_panel(panel_node)

func _style_existing_header_row() -> void:
	var title := get_node_or_null("Panel/VBox/Title")
	if title is Label:
		title.text = "Settings"
		title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
		title.add_theme_font_size_override("font_size", 96)

	# Restyle the existing VolumeContainer as the first AUDIO card.
	var vc := get_node_or_null("Panel/VBox/VolumeContainer")
	if vc is HBoxContainer:
		_wrap_row_in_card(vc, CLR_BORDER_SKY)
		var lbl := vc.get_node_or_null("Label")
		if lbl is Label:
			lbl.text = "Music Volume"
			lbl.add_theme_color_override("font_color", UITheme.CLR_INK)
			lbl.add_theme_font_size_override("font_size", 60)
		volume_value_label.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
		volume_value_label.add_theme_font_size_override("font_size", 60)

## Apply slider track/fill style per spec.
## Emil Kowalski principle: grabber scales slightly on hover for press feedback.
func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = UITheme.CLR_MAROON_D
	track.border_color = UITheme.CLR_INK
	track.set_border_width_all(2)
	track.set_corner_radius_all(0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = CLR_BORDER_SKY
	fill.border_color = UITheme.CLR_INK
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(0)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = UITheme.CLR_CREAM
	grabber.border_color = UITheme.CLR_INK
	grabber.set_border_width_all(2)
	grabber.set_corner_radius_all(0)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	grabber.content_margin_top = 10
	grabber.content_margin_bottom = 10
	slider.add_theme_stylebox_override("grabber", grabber)

	# Grabber highlight: slightly larger on hover for press feedback (Emil Kowalski).
	var grabber_hi := grabber.duplicate() as StyleBoxFlat
	grabber_hi.bg_color = UITheme.CLR_CREAM_LT
	grabber_hi.content_margin_top    = 12
	grabber_hi.content_margin_bottom = 12
	slider.add_theme_stylebox_override("grabber_highlight", grabber_hi)

## Drop a card background + accent behind a row.
func _wrap_row_in_card(row: HBoxContainer, accent: Color) -> void:
	var bg := ColorRect.new()
	bg.color = CLR_BG_CARD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	row.move_child(bg, 0)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 4
	stripe.show_behind_parent = true
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	row.move_child(stripe, 1)

# ══════════════════════════════════════════════════════════════════════════════
#  EXPANDED LAYOUT — build AUDIO/GAME/DISPLAY sections in script
# ══════════════════════════════════════════════════════════════════════════════

func _build_expanded_layout() -> void:
	var vbox := get_node_or_null("Panel/VBox")
	if not (vbox is VBoxContainer):
		return

	# AUDIO section continues with SFX + Mute rows.
	var audio_section := _make_section_label("AUDIO")
	vbox.add_child(audio_section)
	vbox.move_child(audio_section, 1)   # right below Title

	# SFX slider row.
	var sfx_row := _make_sfx_slider_row()
	vbox.add_child(sfx_row)
	vbox.move_child(sfx_row, 3)   # Title → AUDIO → VolumeContainer → SFXRow

	# Mute row — labeled button (not a switch) that toggles between Mute/Unmute.
	var mute_row := _make_mute_row()
	is_muted = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_update_mute_label()
	vbox.add_child(mute_row)
	vbox.move_child(mute_row, 4)   # Title → AUDIO → Music → SFX → Mute

	# GAME section — all on by default.
	vbox.add_child(_make_section_label("GAME"))
	vbox.add_child(_make_toggle_row_for_state(
		"Notifications", "Show warnings and event popups",
		CLR_BORDER_SKY, "notifications_enabled", true))
	vbox.add_child(_make_toggle_row_for_state(
		"Inflation Active", "Prices rise slowly over time",
		Color("#FFA726"), "inflation_enabled", true))
	vbox.add_child(_make_toggle_row_for_state(
		"Random Events", "Occasional surprises and challenges",
		CLR_CYAN, "random_events_enabled", true))

	# DISPLAY section.
	vbox.add_child(_make_section_label("DISPLAY"))
	vbox.add_child(_make_toggle_row_for_state(
		"Tooltips", "Show helpful hints on hover",
		CLR_CYAN, "tooltips_enabled", true))

	var fs_row := _make_toggle_row(
		"Fullscreen",
		"Expand the game to fill the screen",
		CLR_BORDER_SKY,
		true,
		_on_fullscreen_toggled,
	)
	vbox.add_child(fs_row.get_parent())

	# CONTROLS section — opens the Keybinds overlay.
	vbox.add_child(_make_section_label("CONTROLS"))
	vbox.add_child(_make_keybinds_button())

	# Make sure CloseBtn stays at the bottom of the VBox.
	vbox.move_child(close_btn, vbox.get_child_count() - 1)

func _make_keybinds_button() -> Button:
	var btn := Button.new()
	btn.text = "Keybinds"
	btn.custom_minimum_size = Vector2(0, 120)
	btn.add_theme_font_size_override("font_size", 56)
	var pf := UITheme.get_pixel_font()
	if pf: btn.add_theme_font_override("font", pf)
	UITheme.style_pixel_button(btn)
	btn.pressed.connect(_on_keybinds_pressed)
	return btn

func _on_keybinds_pressed() -> void:
	var keybinds_menu = load("res://scenes/ui/KeybindsMenu.tscn").instantiate()
	get_tree().root.add_child(keybinds_menu)

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	lbl.add_theme_font_size_override("font_size", 44)
	var font := UITheme.get_pixel_font()
	if font: lbl.add_theme_font_override("font", font)
	return lbl

func _make_toggle_row_for_state(name: String, sub: String, accent: Color,
		state_prop: String, default_on: bool) -> HBoxContainer:
	var initial := default_on
	if state_prop in GameState:
		initial = bool(GameState.get(state_prop))
	var btn := _make_toggle_row(name, sub, accent, initial,
		func(on: bool): _apply_state_toggle(state_prop, on))
	_toggles[state_prop] = btn
	return btn.get_parent()

func _apply_state_toggle(prop: String, value: bool) -> void:
	if prop in GameState:
		GameState.set(prop, value)

func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

## Build a row: card panel + icon tile + label/sub + pill toggle switch.
## Returns the toggle Button (call get_parent() for the row container).
func _make_toggle_row(name: String, sub: String, accent: Color,
		initial_on: bool, on_toggled: Callable) -> Button:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	_wrap_row_in_card(row, accent)

	var tile := ColorRect.new()
	tile.color = Color(accent.r, accent.g, accent.b, 0.22)
	tile.custom_minimum_size = Vector2(72, 72)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 52)
	var pf := UITheme.get_pixel_font()
	if pf: name_lbl.add_theme_font_override("font", pf)
	block.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = sub
	sub_lbl.add_theme_color_override("font_color", CLR_DIM)
	sub_lbl.add_theme_font_size_override("font_size", 36)
	block.add_child(sub_lbl)
	row.add_child(block)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = initial_on
	toggle.custom_minimum_size = Vector2(140, 72)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.text = ""
	_apply_toggle_visual(toggle)
	toggle.toggled.connect(func(on: bool):
		_apply_toggle_visual(toggle)
		on_toggled.call(on)
	)
	row.add_child(toggle)

	return toggle

## Build the Mute All Audio row with a plain labeled button (Mute / Unmute).
func _make_mute_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	_wrap_row_in_card(row, Color("#FFA726"))

	var tile := ColorRect.new()
	tile.color = Color(1.0, 0.655, 0.149, 0.22)
	tile.custom_minimum_size = Vector2(72, 72)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = "Mute All Audio"
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 52)
	var pf := UITheme.get_pixel_font()
	if pf: name_lbl.add_theme_font_override("font", pf)
	block.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Silences music and sound effects"
	sub_lbl.add_theme_color_override("font_color", CLR_DIM)
	sub_lbl.add_theme_font_size_override("font_size", 36)
	block.add_child(sub_lbl)

	row.add_child(block)

	mute_btn = Button.new()
	mute_btn.toggle_mode = false
	mute_btn.custom_minimum_size = Vector2(180, 80)
	mute_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.pressed.connect(_on_mute_button_pressed)
	row.add_child(mute_btn)

	return row

## Inject a small red "✕" close button in the top-right of the title bar.
func _inject_header_close_btn() -> void:
	var title := get_node_or_null("Panel/VBox/Title")
	if not (title is Label):
		return
	var vbox := title.get_parent()
	if not (vbox is VBoxContainer):
		return

	var header := HBoxContainer.new()
	header.name = "HeaderRow"
	header.add_theme_constant_override("separation", 10)

	var title_index := title.get_index()
	vbox.remove_child(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(88, 88)
	x.focus_mode = Control.FOCUS_NONE
	UITheme.style_close_button(x)
	x.pressed.connect(_on_close_pressed)
	header.add_child(x)

	vbox.add_child(header)
	vbox.move_child(header, title_index)

## Build the SFX slider row as a card.
func _make_sfx_slider_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	_wrap_row_in_card(row, CLR_CYAN)

	var tile := ColorRect.new()
	tile.color = Color(CLR_CYAN.r, CLR_CYAN.g, CLR_CYAN.b, 0.22)
	tile.custom_minimum_size = Vector2(72, 72)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)

	var name_lbl := Label.new()
	name_lbl.text = "SFX"
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 56)
	var pf := UITheme.get_pixel_font()
	if pf: name_lbl.add_theme_font_override("font", pf)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(400, 20)
	slider.min_value = 0
	slider.max_value = 100
	slider.value = volume_slider.value
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	var pct := Label.new()
	pct.text = str(int(slider.value)) + "%"
	pct.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	pct.add_theme_font_size_override("font_size", 48)
	pct.custom_minimum_size.x = 120
	if pf: pct.add_theme_font_override("font", pf)
	row.add_child(pct)

	slider.value_changed.connect(func(v: float):
		pct.text = str(int(v)) + "%"
		_on_volume_changed(v)
		volume_slider.set_value_no_signal(v)
		# Sliding SFX up while muted → auto-unmute.
		if is_muted and v > 0:
			is_muted = false
			_update_mute_label()
	)

	# Save refs so _set_muted can silence/restore this slider.
	sfx_slider    = slider
	sfx_pct_label = pct

	return row

## Pill-shaped toggle switch visual.
## ON  → green pill, white thumb on the right.
## OFF → cream pill with ink border, dark thumb on the left.
func _apply_toggle_visual(btn: Button) -> void:
	var on := btn.button_pressed
	var sb := StyleBoxFlat.new()
	sb.bg_color     = UITheme.CLR_GREEN if on else UITheme.CLR_CREAM_LT
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(36)   # pill — half of 72px height
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)

	# Thumb indicator — created once, repositioned on state change.
	var thumb := btn.get_node_or_null("Thumb")
	if not thumb:
		thumb = ColorRect.new()
		thumb.name = "Thumb"
		thumb.custom_minimum_size = Vector2(48, 48)
		thumb.size = Vector2(48, 48)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(thumb)
	thumb.color    = Color.WHITE if on else UITheme.CLR_INK
	# Hardcoded for custom_minimum_size = Vector2(140, 72).
	# ON: right side (140 - 48 - 8 = 84, (72-48)/2 = 12)
	# OFF: left side (8, 12)
	thumb.position = Vector2(84.0 if on else 8.0, 12.0)
