# COMMIT: Achievements and Catch Minigame Update
extends CharacterBody2D

@export var target_distance: float = 67.0
@export var player_group: String = "player"
@export var needs_menu_scene: PackedScene = preload("res://scenes/ui/needs_menu.tscn")

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var breed: String = "basic_dog"

# State machine
enum DogState {FOLLOWING_PLAYER, GOING_TO_FOOD, GOING_TO_WATER, GOING_TO_SLEEP, SLEEPING}
var current_state: DogState = DogState.FOLLOWING_PLAYER

var path: Array[Vector2] = []
var needs_menu_instance: CanvasLayer

# Direct-coordinate action movement (food/water/sleep)
var action_target: Vector2 = Vector2.ZERO
var action_has_target: bool = false
var action_callback: Callable
var action_speed: float = 250.0

# Auto-routine when player enters the house
var was_in_house: bool = false
var is_in_evening_routine: bool = false

# Hard-coded destinations for the three dog actions (1/2/3 keys).
const FOOD_TARGET: Vector2 = Vector2(450, -585)
const WATER_TARGET: Vector2 = Vector2(410, -580)
const SLEEP_TARGET: Vector2 = Vector2(310, -590)

var hunger: float = 80.0
var thirst: float = 70.0
var energy: float = 100.0
var health: float = 30.0 # Starts low on Day 1

var hunger_decay: float = 100.0 / 240.0 # ~0.417 per second (4 minutes to empty)
var thirst_decay: float = 100.0 / 240.0
var energy_decay: float = 100.0 / 240.0

# Emotion bubble
var emotion_label: Label = null
var is_hovered: bool = false
var prev_emotion: String = ""
var emotion_timer: float = 0.0
# Idle twitch
var idle_time: float = 0.0
var twitch_timer: float = 0.0

# Initialize all pet needs for Day 1
func initialize_day_one():
	hunger = 100.0
	thirst = 100.0
	energy = 100.0
	health = 30.0 # Health starts low on Day 1

# Apply random health change at start of each day
func apply_daily_health_change():
	var change = randi_range(-30, 30)
	health = clamp(health + change, 10, 100) # Floor at 10, cap at 100
	
	# Apply medication healing (medication is processed in GameState.advance_day)
	if GameState.medication != "none":
		health = min(100.0, health + 30)


## Random nightly health roll only (week simulation — no duplicate antibiotic bonus here).
func apply_random_night_health_roll() -> void:
	var change = randi_range(-30, 30)
	health = clamp(health + change, 10, 100)

func _ready() -> void:
	add_to_group("dog")
	input_pickable = true
	
	# Ensure dog collides with everything
	collision_mask = 1
	collision_layer = 1
	
	if needs_menu_scene:
		needs_menu_instance = needs_menu_scene.instantiate()
		get_tree().root.add_child.call_deferred(needs_menu_instance)
	
	# Connect to day started signal
	GameState.day_started.connect(_on_day_started)

	# Create emotion bubble label above the dog
	emotion_label = Label.new()
	emotion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emotion_label.add_theme_font_size_override("font_size", 24)
	emotion_label.position = Vector2(-16, -60)
	emotion_label.z_index = 10
	emotion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emotion_label.visible = false
	add_child(emotion_label)

	# Hover detection
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	is_hovered = true

func _on_mouse_exited() -> void:
	is_hovered = false

func _get_emotion_emoji() -> String:
	if health < 50:   return "🤒"
	if hunger < 30:   return "😢"
	if thirst < 30:   return "💧"
	if energy < 30:   return "😴"
	return "❤️"

func _update_emotion_bubble(delta: float) -> void:
	if not emotion_label: return
	var emoji := _get_emotion_emoji()
	# State changed — restart 2-second display timer
	if emoji != prev_emotion:
		prev_emotion = emoji
		emotion_timer = 2.0
	# Tick down timer
	if emotion_timer > 0.0:
		emotion_timer = max(0.0, emotion_timer - delta)
	emotion_label.text = emoji
	emotion_label.visible = emotion_timer > 0.0 or is_hovered

