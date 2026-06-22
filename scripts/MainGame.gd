# COMMIT: Achievements and Catch Minigame Update
extends Node2D

# Tile (45, 20) in Map.tscn scaled by 2 and offset by (-724, -317)
# (45 * 16 * 2) - 724 = 716
# (20 * 16 * 2) - 317 = 323
@onready var player_spawn_pos = Vector2(716, 323)
@onready var dog_spawn_pos = Vector2(766, 323) # Spawn dog slightly to the right

var dog_instance: CharacterBody2D = null
var hud_instance: CanvasLayer = null
var tutorial_controller: Node = null

var Day1Tutorial = preload("res://scripts/day1_tutorial.gd")
var Day2Tutorial = preload("res://scripts/day2_tutorial.gd")
var day2_tutorial_controller: Node = null
var _job_path_line: Node2D = null
@onready var shop_path = $ShopPath
@onready var original_path = $VetPath

func _ready():
	if GameState.selected_pathway in ["kid", "teenager"]:
		var pm := get_node_or_null("KidTeenPlayerSpawn")
		var dm := get_node_or_null("KidTeenDogSpawn")
		if pm: player_spawn_pos = pm.position
		if dm: dog_spawn_pos = dm.position
	spawn_player()
	spawn_dog()
	setup_hud()
	spawn_mother_npc()
	spawn_manager_npcs()
	# Dressed to the Nines: all 5 layers are non-default
	if GameState.uses_component_system:
		var comps := GameState.get_character_components()
		if comps.get("body", 0) > 0 and comps.get("eyes", 0) > 0 and comps.get("outfit", 0) > 0 \
				and comps.get("hairstyle", 0) > 0 and comps.get("accessory", 0) > 0:
			GameState._unlock("Dressed to the Nines")
	# Only show tutorial paths if it's Day 1 and tutorial isn't complete
	if GameState.is_day_one and not GameState.is_tutorial_complete:
		_make_paths_visible()
	else:
		# Ensure they are hidden if they exist
		if original_path: original_path.visible = false
		if shop_path: shop_path.visible = false
	
	# Background Music
	var music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	var music_stream = load("res://assets/Music/inspiring-synth-arpeggios-with-mellow-pads-and-creative-calm-energy-408709 (1).mp3")
	if music_stream:
		music_player.stream = music_stream
		music_player.autoplay = true
		# Godot 4.x loop setting is on the stream itself usually for mp3, 
		# but let's ensure it loops via script if needed or trust the importer.
		# If it's an AudioStreamMP3, we can set loop.
		if music_stream is AudioStreamMP3:
			music_stream.loop = true
		add_child(music_player)
		music_player.play()
	
	# Initialize Day 1 if it's a new game
	if GameState.is_day_one and not GameState.is_tutorial_complete:
		if dog_instance:
			dog_instance.initialize_day_one()
		GameState.initialize_day_one()
		
		# Start Day 1 tutorial after a brief delay
		call_deferred("start_day1_tutorial")
	else:
		# Restore saved dog data if continuing
		restore_dog_from_save()
	
	# Connect to day started signal for health changes
	GameState.day_started.connect(_on_day_started)
	GameState.vet_talk_finished.connect(_on_vet_talk_finished)
	GameState.open_shop_requested.connect(_on_open_shop_requested)

func _on_open_shop_requested():
	if shop_path:
		shop_path.visible = false

var home_hint_shown = false
func _on_shop_closed():
	if GameState.is_day_one and not home_hint_shown:
		home_hint_shown = true
		# Show hint after shop
		var tutorial_hint_scene = preload("res://scenes/ui/tutorial_hint.tscn")
		var hint = tutorial_hint_scene.instantiate()
		get_tree().root.add_child(hint)
		hint.show_hint("Press 📱 to go home.", 6.0)

func _on_vet_talk_finished():
	if GameState.is_day_one:
		if original_path:
			original_path.visible = false
		if shop_path:
			shop_path.visible = true
			# Ensure the visual representation (Line2D) is also updated if needed
			# _make_paths_visible() already creates Line2D as children.
			# If shop_path was already visible, _make_paths_visible handles it.
			# But we might need to recreate Line2D if we just made it visible.

