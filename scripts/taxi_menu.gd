# COMMIT: Achievements and Catch Minigame Update
extends CanvasLayer

@onready var panel = $PanelContainer

signal menu_opened
signal menu_closed

# Destination coordinates
const DESTINATIONS := {
	"Home": Vector2(750, 380),
	"Store": Vector2(1025, 2185),
	"Vet": Vector2(1400, 1805),
	"Park": Vector2(1200, 600),
}

const _TAXI_TEX_EAST := preload("res://scenes/People and dog/Taxi/TAXI_CLEAN_EAST_000.png")
const _TAXI_TEX_SOUTH := preload("res://scenes/People and dog/Taxi/TAXI_CLEAN_SOUTH_000.png")
const _TAXI_ATLAS_SIZE := Vector2i(100, 100)

func _ready():
	UITheme.apply_overlay_theme(self )
	panel.hide()
	$PanelContainer/VBoxContainer/TitleHBox/CloseButton.pressed.connect(func():
		hide_menu()
	)
	$PanelContainer/VBoxContainer/HomeRow/HomeBtn.pressed.connect(func(): _travel_to("Home"))
	$PanelContainer/VBoxContainer/StoreRow/StoreBtn.pressed.connect(func(): _travel_to("Store"))
	$PanelContainer/VBoxContainer/VetRow/VetBtn.pressed.connect(func(): _travel_to("Vet"))
	$PanelContainer/VBoxContainer/ParkRow/ParkBtn.pressed.connect(func(): _travel_to("Park"))

func show_menu():
	panel.show()
	menu_opened.emit()

func hide_menu():
	panel.hide()
	menu_closed.emit()

func toggle_menu():
	if panel.visible:
		hide_menu()
	else:
		show_menu()

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel") and panel.visible:
		hide_menu()

func get_menu_visible() -> bool:
	return panel.visible

func _show_taxi_warning(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, Color(1, 0.5, 0.2))

## Overlapping taxi Area2D from group `taxi_call_area`, or null if none.
func _taxi_call_area_for_player(player: Node2D) -> Area2D:
	for node in get_tree().get_nodes_in_group("taxi_call_area"):
		if node is Area2D and node.overlaps_body(player):
			return node
	return null

func _taxi_call_area_is_vertical(area: Area2D) -> bool:
	return area.name.contains("vertical")

func _apply_taxi_sprite_facing(taxi_root: Node2D, facing: String) -> void:
	var spr := taxi_root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null:
		return
	var src: Texture2D = _TAXI_TEX_SOUTH if facing == "south" else _TAXI_TEX_EAST
	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.region = Rect2(Vector2.ZERO, _TAXI_ATLAS_SIZE)
	var sf := SpriteFrames.new()
	sf.add_animation("default")
	sf.set_animation_loop("default", true)
	sf.add_frame("default", atlas, 1.0)
	spr.sprite_frames = sf
	spr.play("default")
	taxi_root.rotation_degrees = 0.0

func _travel_to(destination: String):
	var pos = DESTINATIONS[destination]
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var call_area = _taxi_call_area_for_player(player)
	if call_area == null:
		_show_taxi_warning("Be near the road to hail a taxi")
		return
	var is_vertical_call := _taxi_call_area_is_vertical(call_area)
	if not GameState.spend_money(GameState.taxi_cost, "Travel"):
		return
	hide_menu()

	# Achievement tracking
	GameState.taxi_ride_count += 1
	if not GameState.locations_visited.has(destination):
		GameState.locations_visited.append(destination)
	GameState.check_achievements()
	
	var dog = get_tree().get_first_node_in_group("dog")
	
	var taxi_scene = load("res://taxi.tscn")
	var taxi_instance = null
	if taxi_scene:
		taxi_instance = taxi_scene.instantiate()
		_apply_taxi_sprite_facing(taxi_instance, "south" if is_vertical_call else "east")
		if player:
			taxi_instance.global_position = player.global_position + Vector2(0, 20)
		get_tree().current_scene.add_child(taxi_instance)
	
	if player:
		player.hide()
	if dog:
		dog.hide()
	
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	get_tree().current_scene.add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(taxi_instance):
			if is_vertical_call:
				taxi_instance.global_position.y += 40
			else:
				taxi_instance.global_position.x += 40
	)
	
	SceneManager.fade_in_place({
		"pattern": "curtains",
		"on_fade_out": func():
			if is_instance_valid(timer):
				timer.queue_free()
			if is_instance_valid(taxi_instance):
				taxi_instance.queue_free()
			if player:
				player.show()
				player.global_position = pos
			if dog:
				dog.show()
				dog.global_position = pos + Vector2(50, 0)
	})
