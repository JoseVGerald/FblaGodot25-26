extends CharacterBody2D
## Manager NPC stationed at a job location (burger / bank / post).
##
## You can only interact with the manager of a job you actually signed up for.
## The first time you talk on a new job, they give a briefing (promotion ladder,
## benefits, how promotions work) via the vet-style bottom dialogue balloon.
## After that, talking to them works a shift:
##   • burger  -> launches the Burger Blitz mini-game (tips flow back to cash)
##   • bank/post -> runs a shift directly and confirms in the dialogue box
## (Bank and Paper Boy have no mini-game yet — proof of concept.)

## "burger", "bank" or "post" — maps to a job via GameState.JOB_FOR_LOCATION.
@export var location_key: String = ""

var tutorial_hint_scene = preload("res://scenes/ui/tutorial_hint.tscn")
var hint_instance: CanvasLayer = null
var player_in_area: bool = false
var _talked_once: bool = false

# Tracks the active balloon so double-pressing E won't spawn a duplicate.
var _active_balloon: CanvasLayer = null


func _ready() -> void:
	var area := get_node_or_null("InteractionArea") as Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	hint_instance = tutorial_hint_scene.instantiate()
	get_tree().root.add_child.call_deferred(hint_instance)


func _job_id() -> String:
	return GameState.JOB_FOR_LOCATION.get(location_key, "")


## You can only talk to the manager of the job you currently hold.
func _is_my_employer() -> bool:
	return GameState.active_job == _job_id()


func _hint_text() -> String:
	var mgr := GameState.get_job_manager_name(_job_id())
	if not GameState.has_manager_briefed(_job_id()):
		return "Press E to meet %s" % mgr
	return "Press E to work your shift"


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		if hint_instance and _is_my_employer() and not is_instance_valid(_active_balloon):
			hint_instance.show_hint(_hint_text())


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		if hint_instance:
			hint_instance.hide_hint()


func _input(event: InputEvent) -> void:
	if player_in_area and (event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E)):
		get_viewport().set_input_as_handled()
		_interact()


func _interact() -> void:
	# Ignore if a balloon is up, a conversation is active, or this isn't your boss.
	if is_instance_valid(_active_balloon) or GameState.is_dialogue_active:
		return
	if not _is_my_employer():
		return

	var job := _job_id()

	# First day on the job — the manager briefs you (no shift yet).
	if not GameState.has_manager_briefed(job):
		_show_dialogue(GameState.get_manager_dialogue_lines(location_key))
		GameState.mark_manager_briefed(job)
		return

	# Already briefed — talking works a shift, subject to the weekly limit.
	var block := GameState.shift_block_reason()
	if block != "":
		_show_dialogue([block])
		return

	# Dog-at-work check: if dog is in the scene and wasn't sent to daycare, the
	# boss notices and issues an escalating warning + fine (possibly a firing).
	if not GameState.dog_at_daycare and get_tree().get_nodes_in_group("dog").size() > 0:
		var intro := "Hey — is that your dog at work AGAIN?" if GameState.dog_at_work_offenses > 0 else "Hey — is that your dog? You can't bring your dog to work."
		# apply_dog_at_work_penalty() increments the offense count, so read the
		# intro first and let its return value carry the warning/fine details.
		_show_dialogue([
			intro,
			GameState.apply_dog_at_work_penalty()
		])
		return

	if location_key == "burger":
		# The grill mini-game IS the shift; it credits cash + tips on completion.
		var launcher = get_node_or_null("/root/BurgerLauncher")
		if launcher and launcher.has_method("open_for_work"):
			if hint_instance:
				hint_instance.hide_hint()
			launcher.open_for_work()
			GameState.worked_today = true
		else:
			_show_dialogue([GameState.complete_work_shift()])
			GameState.worked_today = true
	elif location_key == "bank":
		# The Loan Decision Desk mini-game IS the shift; it credits commission
		# on completion and can only be played once per in-game day.
		var loan_launcher = get_node_or_null("/root/LoanLauncher")
		if loan_launcher and loan_launcher.has_method("open_for_work"):
			if hint_instance:
				hint_instance.hide_hint()
			loan_launcher.open_for_work()
			GameState.worked_today = true
		else:
			_show_dialogue([GameState.complete_work_shift()])
			GameState.worked_today = true
	else:
		# Paper Boy: no mini-game yet — run the shift and confirm.
		_show_dialogue([GameState.complete_work_shift()])
		GameState.worked_today = true


## Show one or more lines in the vet-style bottom balloon.
func _show_dialogue(lines: Array) -> void:
	if lines.is_empty() or DialogueManager == null:
		return
	if hint_instance:
		hint_instance.hide_hint()
	if not _talked_once:
		_talked_once = true
		GameState.npcs_talked += 1
		GameState.check_achievements()
	var resource = DialogueManager.create_resource_from_text(_build_dialogue_text(lines, GameState.get_job_manager_name(_job_id())))
	var balloon_scene = load("res://dialogues/balloon.tscn")
	_active_balloon = balloon_scene.instantiate()
	_active_balloon.tree_exited.connect(func(): _active_balloon = null)
	get_tree().root.add_child(_active_balloon)
	_active_balloon.start(resource, "start")


## Compile the manager's lines into a Dialogue Manager script — one balloon
## page per line. Text is sanitised so it can't be misread as dialogue syntax.
func _build_dialogue_text(lines: Array, speaker: String) -> String:
	var out := "~ start\n"
	for line in lines:
		var safe := str(line).replace("\n", " ").replace("\t", " ").strip_edges()
		if safe.is_empty():
			continue
		out += "%s: %s\n" % [speaker, safe]
	out += "=> END\n"
	return out


func _exit_tree() -> void:
	if hint_instance:
		hint_instance.queue_free()
		hint_instance = null
