# SettingsMenu.gd
# Fully redesigned overlay with ScrollContainer, circular switch thumbs, and emoji icon blocks.
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

	# Restyle the scene shell to the design identity.
	_style_panel_shell()
	
	var main_vbox := get_node_or_null("Panel/VBox")
	if main_vbox:
		# Style existing close button at the bottom
		UITheme.style_close_button(close_btn)
		close_btn.pressed.connect(_on_close_pressed)

		# Create header close button dynamically
		_inject_header_close_btn()
		
		# Style existing title
		var title := get_node_or_null("Panel/VBox/HeaderRow/Title")
		if not title:
			title = get_node_or_null("Panel/VBox/Title")
		if title is Label:
			title.text = "Settings"
			var title_font := SystemFont.new()
			title_font.font_weight = 900
			title.add_theme_font_override("font", title_font)
			title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
			title.add_theme_font_size_override("font_size", 64)
			title.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
			title.add_theme_constant_override("outline_size", 12)
			title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
			title.add_theme_constant_override("shadow_offset_x", 3)
			title.add_theme_constant_override("shadow_offset_y", 3)

		# Create ScrollContainer
		var scroll_container := ScrollContainer.new()
		scroll_container.name = "ScrollContainer"
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var scroll_vbox := VBoxContainer.new()
		scroll_vbox.name = "ScrollVBox"
		scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_vbox.add_theme_constant_override("separation", 18)
		scroll_container.add_child(scroll_vbox)
		
		# Restyle and wrap existing VolumeContainer
		var vc := get_node_or_null("Panel/VBox/VolumeContainer")
		var music_card: PanelContainer = null
		if vc is HBoxContainer:
			# Format VolumeContainer separation
			vc.add_theme_constant_override("separation", 24)
			if volume_slider:
				volume_slider.custom_minimum_size = Vector2(240, 20)
				volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			music_card = _wrap_row_in_card(vc, CLR_BORDER_SKY, "🎵")
			var lbl := vc.get_node_or_null("Label")
			if lbl is Label:
				lbl.text = "Music Volume"
				lbl.add_theme_color_override("font_color", UITheme.CLR_INK)
				lbl.add_theme_font_size_override("font_size", 32)
				var font_medium := SystemFont.new()
				font_medium.font_weight = 500
				lbl.add_theme_font_override("font", font_medium)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			volume_value_label.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
			volume_value_label.add_theme_font_size_override("font_size", 28)
			var font_bold := SystemFont.new()
			font_bold.font_weight = 700
			volume_value_label.add_theme_font_override("font", font_bold)

		# Inject the ScrollContainer into main_vbox
		main_vbox.add_child(scroll_container)
		
		# Move the ScrollContainer below the header (header is at index 0, scrollcontainer at index 1)
		main_vbox.move_child(scroll_container, 1)

		if music_card:
			scroll_vbox.add_child(music_card)

	# Initial volume from GameState (preserves existing behaviour).
	var initial_volume = GameState.get("master_volume") if "master_volume" in GameState else 70
	volume_slider.value = initial_volume
	volume_value_label.text = str(int(initial_volume)) + "%"
	_pre_mute_music = initial_volume
	_pre_mute_sfx   = initial_volume
	_style_slider(volume_slider)
	volume_slider.value_changed.connect(_on_volume_changed)

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
#  AUDIO LOGIC — unchanged signatures
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
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	mute_btn.add_theme_font_override("font", font_bold)
	mute_btn.add_theme_font_size_override("font_size", 24)
	
	if is_muted:
		mute_btn.text = "Unmute"
		var sb := StyleBoxFlat.new()
		sb.bg_color     = UITheme.CLR_GREEN
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(3)
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
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		mute_btn.add_theme_stylebox_override("normal",  sb)
		mute_btn.add_theme_stylebox_override("hover",   sb)
		mute_btn.add_theme_stylebox_override("pressed", sb)
		mute_btn.add_theme_color_override("font_color",       UITheme.CLR_INK)
		mute_btn.add_theme_color_override("font_hover_color", UITheme.CLR_INK)

# ══════════════════════════════════════════════════════════════════════════════
#  STYLING & ICON BLOCKS
# ══════════════════════════════════════════════════════════════════════════════

func _style_panel_shell() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node is PanelContainer:
		UITheme.style_cream_panel(panel_node)

## Apply slider track/fill style per spec.
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

	var grabber_hi := grabber.duplicate() as StyleBoxFlat
	grabber_hi.bg_color = UITheme.CLR_CREAM_LT
	grabber_hi.content_margin_top    = 12
	grabber_hi.content_margin_bottom = 12
	slider.add_theme_stylebox_override("grabber_highlight", grabber_hi)

