# SettingsMenu.gd
# Fully redesigned overlay with unified card heights, square checkboxes, and separate header/footer panels.
extends CanvasLayer

signal settings_closed

# ── Design tokens ─────────────────────────────────────────────────────────────
const CLR_BG_DEEP    := UITheme.CLR_MAROON_D
const CLR_BG_CARD    := UITheme.CLR_CREAM
const CLR_BORDER_SKY := UITheme.CLR_MAROON
const CLR_BORDER_DIM := UITheme.CLR_GRAY_DRK
const CLR_CYAN       := UITheme.CLR_ORANGE_PX
const CLR_WHITE      := UITheme.CLR_INK
const CLR_DIM        := UITheme.CLR_GRAY_DRK

# ── Pre-existing scene refs (keep names identical for compatibility) ──────────
@onready var volume_slider      : HSlider = $Panel/VBox/VolumeContainer/VolumeSlider
@onready var volume_value_label : Label   = $Panel/VBox/VolumeContainer/VolumeValue
@onready var close_btn          : Button  = $Panel/VBox/CloseBtn

var mute_btn: Button = null
var is_muted: bool = false

# Volume memory for restore-on-unmute.
var _pre_mute_music: float = 70.0
var _pre_mute_sfx:   float = 70.0

# SFX row refs
var sfx_slider:    HSlider = null
var sfx_pct_label: Label   = null

