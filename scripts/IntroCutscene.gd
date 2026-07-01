# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var label = $VBoxContainer/Label
@onready var continue_button = $VBoxContainer/ContinueButton
@onready var technical_panel = $TechnicalPanel
@onready var slides_container = $VBoxContainer

var slides = [
	"Some dogs don't start life feeling safe.",
	"This one didn't either.",
	"You've adopted a dog who's been through more than they can show.",
	"They're not broken. Just unsure who to trust.",
	"Through daily care, play, and time together, you'll help them heal.",
	"Welcome to your little buddy."
]

var current_slide = 0
var typing_speed = 0.05
var is_typing = false
var technical_slide_index = 6

const ARROW_CLOSED = "▶   "
const ARROW_OPEN   = "▼   "
const SECTION_LABELS = [
	"Stats & Interactions",
	"Care Costs & Budget",
	"Pet Emotions & Growth",
	"Customization & Programming Learning",
]
const SECTION_ICONS = ["", "", "", ""]
var open_section: int = -1

func _ready():
	UITheme.apply_theme(self)
	UITheme.style_checker_label(label, 12)
	label.add_theme_font_size_override("font_size", 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	technical_panel.hide()
	continue_button.hide()
	show_slide(0)

func _input(event):
	var is_enter = event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
	var is_mouse = event is InputEventMouseButton and event.pressed
	
	if is_enter or is_mouse:
		if current_slide < technical_slide_index:
			if is_typing:
				finish_typing()
			else:
				next_slide()
		elif current_slide == technical_slide_index:
			if is_enter:
				_on_continue_button_pressed()

	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSLASH:
		_skip_tutorial()

func _skip_tutorial():
	GameState.reset_all()
	GameState.player_name = "Player"
	GameState.pet_name = "Buddy"
	GameState.is_tutorial_complete = true
	GameState.is_day_one = false
	GameState.save_character_components(1, 1, 1, 1, 1)
	SceneManager.change_scene("res://scenes/ui/MainGame.tscn", {"pattern": "curtains"})

func show_slide(index):
	if index < slides.size():
		current_slide = index
		label.text = ""
		start_typing(slides[index])
	elif index == technical_slide_index:
		current_slide = index
		slides_container.hide()
		technical_panel.show()

		# Clamp panel to viewport
		var vp := get_viewport().get_visible_rect().size
		var pw := minf(1600.0, vp.x - 80.0)
		var ph := minf(1100.0, vp.y - 80.0)
		technical_panel.offset_left   = -pw * 0.5
		technical_panel.offset_right  =  pw * 0.5
		technical_panel.offset_top    = -ph * 0.5
		technical_panel.offset_bottom =  ph * 0.5

		_setup_overview_panel()

		if continue_button.get_parent() != technical_panel.get_node("OuterMargin/VBoxContainer"):
			var parent = continue_button.get_parent()
			parent.remove_child(continue_button)
			technical_panel.get_node("OuterMargin/VBoxContainer").add_child(continue_button)

		# Style the continue button to fill width properly
		continue_button.custom_minimum_size = Vector2(0, 80)
		continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		continue_button.add_theme_font_size_override("font_size", 40)
		continue_button.show()

func start_typing(text):
	is_typing = true
	label.text = ""
	for c in text:
		if not is_typing: break
		label.text += c
		await get_tree().create_timer(typing_speed).timeout
	is_typing = false

func finish_typing():
	is_typing = false
	label.text = slides[current_slide]

func next_slide():
	if current_slide < technical_slide_index:
		show_slide(current_slide + 1)

func _on_continue_button_pressed():
	SceneManager.change_scene("res://scenes/ui/CharacterCustomize.tscn", {"pattern": "curtains"})

func _setup_overview_panel() -> void:
	var vbox = technical_panel.get_node("OuterMargin/VBoxContainer")

	# Style the TechnicalPanel margin values dynamically via its StyleBox
	var sb = technical_panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var new_sb = sb.duplicate() as StyleBoxFlat
		new_sb.content_margin_top = 48
		new_sb.content_margin_bottom = 24
		new_sb.content_margin_left = 48
		new_sb.content_margin_right = 48
		technical_panel.add_theme_stylebox_override("panel", new_sb)

	# Redesign Title area to feel like a premium plaque/banner
	var title: Label = vbox.get_node("Title")
	var title_parent = title.get_parent()
	if title_parent.name != "TitlePlaque":
		var plaque := PanelContainer.new()
		plaque.name = "TitlePlaque"
		
		var plaque_sb := StyleBoxFlat.new()
		plaque_sb.bg_color = UITheme.CLR_CREAM
		plaque_sb.border_color = UITheme.CLR_INK
		plaque_sb.border_width_left = 5
		plaque_sb.border_width_top = 5
		plaque_sb.border_width_right = 5
		plaque_sb.border_width_bottom = 10 # 3D Depth
		plaque_sb.content_margin_left = 40
		plaque_sb.content_margin_right = 40
		plaque_sb.content_margin_top = 12
		plaque_sb.content_margin_bottom = 12
		plaque_sb.anti_aliasing = false
		plaque_sb.set_corner_radius_all(0)
		plaque.add_theme_stylebox_override("panel", plaque_sb)
		
		plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		var title_idx = title.get_index()
		vbox.remove_child(title)
		plaque.add_child(title)
		vbox.add_child(plaque)
		vbox.move_child(plaque, title_idx)

	title.add_theme_font_override("font", UITheme.get_pixel_font())
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
	title.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
	title.add_theme_constant_override("outline_size", 18) # thick visual boundary
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

	# Style the subtitle Overview label
	var overview: Label = vbox.get_node("Overview")
	overview.add_theme_font_size_override("font_size", 28)
	overview.add_theme_color_override("font_color", UITheme.CLR_INK)
	overview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overview.add_theme_constant_override("line_spacing", 8)
	overview.add_theme_constant_override("shadow_offset_x", 0)
	overview.add_theme_constant_override("shadow_offset_y", 0)
	overview.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	overview.remove_theme_font_override("font")
	var bold_font := SystemFont.new()
	bold_font.font_weight = 700
	overview.add_theme_font_override("font", bold_font)

	# Style and insert a premium decorative visual separator
	var divider = vbox.get_node("Divider")
	if divider and not divider.has_meta("custom_divider"):
		var divider_idx = divider.get_index()
		vbox.remove_child(divider)
		divider.queue_free()
		
		var container := HBoxContainer.new()
		container.name = "Divider"
		container.set_meta("custom_divider", true)
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var left_line := ColorRect.new()
		left_line.color = UITheme.CLR_INK
		left_line.custom_minimum_size = Vector2(150, 5)
		left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var center_lbl := Label.new()
		center_lbl.text = " 🐾 ✦ 🐾 "
		center_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
		center_lbl.add_theme_font_size_override("font_size", 28)
		center_lbl.add_theme_color_override("font_color", UITheme.CLR_INK)
		
		var right_line := ColorRect.new()
		right_line.color = UITheme.CLR_INK
		right_line.custom_minimum_size = Vector2(150, 5)
		right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		container.add_child(left_line)
		container.add_child(center_lbl)
		container.add_child(right_line)
		
		var top_spacer := Control.new()
		top_spacer.custom_minimum_size = Vector2(0, 28)
		
		var bottom_spacer := Control.new()
		bottom_spacer.custom_minimum_size = Vector2(0, 28)
		
		vbox.add_child(top_spacer)
		vbox.move_child(top_spacer, divider_idx)
		
		vbox.add_child(container)
		vbox.move_child(container, divider_idx + 1)
		
		vbox.add_child(bottom_spacer)
		vbox.move_child(bottom_spacer, divider_idx + 2)

	# Minimize BottomSpacer height
	var bottom_spacer_node = vbox.get_node_or_null("BottomSpacer")
	if bottom_spacer_node:
		bottom_spacer_node.custom_minimum_size = Vector2(0, 0)

	open_section = -1

	for i in range(1, 5):
		var section = vbox.get_node("Section%d" % i)
		var header: Button = section.get_node("Header")
		var content: Label = section.get_node("Content")

		# Disconnect old generic signal if wired
		if header.pressed.is_connected(_on_toggle_pressed):
			header.pressed.disconnect(_on_toggle_pressed)

		var idx = i - 1
		if not header.pressed.is_connected(_on_section_header_pressed.bind(idx)):
			header.pressed.connect(_on_section_header_pressed.bind(idx))

		content.visible = false
		header.text = SECTION_ICONS[idx] + "  " + ARROW_CLOSED + SECTION_LABELS[idx]
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Reuse standard UITheme pixel button style
		UITheme.style_pixel_button(header, false)
		header.add_theme_font_size_override("font_size", 32)
		header.custom_minimum_size = Vector2(0, 60)
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Content label styling — no shadow, readable size
		content.add_theme_font_size_override("font_size", 32)
		content.add_theme_color_override("font_color", UITheme.CLR_INK)
		content.add_theme_constant_override("shadow_offset_x", 0)
		content.add_theme_constant_override("shadow_offset_y", 0)
		content.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		content.remove_theme_font_override("font")
		content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_theme_constant_override("margin_left", 28)

	# Deferred style override for the continue button (overriding show_slide values)
	var apply_continue_style = func():
		continue_button.custom_minimum_size = Vector2(0, 84)
		continue_button.add_theme_font_size_override("font_size", 38)
		UITheme.style_pixel_button_colored(continue_button, UITheme.CLR_GREEN)
		
		continue_button.add_theme_color_override("font_color", Color.WHITE)
		continue_button.add_theme_color_override("font_hover_color", Color.WHITE)
		continue_button.add_theme_color_override("font_pressed_color", Color.WHITE)
		continue_button.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
		continue_button.add_theme_constant_override("outline_size", 10)
		
		continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		continue_button.show()
	apply_continue_style.call_deferred()

	_resize_panel()

func _on_section_header_pressed(index: int) -> void:
	var vbox = technical_panel.get_node("OuterMargin/VBoxContainer")
	open_section = -1 if open_section == index else index

	for i in range(1, 5):
		var idx = i - 1
		var header: Button = vbox.get_node("Section%d/Header" % i)
		var content: Label = vbox.get_node("Section%d/Content" % i)
		var is_open = (idx == open_section)
		content.visible = is_open
		var arrow = ARROW_OPEN if is_open else ARROW_CLOSED
		header.text = SECTION_ICONS[idx] + "  " + arrow + SECTION_LABELS[idx]
		
		# Reuse standard UITheme styles dynamically to ensure consistency
		if is_open:
			UITheme.style_pixel_button_colored(header, UITheme.CLR_GOLD)
			header.add_theme_color_override("font_color", UITheme.CLR_INK)
			header.add_theme_color_override("font_hover_color", UITheme.CLR_INK)
			header.add_theme_color_override("font_pressed_color", UITheme.CLR_INK)
		else:
			UITheme.style_pixel_button(header, false)
			
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if is_open:
			var sb_content := StyleBoxFlat.new()
			sb_content.bg_color = Color("#fffcf8")
			sb_content.border_color = UITheme.CLR_INK
			sb_content.border_width_left = 4
			sb_content.border_width_right = 4
			sb_content.border_width_bottom = 8
			sb_content.border_width_top = 0 # Merge
			sb_content.anti_aliasing = false
			sb_content.set_corner_radius_all(0)
			sb_content.content_margin_left = 28
			sb_content.content_margin_right = 28
			sb_content.content_margin_top = 18
			sb_content.content_margin_bottom = 18
			content.add_theme_stylebox_override("normal", sb_content)

	_resize_panel()

func _resize_panel() -> void:
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var vbox = technical_panel.get_node("OuterMargin/VBoxContainer")
	var content_h: float = vbox.get_combined_minimum_size().y
	
	# Fetch actual content margin heights from the StyleBox
	var sb = technical_panel.get_theme_stylebox("panel")
	var margin_top: float = sb.content_margin_top if sb else 22.0
	var margin_bottom: float = sb.content_margin_bottom if sb else 22.0
	
	var target_h: float = minf(content_h + margin_top + margin_bottom, vp.y - 60.0)
	technical_panel.offset_top = -target_h * 0.5
	technical_panel.offset_bottom = target_h * 0.5

# Keep old signal alive so existing connections don't error
func _on_toggle_pressed(_toggle_index):
	pass

# Updated on 2026-06-20
