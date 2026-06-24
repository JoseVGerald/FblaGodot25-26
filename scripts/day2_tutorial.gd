# Day 0 work tutorial — fires the moment the player first leaves the shop,
# for the teenager and adult pathways only (the kid has no job). Merged from the
# old "Day 2" first-work-day flow so the whole tutorial now happens on day zero.
#
# Flow:
#   1. Mom messages the teen (an inner monologue for the adult) that the shop is
#      close to their workplace and they should pick up a shift there.
#   2. After they dismiss it, they're told to drop the dog at daycare, the
#      daycare button is spotlighted, and the path to their job appears.
#   3. Once the dog is at daycare the hint switches to "Follow the path…", and the
#      path stays up until they clock in (worked_today) or lose the job.
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

	# Let the shop menu finish closing before Mom speaks up.
	await get_tree().create_timer(0.5, false, true).timeout

	# 1. Shop-is-close-to-your-job message — blocks movement until dismissed.
	GameState.tutorial_blocks_movement = true
	if GameState.selected_pathway == "adult":
		await _run_dialogue("day0_adult_work")
	else:
		await _run_dialogue("day0_teen_work")
	GameState.tutorial_blocks_movement = false

	# 2. Tell them to drop the buddy at daycare and reveal the path to work.
	_show_job_path_and_hint()

	# 3. Spotlight the Daycare button until the buddy is dropped off. Once the
	# daycare popup opens, move the spotlight onto the popup itself so it stays
	# bright and clickable.
	if hud and "daycare_btn" in hud and hud.daycare_btn and not GameState.daycare_used_today:
		if tutorial_hint:
			tutorial_hint.show_hint("Drop your buddy at daycare before work!")
			tutorial_hint.set_highlight_target(hud.daycare_btn)
		var on_panel := false
		while not GameState.daycare_used_today:
			var menu = hud.daycare_menu_instance if "daycare_menu_instance" in hud else null
			var menu_open: bool = menu != null and menu.visible
			if menu_open and not on_panel and "panel" in menu and menu.panel:
				if tutorial_hint:
					tutorial_hint.set_highlight_target(menu.panel)
				on_panel = true
			elif not menu_open and on_panel:
				# Closed without choosing — point back at the button.
				if tutorial_hint:
					tutorial_hint.set_highlight_target(hud.daycare_btn)
				on_panel = false
			await get_tree().process_frame
		if tutorial_hint:
			tutorial_hint.set_highlight_target(null)

	# 4. Buddy is dropped off — switch the hint to the path-following prompt and
	# keep the path up until they clock in (worked_today) or lose the job.
	var location := _job_location()
	if tutorial_hint:
		tutorial_hint.show_hint("Follow the path to the %s." % location)

	var elapsed := 0.0
	while not GameState.worked_today and GameState.active_job != "none" and elapsed < 600.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_finish()


func _job_location() -> String:
	var location := "your job"
	var prog: Dictionary = GameState.JOB_PROGRESSION.get(GameState.active_job, {})
	if prog.has("location"):
		location = str(prog["location"])
	return location


func _show_job_path_and_hint() -> void:
	var node_name := _path_node_for_job(GameState.active_job)
	if main_game and main_game.has_method("show_job_path") and node_name != "":
		main_game.show_job_path(node_name)


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