## Wrap the row in a stylized PanelContainer card with an accent bar and an emoji icon block.
func _wrap_row_in_card(row: HBoxContainer, accent: Color, emoji: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Cream Panel container styling with a clean 3px ink border
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CLR_CREAM_LT
	sb.border_color = UITheme.CLR_INK
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16
	sb.content_margin_top = 16
	sb.content_margin_right = 16
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	
	# Inner HBox to align everything
	var inner_hbox := HBoxContainer.new()
	inner_hbox.add_theme_constant_override("separation", 24)
	inner_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(inner_hbox)
	
	# Left accent stripe (distinguishable colored accent)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.custom_minimum_size = Vector2(10, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_hbox.add_child(stripe)
	
	# Icon block with emoji
	var icon_block := _make_icon_block(emoji, accent)
	inner_hbox.add_child(icon_block)
	
	# Move the row container (HBox) into the inner_hbox
	if row.get_parent():
		row.get_parent().remove_child(row)
	inner_hbox.add_child(row)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	return card

func _make_icon_block(emoji: String, accent: Color) -> PanelContainer:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(72, 72)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	container.add_theme_stylebox_override("panel", sb)
	
	var label := Label.new()
	label.text = emoji
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36) # Big readable emoji
	container.add_child(label)
	
	return container

# ══════════════════════════════════════════════════════════════════════════════
#  EXPANDED LAYOUT — build AUDIO/GAME/DISPLAY/CONTROLS sections
# ══════════════════════════════════════════════════════════════════════════════

func _build_expanded_layout() -> void:
	var vbox := get_node_or_null("Panel/VBox")
	if not (vbox is VBoxContainer):
		return

	# We created ScrollContainer in _ready(). Let's find it.
	var scroll_container = vbox.get_node_or_null("ScrollContainer")
	var scroll_vbox = scroll_container.get_node_or_null("ScrollVBox") if scroll_container else null
	if not scroll_vbox:
		scroll_vbox = vbox # Fallback if not found

	# AUDIO section.
	var audio_section := _make_section_label("AUDIO")
	scroll_vbox.add_child(audio_section)

	# SFX slider row.
	var sfx_row := _make_sfx_slider_row()
	scroll_vbox.add_child(sfx_row)

	# Mute row.
	var mute_row := _make_mute_row()
	is_muted = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_update_mute_label()
	scroll_vbox.add_child(mute_row)

	# GAME section.
	scroll_vbox.add_child(_make_section_label("GAME"))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Notifications", "Show warnings and event popups",
		CLR_BORDER_SKY, "notifications_enabled", true, "🔔"))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Inflation Active", "Prices rise slowly over time",
		Color("#FFA726"), "inflation_enabled", true, "📈"))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Random Events", "Occasional surprises and challenges",
		CLR_CYAN, "random_events_enabled", true, "🎲"))

	# DISPLAY section.
	scroll_vbox.add_child(_make_section_label("DISPLAY"))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Tooltips", "Show helpful hints on hover",
		CLR_CYAN, "tooltips_enabled", true, "💬"))

	var fs_row := _make_toggle_row(
		"Fullscreen",
		"Expand the game to fill the screen",
		CLR_BORDER_SKY,
		true,
		_on_fullscreen_toggled,
		"🖥️"
	)
	scroll_vbox.add_child(fs_row.get_parent().get_parent()) # PanelContainer Card

	# CONTROLS section.
	scroll_vbox.add_child(_make_section_label("CONTROLS"))
	scroll_vbox.add_child(_make_keybinds_row())

	# Make sure CloseBtn stays at the bottom of the VBox.
	vbox.move_child(close_btn, vbox.get_child_count() - 1)