func _on_day_started(_day: int):
	# Full-night rest — wake and restore needs to 100 (health stays as-is).
	if current_state == DogState.SLEEPING:
		_wake_up_dog(false)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_menu()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pet_menu"):
		toggle_menu()
	
	# Dog action keys (only when following player)
	if current_state == DogState.FOLLOWING_PLAYER and event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			start_action(FOOD_TARGET, DogState.GOING_TO_FOOD, _on_food_complete)
		elif event.keycode == KEY_2:
			start_action(WATER_TARGET, DogState.GOING_TO_WATER, _on_water_complete)
		elif event.keycode == KEY_3:
			start_action(SLEEP_TARGET, DogState.GOING_TO_SLEEP, _on_sleep_complete)

	# Wake the dog early by pressing 4 while inside the house.
	if event is InputEventKey and event.pressed and event.keycode == KEY_4:
		if GameState.Inside_house and current_state == DogState.SLEEPING:
			_wake_up_dog(true)

func start_action(target: Vector2, state: DogState, callback: Callable):
	action_target = target
	action_has_target = true
	action_callback = callback
	current_state = state
	path.clear()
	print("Started action → target: ", target)

func _on_food_complete():
	if GameState.food <= 0:
		GameState.event_triggered.emit("⚠️ No food at home! Buy some from the shop.")
		current_state = DogState.FOLLOWING_PLAYER
		return
	
	GameState.food -= 1
	var fed_type = GameState.foods[randi() % GameState.foods.size()]
	
	if fed_type == GameState.favorite_food:
		hunger = min(100.0, hunger + 50.0)
		GameState.event_triggered.emit("Fed dog " + fed_type + ". It's their favorite! 💖")
		health = min(100.0, health + 10)
	elif fed_type == GameState.disliked_food:
		hunger = min(100.0, hunger + 10.0)
		GameState.event_triggered.emit("Fed dog " + fed_type + ". They hated it... 🤢")
		health -= 5
	else:
		hunger = min(100.0, hunger + 30.0)
		GameState.event_triggered.emit("Fed dog " + fed_type + ".")
		
	GameState.times_fed += 1
	GameState.check_achievements()
		
	current_state = DogState.FOLLOWING_PLAYER
	print("Dog ate! Hunger: ", hunger)

func _on_water_complete():
	if GameState.water <= 0:
		GameState.event_triggered.emit("⚠️ No water at home! Buy some from the shop.")
		current_state = DogState.FOLLOWING_PLAYER
		return

	GameState.water -= 1
	thirst = min(100.0, thirst + 30.0)
	current_state = DogState.FOLLOWING_PLAYER
	GameState.times_watered += 1
	GameState.check_achievements()
	print("Dog drank! Thirst: ", thirst)

func _on_sleep_complete():
	energy = 100.0
	current_state = DogState.SLEEPING
	GameState.is_dog_sleeping = true
	_play_animation("sleeping")
	GameState.nap_count += 1
	GameState.check_achievements()
	is_in_evening_routine = false
	print("Dog sleeping! Energy: ", energy)

# Chain: food → water → sleep, started on house entry.
func _start_evening_routine() -> void:
	if is_in_evening_routine or current_state == DogState.SLEEPING:
		return
	is_in_evening_routine = true
	start_action(FOOD_TARGET, DogState.GOING_TO_FOOD, _on_routine_food_done)

func _on_routine_food_done() -> void:
	_on_food_complete()
	# Hold position during the dwell — otherwise FOLLOWING_PLAYER pulls the
	# dog back to the player before it can finish its routine.
	current_state = DogState.GOING_TO_FOOD
	action_has_target = false
	await get_tree().create_timer(1.0).timeout
	if not is_in_evening_routine:
		return
	start_action(WATER_TARGET, DogState.GOING_TO_WATER, _on_routine_water_done)

func _on_routine_water_done() -> void:
	_on_water_complete()
	current_state = DogState.GOING_TO_WATER
	action_has_target = false
	await get_tree().create_timer(1.0).timeout
	if not is_in_evening_routine:
		return
	start_action(SLEEP_TARGET, DogState.GOING_TO_SLEEP, _on_sleep_complete)

