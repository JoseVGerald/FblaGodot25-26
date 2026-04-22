# SettingsMenu.gd
# Settings overlay — audio volume slider, mute, plus game/display toggles.
# Redesigned 2026-04-22: new sectioned layout (AUDIO · GAME · DISPLAY).
extends CanvasLayer

signal settings_closed

# ── Design tokens ────────────────────────────────────────────────────────────
const CLR_BG_DEEP    := Color("#0d1b36")
const CLR_BG_CARD    := Color("#162240")
const CLR_BORDER_SKY := Color("#4A90D9")
const CLR_BORDER_DIM := Color("#2d6aad")
const CLR_CYAN       := Color("#53d8fb")
const CLR_WHITE      := Color("#f0f4ff")
const CLR_DIM        := Color(0.94, 0.96, 1.0, 0.55)

# ── Pre-existing scene refs (keep paths identical for tscn compatibility) ────
@onready var volume_slider      : HSlider = $Panel/VBox/VolumeContainer/VolumeSlider
@onready var volume_value_label : Label   = $Panel/VBox/VolumeContainer/VolumeValue
@onready var close_btn          : Button  = $Panel/VBox/CloseBtn

var mute_btn: Button = null
var is_muted: bool = false

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
	_style_slider(volume_slider)
	volume_slider.value_changed.connect(_on_volume_changed)

	# Red close button.
	UITheme.style_button(close_btn, UITheme.CLR_RED)
	close_btn.pressed.connect(_on_close_pressed)

	# Build expanded sections procedurally so the scene file stays tiny.
	_build_expanded_layout()

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

func _on_close_pressed() -> void:
	settings_closed.emit()
	queue_free()

func _on_mute_toggled(pressed: bool) -> void:
	is_muted = pressed
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted)
	_update_mute_label()

func _update_mute_label() -> void:
	if not mute_btn: return
	mute_btn.text = "Unmute" if is_muted else "Mute"

# ══════════════════════════════════════════════════════════════════════════════
#  STYLING
# ══════════════════════════════════════════════════════════════════════════════

func _style_panel_shell() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node is PanelContainer:
		UITheme.style_panel(panel_node)

func _style_existing_header_row() -> void:
	var title := get_node_or_null("Panel/VBox/Title")
	if title is Label:
		title.text = "Settings"
		title.add_theme_color_override("font_color", CLR_BORDER_SKY)
		title.add_theme_font_size_override("font_size", 48)

	# Restyle the existing VolumeContainer as the first AUDIO card.
	var vc := get_node_or_null("Panel/VBox/VolumeContainer")
	if vc is HBoxContainer:
		_wrap_row_in_card(vc, CLR_BORDER_SKY)
		var lbl := vc.get_node_or_null("Label")
		if lbl is Label:
			lbl.text = "Music Volume"
			lbl.add_theme_color_override("font_color", CLR_WHITE)
			lbl.add_theme_font_size_override("font_size", 30)
		volume_value_label.add_theme_color_override("font_color", CLR_CYAN)
		volume_value_label.add_theme_font_size_override("font_size", 30)

## Apply slider track/fill style per spec.
func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = CLR_BORDER_SKY
	fill.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color.WHITE
	grabber.border_color = CLR_BORDER_SKY
	grabber.set_border_width_all(2)
	grabber.set_corner_radius_all(8)
	grabber.content_margin_left = 8
	grabber.content_margin_right = 8
	grabber.content_margin_top = 8
	grabber.content_margin_bottom = 8
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber)

## Drop a dark card background + sky-blue left accent behind a row.
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

## Insert section headers + toggle rows into the existing VBox.
## We build between VolumeContainer and CloseBtn so the original scene
## nodes stay untouched and at their original paths.
func _build_expanded_layout() -> void:
	var vbox := get_node_or_null("Panel/VBox")
	if not (vbox is VBoxContainer):
		return

	# Re-order existing children so insertions land in the right spot.
	var close_idx := close_btn.get_index()

	# AUDIO section continues with SFX + Mute rows.
	var audio_section := _make_section_label("AUDIO")
	vbox.add_child(audio_section)
	vbox.move_child(audio_section, 1)   # right below Title

	# SFX slider row (distinct from Music Volume — shares the Master bus here
	# so the slider visually tracks the same audio output).
	var sfx_row := _make_sfx_slider_row()
	vbox.add_child(sfx_row)
	vbox.move_child(sfx_row, 3)   # Title → AUDIO → VolumeContainer → SFXRow

	mute_btn = _make_toggle_row(
		"Mute All Audio",
		"Silences music and sound effects",
		Color("#FFA726"),
		AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		_on_mute_toggled,
	)
	is_muted = mute_btn.button_pressed
	_update_mute_label()
	vbox.add_child(mute_btn.get_parent())   # add the row container, not the toggle itself
	vbox.move_child(mute_btn.get_parent(), 4)   # Title → AUDIO → Music → SFX → Mute

	# GAME section.
	vbox.add_child(_make_section_label("GAME"))
	vbox.add_child(_make_toggle_row_for_state(
		"Notifications", "Show warnings and event popups",
		CLR_BORDER_SKY, "notifications_enabled", true))
	vbox.add_child(_make_toggle_row_for_state(
		"Inflation Active", "Prices rise slowly over time",
		Color("#FFA726"), "inflation_enabled", true))
	vbox.add_child(_make_toggle_row_for_state(
		"Random Events", "Occasional surprises and challenges",
		CLR_CYAN, "random_events_enabled", false))

	# DISPLAY section.
	vbox.add_child(_make_section_label("DISPLAY"))
	vbox.add_child(_make_toggle_row_for_state(
		"Tooltips", "Show helpful hints on hover",
		CLR_CYAN, "tooltips_enabled", true))

	var fs_row := _make_toggle_row(
		"Fullscreen",
		"Expand the game to fill the screen",
		CLR_BORDER_SKY,
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		_on_fullscreen_toggled,
	)
	vbox.add_child(fs_row.get_parent())

	# Make sure CloseBtn stays at the bottom of the VBox.
	vbox.move_child(close_btn, vbox.get_child_count() - 1)
	_ = close_idx  # (unused — silence warning)