func _ready() -> void:
	UITheme.apply_overlay_theme(self)

	# Restyle the scene shell to the design identity.
	_style_panel_shell()
	
	var main_vbox := get_node_or_null("Panel/VBox")
	if main_vbox:
		# Grabbing references to existing title and close button before restructuring
		var title_lbl = get_node_or_null("Panel/VBox/Title")
		if title_lbl:
			title_lbl.get_parent().remove_child(title_lbl)
			
		var default_close_btn = get_node_or_null("Panel/VBox/CloseBtn")
		if default_close_btn:
			default_close_btn.get_parent().remove_child(default_close_btn)
			
		var vc := get_node_or_null("Panel/VBox/VolumeContainer")
		if vc:
			vc.queue_free() # We will create volume controls dynamically
			
		# Clean all other children from main_vbox to rebuild
		for child in main_vbox.get_children():
			child.queue_free()
			
		# Use zero separation between main blocks so separators sit flush
		main_vbox.add_theme_constant_override("separation", 0)
		
		# 1. HEADER PANEL
		var header_panel := PanelContainer.new()
		header_panel.name = "HeaderPanel"
		header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var header_sb := StyleBoxFlat.new()
		header_sb.bg_color = UITheme.CLR_CREAM
		header_sb.border_color = UITheme.CLR_INK
		header_sb.border_width_left = 0
		header_sb.border_width_top = 0
		header_sb.border_width_right = 0
		header_sb.border_width_bottom = 3 # separates header from content
		header_sb.set_corner_radius_all(0)
		header_sb.content_margin_left = 20
		header_sb.content_margin_top = 16
		header_sb.content_margin_right = 20
		header_sb.content_margin_bottom = 16
		header_panel.add_theme_stylebox_override("panel", header_sb)
		
		var header_hbox := HBoxContainer.new()
		header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_panel.add_child(header_hbox)
		
		# Balanced spacer on the left to perfectly center the title
		var left_spacer := Control.new()
		left_spacer.custom_minimum_size = Vector2(64, 0)
		header_hbox.add_child(left_spacer)
		
		# Title label styling (standard header style - dark ink color with no shadow)
		if not title_lbl:
			title_lbl = Label.new()
		title_lbl.text = "Settings"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var title_font := SystemFont.new()
		title_font.font_weight = 900
		title_lbl.add_theme_font_override("font", title_font)
		title_lbl.add_theme_color_override("font_color", UITheme.CLR_CREAM)
		title_lbl.add_theme_font_size_override("font_size", 48)
		title_lbl.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
		title_lbl.add_theme_constant_override("outline_size", 14)
		title_lbl.remove_theme_color_override("font_shadow_color")
		title_lbl.add_theme_constant_override("shadow_offset_x", 0)
		title_lbl.add_theme_constant_override("shadow_offset_y", 0)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_hbox.add_child(title_lbl)
		
		# Red X Close button on the right
		var x_btn := Button.new()
		x_btn.name = "HeaderCloseBtn"
		x_btn.text = "X"
		x_btn.custom_minimum_size = Vector2(64, 64)
		x_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		x_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		x_btn.focus_mode = Control.FOCUS_NONE
		UITheme.style_pixel_button_colored(x_btn, Color("#EF5350"))
		x_btn.pressed.connect(_on_close_pressed)
		header_hbox.add_child(x_btn)
		
		main_vbox.add_child(header_panel)
		
		# 2. CONTENT FRAME (ScrollFrame with no border around ScrollContainer)
		var content_margin := MarginContainer.new()
		content_margin.name = "ContentMargin"
		content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_margin.add_theme_constant_override("margin_left", 0)
		content_margin.add_theme_constant_override("margin_right", 0)
		content_margin.add_theme_constant_override("margin_top", 0)
		content_margin.add_theme_constant_override("margin_bottom", 0)
		main_vbox.add_child(content_margin)
		
		var scroll_frame := PanelContainer.new()
		scroll_frame.name = "ScrollFrame"
		scroll_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var frame_sb := StyleBoxFlat.new()
		frame_sb.bg_color = UITheme.CLR_CREAM_LT
		frame_sb.set_border_width_all(0) # No border!
		frame_sb.set_corner_radius_all(0)
		frame_sb.content_margin_left = 24
		frame_sb.content_margin_top = 24
		frame_sb.content_margin_right = 24
		frame_sb.content_margin_bottom = 24
		scroll_frame.add_theme_stylebox_override("panel", frame_sb)
		content_margin.add_child(scroll_frame)
		
		var scroll_container := ScrollContainer.new()
		scroll_container.name = "ScrollContainer"
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_frame.add_child(scroll_container)
		
		var scroll_vbox := VBoxContainer.new()
		scroll_vbox.name = "ScrollVBox"
		scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_vbox.add_theme_constant_override("separation", 18)
		scroll_container.add_child(scroll_vbox)
		
		# 3. FOOTER PANEL
		var footer_panel := PanelContainer.new()
		footer_panel.name = "FooterPanel"
		footer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var footer_sb := StyleBoxFlat.new()
		footer_sb.bg_color = UITheme.CLR_CREAM
		footer_sb.border_color = UITheme.CLR_INK
		footer_sb.border_width_left = 0
		footer_sb.border_width_top = 3 # separates content from footer
		footer_sb.border_width_right = 0
		footer_sb.border_width_bottom = 0
		footer_sb.set_corner_radius_all(0)
		footer_sb.content_margin_left = 20
		footer_sb.content_margin_top = 16
		footer_sb.content_margin_right = 20
		footer_sb.content_margin_bottom = 16
		footer_panel.add_theme_stylebox_override("panel", footer_sb)
		
		if not default_close_btn:
			default_close_btn = Button.new()
		close_btn = default_close_btn
		close_btn.name = "CloseBtn"
		close_btn.text = "Close"
		close_btn.custom_minimum_size = Vector2(180, 64)
		close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close_btn.focus_mode = Control.FOCUS_NONE
		UITheme.style_pixel_button(close_btn, false) # standard tan button
		close_btn.add_theme_font_size_override("font_size", 24)
		
		if not close_btn.pressed.is_connected(_on_close_pressed):
			close_btn.pressed.connect(_on_close_pressed)
			
		footer_panel.add_child(close_btn)
		main_vbox.add_child(footer_panel)

	# Build expanded sections procedurally.
	_build_expanded_layout()

	# Default fullscreen to on.
	_on_fullscreen_toggled(true)

func _input(event: InputEvent) -> void:
	# ESC closes settings without triggering the pause menu.
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════════════
#  AUDIO LOGIC
# ══════════════════════════════════════════════════════════════════════════════

func _on_volume_changed(value: float) -> void:
	if volume_value_label:
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

func _on_mute_button_pressed() -> void:
	_set_muted(not is_muted)

