# achievements_popup.gd
# Achievements Panel — shows all achievements, descriptions, and unlock status.
# Redesigned to match the game's sky-blue / green pixel-art identity.
#
# Fully opaque navy-blue panel — no world / pause-menu bleed-through.
# layer = 11 so it renders above PauseMenu (layer 10).
extends CanvasLayer

const ACHIEVEMENT_DESCRIPTIONS := {
	# Pet Care
	"Penny Pincher"        : "Save $200 in your emergency fund",
	"Master Chef"          : "Feed your dog 10 times",
	"Hydration Hero"       : "Give your dog water 10 times",
	"Dr. Doolittle"        : "Administer medication 5 times",
	"Clean Bill of Health" : "Bring your dog's health to 100",
	"Vet Regular"          : "Visit the vet 3 times",
	"On the Mend"          : "Nurse your dog from critical (<30) to healthy (>60)",
	# Economy
	"Rainy Day Fund"       : "Save $500 in your emergency fund",
	"Big Spender"          : "Spend $300 in total",
	"Taxi Tycoon"          : "Take 10 taxi rides",
	"First Paycheck"       : "Receive your first weekly allowance",
	"Shopaholic"           : "Visit the store 5 times",
	"Tightwad"             : "Finish a week spending $30 or less",
	# Catch Minigame
	"Catch Pro"            : "Earn $40 in a single catch round",
	"Catch Master"         : "Earn $200 total from the catch minigame",
	"First Fetch"          : "Complete your first catch minigame",
	"Into the Frenzy"      : "Survive to FRENZY MODE",
	"Ball Machine"         : "Catch 15 balls in a single session",
	"Daily Exercise"       : "Play the catch minigame on 5 different days",
	# Day / Time
	"Golden Years"         : "Reach Day 30",
	"Survivor"             : "Reach Day 7",
	"Dedicated"            : "Reach Day 14",
	"Graduated"            : "Complete the Day 1 tutorial",
	# Character Customization
	"Dressed to the Nines" : "Start a game with all 5 character layers equipped",
	"Hat Collector"        : "Equip 4 different hat-type accessories",
	"Identity Crisis"      : "Completely change your look 2 times",
	# Social / Exploration
	"Neighborhood Friend"  : "Talk to 5 different NPCs",
	"World Explorer"       : "Visit all 4 destinations by taxi",
	# Bonus
	"Nap Champion"         : "Let your dog sleep 5 times",
	"Week One Down"        : "Complete all Day 1 tutorial actions",
}

# ── Colour palette — cream/maroon identity matching SettingsMenu ─────────────
const CLR_PANEL_BG   := UITheme.CLR_CREAM
const CLR_ROW_UNLOCK := UITheme.CLR_CREAM_LT
const CLR_ROW_LOCK   := Color("#e8c497")      # slightly darker cream for locked rows
const CLR_BORDER     := UITheme.CLR_INK
const CLR_TITLE      := UITheme.CLR_MAROON_D
const CLR_COUNTER    := UITheme.CLR_MAROON_D
const CLR_SEPARATOR  := UITheme.CLR_INK
const CLR_GREEN      := Color("#4CAF50")
const CLR_GOLD       := Color("#FFD700")
const CLR_RED        := Color("#EF5350")
const CLR_WHITE      := UITheme.CLR_INK
const CLR_GREY_ICON  := UITheme.CLR_GRAY_DRK
const CLR_GREY_TITLE := Color("#8a786899")   # CLR_GRAY_DRK at 60% alpha
const CLR_GREY_DESC  := UITheme.CLR_GRAY_DRK

var was_paused     : bool         = false
var list_container : VBoxContainer = null

func _ready() -> void:
	layer        = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	was_paused        = get_tree().paused
	get_tree().paused = true
	UITheme.apply_overlay_theme(self)
	_build_ui()
	if not GameState.achievement_unlocked.is_connected(_on_achievement_unlocked):
		GameState.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(_name: String) -> void:
	if list_container:
		for child in list_container.get_children():
			child.queue_free()
		_fill_list(list_container)

