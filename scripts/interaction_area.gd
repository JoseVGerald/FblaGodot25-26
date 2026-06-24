# COMMIT: Achievements and Catch Minigame Update
extends Area2D

@export var hint_text: String = "Press E to interact"
@export var target_position: Vector2
@export var is_exit: bool = false
@export var post_teleport_hint: String = ""
@export var is_sleep: bool = false
# Mark this area as the house entry/exit teleporter. When the player triggers
# it, we flip GameState.Inside_house so the dog can react immediately.
@export var is_house: bool = false

var tutorial_hint_scene = preload("res://scenes/ui/tutorial_hint.tscn")
var hint_instance: CanvasLayer = null
var player_in_area: bool = false

func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create hint instance if it doesn't exist
	# Note: We share one hint instance per area, but in a real game we might want a global one
	hint_instance = tutorial_hint_scene.instantiate()
	get_tree().root.add_child.call_deferred(hint_instance)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_area = true
		if hint_instance:
			await get_tree().process_frame
			hint_instance.show_hint(hint_text)

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_area = false
		if hint_instance:
			hint_instance.hide_hint()

func _input(event: InputEvent):
	if player_in_area and (event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E)):
		if is_sleep:
			trigger_sleep()
		else:
			teleport()

func trigger_sleep():
	if hint_instance:
		hint_instance.hide_hint()
	
	# Curtain transition, then advance day
	await SceneManager.fade_in_place({"pattern": "curtains"})
	GameState.advance_day()

func teleport():
	var player = get_tree().get_first_node_in_group("player")
	var dog = get_tree().get_first_node_in_group("dog")

	# Doors named "<Building>Enter"/"<Building>Exit" teleport to their partner
	# door's trigger; target_position is only a fallback for unpaired areas.
	var dest := target_position
	var entering := not is_exit
	var partner := _find_partner_door()
	if partner != null:
		dest = _area_trigger_position(partner)
		entering = _door_info()["entering"]

	# Flip the house flag BEFORE teleporting so listeners (dog routine) see
	# the change as soon as the player commits to entering/exiting.
	if is_house:
		GameState.Inside_house = entering

	if player:
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		player.global_position = dest
	# Leave the dog alone while it's sleeping — the player entering/exiting
	# the house shouldn't drag the dog off its sleep spot.
	if dog and not GameState.is_dog_sleeping:
		if dog is CharacterBody2D:
			dog.velocity = Vector2.ZERO
		if is_house and entering:
			dog.global_position = Vector2(560, -755)
		else:
			dog.global_position = dest + Vector2(40, 0)
		if "path" in dog:
			dog.path.clear()
	
	if hint_instance:
		hint_instance.hide_hint()
		if post_teleport_hint != "":
			# Use a small delay to ensure it shows after the fade out of previous hint
			await get_tree().create_timer(0.5).timeout
			hint_instance.show_hint(post_teleport_hint, 4.0)
	
	# Small delay to prevent immediate re-trigger if teleporting near another area
	player_in_area = false

# --- name-based door pairing -------------------------------------------------
# Doors pair by node name, case/space-insensitive: "HouseEnter" ↔ "HouseExit",
# "Burger enter" ↔ "Burger exit", etc.

func _door_info() -> Dictionary:
	var n := name.to_lower().replace(" ", "").replace("_", "")
	if n.ends_with("enter"):
		return {"prefix": n.trim_suffix("enter"), "entering": true}
	if n.ends_with("exit"):
		return {"prefix": n.trim_suffix("exit"), "entering": false}
	return {}

func _find_partner_door() -> Area2D:
	var info := _door_info()
	if info.is_empty():
		return null
	var want: String = info["prefix"] + ("exit" if info["entering"] else "enter")
	for sibling in get_parent().get_children():
		if sibling == self or not (sibling is Area2D):
			continue
		var sib_name := str(sibling.name).to_lower().replace(" ", "").replace("_", "")
		if sib_name == want:
			return sibling
	push_warning("interaction_area '%s': no partner door named like '%s' found" % [name, want])
	return null

static func _area_trigger_position(area: Area2D) -> Vector2:
	# Door Area2Ds sit at the scene origin with the offset on their collision
	# shape, so the shape's global position is the real trigger spot.
	for child in area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return (child as Node2D).global_position
	return area.global_position

func _exit_tree():
	if hint_instance:
		hint_instance.queue_free()
		hint_instance = null

# Updated on 2026-04-19
