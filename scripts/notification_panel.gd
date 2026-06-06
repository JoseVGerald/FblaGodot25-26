# notification_panel.gd
# Full-screen overlay panel showing all stored notifications.
# Layer 12 — above AchievementsPopup (layer 11) and PauseMenu (layer 10).
#
# Row types:
#   EVENT       — highlighted on hover; no click action
#   ACHIEVEMENT — click opens the achievements popup
#   WARNING     — click shows taxi dialog if a known destination is implied
#
# Layout matches achievements_popup.gd: ColorRect bg + sibling HBoxContainer rows.

extends CanvasLayer

# ── Colour palette (matches game-wide identity) ────────────────────────────
const CLR_NAVY       := Color("#1a2a4a")
const CLR_NAVY_LIGHT := Color("#1e3a6e")
const CLR_NAVY_DEEP  := Color("#0d1b36")
const CLR_SKY        := Color("#4A90D9")
const CLR_CYAN       := Color("#53d8fb")
const CLR_GREEN      := Color("#4CAF50")
const CLR_RED        := Color("#EF5350")
const CLR_GOLD       := Color("#FFD700")
const CLR_WHITE      := Color.WHITE
const CLR_GREY_ICON  := Color("#666688")
const CLR_GREY_TITLE := Color(0.6, 0.6, 0.6, 0.5)
const CLR_GREY_DESC  := Color(0.38, 0.38, 0.38)

# ── Internal state ────────────────────────────────────────────────────────────
var _list_container : VBoxContainer = null
var _counter_label  : Label = null
var _taxi_dialog    : PanelContainer = null

# ══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	layer        = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply_overlay_theme(self)
	NotificationCenter.mark_all_read()
	_build_ui()

# ══════════════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var map = load("res://New Ui/FINAL NOTIFICATIONS/Map.tscn").instantiate()
	map.scale = Vector2(7.5, 7.5)
	var bg = Node2D.new()
	bg.name = "Backdrop"
	bg.add_child(map)
	root.add_child(bg)

	var panel := MarginContainer.new()
	panel.custom_minimum_size = Vector2(960, 680)
	panel.anchors_preset      = Control.PRESET_CENTER
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -480
	panel.offset_top    = -340
	panel.offset_right  = 480
	panel.offset_bottom = 340
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Notifications"
	title.add_theme_font_size_override("font_size", 58)
	title.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UITheme.CLR_CREAM)
	var font := UITheme.get_pixel_font()
	if font:
		title.add_theme_font_override("font", font)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(80, 80)
	close_btn.add_theme_font_size_override("font_size", 42)
	close_btn.pressed.connect(_close_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#ef5350")
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	close_btn.add_theme_stylebox_override("normal", sb)
	close_btn.add_theme_stylebox_override("hover", sb)
	close_btn.add_theme_stylebox_override("pressed", sb)
	UITheme._do_juice_on(close_btn)
	header.add_child(close_btn)

	_counter_label = Label.new()
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 32)
	_counter_label.add_theme_color_override("font_color", UITheme.CLR_GOLD)
	if font:
		_counter_label.add_theme_font_override("font", font)
	vbox.add_child(_counter_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 24)
	scroll.add_child(_list_container)

	_fill_list()

# ══════════════════════════════════════════════════════════════════════════════
#  LIST POPULATION — matches achievements_popup.gd layout pattern exactly
# ══════════════════════════════════════════════════════════════════════════════

func _fill_list() -> void:
	if not _list_container: return
	for child in _list_container.get_children():
		child.queue_free()

	var font := UITheme.get_pixel_font()
	var all_notifs: Array = NotificationCenter.notifications

	# Refresh counter text
	if _counter_label:
		_counter_label.text = "%d Notification%s" % [all_notifs.size(), "" if all_notifs.size() == 1 else "s"]

	# Iterate in reverse so newest entries appear at the top
	for i in range(all_notifs.size() - 1, -1, -1):
		var entry : Dictionary = all_notifs[i]
		_add_row(entry, font)

	# Show placeholder when empty
	if all_notifs.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No notifications yet."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(CLR_WHITE, 0.4))
		empty_lbl.add_theme_font_size_override("font_size", 32)
		if font:
			empty_lbl.add_theme_font_override("font", font)
		_list_container.add_child(empty_lbl)


