# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var preview = $VBoxContainer/PreviewContainer/DogPreview
@onready var pet_name_input = $VBoxContainer/PetNameInput

func _ready():
	UITheme.apply_theme(self)
	var dog_scene = load("res://scenes/People and dog/dog.tscn").instantiate()
	preview.sprite_frames = dog_scene.get_node("AnimatedSprite2D").sprite_frames
	dog_scene.free()
	
	update_preview()
	pet_name_input.grab_focus()
	InputValidator.register_text_field(pet_name_input)
	
	# Override LineEdit styling to match the Character Creator name input style
	var pixel_font = UITheme.get_pixel_font()
	if pixel_font:
		pet_name_input.add_theme_font_override("font", pixel_font)
	pet_name_input.add_theme_font_size_override("font_size", 36)
	pet_name_input.add_theme_color_override("font_color", UITheme.CLR_INK)
	pet_name_input.add_theme_color_override("font_placeholder_color", UITheme.CLR_GRAY_DRK)
	pet_name_input.custom_minimum_size = Vector2(510, 72)
	
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = UITheme.CLR_CREAM_LT
	input_sb.border_color = UITheme.CLR_INK
	input_sb.set_border_width_all(5)
	input_sb.content_margin_left = 18
	input_sb.content_margin_right = 18
	input_sb.content_margin_top = 9
	input_sb.content_margin_bottom = 9
	input_sb.set_corner_radius_all(0)
	pet_name_input.add_theme_stylebox_override("normal", input_sb)
	
	var input_sb_focus: StyleBoxFlat = input_sb.duplicate()
	input_sb_focus.border_color = UITheme.CLR_ORANGE_PX
	input_sb_focus.border_width_bottom = 6
	pet_name_input.add_theme_stylebox_override("focus", input_sb_focus)

	# New UI pixel-art styling
	var cont_btn = get_node_or_null("VBoxContainer/ContinueButton")
	if cont_btn: UITheme.style_pixel_button(cont_btn)
	var title_lbl = get_node_or_null("VBoxContainer/Title")
	if title_lbl is Label:
		UITheme.style_checker_label(title_lbl, 14)


func _input(event):
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_on_continue_button_pressed()

func update_preview():
	var breed_id = GameState.dog_breed
	var anim_name = breed_id + "_run"
	
	if preview.sprite_frames.has_animation(anim_name):
		preview.play(anim_name)
	else:
		preview.play("basic_dog_run")
	
	preview.flip_h = true

func _on_continue_button_pressed():
	var p_name = pet_name_input.text.strip_edges()
	if p_name == "":
		return
		
	GameState.save_pet_name(p_name)
	SceneManager.change_scene("res://scenes/ui/CostCustomization.tscn", {"pattern": "curtains"})

# Updated on 2026-04-19
