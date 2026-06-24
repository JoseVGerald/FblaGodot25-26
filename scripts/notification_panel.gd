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

# ── Colour palette (maroon pixel-art identity) ─────────────────────────────────
const CLR_PANEL_BG   := UITheme.CLR_CREAM
const CLR_ROW_BG     := UITheme.CLR_CREAM_LT
const CLR_ROW_HOVER  := Color("#f5c89a")   # slightly darker cream for hover
const CLR_BORDER     := UITheme.CLR_INK
const CLR_GREEN      := Color("#4CAF50")
const CLR_RED        := Color("#EF5350")
const CLR_GOLD       := UITheme.CLR_GOLD
const CLR_TEXT       := UITheme.CLR_INK
const CLR_GREY_ICON  := UITheme.CLR_GRAY_DRK
const CLR_GREY_TITLE := Color(UITheme.CLR_INK.r, UITheme.CLR_INK.g, UITheme.CLR_INK.b, 0.5)
const CLR_GREY_DESC  := Color(UITheme.CLR_INK.r, UITheme.CLR_INK.g, UITheme.CLR_INK.b, 0.6)

# ── Internal state ────────────────────────────────────────────────────────────
var _list_container : VBoxContainer = null
var _counter_label  : Label = null
var _taxi_dialog    : PanelContainer = null
var _filters : Dictionary = { "warnings": true, "achievements": true, "events": true }

# ══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	layer        = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply_overlay_theme(self)
	NotificationCenter.mark_all_read()

	# On first open on Day 0, show Warnings only
	if GameState.current_day == 0 and not NotificationCenter.first_open_done:
		_filters["warnings"] = true
		_filters["achievements"] = false
		_filters["events"] = false
		NotificationCenter.first_open_done = true

	_build_ui()

# ══════════════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Full-screen dimmer
	var bg := ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right   = 1.0
	bg.anchor_bottom  = 1.0
	bg.color          = Color(0, 0, 0, 0.65)
	bg.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Main panel (match SettingsMenu shell style & structure)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1150, 800)
	panel.anchors_preset      = Control.PRESET_CENTER
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -575
	panel.offset_top    = -400
	panel.offset_right  = 575
	panel.offset_bottom = 400
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color     = CLR_PANEL_BG
	panel_sb.border_color = CLR_BORDER
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(0)
	panel_sb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", panel_sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# HEADER PANEL (cream band with centered title + close)
	var header_panel := PanelContainer.new()
	header_panel.name = "HeaderPanel"
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = UITheme.CLR_CREAM
	header_sb.border_color = UITheme.CLR_INK
	header_sb.border_width_bottom = 3
	header_sb.set_corner_radius_all(0)
	header_sb.content_margin_left = 20
	header_sb.content_margin_top = 12
	header_sb.content_margin_right = 20
	header_sb.content_margin_bottom = 12
	header_panel.add_theme_stylebox_override("panel", header_sb)

	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.add_child(header_hbox)

	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(64, 0)
	header_hbox.add_child(left_spacer)

	var title := Label.new()
	title.text = "Notifications"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font := UITheme.get_pixel_font()
	if font:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UITheme.CLR_CREAM)
	title.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
	title.add_theme_constant_override("outline_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 64)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_pixel_button_colored(close_btn, Color("#EF5350"))
	close_btn.pressed.connect(_close_panel)
	header_hbox.add_child(close_btn)

	vbox.add_child(header_panel)

	# Content frame (cream-lite area with padding)
	var content_margin := MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_margin)

	var scroll_frame := PanelContainer.new()
	scroll_frame.name = "ScrollFrame"
	scroll_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = UITheme.CLR_CREAM_LT
	frame_sb.set_border_width_all(0)
	frame_sb.set_corner_radius_all(0)
	frame_sb.content_margin_left = 20
	frame_sb.content_margin_top = 16
	frame_sb.content_margin_right = 20
	frame_sb.content_margin_bottom = 16
	scroll_frame.add_theme_stylebox_override("panel", frame_sb)
	content_margin.add_child(scroll_frame)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_frame.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	# Counter + Filters row
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	content_vbox.add_child(top_row)

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 36)
	_counter_label.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if font:
		_counter_label.add_theme_font_override("font", font)
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_counter_label)

	var filters_hbox := HBoxContainer.new()
	filters_hbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	filters_hbox.add_theme_constant_override("separation", 8)
	top_row.add_child(filters_hbox)

	# Filter toggles (Warnings / Achievements / Events)
	var warn_cb := _create_custom_checkbox(_filters["warnings"], func(v): _on_filter_toggled("warnings", v))
	filters_hbox.add_child(_wrap_toggle_with_label(warn_cb, "Warnings"))

	var ach_cb := _create_custom_checkbox(_filters["achievements"], func(v): _on_filter_toggled("achievements", v))
	filters_hbox.add_child(_wrap_toggle_with_label(ach_cb, "Achievements"))

	var ev_cb := _create_custom_checkbox(_filters["events"], func(v): _on_filter_toggled("events", v))
	filters_hbox.add_child(_wrap_toggle_with_label(ev_cb, "Events"))

	# List container (inside scroll)
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 10)
	content_vbox.add_child(_list_container)

	# FOOTER (Close + Mark All Read)
	var footer_panel := PanelContainer.new()
	footer_panel.name = "FooterPanel"
	footer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var footer_sb := StyleBoxFlat.new()
	footer_sb.bg_color = UITheme.CLR_CREAM
	footer_sb.border_color = UITheme.CLR_INK
	footer_sb.border_width_top = 3
	footer_sb.set_corner_radius_all(0)
	footer_sb.content_margin_left = 16
	footer_sb.content_margin_top = 12
	footer_sb.content_margin_right = 16
	footer_sb.content_margin_bottom = 12
	footer_panel.add_theme_stylebox_override("panel", footer_sb)

	var footer_hbox := HBoxContainer.new()
	footer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_panel.add_child(footer_hbox)

	var mark_all := Button.new()
	mark_all.text = "Mark All Read"
	mark_all.custom_minimum_size = Vector2(180, 56)
	UITheme.style_pixel_button(mark_all, true)
	mark_all.pressed.connect(func(): NotificationCenter.mark_all_read(); _fill_list())
	footer_hbox.add_child(mark_all)

	var close_btn2 := Button.new()
	close_btn2.text = "Close"
	close_btn2.custom_minimum_size = Vector2(160, 56)
	UITheme.style_pixel_button(close_btn2, false)
	close_btn2.pressed.connect(_close_panel)
	footer_hbox.add_child(close_btn2)

	vbox.add_child(footer_panel)

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

	# Apply filters and build a filtered list
	var filtered := []
	for i in range(all_notifs.size() - 1, -1, -1):
		var entry : Dictionary = all_notifs[i]
		var t = entry.get("type", NotificationCenter.NotifType.EVENT)
		if t == NotificationCenter.NotifType.WARNING and not _filters["warnings"]:
			continue
		if t == NotificationCenter.NotifType.ACHIEVEMENT and not _filters["achievements"]:
			continue
		if t == NotificationCenter.NotifType.EVENT and not _filters["events"]:
			continue
		filtered.append(entry)

	# Refresh counter text: show filtered / total
	if _counter_label:
		_counter_label.text = "%d of %d Notification%s" % [filtered.size(), all_notifs.size(), "" if all_notifs.size() == 1 else "s"]

	# Populate rows
	if filtered.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No notifications match your filters."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(CLR_TEXT.r, CLR_TEXT.g, CLR_TEXT.b, 0.4))
		empty_lbl.add_theme_font_size_override("font_size", 28)
		if font:
			empty_lbl.add_theme_font_override("font", font)
		_list_container.add_child(empty_lbl)
		return

	for entry in filtered:
		_add_row(entry, font)


