# KeybindsMenu.gd
# Redesigned keybinds overlay matching the settings popup visual layout.
extends CanvasLayer

signal keybinds_closed

const SAVE_PATH := "user://keybinds.cfg"

# (action, display label) — order = display order in the menu.
const ACTIONS := [
	["move_up",     "Move Up"],
	["move_down",   "Move Down"],
	["move_left",   "Move Left"],
	["move_right",  "Move Right"],
	["interact",    "Interact"],
	["pause",       "Pause / Menu"],
	["pet_menu",    "Pet Menu"],
	["chore_menu",  "Chore Menu"],
	["sim_day",     "Skip Week"],
]

# Design tokens — maroon brand palette
const CLR_BG_CARD    := UITheme.CLR_CREAM_LT    # row background (light card)
const CLR_BORDER_SKY := UITheme.CLR_ORANGE_PX   # row accent stripe
const CLR_BORDER_DIM := UITheme.CLR_INK         # keycap button border
const CLR_CYAN       := UITheme.CLR_MAROON_D     # status confirmations
const CLR_WHITE      := UITheme.CLR_INK          # row label + keycap text
const CLR_DIM        := Color(UITheme.CLR_INK.r, UITheme.CLR_INK.g, UITheme.CLR_INK.b, 0.7)
const CLR_AMBER      := UITheme.CLR_ORANGE_PX    # reset btn + listening highlight

# Default events captured once before any saved override is applied.
static var _original_events: Dictionary = {}

var _row_buttons: Dictionary = {}     # action_name → Button (the bind button)
var _rebinding_action: String = ""    # waiting for next key press
var _status_label: Label = null

@onready var vbox: VBoxContainer = $Panel/VBox

# ── Static API ────────────────────────────────────────────────────────────────

static func load_saved_keybinds() -> void:
	_capture_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action in cfg.get_section_keys("keybinds"):
		if not InputMap.has_action(action):
			continue
		var physical_keycode: int = int(cfg.get_value("keybinds", action, 0))
		if physical_keycode == 0:
			continue
		var ev := InputEventKey.new()
		ev.physical_keycode = physical_keycode
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ev)

static func _capture_defaults() -> void:
	if not _original_events.is_empty():
		return
	for entry in ACTIONS:
		var action: String = entry[0]
		if not InputMap.has_action(action):
			continue
		var snapshot: Array = []
		for ev in InputMap.action_get_events(action):
			snapshot.append(ev.duplicate())
		_original_events[action] = snapshot

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	UITheme.apply_overlay_theme(self)
	_capture_defaults()

	var panel := get_node_or_null("Panel")
	if panel is PanelContainer:
		panel.custom_minimum_size = Vector2(800, 750)
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		panel.offset_left = -400.0
		panel.offset_top = -375.0
		panel.offset_right = 400.0
		panel.offset_bottom = 375.0
		
		# Custom stylebox with reduced border thickness (3px instead of 4px)
		var sb := StyleBoxFlat.new()
		sb.bg_color     = UITheme.CLR_CREAM
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		sb.set_content_margin_all(0)
		panel.add_theme_stylebox_override("panel", sb)
		panel.modulate.a = 1.0

	_build_layout()

func _input(event: InputEvent) -> void:
	if _rebinding_action != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
		else:
			_apply_rebind(_rebinding_action, event)
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

# ── Layout ────────────────────────────────────────────────────────────────────

func _build_layout() -> void:
	# Clear vbox children to rebuild
	for child in vbox.get_children():
		child.queue_free()
	
	vbox.add_theme_constant_override("separation", 0)

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
	
	# Title label styling
	var title_lbl := Label.new()
	title_lbl.text = "Keybinds"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font := SystemFont.new()
	title_font.font_weight = 900
	title_lbl.add_theme_font_override("font", title_font)
	title_lbl.add_theme_color_override("font_color", UITheme.CLR_CREAM)
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
	title_lbl.add_theme_constant_override("outline_size", 14)
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
	x_btn.pressed.connect(_close)
	header_hbox.add_child(x_btn)
	
	vbox.add_child(header_panel)

	# Subheading / Hint label (taken out of the internal box)
	var hint_margin := MarginContainer.new()
	hint_margin.name = "HintMargin"
	hint_margin.add_theme_constant_override("margin_left", 32)
	hint_margin.add_theme_constant_override("margin_right", 32)
	hint_margin.add_theme_constant_override("margin_top", 16)
	hint_margin.add_theme_constant_override("margin_bottom", 16) # Add padding below subheading to space it from list
	
	var hint := Label.new()
	hint.text = "Click a key to rebind. ESC cancels."
	hint.add_theme_color_override("font_color", CLR_DIM)
	hint.add_theme_font_size_override("font_size", 24)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	hint.add_theme_font_override("font", font_medium)
	hint_margin.add_child(hint)
	vbox.add_child(hint_margin)

	# 2. CONTENT FRAME (ScrollFrame with no border around ScrollContainer)
	var content_margin := MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 0)
	content_margin.add_theme_constant_override("margin_right", 0)
	content_margin.add_theme_constant_override("margin_top", 0)
	content_margin.add_theme_constant_override("margin_bottom", 0)
	vbox.add_child(content_margin)
	
	var scroll_frame := PanelContainer.new()
	scroll_frame.name = "ScrollFrame"
	scroll_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = UITheme.CLR_CREAM_LT
	frame_sb.set_border_width_all(0) # No border!
	frame_sb.set_corner_radius_all(0)
	frame_sb.content_margin_left = 24
	frame_sb.content_margin_top = 0 # No top margin so list starts cleanly under divider line
	frame_sb.content_margin_right = 24
	frame_sb.content_margin_bottom = 24
	scroll_frame.add_theme_stylebox_override("panel", frame_sb)
	content_margin.add_child(scroll_frame)

	# Inner vertical container inside ScrollFrame
	var inner_vbox := VBoxContainer.new()
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 12)
	scroll_frame.add_child(inner_vbox)

	# Scrollable list of action rows
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for entry in ACTIONS:
		list.add_child(_build_action_row(entry[0], entry[1]))

	# Status line for "press a key" prompts and confirmations
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", CLR_CYAN)
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pf := UITheme.get_pixel_font()
	if pf: _status_label.add_theme_font_override("font", pf)
	inner_vbox.add_child(_status_label)

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
	
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	footer_panel.add_child(footer)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.custom_minimum_size = Vector2(240, 64)
	reset_btn.add_theme_font_size_override("font_size", 24)
	UITheme.style_pixel_button(reset_btn, false) # tan standard button
	reset_btn.pressed.connect(_reset_to_defaults)
	footer.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(180, 64)
	close_btn.add_theme_font_size_override("font_size", 24)
	UITheme.style_pixel_button(close_btn, false) # tan standard button
	close_btn.pressed.connect(_close)
	footer.add_child(close_btn)

	vbox.add_child(footer_panel)

