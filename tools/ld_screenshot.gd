extends Node
## Captures the Loan Decision Desk play view + policy modal to PNG.
## Run (windowed): godot --path . res://tools/LDScreenshot.tscn

const OUT_DIR := "/tmp/ld_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: PackedScene = load("res://loan_minigame/LoanDesk.tscn")
	var game: LDGame = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	# deterministic demo state
	game.playing = false  # freeze the loop so patience/time don't move
	if game.sfx:
		game.sfx.muted = true
	game._banner.visible = false
	game.day = 2
	game.capital = 6240.0
	game.score = 360
	game.streak = 3
	game.day_approved = 2
	game.day_denied = 1
	game.day_time_left = 78.0
	game.day_applicants = 7
	# a clear, readable application at the window
	var app := LDData.generate_application(2)
	app["name"] = "Mabel"
	app["occupation"] = "Baker"
	app["income"] = 5200
	app["debt"] = 540
	app["amount"] = 6000
	app["term"] = 36
	app["payment"] = 167
	app["credit_score"] = 712
	app["purpose"] = "Open a bakery"
	app["purpose_banned"] = false
	app["collateral_label"] = "Workshop tools"
	app["collateral_value"] = 4200
	LDData.eval_risk(app)
	game.queue = [app, {"avatar_seed": 4242, "mood": "neutral"}, {"avatar_seed": 9001, "mood": "neutral"}]
	game.render_active()
	game._update_hud()
	await _snap("desk")

	game._open_policy()
	await _snap("policy")

	get_tree().quit(0)


func _snap(tag: String) -> void:
	for i in range(5):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, tag])
	print("SAVED %s/%s.png" % [OUT_DIR, tag])
