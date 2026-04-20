# COMMIT: Achievements and Catch Minigame Update
extends Control

@onready var components: Control = $Components
@onready var confirm_button: Button = $Button
@onready var back_to_menu_button: Button = $BackToMenu
@onready var name_edit: LineEdit = $HBoxContainer/LineEdit
@onready var character_preferences: Node = get_node("/root/CharacterPreferences")
@onready var carousel: HBoxContainer = $CarouselContainer

const TAB_NAMES := ["Body", "Hairstyle", "Outfit", "Eyes", "Accessory"]
const DIRECTIONS := ["Front", "Right", "Back", "Left"]
const DIRECTION_X_OFFSETS := [0, 48, 96, 144]

var current_direction: int = 0


func _ready() -> void:
	_apply_saved_preferences()
	_connect_customization_buttons()
	_setup_carousel()
	_sync_initial_preview()
	_update_confirm_enabled()
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	name_edit.text_changed.connect(_on_name_changed)


func _apply_saved_preferences() -> void:
	name_edit.text = character_preferences.player_name
	for tab_name in TAB_NAMES:
		var option: int = character_preferences.get_option(tab_name)
		var tab: Control = $CustomizationOptions.get_node(tab_name)
		var checkbox: BaseButton = tab.get_child(option - 1)
		checkbox.button_pressed = true


func _connect_customization_buttons() -> void:
	for tab_name in TAB_NAMES:
		var tab: Control = $CustomizationOptions.get_node(tab_name)
		var first_checkbox: BaseButton = tab.get_child(0)
		var button_group: ButtonGroup = first_checkbox.button_group
		if button_group:
			button_group.pressed.connect(_on_option_pressed.bind(tab_name))


func _sync_initial_preview() -> void:
	for tab_name in TAB_NAMES:
		var tab: Control = $CustomizationOptions.get_node(tab_name)
		var first_checkbox: BaseButton = tab.get_child(0)
		var button_group: ButtonGroup = first_checkbox.button_group
		if button_group:
			var pressed_button: BaseButton = button_group.get_pressed_button()
			if pressed_button:
				_on_option_pressed(pressed_button, tab_name)


func _on_option_pressed(button: BaseButton, category: String) -> void:
	var option_index: int = button.get_index()
	var option_one_based: int = option_index + 1
	var animation_name: String = "Option%d" % option_one_based
	var sprite: AnimatedSprite2D = components.get_node_or_null(category)
	if sprite:
		sprite.animation = animation_name
	character_preferences.set_option(category, option_one_based)


func _on_name_changed(new_text: String) -> void:
	character_preferences.set_player_name(new_text)
	_update_confirm_enabled()


func _update_confirm_enabled() -> void:
	confirm_button.disabled = name_edit.text.strip_edges().is_empty()


func _on_confirm_pressed() -> void:
	confirm_button.disabled = true
	await SceneManager.change_scene("res://scenes/world.tscn", get_node("/root/TransitionPrefs").get_transition_dict())


func _on_back_to_menu_pressed() -> void:
	back_to_menu_button.disabled = true
	await SceneManager.change_scene("res://scenes/menu/starting_menu.tscn", get_node("/root/TransitionPrefs").get_transition_dict())


func _setup_carousel() -> void:
	for i in range(DIRECTIONS.size()):
		var button = carousel.get_child(i) if i < carousel.get_child_count() else null
		if button:
			button.pressed.connect(_on_direction_selected.bind(i))
	_update_carousel_highlight()


func _on_direction_selected(direction: int) -> void:
	current_direction = direction
	_update_character_direction()
	_update_carousel_highlight()


func _update_character_direction() -> void:
	var x_offset = DIRECTION_X_OFFSETS[current_direction]
	for component_name in TAB_NAMES:
		var sprite: AnimatedSprite2D = components.get_node_or_null(component_name)
		if sprite and sprite.sprite_frames:
			for frame_data in sprite.sprite_frames.get_animation_names():
				var atlas: AtlasTexture = sprite.sprite_frames.get_frame_texture(frame_data, 0)
				if atlas and atlas is AtlasTexture:
					var new_region = atlas.region
					new_region.position.x = x_offset
					atlas.region = new_region


func _update_carousel_highlight() -> void:
	for i in range(DIRECTIONS.size()):
		var button = carousel.get_child(i) if i < carousel.get_child_count() else null
		if button:
			button.modulate = Color.GOLD if i == current_direction else Color.WHITE
