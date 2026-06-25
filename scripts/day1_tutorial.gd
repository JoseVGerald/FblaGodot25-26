# Day 1 Tutorial Controller
# Manages conversational or legacy tutorials on the first day based on the chosen pathway.
extends Node

var tutorial_hint_scene = load("res://scenes/ui/tutorial_hint.tscn")
var tutorial_hint: CanvasLayer = null

var current_step: int = 1
var tutorial_active: bool = false

# References to game elements
var dog: CharacterBody2D = null
var hud: CanvasLayer = null

signal tutorial_completed

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_tutorial(game_dog: CharacterBody2D, game_hud: CanvasLayer):
	"""Initialize and start the Day 1 tutorial."""
	dog = game_dog
	hud = game_hud
	tutorial_active = true
	current_step = 1
	
	# Connect to the job selection trigger signal in GameState
	if not GameState.job_selection_requested.is_connected(_on_job_selection_requested):
		GameState.job_selection_requested.connect(_on_job_selection_requested)
	
	# Create tutorial hint UI for highlights and prompts
	tutorial_hint = tutorial_hint_scene.instantiate()
	tutorial_hint.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(tutorial_hint)
	
	# Wait for scene to render
	await get_tree().create_timer(1.0, false, true).timeout
	
	# Block movement but allow menu inputs
	GameState.tutorial_blocks_movement = true
	
	print("[Tutorial] Starting tutorial from Step 1 (Pathway: ", GameState.selected_pathway, ")")
	run_step()

func run_dialogue(title_name: String) -> void:
	"""Helper to play a DialogueManager conversation branch and wait for completion."""
	if DialogueManager == null:
		return
		
	var dialogue_resource = load("res://dialogues/tutorial.dialogue")
	var balloon_scene = load("res://dialogues/balloon.tscn")
	var balloon = balloon_scene.instantiate()
	
	GameState.tutorial_blocks_movement = true
	get_tree().root.add_child(balloon)
	balloon.start(dialogue_resource, title_name)
	
	# Wait until conversation finishes (the balloon exits the tree)
	await balloon.tree_exited

func _on_job_selection_requested() -> void:
	"""Spawns the Job Selection screen overlay."""
	var job_menu_scene = load("res://scenes/ui/JobSelectionMenu.tscn")
	if job_menu_scene:
		var job_menu = job_menu_scene.instantiate()
		get_tree().root.add_child(job_menu)
		print("[Tutorial] Job selection screen overlaid successfully.")

func run_step():
	"""Execute pathway-specific conversational or legacy tutorial steps."""
	print("[Tutorial] Running step ", current_step)
	var pathway = GameState.selected_pathway
	
	if pathway == "adult":
		run_adult_step()
	else:
		run_kid_teen_step()

func run_kid_teen_step():
	"""Conversational dialogue pathway for Kid & Teenager."""
	var pathway = GameState.selected_pathway
	match current_step:
		1:
			# Step 1: Conversational Intro, then wait for Supplies Menu (swapped to be first)
			if pathway == "kid":
				await run_dialogue("kid_step1")
			else:
				await run_dialogue("teen_step1")
				
			# Spotlight Supplies button
			if tutorial_hint:
				tutorial_hint.show_hint("Press Supplies to see your supplies.")
				if hud and "supplies_btn" in hud and hud.supplies_btn:
					tutorial_hint.set_highlight_target(hud.supplies_btn)
			
			# Wait for Supplies Menu to be visible
			var supplies_open = false
			while not supplies_open:
				await get_tree().process_frame
				if hud and hud.supplies_menu_instance and hud.supplies_menu_instance.get_menu_visible():
					supplies_open = true
			
			if tutorial_hint:
				tutorial_hint.set_highlight_target(null)
				tutorial_hint.show_hint("Close the Supplies menu to continue.")
			
			# Wait for Supplies Menu to be closed
			while hud and hud.supplies_menu_instance and hud.supplies_menu_instance.get_menu_visible():
				await get_tree().process_frame
			
			if tutorial_hint:
				tutorial_hint.hide_hint()
			advance_step()
		
		2:
			# Step 2: Explain needs, then spotlight Needs button (swapped to be second)
			if pathway == "kid":
				await run_dialogue("kid_step2")
			else:
				await run_dialogue("teen_step2")
				
			# Note: Supplies menu was closed by user in Step 1
			
			# Spotlight the Needs button
			if tutorial_hint:
				tutorial_hint.show_hint("Press P or Needs to open pet needs.")
				if hud and "needs_btn" in hud and hud.needs_btn:
					tutorial_hint.set_highlight_target(hud.needs_btn)
			
			# Wait for Needs Menu to be visible
			var menu_open = false
			while not menu_open:
				await get_tree().process_frame
				if dog and dog.needs_menu_instance and dog.needs_menu_instance.panel.visible:
					menu_open = true
			
			if tutorial_hint:
				tutorial_hint.set_highlight_target(null)
				tutorial_hint.show_hint("Close the Needs menu to continue.")
			
			# Wait for Needs Menu to be closed
			while dog and dog.needs_menu_instance and dog.needs_menu_instance.panel.visible:
				await get_tree().process_frame
				
			if tutorial_hint:
				tutorial_hint.hide_hint()
			advance_step()
		
		3:
			# Step 3: Explain inventory, close Needs, and comment out Finances menu step
			if pathway == "kid":
				await run_dialogue("kid_step3")
			else:
				await run_dialogue("teen_step3")
				
			# Note: Needs menu was closed by user in Step 2
					
			# [FINANCES TUTORIAL STEP COMMENTED OUT]
			# if tutorial_hint:
			# 	tutorial_hint.show_hint("Click Finances to see your finances.")
			# 	if hud and "finance_btn" in hud and hud.finance_btn:
			# 		tutorial_hint.set_highlight_target(hud.finance_btn)
			# if hud:
			# 	await hud.finance_menu_opened
			# else:
			# 	await get_tree().create_timer(3.0, false, true).timeout
			# if tutorial_hint:
			# 	tutorial_hint.set_highlight_target(null)
			# 	tutorial_hint.hide_hint()
			
			# Proceed directly to Dialogue/Job selection sequence (previously Step 4)
			if pathway == "kid":
				await run_dialogue("kid_step4")
				advance_step()
			else:
				# Teenager triggers job selection
				await run_dialogue("teen_step4")
				
				# Wait until job is chosen
				while GameState.active_job == "none":
					await get_tree().process_frame
					
				await get_tree().create_timer(0.5, false, true).timeout
				await run_dialogue("teen_step5")
				advance_step()
		
		4:
			# Complete!
			end_tutorial()

