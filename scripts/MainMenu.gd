
# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var start_button = $VBoxContainer/StartButton
@onready var settings_button = $VBoxContainer/SettingsButton

func _ready():
	UITheme.apply_theme(self)
	# New UI pixel-art button styling
	UITheme.style_pixel_button(continue_button)
	UITheme.style_pixel_button(start_button)
	UITheme.style_pixel_button(settings_button, true)   # secondary (gray)
	# Title label cream colour
	var title = get_node_or_null("VBoxContainer/Title")
	if title is Label:
		title.add_theme_color_override("font_color", UITheme.CLR_CREAM)
		title.add_theme_color_override("font_shadow_color", UITheme.CLR_MAROON_D)
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