func _set_muted(should_mute: bool) -> void:
	is_muted = should_mute
	if is_muted:
		# Save current levels so we can restore on unmute.
		_pre_mute_music = volume_slider.value if volume_slider else 70.0
		_pre_mute_sfx   = sfx_slider.value if sfx_slider else 70.0
		# Silence both sliders without firing value_changed.
		if volume_slider: volume_slider.set_value_no_signal(0)
		if sfx_slider: sfx_slider.set_value_no_signal(0)
		if volume_value_label: volume_value_label.text = "0%"
		if sfx_pct_label: sfx_pct_label.text = "0%"
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	else:
		# Restore saved levels.
		if volume_slider: volume_slider.set_value_no_signal(_pre_mute_music)
		if sfx_slider: sfx_slider.set_value_no_signal(_pre_mute_sfx)
		if volume_value_label: volume_value_label.text = str(int(_pre_mute_music)) + "%"
		if sfx_pct_label: sfx_pct_label.text = str(int(_pre_mute_sfx)) + "%"
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
		var db: float = linear_to_db(_pre_mute_music / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
		if "master_volume" in GameState:
			GameState.master_volume = int(_pre_mute_music)
	_update_mute_label()

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
	else:
		mute_btn.text = "Mute"
	# Always style as standard tan pixel button
	UITheme.style_pixel_button(mute_btn, false)

func _on_fullscreen_toggled(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# ══════════════════════════════════════════════════════════════════════════════
#  STYLING & CARD HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _style_panel_shell() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node is PanelContainer:
		panel_node.custom_minimum_size = Vector2(1200, 900)
		panel_node.set_anchors_preset(Control.PRESET_CENTER)
		panel_node.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel_node.grow_vertical = Control.GROW_DIRECTION_BOTH
		panel_node.offset_left = -600.0
		panel_node.offset_top = -450.0
		panel_node.offset_right = 600.0
		panel_node.offset_bottom = 450.0
		
		# Custom stylebox with reduced border thickness (3px instead of 4px)
		var sb := StyleBoxFlat.new()
		sb.bg_color     = UITheme.CLR_CREAM
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		sb.set_content_margin_all(0)
		panel_node.add_theme_stylebox_override("panel", sb)
		panel_node.modulate.a = 1.0

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

func _wrap_row_in_card(row: HBoxContainer, _accent: Color, _emoji: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CLR_CREAM_LT
	sb.border_color = UITheme.CLR_INK
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 20
	sb.content_margin_top = 16
	sb.content_margin_right = 20
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	
	if row.get_parent():
		row.get_parent().remove_child(row)
	card.add_child(row)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	return card

# ══════════════════════════════════════════════════════════════════════════════
#  EXPANDED LAYOUT GENERATION
# ══════════════════════════════════════════════════════════════════════════════

func _build_expanded_layout() -> void:
	var scroll_container = get_node_or_null("Panel/VBox/ContentMargin/ScrollFrame/ScrollContainer")
	var scroll_vbox = scroll_container.get_node_or_null("ScrollVBox") if scroll_container else null
	if not scroll_vbox:
		return

	# AUDIO section.
	var audio_section := _make_section_label("AUDIO")
	scroll_vbox.add_child(audio_section)

	# SFX Volume Row (replaces Music Volume row as we already have SFX).
	var initial_volume = GameState.get("master_volume") if "master_volume" in GameState else 70
	var sfx_data = _make_slider_row("SFX Volume", "Adjust sound effects volume", initial_volume, func(v: float):
		if sfx_pct_label:
			sfx_pct_label.text = str(int(v)) + "%"
		_on_volume_changed(v)
		if is_muted and v > 0:
			is_muted = false
			_update_mute_label()
	)
	var sfx_card = sfx_data[0]
	sfx_slider = sfx_data[1]
	sfx_pct_label = sfx_data[2]
	
	# Point pre-existing volume refs to SFX slider/pct for scene/script compatibility.
	volume_slider = sfx_slider
	volume_value_label = sfx_pct_label
	
	_pre_mute_sfx   = initial_volume
	_pre_mute_music = initial_volume
	scroll_vbox.add_child(sfx_card)

	# Mute Row.
	var mute_row := _make_mute_row()
	is_muted = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_update_mute_label()
	scroll_vbox.add_child(mute_row)

	# GAME section.
	scroll_vbox.add_child(_make_section_label("GAME"))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Notifications", "Show warnings and event popups",
		CLR_BORDER_SKY, "notifications_enabled", true, ""))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Inflation Active", "Prices rise slowly over time",
		Color("#FFA726"), "inflation_enabled", true, ""))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Random Events", "Occasional surprises and challenges",
		CLR_CYAN, "random_events_enabled", true, ""))

	# DISPLAY section.
	scroll_vbox.add_child(_make_section_label("DISPLAY"))
	scroll_vbox.add_child(_make_toggle_row_for_state(
		"Tooltips", "Show helpful hints on hover",
		CLR_CYAN, "tooltips_enabled", true, ""))

	var fs_card := _make_toggle_row(
		"Fullscreen",
		"Expand the game to fill the screen",
		CLR_BORDER_SKY,
		true,
		_on_fullscreen_toggled,
		""
	)
	scroll_vbox.add_child(fs_card)

	# CONTROLS section.
	scroll_vbox.add_child(_make_section_label("CONTROLS"))
	scroll_vbox.add_child(_make_keybinds_row())