func _make_keybinds_row() -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	var card = _wrap_row_in_card(row, CLR_CYAN, "⌨️")

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = "Keybinds"
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 32)
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	name_lbl.add_theme_font_override("font", font_bold)
	block.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Customize keyboard shortcuts"
	sub_lbl.add_theme_color_override("font_color", CLR_DIM)
	sub_lbl.add_theme_font_size_override("font_size", 20)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)

	row.add_child(block)

	var btn := Button.new()
	btn.text = "Configure"
	btn.custom_minimum_size = Vector2(160, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	
	var font_btn := SystemFont.new()
	font_btn.font_weight = 700
	btn.add_theme_font_override("font", font_btn)
	btn.add_theme_font_size_override("font_size", 24)
	
	UITheme.style_pixel_button(btn)
	btn.pressed.connect(_on_keybinds_pressed)
	row.add_child(btn)

	return card

func _on_keybinds_pressed() -> void:
	var keybinds_menu = load("res://scenes/ui/KeybindsMenu.tscn").instantiate()
	get_tree().root.add_child(keybinds_menu)

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	lbl.add_theme_font_size_override("font_size", 32)
	var font_bold := SystemFont.new()
	font_bold.font_weight = 800
	lbl.add_theme_font_override("font", font_bold)
	lbl.custom_minimum_size = Vector2(0, 48)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return lbl

func _make_toggle_row_for_state(name: String, sub: String, accent: Color,
		state_prop: String, default_on: bool, emoji: String) -> PanelContainer:
	var initial := default_on
	if state_prop in GameState:
		initial = bool(GameState.get(state_prop))
	var btn := _make_toggle_row(name, sub, accent, initial,
		func(on: bool): _apply_state_toggle(state_prop, on), emoji)
	_toggles[state_prop] = btn
	return btn.get_parent().get_parent() as PanelContainer

func _apply_state_toggle(prop: String, value: bool) -> void:
	if prop in GameState:
		GameState.set(prop, value)

func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

func _make_toggle_row(name: String, sub: String, accent: Color,
		initial_on: bool, on_toggled: Callable, emoji: String) -> Button:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	_wrap_row_in_card(row, accent, emoji)

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)
	
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 32)
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	name_lbl.add_theme_font_override("font", font_bold)
	block.add_child(name_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = sub
	sub_lbl.add_theme_color_override("font_color", CLR_DIM)
	sub_lbl.add_theme_font_size_override("font_size", 20)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)
	row.add_child(block)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = initial_on
	toggle.custom_minimum_size = Vector2(140, 72)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.text = ""
	_apply_toggle_visual(toggle)
	toggle.toggled.connect(func(on: bool):
		_apply_toggle_visual(toggle)
		on_toggled.call(on)
	)
	row.add_child(toggle)

	return toggle

func _make_mute_row() -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	var card = _wrap_row_in_card(row, Color("#FFA726"), "🔇")

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = "Mute All Audio"
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 32)
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	name_lbl.add_theme_font_override("font", font_bold)
	block.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Silences music and sound effects"
	sub_lbl.add_theme_color_override("font_color", CLR_DIM)
	sub_lbl.add_theme_font_size_override("font_size", 20)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)

	row.add_child(block)

	mute_btn = Button.new()
	mute_btn.toggle_mode = false
	mute_btn.custom_minimum_size = Vector2(160, 64)
	mute_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	mute_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.pressed.connect(_on_mute_button_pressed)
	row.add_child(mute_btn)

	return card

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

func _make_sfx_slider_row() -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 24)
	var card = _wrap_row_in_card(row, CLR_CYAN, "🔊")

	var name_lbl := Label.new()
	name_lbl.text = "SFX"
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 32)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	name_lbl.add_theme_font_override("font", font_medium)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(240, 20)
	slider.min_value = 0
	slider.max_value = 100
	slider.value = volume_slider.value
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	var pct := Label.new()
	pct.text = str(int(slider.value)) + "%"
	pct.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	pct.add_theme_font_size_override("font_size", 28)
	pct.custom_minimum_size.x = 100
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	pct.add_theme_font_override("font", font_bold)
	row.add_child(pct)

	slider.value_changed.connect(func(v: float):
		pct.text = str(int(v)) + "%"
		_on_volume_changed(v)
		volume_slider.set_value_no_signal(v)
		if is_muted and v > 0:
			is_muted = false
			_update_mute_label()
	)

	sfx_slider    = slider
	sfx_pct_label = pct

	return card

func _apply_toggle_visual(btn: Button) -> void:
	var on := btn.button_pressed
	var sb := StyleBoxFlat.new()
	sb.bg_color     = UITheme.CLR_GREEN if on else UITheme.CLR_CREAM_LT
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(36)
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)

	var thumb := btn.get_node_or_null("Thumb") as Panel
	if not thumb:
		thumb = Panel.new()
		thumb.name = "Thumb"
		thumb.custom_minimum_size = Vector2(48, 48)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(thumb)
		
	var thumb_sb := StyleBoxFlat.new()
	thumb_sb.bg_color = Color.WHITE if on else UITheme.CLR_INK
	thumb_sb.set_corner_radius_all(24) # Circular thumb
	thumb_sb.anti_aliasing = false
	thumb.add_theme_stylebox_override("panel", thumb_sb)
	
	thumb.position = Vector2(80.0 if on else 12.0, 12.0)