## Create one notification row — same structure as achievements_popup.gd:
##   ColorRect (background)  →  sibling in VBox
##   HBoxContainer (content) →  sibling in VBox
##   ColorRect (separator)   →  sibling in VBox
func _add_row(entry: Dictionary, font: Font) -> void:
	var is_warning: bool     = (entry.type == NotificationCenter.NotifType.WARNING)
	var is_achievement: bool = (entry.type == NotificationCenter.NotifType.ACHIEVEMENT)
	var _is_event: bool      = (entry.type == NotificationCenter.NotifType.EVENT)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_list_container.add_child(row)

	var action := _get_action(entry)

	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			match action["kind"]:
				"taxi":         _show_taxi_dialog(action["dest"])
				"achievements": _open_achievements_popup()
				"finance":      _open_finance_menu()
				_:              _close_panel()
	)

	var icon := Label.new()
	if is_warning:
		icon.text = "!"
		icon.add_theme_color_override("font_color", Color("#ef5350"))
	elif is_achievement:
		icon.text = "★"
		icon.add_theme_color_override("font_color", Color("#ffd071"))
	else:
		icon.text = "•"
		icon.add_theme_color_override("font_color", Color("#8a7868"))
	icon.add_theme_font_size_override("font_size", 40)
	icon.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size.x = 54
	if font:
		icon.add_theme_font_override("font", font)
	row.add_child(icon)
	
	var texts_vbox = VBoxContainer.new()
	texts_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts_vbox)

	var type_text := ""
	if is_warning:
		type_text = "Warning — Day %d" % entry.timestamp_day
	elif is_achievement:
		type_text = "Achievement — Day %d" % entry.timestamp_day
	else:
		type_text = "Event — Day %d" % entry.timestamp_day

	var name_label := Label.new()
	name_label.text = type_text
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", UITheme.CLR_INK)
	if font:
		name_label.add_theme_font_override("font", font)
	texts_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = entry.message
	desc_label.add_theme_font_size_override("font_size", 24)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if font:
		desc_label.add_theme_font_override("font", font)
	texts_vbox.add_child(desc_label)

	if action["kind"] != "none":
		var arrow := Label.new()
		arrow.text = "→"
		arrow.add_theme_font_size_override("font_size", 32)
		arrow.add_theme_color_override("font_color", UITheme.CLR_GOLD)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if font:
			arrow.add_theme_font_override("font", font)
		row.add_child(arrow)

	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.custom_minimum_size = Vector2(48, 48)
	x_btn.add_theme_font_size_override("font_size", 24)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#ef5350")
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	x_btn.add_theme_stylebox_override("normal", sb)
	x_btn.add_theme_stylebox_override("hover", sb)
	x_btn.add_theme_stylebox_override("pressed", sb)
	
	UITheme._do_juice_on(x_btn)
	x_btn.name = "Dismiss"
	if font:
		x_btn.add_theme_font_override("font", font)
	row.add_child(x_btn)

	x_btn.pressed.connect(func():
		NotificationCenter.remove_notification(entry)
		row.queue_free()
		var count = NotificationCenter.notifications.size()
		if _counter_label:
			_counter_label.text = "%d Notification%s" % [count, "" if count == 1 else "s"]
	)

func _get_action(entry: Dictionary) -> Dictionary:
	var msg: String = entry.get("message", "").to_lower()
	var t = entry.get("type", NotificationCenter.NotifType.EVENT)

	if t == NotificationCenter.NotifType.ACHIEVEMENT:
		return { "kind": "achievements", "dest": "" }

	if msg.contains("budget") or msg.contains("savings") or msg.contains("emergency fund") \
	   or msg.contains("spent") or msg.contains("finance") or msg.contains("allowance") \
	   or msg.contains("inflation") or msg.contains("tax") or msg.contains("earned"):
		return { "kind": "finance", "dest": "" }

	if msg.contains("food") or msg.contains("hungry") or msg.contains("starv") \
	   or msg.contains("water") or msg.contains("thirst") or msg.contains("dehydrat") \
	   or msg.contains("supply") or msg.contains("store"):
		return { "kind": "taxi", "dest": "Store" }

	if msg.contains("health") or msg.contains("sick") or msg.contains("vet") \
	   or msg.contains("medic") or msg.contains("prescri") or msg.contains("critical"):
		return { "kind": "taxi", "dest": "Vet" }

	return { "kind": "none", "dest": "" }


func _open_achievements_popup() -> void:
	_close_panel()
	var popup_script := load("res://scripts/achievements_popup.gd")
	if popup_script:
		var popup := CanvasLayer.new()
		popup.set_script(popup_script)
		get_tree().root.add_child(popup)


func _is_finance_notification(entry: Dictionary) -> bool:
	var msg = entry.message.to_lower()
	var finance_keywords = [
		"budget", "money", "allowance", "inflation", "tax", 
		"emergency fund", "spent", "earned", "cost", "transaction"
	]
	for kw in finance_keywords:
		if kw in msg:
			return true
	return false

