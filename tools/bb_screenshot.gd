extends Node
## Captures Burger Blitz grill + assemble views to PNG for visual comparison.
## Run (windowed): godot --path . res://tools/BBScreenshot.tscn

const OUT_DIR := "/tmp/bb_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: PackedScene = load("res://burger_minigame/BurgerBlitz.tscn")
	var game: BBGame = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	# deterministic demo state matching the reference screenshots
	game.playing = false  # freeze the loop so patience/time don't move
	game.sfx.muted = true
	game.sfx.stop_sizzle()
	game._banner.visible = false
	game.day_time_left = 90.0
	game._populate_demo()
	game._update_hud()
	game._chips["time"].text = "90"

	game.set_tab("grill", true)
	await _snap("grill")

	game.set_tab("build", true)
	await _snap("build")

	# a populated grill + tray + half burger for the animation-rich view
	game.grill_station.add_patty()
	game.grill_station.add_patty()
	game.grill_station.slots[0]["cook"] = 60.0
	game.grill_station.slots[1]["cook"] = 110.0
	game.grill_station._render_slot(0)
	game.grill_station._render_slot(1)
	game.grill_station.ready_patties = [
		{"doneness": "Medium", "even_sear": true, "seed": 42},
		{"doneness": "Well", "even_sear": false, "seed": 99},
	]
	game.grill_station.render_tray()
	game.set_tab("grill", true)
	await _snap("grill_busy")

	game.build_station.build = [
		{"type": "bunBottom"},
		{"type": "patty", "doneness": "Medium", "seed": 42},
		{"type": "cheese"},
		{"type": "lettuce"},
		{"type": "tomato"},
	]
	game.build_station.render()
	game.set_tab("build", true)
	await _snap("build_stacked")

	get_tree().quit(0)


func _snap(tag: String) -> void:
	for i in range(4):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, tag])
	print("SAVED %s/%s.png" % [OUT_DIR, tag])