func start_day1_tutorial():
	tutorial_controller = Day1Tutorial.new()
	add_child(tutorial_controller)
	tutorial_controller.start_tutorial(dog_instance, hud_instance)

func _on_day_started(day_number: int):
	if dog_instance:
		dog_instance.apply_daily_health_change()
	# Auto-save at end of each day
	save_current_game()
	# Day 2 (first work day) tutorial — teen/adult only, fires once.
	if day_number == 1 \
			and GameState.selected_pathway in ["teenager", "adult"] \
			and GameState.is_tutorial_complete \
			and not GameState.day_two_tutorial_done:
		GameState.day_two_tutorial_done = true
		start_day2_tutorial()

func start_day2_tutorial():
	day2_tutorial_controller = Day2Tutorial.new()
	add_child(day2_tutorial_controller)
	day2_tutorial_controller.start_tutorial(self, hud_instance)

## Draw a visible guidance line over one of the named job Path2D nodes
## ("Burger path" / "bank path" / "post path"). Mirrors _make_paths_visible().
func show_job_path(node_name: String) -> void:
	hide_job_path()
	var path = get_node_or_null(node_name)
	if path and path is Path2D and path.curve:
		_job_path_line = PathGuider.new()
		_job_path_line.setup_path(path, 6.0, Color(1, 0.9, 0.1))
		_job_path_line.z_index = 100 # Always draw above the map/buildings
		path.add_child(_job_path_line)

func hide_job_path() -> void:
	if _job_path_line and is_instance_valid(_job_path_line):
		_job_path_line.queue_free()
	_job_path_line = null

func _exit_tree():
	# Save game when leaving the scene
	save_current_game()

func save_current_game():
	if dog_instance:
		var dog_data = {
			"hunger": dog_instance.hunger,
			"thirst": dog_instance.thirst,
			"energy": dog_instance.energy,
			"health": dog_instance.health
		}
		GameState.save_game(dog_data)

func restore_dog_from_save():
	var saved_dog_data = GameState.get_saved_dog_data()
	if dog_instance and not saved_dog_data.is_empty():
		dog_instance.hunger = saved_dog_data.get("hunger", 100.0)
		dog_instance.thirst = saved_dog_data.get("thirst", 100.0)
		dog_instance.energy = saved_dog_data.get("energy", 100.0)
		dog_instance.health = saved_dog_data.get("health", 30.0)

func setup_hud():
	var hud_scene = load("res://scenes/ui/bottom_hud.tscn")
	if hud_scene:
		var hud = hud_scene.instantiate()
		add_child(hud)
		# Store reference for tutorial
		hud_instance = hud

		# Connect to shop closed signal for home hint
		if hud.shop_menu_instance:
			hud.shop_menu_instance.shop_closed.connect(_on_shop_closed)

func spawn_player():
	if GameState.uses_component_system:
		_spawn_component_player()
	else:
		_spawn_legacy_player()


func _spawn_legacy_player():
	var variant = GameState.character_variant
	var id = GameState.character_id
	var scene_path = ""
	
	if variant == "male":
		if id == 1:
			scene_path = "res://scenes/People and dog/Dude1.tscn"
		else:
			scene_path = "res://scenes/People and dog/Dude" + str(id) + ".tscn"
	else:
		scene_path = "res://scenes/People and dog/girl" + str(id) + ".tscn"
		
	var player = load(scene_path).instantiate()
	player.global_position = player_spawn_pos
	player.scale = Vector2(0.75, 0.75)
	player.set_script(load("res://scripts/player.gd"))
	player.input_pickable = true
	add_child(player)
	player.add_to_group("player")
	_add_name_tag(player)


