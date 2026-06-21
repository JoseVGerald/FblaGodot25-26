# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var preview = $VBoxContainer/PreviewContainer/DogPreview
@onready var breed_label = $VBoxContainer/CycleContainer/BreedName

var breeds = [
	{"name": "Golden Retriever", "id": "Golden_Retriever"},
	{"name": "Husky", "id": "Husky"},
	{"name": "Dalmatian", "id": "dalmatian"},
	{"name": "Labrador", "id": "labrador_more_blond"},
	{"name": "Rottweiler", "id": "rottie"},
	{"name": "Argentino", "id": "Argentino"},
	{"name": "Pharaoh Hound", "id": "Pharoah_hound"},
	{"name": "Cane Corso", "id": "basic_Dog"}
]

var current_breed_index = 0

func _ready():
	UITheme.apply_theme(self)
	var dog_scene = load("res://scenes/People and dog/dog.tscn").instantiate()
	preview.sprite_frames = dog_scene.get_node("AnimatedSprite2D").sprite_frames
	dog_scene.free()
	update_preview()
	# Expand VBoxContainer width programmatically to give the breed name text more space
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_left = -550.0
		vbox.offset_right = 550.0

	# New UI pixel-art styling
	var prev_btn = get_node_or_null("VBoxContainer/CycleContainer/PrevButton")
	var next_btn = get_node_or_null("VBoxContainer/CycleContainer/NextButton")
	var cont_btn = get_node_or_null("VBoxContainer/ContinueButton")
	if prev_btn:
		prev_btn.custom_minimum_size = Vector2(100, 100)
		prev_btn.add_theme_font_size_override("font_size", 58)
		UITheme.style_pixel_button(prev_btn, true)
	if next_btn:
		next_btn.custom_minimum_size = Vector2(100, 100)
		next_btn.add_theme_font_size_override("font_size", 58)
		UITheme.style_pixel_button(next_btn, true)
	if cont_btn: UITheme.style_pixel_button(cont_btn)
	# Title and breed name sit directly on the checker — cream + outline.
	UITheme.style_checker_label($VBoxContainer/Title, 14)
	UITheme.style_checker_label(breed_label, 10)
	# Lock the label to a constant width so < > arrows never shift position.
	# SIZE_SHRINK_CENTER and custom_minimum_size ensures arrows stay close but safe.
	breed_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	breed_label.custom_minimum_size = Vector2(600, 0)
	breed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breed_label.clip_text = true  # foolproof: minimum size ignores text width → arrows never shift
	breed_label.add_theme_font_size_override("font_size", 54)  # larger, more prominent text area
	# Tighten the gap between arrows and label
	var cycle_container = get_node_or_null("VBoxContainer/CycleContainer")
	if cycle_container:
		cycle_container.add_theme_constant_override("separation", 30)

func _input(event):
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		cycle_breed(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		cycle_breed(1)
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_on_continue_button_pressed()

func cycle_breed(direction):
	current_breed_index += direction
	if current_breed_index >= breeds.size(): current_breed_index = 0
	if current_breed_index < 0: current_breed_index = breeds.size() - 1
	update_preview()

func update_preview():
	var breed = breeds[current_breed_index]
	breed_label.text = breed["name"]
	
	var anim_name = breed["id"] + "_idle"
	if preview.sprite_frames.has_animation(anim_name):
		preview.play(anim_name)
	else:
		preview.play("basic_Dog_idle")

func _on_prev_button_pressed():
	cycle_breed(-1)

func _on_next_button_pressed():
	cycle_breed(1)

func _on_continue_button_pressed():
	GameState.save_pet(breeds[current_breed_index]["id"])
	SceneManager.change_scene("res://scenes/ui/PetName.tscn", {"pattern": "curtains"})

# Updated on 2026-04-19