func _open_finance_menu() -> void:
	_close_panel()
	
	var finance_scene = load("res://scenes/ui/FinanceMenu.tscn")
	if finance_scene:
		get_tree().paused = true
		var menu = finance_scene.instantiate()
		get_tree().root.add_child(menu)
		menu.show_menu()
		
		# Ensure we unpause when the menu is closed
		if menu.has_signal("menu_closed"):
			menu.menu_closed.connect(func():
				get_tree().paused = false
				menu.queue_free()
			)

# ══════════════════════════════════════════════════════════════════════════════
#  TAXI CONFIRM DIALOG
# ══════════════════════════════════════════════════════════════════════════════

func _show_taxi_dialog(dest: String) -> void:
	if _taxi_dialog and is_instance_valid(_taxi_dialog):
		return

	_taxi_dialog = PanelContainer.new()
	_taxi_dialog.custom_minimum_size = Vector2(500, 220)
	_taxi_dialog.anchors_preset      = Control.PRESET_CENTER
	_taxi_dialog.anchor_left   = 0.5
	_taxi_dialog.anchor_top    = 0.5
	_taxi_dialog.anchor_right  = 0.5
	_taxi_dialog.anchor_bottom = 0.5
	_taxi_dialog.offset_left   = -250
	_taxi_dialog.offset_top    = -110
	_taxi_dialog.offset_right  = 250
	_taxi_dialog.offset_bottom = 110
	_taxi_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_taxi_dialog.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var dialog_sb := StyleBoxFlat.new()
	dialog_sb.bg_color     = CLR_NAVY
	dialog_sb.border_color = CLR_GOLD
	dialog_sb.set_border_width_all(2)
	dialog_sb.set_corner_radius_all(8)
	dialog_sb.set_content_margin_all(20)
	_taxi_dialog.add_theme_stylebox_override("panel", dialog_sb)
	add_child(_taxi_dialog)

	var font := UITheme.get_pixel_font()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_taxi_dialog.add_child(vbox)

	var question_lbl := Label.new()
	question_lbl.text = "Take a Taxi?"
	question_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_lbl.add_theme_font_size_override("font_size", 40)
	question_lbl.add_theme_color_override("font_color", CLR_GOLD)
	if font:
		question_lbl.add_theme_font_override("font", font)
	vbox.add_child(question_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "This will cost $%d" % GameState.taxi_cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 30)
	cost_lbl.add_theme_color_override("font_color", CLR_WHITE)
	if font:
		cost_lbl.add_theme_font_override("font", font)
	vbox.add_child(cost_lbl)

	var broke_lbl := Label.new()
	broke_lbl.text = "Not enough money!"
	broke_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	broke_lbl.add_theme_font_size_override("font_size", 26)
	broke_lbl.add_theme_color_override("font_color", CLR_RED)
	if font:
		broke_lbl.add_theme_font_override("font", font)
	broke_lbl.visible = false
	vbox.add_child(broke_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes — $%d" % GameState.taxi_cost
	yes_btn.custom_minimum_size = Vector2(200, 60)
	yes_btn.add_theme_font_size_override("font_size", 28)
	UITheme.style_button(yes_btn, CLR_GREEN)
	if font:
		yes_btn.add_theme_font_override("font", font)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(120, 60)
	no_btn.add_theme_font_size_override("font_size", 28)
	UITheme.style_button(no_btn, CLR_RED)
	if font:
		no_btn.add_theme_font_override("font", font)
	btn_row.add_child(no_btn)

	no_btn.pressed.connect(func():
		if _taxi_dialog and is_instance_valid(_taxi_dialog):
			_taxi_dialog.queue_free()
			_taxi_dialog = null
		queue_free()
	)

	yes_btn.pressed.connect(func():
		# If the player is hailing a taxi to the Vet straight from a
		# notification warning, release any lingering tutorial movement block
		# so they can walk around as soon as the fade completes.
		if dest == "Vet":
			GameState.tutorial_blocks_movement = false

		# Cost and transaction log are handled inside taxi_menu.gd's _travel_to().
		# We just need to trigger it correctly via the HUD's helper method.
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("_travel_via_taxi"):
			hud._travel_via_taxi(dest)
		else:
			# Fallback if HUD group isn't found (e.g. durante tutorial)
			for child in get_tree().root.get_children():
				if child.has_method("_travel_to"):
					child._travel_to(dest)
					break

		if _taxi_dialog and is_instance_valid(_taxi_dialog):
			_taxi_dialog.queue_free()
			_taxi_dialog = null
		_close_panel()
	)

# ══════════════════════════════════════════════════════════════════════════════
#  CLOSE
# ══════════════════════════════════════════════════════════════════════════════

func _close_panel() -> void:
	if _taxi_dialog and is_instance_valid(_taxi_dialog):
		_taxi_dialog.queue_free()
		_taxi_dialog = null
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_panel()
		get_viewport().set_input_as_handled()

# Updated on 2026-04-19