## Create one notification row — same structure as achievements_popup.gd:
##   ColorRect (background)  →  sibling in VBox
##   HBoxContainer (content) →  sibling in VBox
##   ColorRect (separator)   →  sibling in VBox
func _add_row(entry: Dictionary, font: Font) -> void:
	var is_warning: bool     = (entry.type == NotificationCenter.NotifType.WARNING)
	var is_achievement: bool = (entry.type == NotificationCenter.NotifType.ACHIEVEMENT)
	var _is_event: bool      = (entry.type == NotificationCenter.NotifType.EVENT)

	# ── Row container (PanelContainer used as a padded card) ────────────
	var row_bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_ROW_BG
	sb.border_color = CLR_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	row_bg.add_theme_stylebox_override("panel", sb)
	row_bg.custom_minimum_size   = Vector2(0, 72)
	row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_list_container.add_child(row_bg)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	row_bg.add_child(row)

	# ── Hover highlighting on the panel's background ─────────────────
	row_bg.mouse_entered.connect(func():
		var s: StyleBoxFlat = row_bg.get_theme_stylebox("panel") as StyleBoxFlat
		if s: s.bg_color = CLR_ROW_HOVER
	)
	row_bg.mouse_exited.connect(func():
		var s: StyleBoxFlat = row_bg.get_theme_stylebox("panel") as StyleBoxFlat
		if s: s.bg_color = CLR_ROW_BG
	)

	# ── Determine action for this row ─────────────────────────────────────
	var action := _get_action(entry)

	# ── Click handling via gui_input on the HBox ───────────────────────────
	row_bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			match action["kind"]:
				"taxi":         _show_taxi_dialog(action["dest"])
				"achievements": _open_achievements_popup()
				"finance":      _open_finance_menu()
				_:              _close_panel()
	)

	# ── Icon tile (small colored square) ─────────────────────────────────
	var tile_color := CLR_GREY_ICON
	if is_warning:
		tile_color = CLR_RED
	elif is_achievement:
		tile_color = CLR_GOLD
	var tile := UITheme.make_icon_tile(tile_color, 52)
	var icon_lbl := Label.new()
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 34)
	if is_warning:
		icon_lbl.text = "!"
	elif is_achievement:
		icon_lbl.text = "T"
	else:
		icon_lbl.text = "-"
	if font:
		icon_lbl.add_theme_font_override("font", font)
	tile.add_child(icon_lbl)
	row.add_child(tile)

	# ── Title (notification type + day) ────────────────────────────────────
	var type_text := ""
	if is_warning:
		type_text = "Warning — Day %d" % entry.timestamp_day
	elif is_achievement:
		type_text = "Achievement — Day %d" % entry.timestamp_day
	else:
		type_text = "Event — Day %d" % entry.timestamp_day

	var name_label := Label.new()
	name_label.text = type_text
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", CLR_GREY_TITLE)
	name_label.clip_text = true
	if font:
		name_label.add_theme_font_override("font", font)
	row.add_child(name_label)

	# ── Description (right-aligned, grayed like achievements) ──────────────
	var desc_label := Label.new()
	desc_label.text = entry.message
	desc_label.add_theme_font_size_override("font_size", 28)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	desc_label.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	desc_label.add_theme_color_override("font_color", CLR_GREY_DESC)
	desc_label.clip_text = true
	if font:
		desc_label.add_theme_font_override("font", font)
	row.add_child(desc_label)

	# ── Hover: brighten text like achievements unlocked state ──────────────
	row_bg.mouse_entered.connect(func():
		name_label.add_theme_color_override("font_color", CLR_TEXT)
		desc_label.add_theme_color_override("font_color", CLR_GREEN if is_achievement else CLR_RED if is_warning else CLR_TEXT)
	)
	row_bg.mouse_exited.connect(func():
		name_label.add_theme_color_override("font_color", CLR_GREY_TITLE)
		desc_label.add_theme_color_override("font_color", CLR_GREY_DESC)
	)

	# ── Action arrow indicator (→) for clickable rows ─────────────────────
	if action["kind"] != "none":
		var arrow := Label.new()
		arrow.text = "→"
		arrow.add_theme_font_size_override("font_size", 32)
		arrow.add_theme_color_override("font_color", CLR_GOLD)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if font:
			arrow.add_theme_font_override("font", font)
		row.add_child(arrow)

	# ── Dismiss button (Red X) ────────────────────────────────────────────
	# Uses a smaller button on the far right to clear this specific entry.
	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.custom_minimum_size = Vector2(56, 56)
	x_btn.add_theme_font_size_override("font_size", 26)
	UITheme.style_close_button(x_btn)
	if font:
		x_btn.add_theme_font_override("font", font)
	row.add_child(x_btn)

	x_btn.pressed.connect(func():
		NotificationCenter.remove_notification(entry)
		_fill_list()
	)

	# (No separator ColorRect to match SettingsMenu cleaner design)
	pass

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


