class_name DoorArea
extends Area2D
## Attach this to any Area2D whose name ends with "Enter" or "Exit".
## Naming convention: BurgersEnter / BurgersExit, BankEnter / BankExit, etc.
##
## Enter  → teleports player to matching Exit.global_position + (0, +10)  (10 px below exit)
## Exit   → teleports player to matching Enter.global_position + (0, -10) (10 px above entrance)

const ENTER_SPAWN_OFFSET: Vector2 = Vector2(0.0, 10.0)
const EXIT_SPAWN_OFFSET: Vector2 = Vector2(0.0, -10.0)

## Seconds the door is blocked after a teleport (prevents re-triggering).
const COOLDOWN: float = 0.5

var _is_enter: bool = false
var _building_prefix: String = ""
var _partner: Area2D = null
var _on_cooldown: bool = false


func _ready() -> void:
	var n: String = name
	if n.ends_with("Enter"):
		_is_enter = true
		_building_prefix = n.trim_suffix("Enter")
	elif n.ends_with("Exit"):
		_is_enter = false
		_building_prefix = n.trim_suffix("Exit")
	else:
		push_warning("DoorArea '%s': node name must end with 'Enter' or 'Exit'" % n)
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _on_cooldown:
		return
	if not body.is_in_group("player"):
		return

	if _partner == null:
		_partner = _find_partner()
	if _partner == null:
		push_warning("DoorArea '%s': partner not found yet — is it in the scene?" % name)
		return

	var dest: Vector2 = _partner.global_position
	if _is_enter:
		dest += ENTER_SPAWN_OFFSET   # arriving at interior: 10 px below the exit marker
	else:
		dest += EXIT_SPAWN_OFFSET    # returning to world:   10 px above the entrance marker

	body.global_position = dest
	_start_cooldown()

	# Also cool the partner so it doesn't fire back immediately.
	var partner_door: DoorArea = _partner as DoorArea
	if partner_door != null:
		partner_door._start_cooldown()


func _start_cooldown() -> void:
	_on_cooldown = true
	await get_tree().create_timer(COOLDOWN).timeout
	_on_cooldown = false


func _find_partner() -> Area2D:
	var partner_name: String = _building_prefix + ("Exit" if _is_enter else "Enter")
	# Search the whole scene tree so Enter and Exit can live in different sub-scenes.
	var hits: Array[Node] = get_tree().root.find_children(partner_name, "Area2D", true, false)
	if hits.is_empty():
		return null
	return hits[0] as Area2D