## Build a section divider label.
func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", CLR_BORDER_SKY)
	lbl.add_theme_font_size_override("font_size", 22)
	var font := UITheme.get_pixel_font()
	if font: lbl.add_theme_font_override("font", font)
	return lbl

## Read the initial toggle state from GameState (default if missing) and
## write back on change.
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

## Build a row: card panel + icon tile + label/sub + toggle switch.
## Returns the toggle Button (call get_parent() for the row container).
func _make_toggle_row(name: String, sub: String, accent: Color,
		initial_on: bool, on_toggled: Callable) -> Button:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 12)
	_wrap_row_in_card(row, accent)

	var tile := ColorRect.new()
	tile.color = Color(accent.r, accent.g, accent.b, 0.22)
	tile.custom_minimum_size = Vector2(36, 36)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 2)
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 26)
	var pf := UITheme.get_pixel_font()
	if pf: name_lbl.add_theme_font_override("font", pf)
	block.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = sub
	sub_lbl.add_theme_color_override("font_color", CLR_DIM)
	sub_lbl.add_theme_font_size_override("font_size", 18)
	block.add_child(sub_lbl)
	row.add_child(block)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = initial_on
	toggle.custom_minimum_size = Vector2(70, 36)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.text = ""
	_apply_toggle_visual(toggle)
	toggle.toggled.connect(func(on: bool):
		_apply_toggle_visual(toggle)
		on_toggled.call(on)
	)
	row.add_child(toggle)

	return toggle

## Inject a small red "✕" close button in the top-right of the title bar so
## players can dismiss Settings without scrolling to the footer.
func _inject_header_close_btn() -> void:
	var title := get_node_or_null("Panel/VBox/Title")
	if not (title is Label):
		return
	var vbox := title.get_parent()
	if not (vbox is VBoxContainer):
		return

	# Wrap the existing title in an HBox that adds a right-aligned close ✕.
	var header := HBoxContainer.new()
	header.name = "HeaderRow"
	header.add_theme_constant_override("separation", 10)

	# Detach title from VBox and nest it inside the new header.
	var title_index := title.get_index()
	vbox.remove_child(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(44, 44)
	x.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(x, UITheme.CLR_RED)
	x.pressed.connect(_on_close_pressed)
	header.add_child(x)

	vbox.add_child(header)
	vbox.move_child(header, title_index)

## Build the SFX slider row as a card. The slider shares the Master bus so
## changes cross-fade with the Music Volume slider for now.
func _make_sfx_slider_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 12)
	_wrap_row_in_card(row, CLR_CYAN)

	var tile := ColorRect.new()
	tile.color = Color(CLR_CYAN.r, CLR_CYAN.g, CLR_CYAN.b, 0.22)
	tile.custom_minimum_size = Vector2(36, 36)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)

	var name_lbl := Label.new()
	name_lbl.text = "SFX"
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 28)
	var pf := UITheme.get_pixel_font()
	if pf: name_lbl.add_theme_font_override("font", pf)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(200, 20)
	slider.min_value = 0
	slider.max_value = 100
	slider.value = volume_slider.value
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	var pct := Label.new()
	pct.text = str(int(slider.value)) + "%"
	pct.add_theme_color_override("font_color", CLR_CYAN)
	pct.add_theme_font_size_override("font_size", 24)
	pct.custom_minimum_size.x = 60
	if pf: pct.add_theme_font_override("font", pf)
	row.add_child(pct)

	slider.value_changed.connect(func(v: float):
		pct.text = str(int(v)) + "%"
		# Mirror onto Master bus so SFX audibly changes; future buses can split.
		_on_volume_changed(v)
		volume_slider.set_value_no_signal(v)
	)
	return row

func _apply_toggle_visual(btn: Button) -> void:
	var on := btn.button_pressed
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color("#4CAF50") if on else Color("#1e3a6e")
	sb.border_color = Color("#4CAF50") if on else CLR_BORDER_DIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)