func run_adult_step():
	"""Legacy text-only pathway for independent Adults, starting with job selection."""
	match current_step:
		1:
			# Step 1: Trigger Job Selection immediately at start
			GameState.trigger_job_selection()
			
			# Wait until job is chosen
			while GameState.active_job == "none":
				await get_tree().process_frame
				
			advance_step()
		
		2:
			# Step 2: Open Supplies (swapped to be first)
			if tutorial_hint:
				tutorial_hint.show_hint("Press Supplies to see your supplies.")
				if hud and "supplies_btn" in hud and hud.supplies_btn:
					tutorial_hint.set_highlight_target(hud.supplies_btn)
			
			var supplies_open = false
			while not supplies_open:
				await get_tree().process_frame
				if hud and hud.supplies_menu_instance and hud.supplies_menu_instance.get_menu_visible():
					supplies_open = true
					
			if tutorial_hint:
				if hud and hud.supplies_menu_instance:
					tutorial_hint.set_highlight_target(hud.supplies_menu_instance.panel)
				tutorial_hint.show_hint("This shows your supplies. Food, water, and medication are essential to care for your buddy.", 4.0)
				await tutorial_hint.hint_hidden
				tutorial_hint.set_highlight_target(null)
				tutorial_hint.show_hint("Close the Supplies menu to continue.")
				
			# Wait for Supplies Menu to be closed
			while hud and hud.supplies_menu_instance and hud.supplies_menu_instance.get_menu_visible():
				await get_tree().process_frame
				
			if tutorial_hint:
				tutorial_hint.hide_hint()
			advance_step()
		
		3:
			# Step 3: Open Needs (swapped to be second)
			if tutorial_hint:
				tutorial_hint.show_hint("Press P or Needs to open pet needs.")
				if hud and "needs_btn" in hud and hud.needs_btn:
					tutorial_hint.set_highlight_target(hud.needs_btn)
			
			var menu_open = false
			while not menu_open:
				await get_tree().process_frame
				if dog and dog.needs_menu_instance and dog.needs_menu_instance.panel.visible:
					menu_open = true
			
			if tutorial_hint:
				tutorial_hint.set_highlight_target(null)
			advance_step()
		
		4:
			# Step 4: Needs Explanation
			if tutorial_hint and dog and dog.needs_menu_instance:
				tutorial_hint.set_highlight_target(dog.needs_menu_instance.panel)
			if tutorial_hint:
				tutorial_hint.show_hint("This tells you the needs of your little buddy. When food or water is low, take them back home to feed them.", 4.0)
				await tutorial_hint.hint_hidden
			advance_step()
		
		5:
			# Step 5: Needs Energy & Health
			if tutorial_hint and dog and dog.needs_menu_instance:
				tutorial_hint.set_highlight_target(dog.needs_menu_instance.panel)
			if tutorial_hint:
				tutorial_hint.show_hint("When their energy is low, take them home to sleep. If health is low, take them to the vet.", 6.0)
				await tutorial_hint.hint_hidden
				
			if tutorial_hint:
				tutorial_hint.set_highlight_target(null)
				tutorial_hint.show_hint("Close the Needs menu to continue.")
			
			# Wait for Needs Menu to be closed
			while dog and dog.needs_menu_instance and dog.needs_menu_instance.panel.visible:
				await get_tree().process_frame
				
			if tutorial_hint:
				tutorial_hint.hide_hint()
			
			# [FINANCES TUTORIAL STEP COMMENTED OUT]
			# advance_step()
			# ... proceed directly to complete
			advance_step()
		
		6:
			# Complete!
			end_tutorial()

func advance_step():
	current_step += 1
	run_step()

func end_tutorial():
	"""Clean up main tutorial and start vet visit sequence."""
	tutorial_active = false
	GameState.is_tutorial_complete = true
	
	# Allow player to walk freely
	GameState.tutorial_blocks_movement = false

	# Unlock starting achievements
	GameState._unlock("Graduated")
	GameState._unlock("Week One Down")

	tutorial_completed.emit()
	
	# Guides player directly to the vet (without emojis)
	await show_vet_hints()

func show_vet_hints():
	"""Show hints guiding player to vet."""
	if tutorial_hint:
		tutorial_hint.show_hint("Your pet's health is low. Let's go and take them to the vet!", 4.0)
		await tutorial_hint.hint_hidden
	
	if tutorial_hint:
		tutorial_hint.show_hint("Follow the path to the vet.", 4.0)
		await tutorial_hint.hint_hidden
	
	if tutorial_hint:
		tutorial_hint.queue_free()
		tutorial_hint = null
