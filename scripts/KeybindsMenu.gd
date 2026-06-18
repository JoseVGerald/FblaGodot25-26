# KeybindsMenu.gd
# Overlay that lets the player rebind every gameplay InputMap action and
# persists changes to user://keybinds.cfg. Defaults are captured on first
# load so "Reset to Defaults" can restore project.godot's original binds.
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

# Design tokens — maroon brand palette (sibling of needs_menu: ink-on-cream).
const CLR_BG_CARD    := UITheme.CLR_CREAM_LT    # row background (light card)
const CLR_BORDER_SKY := UITheme.CLR_ORANGE_PX   # row accent stripe
const CLR_BORDER_DIM := UITheme.CLR_INK         # keycap button border
const CLR_CYAN       := UITheme.CLR_MAROON_D     # status confirmations
const CLR_WHITE      := UITheme.CLR_INK          # row label + keycap text
const CLR_DIM        := Color(UITheme.CLR_INK.r, UITheme.CLR_INK.g, UITheme.CLR_INK.b, 0.7)
const CLR_AMBER      := UITheme.CLR_ORANGE_PX    # reset btn + listening highlight

# Default events captured once before any saved override is applied. Used by
# "Reset to Defaults" and to know what to fall back to when a saved bind
# references a missing action.
static var _original_events: Dictionary = {}

var _row_buttons: Dictionary = {}     # action_name → Button (the bind button)
var _rebinding_action: String = ""    # non-empty = waiting for next key press
var _status_label: Label = null

@onready var vbox: VBoxContainer = $Panel/VBox

# ── Static API ────────────────────────────────────────────────────────────────

## Capture the project.godot defaults the first time we run, then apply any
## saved overrides on top. Safe to call more than once.
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
		UITheme.style_panel(panel)

	_build_layout()

func _input(event: InputEvent) -> void:
	# Rebinding mode swallows the next key press and assigns it. ESC cancels.
	if _rebinding_action != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
		else:
			_apply_rebind(_rebinding_action, event)
		return

	# Outside rebinding mode, ESC closes the overlay.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

# ── Layout ────────────────────────────────────────────────────────────────────

func _build_layout() -> void:
	# Header: title + ✕ close button.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "Keybinds"
	title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	title.add_theme_font_size_override("font_size", 48)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pf := UITheme.get_pixel_font()
	if pf: title.add_theme_font_override("font", pf)
	header.add_child(title)

	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.custom_minimum_size = Vector2(44, 44)
	x_btn.focus_mode = Control.FOCUS_NONE
	UITheme.style_close_button(x_btn)
	x_btn.pressed.connect(_close)
	header.add_child(x_btn)
	vbox.add_child(header)

	# Hint line.
	var hint := Label.new()
	hint.text = "Click a key to rebind. ESC cancels."
	hint.add_theme_color_override("font_color", CLR_DIM)
	hint.add_theme_font_size_override("font_size", 18)
	vbox.add_child(hint)

	# Scrollable list of action rows.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	vbox.add_child(scroll)

	for entry in ACTIONS:
		list.add_child(_build_action_row(entry[0], entry[1]))

	# Status line for "press a key" prompts and confirmations.
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", CLR_CYAN)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pf: _status_label.add_theme_font_override("font", pf)
	vbox.add_child(_status_label)

	# Footer buttons.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.custom_minimum_size = Vector2(220, 56)
	reset_btn.add_theme_font_size_override("font_size", 24)
	if pf: reset_btn.add_theme_font_override("font", pf)
	UITheme.style_pixel_button_colored(reset_btn, CLR_AMBER)
	reset_btn.pressed.connect(_reset_to_defaults)
	footer.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(180, 56)
	close_btn.add_theme_font_size_override("font_size", 24)
	if pf: close_btn.add_theme_font_override("font", pf)
	UITheme.style_close_button(close_btn)
	close_btn.pressed.connect(_close)
	footer.add_child(close_btn)

	vbox.add_child(footer)

func _build_action_row(action: String, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 56)
	row.add_theme_constant_override("separation", 12)

	var bg := ColorRect.new()
	bg.color = CLR_BG_CARD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	row.move_child(bg, 0)

	var stripe := ColorRect.new()
	stripe.color = CLR_BORDER_SKY
	stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 4
	stripe.show_behind_parent = true
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	row.move_child(stripe, 1)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_color_override("font_color", CLR_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pf := UITheme.get_pixel_font()
	if pf: name_lbl.add_theme_font_override("font", pf)
	row.add_child(name_lbl)

	var bind_btn := Button.new()
	bind_btn.text = _current_key_label(action)
	bind_btn.custom_minimum_size = Vector2(180, 44)
	bind_btn.add_theme_font_size_override("font_size", 22)
	if pf: bind_btn.add_theme_font_override("font", pf)
	_apply_bind_button_style(bind_btn, false)
	bind_btn.pressed.connect(_begin_rebind.bind(action))
	row.add_child(bind_btn)
	_row_buttons[action] = bind_btn

	return row

# ── Rebind flow ───────────────────────────────────────────────────────────────

func _begin_rebind(action: String) -> void:
	if _rebinding_action != "":
		# Cancel any in-progress rebind on the previous row first.
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
	# Build a clean InputEventKey using physical_keycode so layout differences
	# (AZERTY vs QWERTY etc.) keep working.
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
	# Clear the saved overrides file so a fresh launch also gets defaults.
	var cfg := ConfigFile.new()
	cfg.save(SAVE_PATH)
	if _status_label:
		_status_label.text = "Restored default keybinds"

# ── Persistence ───────────────────────────────────────────────────────────────

func _save_keybind(action: String, physical_keycode: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # ignore failure; treats missing file as empty
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
	# Tan "keycap" look; glows orange while waiting for the next key press.
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_AMBER if listening else UITheme.CLR_TAN
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(3)
	sb.border_width_bottom = 5                            # subtle 3-D keycap base
	sb.set_corner_radius_all(0)                           # crisp pixel edges
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