func _spawn_component_player():
	# Build a layered character from individual component SpriteFrames
	var player = CharacterBody2D.new()
	player.name = "Player"
	player.global_position = player_spawn_pos
	player.scale = Vector2(0.75, 0.75)
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	player.input_pickable = true

	# Layer order: Body → Eyes → Outfit → Hairstyle → Accessory
	var components := GameState.get_character_components()
	var layer_order := ["body", "eyes", "outfit", "hairstyle", "accessory"]
	var first_sprite: AnimatedSprite2D = null

	for category in layer_order:
		var option: int = components.get(category, 1)
		var sf: SpriteFrames = GameState.get_component_sprite_frames(category, option)
		if sf:
			var sprite := AnimatedSprite2D.new()
			sprite.name = category.capitalize()
			sprite.sprite_frames = sf
			sprite.position = Vector2(0, -4.26)
			if sf.has_animation("idle_down"):
				sprite.animation = "idle_down"
			player.add_child(sprite)
			if first_sprite == null:
				first_sprite = sprite

	# Add collision shape
	var collision = CollisionPolygon2D.new()
	collision.polygon = PackedVector2Array([
		Vector2(0, -5.28), Vector2(-3.52, -5.28), Vector2(-3.08, 6.6),
		Vector2(0, 9.25), Vector2(3.08, 6.6), Vector2(3.52, -5.28)
	])
	player.add_child(collision)

	# Add camera
	var camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(2.5, 2.5)
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.scale = Vector2(1.005, 1.075)
	camera.add_to_group("player")
	player.add_child(camera)

	player.set_script(load("res://scripts/player_component.gd"))
	add_child(player)
	player.add_to_group("player")
	_add_name_tag(player)


func _add_name_tag(player: Node):
	var name_tag = Label.new()
	name_tag.text = GameState.player_name
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.custom_minimum_size = Vector2(100, 20)
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 18
	label_settings.outline_size = 3
	label_settings.outline_color = Color.BLACK
	name_tag.label_settings = label_settings
	
	name_tag.scale = Vector2(1.0 / player.scale.x, 1.0 / player.scale.y)
	name_tag.position = Vector2(-50 * name_tag.scale.x, -30 * name_tag.scale.y)
	name_tag.visible = false
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(name_tag)
	
	player.mouse_entered.connect(func():
		name_tag.visible = true
	)
	player.mouse_exited.connect(func():
		name_tag.visible = false
	)

func spawn_dog():
	var dog_scene = load("res://scenes/People and dog/dog.tscn")
	var dog = dog_scene.instantiate()
	dog.global_position = dog_spawn_pos
	dog.breed = GameState.dog_breed
	dog.input_pickable = true
	add_child(dog)
	dog.add_to_group("dog")
	
	# Store reference for save/load
	dog_instance = dog
	
	var name_tag = Label.new()
	name_tag.text = GameState.pet_name
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.custom_minimum_size = Vector2(100, 20)
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 18
	label_settings.outline_size = 3
	label_settings.outline_color = Color.BLACK
	name_tag.label_settings = label_settings
	
	name_tag.scale = Vector2(1.0 / dog.scale.x, 1.0 / dog.scale.y)
	name_tag.position = Vector2(-50 * name_tag.scale.x, -40 * name_tag.scale.y)
	name_tag.visible = false
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dog.add_child(name_tag)
	
	dog.mouse_entered.connect(func():
		name_tag.visible = true
	)
	dog.mouse_exited.connect(func():
		name_tag.visible = false
	)

func _make_paths_visible():
	# Only show tutorial paths (VetPath, ShopPath) — hide dog action paths
	var tutorial_paths = [original_path, shop_path]

	for path in tutorial_paths:
		if path and path is Path2D:
			# Remove any existing PathGuider child to avoid duplicates if re-called
			for child in path.get_children():
				if child is PathGuider:
					child.queue_free()
			var line = PathGuider.new()
			line.setup_path(path, 5.0, Color(1, 0.9, 0.1))
			path.add_child(line)
			print("[MainGame] Made path visible with PathGuider: ", path.name)