func _build_action_row(action: String, label_text: String) -> PanelContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_constant_override("separation", 24)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	name_lbl.add_theme_font_override("font", font_bold)
	row.add_child(name_lbl)

	var bind_btn := Button.new()
	bind_btn.text = _current_key_label(action)
	bind_btn.custom_minimum_size = Vector2(180, 48)
	bind_btn.add_theme_font_size_override("font_size", 22)
	bind_btn.focus_mode = Control.FOCUS_NONE
	_apply_bind_button_style(bind_btn, false)
	bind_btn.pressed.connect(_begin_rebind.bind(action))
	row.add_child(bind_btn)
	_row_buttons[action] = bind_btn

	# Wrap in standard card style matching SettingsMenu
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
	sb.content_margin_top = 10
	sb.content_margin_right = 20
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	card.add_child(row)
	
	return card

# ── Rebind flow ───────────────────────────────────────────────────────────────

func _begin_rebind(action: String) -> void:
	if _rebinding_action != "":
		_cancel_rebind()
	_rebinding_action = action
	var btn: Button = _row_buttons[action]
	btn.text = "Press a key..."
	_apply_bind_button_style(btn, true)
	if _status_label:
		_status_label.text = "Press a key for \"%s\" (ESC to cancel)" % action

func _cancel_rebind() -> void:
	if _rebinding_action == "":
		return
	var action := _rebinding_action
	_rebinding_action = ""
	var btn: Button = _row_buttons[action]
	btn.text = _current_key_label(action)
	_apply_bind_button_style(btn, false)
	if _status_label:
		_status_label.text = ""

func _apply_rebind(action: String, key_event: InputEventKey) -> void:
	_rebinding_action = ""
	var ev := InputEventKey.new()
	ev.physical_keycode = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	_save_keybind(action, ev.physical_keycode)

	var btn: Button = _row_buttons[action]
	btn.text = _current_key_label(action)
	_apply_bind_button_style(btn, false)
	if _status_label:
		_status_label.text = "Bound \"%s\" to %s" % [action, OS.get_keycode_string(ev.physical_keycode)]

func _reset_to_defaults() -> void:
	for entry in ACTIONS:
		var action: String = entry[0]
		if not _original_events.has(action):
			continue
		InputMap.action_erase_events(action)
		for ev in _original_events[action]:
			InputMap.action_add_event(action, ev.duplicate())
		if _row_buttons.has(action):
			var btn: Button = _row_buttons[action]
			btn.text = _current_key_label(action)
			_apply_bind_button_style(btn, false)
	var cfg := ConfigFile.new()
	cfg.save(SAVE_PATH)
	if _status_label:
		_status_label.text = "Restored default keybinds"

# ── Persistence ───────────────────────────────────────────────────────────────

func _save_keybind(action: String, physical_keycode: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("keybinds", action, physical_keycode)
	cfg.save(SAVE_PATH)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _current_key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			if code != 0:
				return OS.get_keycode_string(code)
	return "—"

func _apply_bind_button_style(btn: Button, listening: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_AMBER if listening else UITheme.CLR_TAN
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(3)
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal",  sb)
	var sb_h: StyleBoxFlat = sb.duplicate()
	sb_h.bg_color = CLR_AMBER if listening else UITheme.CLR_TAN_HI
	btn.add_theme_stylebox_override("hover",   sb_h)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", UITheme.CLR_INK)
	btn.add_theme_color_override("font_hover_color", UITheme.CLR_INK)
	btn.add_theme_color_override("font_pressed_color", UITheme.CLR_INK)

func _close() -> void:
	keybinds_closed.emit()
	queue_free()
