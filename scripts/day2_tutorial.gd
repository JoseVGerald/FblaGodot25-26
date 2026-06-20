# Day 2 Tutorial — the first real work day.
# Fires the morning after the player first sleeps (current_day == 1), for the
# teenager and adult pathways only. The teen is woken by Mom; the adult gets an
# inner monologue. Both are reminded to drop the dog at daycare before work, then
# guided along the path to their specific job building.
extends Node

var tutorial_hint_scene = preload("res://scenes/ui/tutorial_hint.tscn")
var tutorial_hint: CanvasLayer = null

var main_game: Node = null
var hud: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_tutorial(game_main: Node, game_hud: CanvasLayer) -> void:
	main_game = game_main
	hud = game_hud

	tutorial_hint = tutorial_hint_scene.instantiate()
	tutorial_hint.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(tutorial_hint)

	# Let the scene settle after the day rolled over.
	await get_tree().create_timer(0.5, false, true).timeout

	# 1. Wake-up dialogue — blocks movement until dismissed.
	GameState.tutorial_blocks_movement = true
	if GameState.selected_pathway == "adult":
		await _run_dialogue("day2_adult_wake")
	else:
		await _run_dialogue("day2_teen_wake")
	GameState.tutorial_blocks_movement = false

	# 2. Spotlight the Daycare button — then, once the popup opens, move the
	# spotlight onto the popup itself so it's bright and clickable (the button
	# cutout otherwise dims and blocks the menu, which sits on a lower layer).
	if hud and "daycare_btn" in hud and hud.daycare_btn and not GameState.daycare_used_today:
		tutorial_hint.show_hint("Drop your buddy at daycare before work!")
		tutorial_hint.set_highlight_target(hud.daycare_btn)
		var on_panel := false
		# Inside_house is the flag the house door teleport actually toggles
		# (is_in_house is the Area2D flag and isn't updated by the teleport).
		while GameState.Inside_house and not GameState.daycare_used_today:
			var menu = hud.daycare_menu_instance if "daycare_menu_instance" in hud else null
			var menu_open: bool = menu != null and menu.visible
			if menu_open and not on_panel and "panel" in menu and menu.panel:
				tutorial_hint.set_highlight_target(menu.panel)
				on_panel = true
			elif not menu_open and on_panel:
				# Closed without choosing — point back at the button.
				tutorial_hint.set_highlight_target(hud.daycare_btn)
				on_panel = false
			await get_tree().process_frame
		tutorial_hint.set_highlight_target(null)
		tutorial_hint.hide_hint()

	# 3. Once they step out of the house, point them to their workplace.
	while GameState.Inside_house:
		await get_tree().process_frame

	_show_job_path_and_hint()

	# 4. Keep the path up until they clock in (worked_today) or lose the job.
	# Generous safety cap so it can't linger forever.
	var elapsed := 0.0
	while not GameState.worked_today and GameState.active_job != "none" and elapsed < 600.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_finish()


func _show_job_path_and_hint() -> void:
	var location := "your job"
	var prog: Dictionary = GameState.JOB_PROGRESSION.get(GameState.active_job, {})
	if prog.has("location"):
		location = str(prog["location"])
	var node_name := _path_node_for_job(GameState.active_job)
	if main_game and main_game.has_method("show_job_path") and node_name != "":
		main_game.show_job_path(node_name)
	if tutorial_hint:
		tutorial_hint.show_hint("Follow the path to the %s." % location)


func _path_node_for_job(job: String) -> String:
	match job:
		"burger_cashier": return "Burger path"
		"bank_accountant": return "bank path"
		"news_boy": return "post path"
	return ""


func _run_dialogue(title_name: String) -> void:
	if DialogueManager == null:
		return
	var dialogue_resource = load("res://dialogues/tutorial.dialogue")
	var balloon_scene = load("res://dialogues/balloon.tscn")
	var balloon = balloon_scene.instantiate()
	get_tree().root.add_child(balloon)
	balloon.start(dialogue_resource, title_name)
	# Wait until the conversation finishes (balloon leaves the tree).
	await balloon.tree_exited


func _finish() -> void:
	if main_game and main_game.has_method("hide_job_path"):
		main_game.hide_job_path()
	if tutorial_hint:
		tutorial_hint.hide_hint()
		await get_tree().create_timer(0.5, false, true).timeout
		if is_instance_valid(tutorial_hint):
			tutorial_hint.queue_free()
		tutorial_hint = null
	queue_free()
