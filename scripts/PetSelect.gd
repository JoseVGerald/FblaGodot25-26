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
	var map = load("res://New Ui/FINAL DOG CHOOSER MENU/Map.tscn").instantiate()
	map.scale = Vector2(7.5, 7.5)
	if map.has_node("Buttons_1"):
		map.get_node("Buttons_1").queue_free()
	
	var bg = Node2D.new()
	bg.name = "Backdrop"
	bg.add_child(map)
	add_child(bg)
	move_child(bg, 0)
	
	if has_node("Background"):
		$Background.hide()
	
	$VBoxContainer/ContinueButton.text = "Choose This Buddy"
	$VBoxContainer/Title.text = "Choose Your Buddy"
	$VBoxContainer/Title.add_theme_color_override("font_color", UITheme.CLR_CREAM)
	
	UITheme.style_pixel_button($VBoxContainer/ContinueButton)
	UITheme.style_pixel_button($VBoxContainer/CycleContainer/PrevButton, true)
	UITheme.style_pixel_button($VBoxContainer/CycleContainer/NextButton, true)
	
	var dog_scene = load("res://scenes/People and dog/dog.tscn").instantiate()
	preview.sprite_frames = dog_scene.get_node("AnimatedSprite2D").sprite_frames
	dog_scene.free()
	update_preview()

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
