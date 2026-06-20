# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var label = $VBoxContainer/Label
@onready var continue_button = $VBoxContainer/ContinueButton
@onready var technical_panel = $TechnicalPanel
@onready var slides_container = $VBoxContainer

var slides = [
	"Some dogs don’t start life feeling safe.",
	"This one didn’t either.",
	"You’ve adopted a dog who’s been through more than they can show.",
	"They’re not broken. Just unsure who to trust.",
	"Through daily care, play, and time together, you’ll help them heal.",
	"Welcome to your little buddy."
]

var current_slide = 0
var typing_speed = 0.05
var is_typing = false
var technical_slide_index = 6

func _ready():
	UITheme.apply_theme(self)
	# Lore text sits directly on the checker — needs cream + outline to read.
	UITheme.style_checker_label(label, 12)
	label.add_theme_font_size_override("font_size", 64)  # 4x bigger lore text
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
	
	# Secret skip tutorial button
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSLASH:
		_skip_tutorial()

func _skip_tutorial():
	GameState.reset_all()
	GameState.player_name = "Player"
	GameState.pet_name = "Buddy"
	GameState.is_tutorial_complete = true
	GameState.is_day_one = false
	# Ensure the character has a reasonable default look
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
		# Clamp panel to viewport so it doesn't stick out on small screens
		var vp := get_viewport().get_visible_rect().size
		var pw := minf(1600.0, vp.x - 40.0)
		var ph := minf(1000.0, vp.y - 40.0)
		technical_panel.offset_left   = -pw * 0.5
		technical_panel.offset_right  =  pw * 0.5
		technical_panel.offset_top    = -ph * 0.5
		technical_panel.offset_bottom =  ph * 0.5
		_style_blurb_labels()
		if continue_button.get_parent() != technical_panel.get_node("VBoxContainer"):
			var parent = continue_button.get_parent()
			parent.remove_child(continue_button)
			technical_panel.get_node("VBoxContainer").add_child(continue_button)
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

func _on_toggle_pressed(toggle_index):
	var vbox = technical_panel.get_node("VBoxContainer")
	for i in range(1, 5):
		var content = vbox.get_node("Section" + str(i) + "/Content")
		if i == toggle_index:
			content.visible = !content.visible
		else:
			content.visible = false

## Apply readable (non-pixel) font at larger size to the blurb content labels.
func _style_blurb_labels() -> void:
	var vbox = technical_panel.get_node_or_null("VBoxContainer")
	if not vbox:
		return
	for i in range(1, 5):
		var content = vbox.get_node_or_null("Section" + str(i) + "/Content")
		if content is Label:
			content.remove_theme_font_override("font")  # use default readable font
			content.add_theme_font_size_override("font_size", 23)
			content.add_theme_color_override("font_color", UITheme.CLR_INK)

# Updated on 2026-04-19
