# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var preview = $VBoxContainer/PreviewContainer/DogPreview
@onready var pet_name_input = $VBoxContainer/PetNameInput

func _ready():
	var map = load("res://New Ui/FINAL PET NAME/Map.tscn").instantiate()
	map.scale = Vector2(7.5, 7.5)
	if map.has_node("Layer_2_0"):
		map.get_node("Layer_2_0").queue_free()
	
	var bg = Node2D.new()
	bg.name = "Backdrop"
	bg.add_child(map)
	add_child(bg)
	move_child(bg, 0)
	
	if has_node("Background"):
		$Background.hide()
	
	$VBoxContainer/Title.text = "Name Your Buddy"
	$VBoxContainer/Title.add_theme_color_override("font_color", UITheme.CLR_CREAM)
	
	pet_name_input.placeholder_text = "Type a name…"
	pet_name_input.max_length = 14
	
	UITheme.style_pixel_button($VBoxContainer/ContinueButton)
	$VBoxContainer/ContinueButton.disabled = pet_name_input.text.strip_edges() == ""
	
	var dog_scene = load("res://scenes/People and dog/dog.tscn").instantiate()
	preview.sprite_frames = dog_scene.get_node("AnimatedSprite2D").sprite_frames
	dog_scene.free()
	
	update_preview()
	pet_name_input.grab_focus()
	pet_name_input.text_changed.connect(_on_pet_name_changed)

func _on_pet_name_changed(new_text: String) -> void:
	var filtered := ""
	for c in new_text:
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or c == " ":
			filtered += c
	if filtered != new_text:
		var caret: int = pet_name_input.caret_column - (new_text.length() - filtered.length())
		pet_name_input.text = filtered
		pet_name_input.caret_column = max(0, min(caret, filtered.length()))
	$VBoxContainer/ContinueButton.disabled = pet_name_input.text.strip_edges() == ""

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