# Wake from sleep. `is_early` = woken via KEY_4 (add 40); otherwise full 100 restore.
# Health is not touched here — it's governed by daily roll / medication.
func _wake_up_dog(is_early: bool) -> void:
	if current_state != DogState.SLEEPING:
		return
	if is_early:
		hunger = min(100.0, hunger + 40.0)
		thirst = min(100.0, thirst + 40.0)
		energy = min(100.0, energy + 40.0)
	else:
		hunger = 100.0
		thirst = 100.0
		energy = 100.0
	current_state = DogState.FOLLOWING_PLAYER
	GameState.is_dog_sleeping = false
	_play_animation("idle")

func toggle_menu() -> void:
	if needs_menu_instance:
		if needs_menu_instance.panel.visible:
			needs_menu_instance.panel.hide()
		else:
			needs_menu_instance.show_menu(self )

func _physics_process(delta: float) -> void:
	GameState.dog_health = health

	# Kick off the food → water → sleep routine the moment the player enters.
	if GameState.Inside_house and not was_in_house:
		_start_evening_routine()
	was_in_house = GameState.Inside_house

	# On the Mend: track if health was critically low then recovered
	if health < 30.0:
		GameState.dog_health_was_low = true
	elif GameState.dog_health_was_low and health > 60.0:
		GameState.dog_health_was_low = false
		GameState._unlock("On the Mend")

	# Clean Bill of Health: health reaches 100
	if health >= 100.0:
		GameState._unlock("Clean Bill of Health")
	
	
	# Features 3, 5, 8: Age Scaling, Color Moods, Jitter, Sleep Cycles
	_apply_dynamic_appearance(delta)

	# Handle state-specific behavior
	match current_state:
		DogState.SLEEPING:
			# Frozen - play sleep animation and stay put
			_play_animation("sleeping")
			velocity = Vector2.ZERO
			return
		DogState.GOING_TO_FOOD, DogState.GOING_TO_WATER, DogState.GOING_TO_SLEEP:
			# Follow action path
			_process_action_path()
			return
		DogState.FOLLOWING_PLAYER:
			_process_following_player(delta)

func _apply_dynamic_appearance(delta: float) -> void:
	if not animated_sprite_2d: return
	
	# 5. Growing Up (Scale) — keep dog closer to player size (old curve hit 2× and read as “giant dog”).
	var age_growth: float = minf(float(GameState.current_day) * 0.012, 0.32)
	var age_scale_factor: float = clampf(0.72 + age_growth, 0.68, 1.06)
	animated_sprite_2d.scale = Vector2(age_scale_factor, age_scale_factor)
	
	# 3. Color Moods
	if health < 50:
		animated_sprite_2d.modulate = Color(0.8, 0.8, 1.0) # Sick (Pale blue)
	elif hunger < 30:
		animated_sprite_2d.modulate = Color(1.0, 0.6, 0.6) # Hungry (Red tint)
	elif energy < 30:
		animated_sprite_2d.modulate = Color(0.7, 0.7, 0.7) # Sleepy (Darker)
	else:
		animated_sprite_2d.modulate = Color(1, 1, 1) # Normal
		
	_update_emotion_bubble(delta)

	# 3. Jitter / Shake if really sick
	if health < 20:
		var jitter = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		animated_sprite_2d.position = jitter
	else:
		animated_sprite_2d.position = Vector2.ZERO

func _process_action_path():
	if not action_has_target:
		velocity = Vector2.ZERO
		_play_animation("idle")
		return

	var distance = global_position.distance_to(action_target)
	if distance < 10.0:
		# Reached destination — snap, stop, fire callback.
		global_position = action_target
		velocity = Vector2.ZERO
		_play_animation("idle")
		action_has_target = false
		if action_callback.is_valid():
			var cb = action_callback
			action_callback = Callable()
			cb.call()
		# Open pet needs menu when path action finishes
		if needs_menu_instance:
			needs_menu_instance.show_menu(self)
		return

	var direction = (action_target - global_position).normalized()
	velocity = direction * action_speed
	move_and_slide()

	_play_animation("run")
	if direction.x < 0:
		animated_sprite_2d.flip_h = true
	elif direction.x > 0:
		animated_sprite_2d.flip_h = false