func _build_ui() -> void:
	# Full-screen dimmer
	var bg := ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right   = 1.0
	bg.anchor_bottom  = 1.0
	bg.color          = Color(0, 0, 0, 0.65)
	bg.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Main panel
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
	panel.modulate.a      = 1.0

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color     = CLR_PANEL_BG
	panel_sb.border_color = CLR_BORDER
	panel_sb.set_border_width_all(4)
	panel_sb.set_corner_radius_all(0)
	panel_sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0) # zero separation between major panels
	panel.add_child(vbox)

	# HEADER PANEL (match SettingsMenu shell style & structure)
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
	title.text = "Achievements"
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
	close_btn.pressed.connect(_close_popup)
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

	var content_vbox := VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll_frame.add_child(content_vbox)

	# Counter
	var unlocked_count := GameState.achievements.values().filter(func(v): return v).size()
	var total_count    := GameState.achievements.size()
	var counter        := Label.new()
	counter.text = "%d / %d Achievements Unlocked" % [unlocked_count, total_count]
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 32)
	counter.add_theme_color_override("font_color", CLR_COUNTER)
	if font:
		counter.add_theme_font_override("font", font)
	content_vbox.add_child(counter)

	# Scroll list
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_vbox.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 12) # spacing between card rows
	scroll.add_child(list_container)
	_fill_list(list_container)

	# FOOTER PANEL
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
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_panel.add_child(footer_hbox)

	var footer_close := Button.new()
	footer_close.text = "Close"
	footer_close.custom_minimum_size = Vector2(180, 56)
	UITheme.style_pixel_button(footer_close, false)
	footer_close.pressed.connect(_close_popup)
	footer_hbox.add_child(footer_close)

	vbox.add_child(footer_panel)

func _fill_list(list: VBoxContainer) -> void:
	var font := UITheme.get_pixel_font()
	for achievement_name in GameState.achievements.keys():
		var is_unlocked : bool   = GameState.achievements[achievement_name]
		var description : String = ACHIEVEMENT_DESCRIPTIONS.get(achievement_name, "")

		# Row wrapper — styled as a clear bordered card
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_sb := StyleBoxFlat.new()
		row_sb.bg_color = CLR_ROW_UNLOCK if is_unlocked else CLR_ROW_LOCK
		row_sb.border_color = CLR_BORDER
		row_sb.set_border_width_all(3) # Nice thick ink borders
		row_sb.set_corner_radius_all(0)
		row_sb.set_content_margin_all(14)
		row_panel.add_theme_stylebox_override("panel", row_sb)
		list.add_child(row_panel)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size   = Vector2(0, 56)
		row.add_theme_constant_override("separation", 18)
		row_panel.add_child(row)

		# Icon
		var icon := Label.new()
		if is_unlocked:
			icon.text = "T"
			icon.add_theme_color_override("font_color", CLR_GOLD)
		else:
			icon.text = "L"
			icon.add_theme_color_override("font_color", CLR_GREY_ICON)
		icon.add_theme_font_size_override("font_size", 40)
		icon.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
		icon.custom_minimum_size.x = 54
		if font:
			icon.add_theme_font_override("font", font)
		row.add_child(icon)

		# Name
		var name_label := Label.new()
		name_label.text = achievement_name
		name_label.add_theme_font_size_override("font_size", 34)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_stretch_ratio = 1.0 # 40% width ratio
		name_label.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", CLR_WHITE if is_unlocked else CLR_GREY_TITLE)
		if font:
			name_label.add_theme_font_override("font", font)
		row.add_child(name_label)

		# Description
		var desc_label := Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 26)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.size_flags_stretch_ratio = 1.5 # 60% width ratio
		desc_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
		desc_label.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
		desc_label.add_theme_color_override("font_color", CLR_GREEN if is_unlocked else CLR_GREY_DESC)
		if font:
			desc_label.add_theme_font_override("font", font)
		row.add_child(desc_label)

		# (No separator ColorRect to match clean bordered card spacing)
		pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()

func _close_popup() -> void:
	get_tree().paused = was_paused
	queue_free()

# Updated on 2026-04-19