func spawn_mother_npc():
	# Only spawn for Kid and Teenager pathways
	if GameState.selected_pathway not in ["kid", "teenager"]:
		return
	
	var mother: CharacterBody2D = null
	
	if GameState.uses_component_system:
		mother = CharacterBody2D.new()
		mother.name = "MotherNPC"
		var mm := get_node_or_null("KidTeenMotherSpawn")
		mother.global_position = mm.position if mm else Vector2(565, -640)
		mother.scale = Vector2(0.75, 0.75)
		mother.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		mother.input_pickable = true
		
		var components := GameState.get_character_components()
		var body_opt = components.get("body", 1)
		var eyes_opt = components.get("eyes", 1)
		
		# Dynamic customization matching the player's body and eyes, with mom outfit/hair/accessories
		var mom_layers = [
			{"category": "body", "option": body_opt},
			{"category": "eyes", "option": eyes_opt},
			{"category": "outfit", "option": 54},
			{"category": "hairstyle", "option": 23},
			{"category": "accessory", "option": 8}
		]
		
		for layer in mom_layers:
			var sf = GameState.get_component_sprite_frames(layer.category, layer.option)
			if sf:
				var sprite := AnimatedSprite2D.new()
				sprite.name = layer.category.capitalize()
				sprite.sprite_frames = sf
				sprite.position = Vector2(0, -4.26)
				if sf.has_animation("idle_left"):
					sprite.animation = "idle_left"
					sprite.play("idle_left")
				elif sf.has_animation("idle_down"):
					sprite.animation = "idle_down"
					sprite.play("idle_down")
				mother.add_child(sprite)
				
		# Add standard collision shape
		var collision = CollisionPolygon2D.new()
		collision.polygon = PackedVector2Array([
			Vector2(0, -5.28), Vector2(-3.52, -5.28), Vector2(-3.08, 6.6),
			Vector2(0, 9.25), Vector2(3.08, 6.6), Vector2(3.52, -5.28)
		])
		mother.add_child(collision)
	else:
		# Fallback to legacy single sprite
		mother = load("res://scenes/girl1.tscn").instantiate()
		mother.name = "MotherNPC"
		var mm := get_node_or_null("KidTeenMotherSpawn")
		mother.global_position = mm.position if mm else Vector2(565, -640)
		mother.scale = Vector2(0.75, 0.75)
		
		var anim_sprite = mother.get_node_or_null("Sprite2D") as AnimatedSprite2D
		if anim_sprite:
			if anim_sprite.sprite_frames.has_animation("idle_left"):
				anim_sprite.play("idle_left")
			else:
				anim_sprite.play("idle_down")
				
	# Add a name tag
	var name_tag = Label.new()
	name_tag.text = "Mother"
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.custom_minimum_size = Vector2(100, 20)
	var label_settings = LabelSettings.new()
	label_settings.font_size = 18
	label_settings.outline_size = 3
	label_settings.outline_color = Color.BLACK
	name_tag.label_settings = label_settings
	name_tag.scale = Vector2(1.0 / mother.scale.x, 1.0 / mother.scale.y)
	name_tag.position = Vector2(-50 * name_tag.scale.x, -30 * name_tag.scale.y)
	mother.add_child(name_tag)
	
	# Create an Area2D for interaction
	var area = Area2D.new()
	area.name = "InteractionArea"
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	col.shape = shape
	area.add_child(col)
	mother.add_child(area)
	
	# Set script dynamically
	var mother_script = GDScript.new()
	mother_script.source_code = "extends CharacterBody2D\n\nvar player_in_range = false\n\nfunc _ready():\n\t$InteractionArea.body_entered.connect(_on_body_entered)\n\t$InteractionArea.body_exited.connect(_on_body_exited)\n\nfunc _on_body_entered(body):\n\tif body.is_in_group(\"player\"):\n\t\tplayer_in_range = true\n\nfunc _on_body_exited(body):\n\tif body.is_in_group(\"player\"):\n\t\tplayer_in_range = false\n\nfunc _input(event):\n\tif player_in_range and event.is_action_pressed(\"interact\"):\n\t\tif GameState.is_dialogue_active:\n\t\t\treturn\n\t\tvar dialogue_resource = load(\"res://dialogues/tutorial.dialogue\")\n\t\tvar balloon_scene = load(\"res://dialogues/balloon.tscn\")\n\t\tvar balloon = balloon_scene.instantiate()\n\t\tget_tree().root.add_child(balloon)\n\t\tballoon.start(dialogue_resource, \"mother_idle\")\n"
	mother.set_script(mother_script)
	
	add_child(mother)
	print("[MainGame] Mother NPC successfully spawned at (565, -640) facing left.")