## Wrap a toggle button with a small label for the header filters.
func _wrap_toggle_with_label(toggle: Button, text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	var f := UITheme.get_pixel_font()
	if f:
		lbl.add_theme_font_override("font", f)

	hb.add_child(lbl)
	hb.add_child(toggle)
	return hb


func _create_custom_checkbox(initial_on: bool, on_toggled: Callable) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial_on
	btn.custom_minimum_size = Vector2(30, 30)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""
	
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

	var center_container = CenterContainer.new()
	center_container.name = "Center"
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center_container)

	var thumb_rect := ColorRect.new()
	thumb_rect.name = "Thumb"
	thumb_rect.custom_minimum_size = Vector2(16, 16)
	thumb_rect.size = Vector2(16, 16)
	thumb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_rect.color = UITheme.CLR_MAROON_D
	thumb_rect.visible = initial_on
	center_container.add_child(thumb_rect)
	
	btn.toggled.connect(func(on: bool):
		thumb_rect.visible = on
		on_toggled.call(on)
	)
	return btn


func _on_filter_toggled(key: String, val: bool) -> void:
	_filters[key] = val
	_fill_list()


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
	dialog_sb.bg_color     = CLR_PANEL_BG
	dialog_sb.border_color = CLR_GOLD
	dialog_sb.set_border_width_all(4)
	dialog_sb.set_corner_radius_all(0)
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
	question_lbl.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if font:
		question_lbl.add_theme_font_override("font", font)
	vbox.add_child(question_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "This will cost $%d" % GameState.taxi_cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 30)
	cost_lbl.add_theme_color_override("font_color", CLR_TEXT)
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
	UITheme.style_pixel_button(yes_btn)
	if font:
		yes_btn.add_theme_font_override("font", font)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(120, 60)
	no_btn.add_theme_font_size_override("font_size", 28)
	UITheme.style_pixel_button(no_btn, true)
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
