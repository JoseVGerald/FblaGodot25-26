extends Node
## Headless gameplay simulation for the Burger Blitz mini-game.
## Run: godot --headless --path . res://tools/BurgerSimTest.tscn

var _fails: int = 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("PASS: " + what)
	else:
		_fails += 1
		printerr("FAIL: " + what)


func _ready() -> void:
	await _run()
	if _fails == 0:
		print("ALL CHECKS GREEN")
	get_tree().quit(1 if _fails > 0 else 0)


func _run() -> void:
	var scene: PackedScene = load("res://burger_minigame/BurgerBlitz.tscn")
	var game: BBGame = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(game.playing, "game starts a day on ready")
	_check(game.queue.size() >= 1, "first customer spawned")
	_check(game.tab == "grill", "starts on grill tab")

	# --- grill flow ---
	game.grill_station.add_patty()
	_check(game.grill_station.slots[0] != null, "raw patty lands in slot 0")
	game.grill_station.update(3.5)  # ~56 cook units -> Medium
	var dn: String = BBData.doneness_from_cook(game.grill_station.slots[0]["cook"])
	_check(dn == "Medium", "patty reaches Medium after 3.5s (got %s)" % dn)
	game.grill_station.flip(0)
	_check(game.grill_station.slots[0]["even_sear"], "flip inside sear window grants even sear")
	game.grill_station.pull(0)
	_check(game.grill_station.slots[0] == null and game.grill_station.ready_patties.size() == 1, "pull moves patty to ready tray")

	# --- build flow ---
	game.build_station.add_ingredient("bunBottom")
	game.build_station.add_ready_patty(0)
	game.build_station.add_ingredient("cheese")
	game.build_station.add_ingredient("lettuce")
	game.build_station.add_ingredient("bunTop")
	_check(game.build_station.build.size() == 5, "five-item burger assembled")
	_check(game.tab == "build", "stacking auto-switches to assemble tab")

	# force the active order to match the build exactly -> 3 stars
	game.queue[0]["items"] = [
		{"type": "bunBottom"},
		{"type": "patty", "doneness": "Medium"},
		{"type": "cheese"},
		{"type": "lettuce"},
		{"type": "bunTop"},
	]
	var served_before: int = game.day_served
	game.serve_order()
	_check(game.day_served == served_before + 1, "serve resolves the order")
	_check(game.money > 0.0, "perfect serve pays out (cash %s)" % BBData.fmt_money(game.money))
	_check(game.day_stars == 3, "exact match scores 3 stars")
	await get_tree().create_timer(0.7).timeout
	_check(game.build_station.build.is_empty(), "plate cleared after serving")

	# --- bad inputs ---
	game.build_station.add_ingredient("cheese")
	game.build_station.add_ingredient("bunBottom")
	_check(game.build_station.build.size() == 1, "bottom bun rejected mid-stack")
	game.build_station.clear_plate()
	_check(game.build_station.build.is_empty(), "clear plate empties the stack")

	# --- L-key launcher integration ---
	var launcher: Node = get_node_or_null("/root/BurgerLauncher")
	_check(launcher != null, "BurgerLauncher autoload present")
	if launcher:
		launcher.open()
		_check(launcher.is_open(), "launcher opens overlay")
		_check(get_tree().paused, "tree paused while overlay open")
		launcher.close()
		await get_tree().process_frame
		_check(not launcher.is_open(), "launcher closes overlay")
		_check(not get_tree().paused, "tree unpaused after close")

	game.queue_free()
	await get_tree().process_frame