func _process_following_player(delta: float):
	# Don't decay needs during tutorial or when dog is sleeping
	if not GameState.is_tutorial_complete or GameState.is_dog_sleeping:
		pass # Skip decay
	else:
		# 8. Sleep Cycles (System Time Integration)
		var time_dict = Time.get_time_dict_from_system()
		var hour = time_dict["hour"]
		var is_late_night = (hour >= 22 or hour <= 6)
		
		# Extra energy decay if awake at night
		var current_energy_decay = energy_decay
		if is_late_night:
			current_energy_decay *= 2.0
			
		hunger = max(0, hunger - hunger_decay * delta)
		thirst = max(0, thirst - thirst_decay * delta)
		energy = max(0, energy - current_energy_decay * delta)
		
		check_emergency_triggers(delta)
	
	var player = get_tree().get_first_node_in_group(player_group)
	if not player:
		return

	# Teleport if far from player — but NEVER while sleeping (don't want the
	# dog yanked outside during a nap) and only if the player is in the house
	# when the dog is already there (prevents teleporting out through walls).
	if current_state != DogState.SLEEPING \
			and not GameState.is_dog_sleeping \
			and global_position.distance_to(player.global_position) > 250:
		global_position = player.global_position + Vector2(-10, 0)
		path.clear()
	
	var old_pos = global_position
	
	if path.is_empty() or path.back().distance_to(player.global_position) > 1.0:
		path.append(player.global_position)
	
	var accumulated_distance = 0.0
	var _found_target = false
	
	for i in range(path.size() - 1, 0, -1):
		var p_current = path[i]
		var p_prev = path[i - 1]
		var segment_distance = p_current.distance_to(p_prev)
		
		if accumulated_distance + segment_distance >= target_distance:
			var remaining_distance = target_distance - accumulated_distance
			var ratio = remaining_distance / segment_distance
			var target_pos = p_current.lerp(p_prev, ratio)
			
			velocity = (target_pos - global_position) / delta
			move_and_slide()
			
			while i > 0:
				path.remove_at(0)
				i -= 1
			
			_found_target = true
			break
		
		accumulated_distance += segment_distance
	
	if old_pos.distance_to(global_position) > 0.1:
		_play_animation("run")
		if global_position.x < old_pos.x:
			animated_sprite_2d.flip_h = true
		elif global_position.x > old_pos.x:
			animated_sprite_2d.flip_h = false
		idle_time = 0.0
		twitch_timer = 0.0
	else:
		_play_animation("idle")
		# Idle twitch — fidget after 3s of standing still
		idle_time += delta
		if twitch_timer > 0.0:
			twitch_timer -= delta
			_play_animation("run")
			if twitch_timer <= 0.0:
				_play_animation("idle")
		elif idle_time >= 3.0:
			idle_time = 0.0
			twitch_timer = 0.3

var emergency_cooldown: float = 0.0

func check_emergency_triggers(delta: float):
	if emergency_cooldown > 0:
		emergency_cooldown -= delta
		return

	# Emergency Vet Logic
	if health < 20:
		# Attempt to pay vet fee for emergency care
		if GameState.spend_money(GameState.vet_fee, "Vet"):
			health = 50
			emergency_cooldown = 10.0
			print("Emergency Vet Care triggered!")
	
	# Emergency Food Logic
	if hunger < 10 and GameState.food <= 0:
		# Attempt to pay food cost for emergency food
		if GameState.spend_money(GameState.food_cost, "Food"):
			GameState.food += 7
			hunger = 50
			emergency_cooldown = 10.0
			print("Emergency Food Purchase triggered!")

func _play_animation(anim_name: String) -> void:
	if not animated_sprite_2d:
		return
	
	var possible_names = [
		breed + "_" + anim_name,
		breed.capitalize() + "_" + anim_name,
		anim_name,
		"basic_dog_" + anim_name
	]
	
	for anim_name_to_check in possible_names:
		if animated_sprite_2d.sprite_frames.has_animation(anim_name_to_check):
			animated_sprite_2d.play(anim_name_to_check)
			return

# Updated on 2026-04-19
