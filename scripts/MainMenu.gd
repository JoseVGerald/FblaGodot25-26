
# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var start_button = $VBoxContainer/StartButton
@onready var settings_button = $VBoxContainer/SettingsButton

func _ready():
	var map = load("res://New Ui/FINAL OPENING MENU/Map.tscn").instantiate()
	map.scale = Vector2(7.5, 7.5)
	if map.has_node("Layer_1_0"):
		map.get_node("Layer_1_0").queue_free()
	
	var bg = Node2D.new()
	bg.name = "Backdrop"
	bg.add_child(map)
	add_child(bg)
	move_child(bg, 0)
	
	UITheme.style_pixel_button(continue_button)
	UITheme.style_pixel_button(start_button)
	UITheme.style_pixel_button(settings_button, true)
	
	$VBoxContainer/Title.add_theme_color_override("font_color", UITheme.CLR_CREAM)
	
	continue_button.pressed.connect(_on_continue_pressed)
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

func _on_continue_pressed():
	# Load saved game data before transitioning
	if GameState.has_save_file():
		GameState.load_game()
	SceneManager.change_scene("res://scenes/ui/MainGame.tscn", {"pattern": "curtains"})

func _on_start_pressed():
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("save_game.dat")
	GameState.reset_all()
	SceneManager.change_scene("res://scenes/ui/IntroCutscene.tscn")

func _on_settings_pressed():
	var settings_scene = load("res://scenes/ui/SettingsMenu.tscn")
	if settings_scene:
		var settings_menu = settings_scene.instantiate()
		add_child(settings_menu)

func _on_close_settings_pressed():
	var panel = get_node_or_null("SettingsPanel")
	if panel:
		panel.hide()

# Updated on 2026-04-19