func _make_slider_row(title_text: String, sub_text: String, initial_val: float, val_changed_callable: Callable) -> Array:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.add_theme_constant_override("separation", 24)

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = title_text
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 32)
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	name_lbl.add_theme_font_override("font", font_bold)
	block.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = sub_text
	sub_lbl.add_theme_color_override("font_color", CLR_DIM)
	sub_lbl.add_theme_font_size_override("font_size", 26)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)

	row.add_child(block)

	# Right-side HBox container for Slider and Value text
	var control_hbox := HBoxContainer.new()
	control_hbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	control_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control_hbox.add_theme_constant_override("separation", 16)
	row.add_child(control_hbox)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(400, 20)
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial_val
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	control_hbox.add_child(slider)

	var pct := Label.new()
	pct.text = str(int(slider.value)) + "%"
	pct.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	pct.add_theme_font_size_override("font_size", 28)
	pct.custom_minimum_size.x = 100
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var font_pct := SystemFont.new()
	font_pct.font_weight = 700
	pct.add_theme_font_override("font", font_pct)
	control_hbox.add_child(pct)

	slider.value_changed.connect(func(v: float):
		pct.text = str(int(v)) + "%"
		val_changed_callable.call(v)
	)

	var card = _wrap_row_in_card(row, CLR_CYAN, "")
	return [card, slider, pct]

func _make_keybinds_row() -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.add_theme_constant_override("separation", 24)
	var card = _wrap_row_in_card(row, CLR_CYAN, "")

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 12)

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
	sub_lbl.add_theme_font_size_override("font_size", 26)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)

	row.add_child(block)

	var btn := Button.new()
	btn.text = "Configure"
	btn.custom_minimum_size = Vector2(180, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	
	var font_btn := SystemFont.new()
	font_btn.font_weight = 700
	btn.add_theme_font_override("font", font_btn)
	btn.add_theme_font_size_override("font_size", 24)
	
	UITheme.style_pixel_button(btn, false) # standard tan button
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

func _make_toggle_row_for_state(name: String, sub: String, color: Color, state_key: String, initial: bool, emoji: String) -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.add_theme_constant_override("separation", 24)
	var card = _wrap_row_in_card(row, color, emoji)
	
	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 12)
	
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
	sub_lbl.add_theme_font_size_override("font_size", 26)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)
	row.add_child(block)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = initial
	toggle.custom_minimum_size = Vector2(32, 32)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.text = ""
	_apply_toggle_visual(toggle)
	toggle.toggled.connect(func(on: bool):
		_apply_toggle_visual(toggle)
		GameState.set(state_key, on)
	)
	row.add_child(toggle)

	return card

func _make_toggle_row(name: String, sub: String, color: Color, initial_on: bool, on_toggled: Callable, emoji: String) -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.add_theme_constant_override("separation", 24)
	var card = _wrap_row_in_card(row, color, emoji)

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 12)
	
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
	sub_lbl.add_theme_font_size_override("font_size", 26)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)
	row.add_child(block)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = initial_on
	toggle.custom_minimum_size = Vector2(32, 32)
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

	return card

func _make_mute_row() -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.add_theme_constant_override("separation", 24)
	var card = _wrap_row_in_card(row, Color("#FFA726"), "")

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 12)

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
	sub_lbl.add_theme_font_size_override("font_size", 26)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	sub_lbl.add_theme_font_override("font", font_medium)
	block.add_child(sub_lbl)

	row.add_child(block)

	mute_btn = Button.new()
	mute_btn.toggle_mode = false
	mute_btn.custom_minimum_size = Vector2(180, 64)
	mute_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	mute_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.pressed.connect(_on_mute_button_pressed)
	row.add_child(mute_btn)

	return card

func _apply_toggle_visual(btn: Button) -> void:
	var on := btn.button_pressed
	
	# Checkbox outer box — cream background with 3px ink border and sharp corners
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CLR_CREAM_LT
	sb.border_color = UITheme.CLR_INK
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

	var center_container = btn.get_node_or_null("Center")
	if not center_container:
		center_container = CenterContainer.new()
		center_container.name = "Center"
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(center_container)

	var thumb = center_container.get_node_or_null("Thumb")
	if not thumb:
		var thumb_rect := ColorRect.new()
		thumb_rect.name = "Thumb"
		thumb_rect.custom_minimum_size = Vector2(16, 16)
		thumb_rect.size = Vector2(16, 16)
		thumb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_container.add_child(thumb_rect)
		thumb = thumb_rect
		
	# Inner fill indicator
	thumb.color = UITheme.CLR_MAROON_D
	thumb.visible = on