# Job-location managers. Each is a layered component character (same system as
# the player/customizer) with a themed accessory, stationed inside its building.
# Talking to one opens the vet-style dialogue box; see scripts/manager_npc.gd.
func spawn_manager_npcs() -> void:
	var managers := [
		{
			"location": "burger", "pos": Vector2(-8800, 3020),
			# Chef Tony — chef's hat (accessory 78)
			"layers": {"body": 2, "eyes": 1, "outfit": 8, "hairstyle": 5, "accessory": 78},
		},
		{
			"location": "bank", "pos": Vector2(4190, 960),
			# Ms. Vault — glasses (accessory 64)
			"layers": {"body": 4, "eyes": 3, "outfit": 30, "hairstyle": 8, "accessory": 64},
		},
		{
			"location": "post", "pos": Vector2(-8225, -3725),
			# Postmaster Gus — cap (accessory 27)
			"layers": {"body": 6, "eyes": 5, "outfit": 20, "hairstyle": 45, "accessory": 27},
		},
	]
	for m in managers:
		_spawn_one_manager(m["location"], m["pos"], m["layers"])


func _spawn_one_manager(location_key: String, pos: Vector2, layers: Dictionary) -> void:
	var npc := CharacterBody2D.new()
	npc.name = "Manager_" + location_key
	npc.global_position = pos
	npc.scale = Vector2(0.75, 0.75)
	npc.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	npc.input_pickable = true

	# Layered sprites in draw order: Body → Eyes → Outfit → Hairstyle → Accessory
	var layer_order := ["body", "eyes", "outfit", "hairstyle", "accessory"]
	for category in layer_order:
		var option: int = int(layers.get(category, 1))
		var sf: SpriteFrames = GameState.get_component_sprite_frames(category, option)
		if sf:
			var sprite := AnimatedSprite2D.new()
			sprite.name = category.capitalize()
			sprite.sprite_frames = sf
			sprite.position = Vector2(0, -4.26)
			if sf.has_animation("idle_down"):
				sprite.animation = "idle_down"
				sprite.play("idle_down")
			npc.add_child(sprite)

	# Solid body so the player can't walk through the manager.
	var collision := CollisionPolygon2D.new()
	collision.polygon = PackedVector2Array([
		Vector2(0, -5.28), Vector2(-3.52, -5.28), Vector2(-3.08, 6.6),
		Vector2(0, 9.25), Vector2(3.08, 6.6), Vector2(3.52, -5.28)
	])
	npc.add_child(collision)

	# Interaction trigger — generous box so "Press E to talk" is easy to find.
	var area := Area2D.new()
	area.name = "InteractionArea"
	var area_col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90, 90)
	area_col.shape = shape
	area.add_child(area_col)
	npc.add_child(area)

	# Floating name tag with the manager's name.
	var name_tag := Label.new()
	var job_id: String = GameState.JOB_FOR_LOCATION.get(location_key, "")
	name_tag.text = GameState.get_job_manager_name(job_id)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.custom_minimum_size = Vector2(120, 20)
	var label_settings := LabelSettings.new()
	label_settings.font_size = 16
	label_settings.outline_size = 3
	label_settings.outline_color = Color.BLACK
	name_tag.label_settings = label_settings
	name_tag.scale = Vector2(1.0 / npc.scale.x, 1.0 / npc.scale.y)
	name_tag.position = Vector2(-60 * name_tag.scale.x, -34 * name_tag.scale.y)
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc.add_child(name_tag)

	npc.set_script(load("res://scripts/manager_npc.gd"))
	npc.set("location_key", location_key)
	add_child(npc)
	print("[MainGame] Manager NPC '%s' spawned at %s." % [location_key, str(pos)])

# Updated on 2026-05-24
