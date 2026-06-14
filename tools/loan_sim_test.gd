extends Node
## Headless gameplay simulation for the Bank Blitz "Loan Decision Desk" mini-game
## and its GameState job integration.
## Run: godot --headless --path . res://tools/LoanSimTest.tscn

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


func _good_app() -> Dictionary:
	# Clean loan: low DTI, strong credit, productive, unsecured is fine.
	var app := {
		"name": "Mabel", "occupation": "Baker", "avatar_seed": 1234,
		"income": 5000, "debt": 500, "amount": 6000, "term": 36, "payment": 167,
		"credit_score": 720, "purpose": "Open a bakery", "purpose_banned": false,
		"collateral_label": "", "collateral_value": 0,
		"patience_max": 30.0, "patience": 30.0, "mood": "neutral", "resolved": false,
	}
	return LDData.eval_risk(app)


func _run() -> void:
	# ---------- policy / risk model (pure logic) ----------
	var good := _good_app()
	_check(good["correct"] == "approve", "clean loan should be approved")
	_check(good["dti_after"] < LDData.MAX_DTI, "clean loan is under the DTI cap")

	var banned := _good_app()
	banned["purpose_banned"] = true
	LDData.eval_risk(banned)
	_check(banned["correct"] == "deny", "speculative purpose forces a deny")

	var high_dti := _good_app()
	high_dti["debt"] = 4000  # (4000+167)/5000 = 83% DTI
	LDData.eval_risk(high_dti)
	_check(high_dti["correct"] == "deny", "DTI over 40% forces a deny")

	var low_credit := _good_app()
	low_credit["credit_score"] = 560
	LDData.eval_risk(low_credit)
	_check(low_credit["correct"] == "deny", "credit under 600 unsecured forces a deny")

	var low_credit_secured := _good_app()
	low_credit_secured["credit_score"] = 560
	low_credit_secured["collateral_value"] = 6500  # >= amount, so secured
	LDData.eval_risk(low_credit_secured)
	_check(low_credit_secured["secured"], "collateral >= amount marks the loan secured")
	_check(low_credit_secured["correct"] == "approve", "low credit but secured can be approved")

	# ---------- the mini-game ----------
	var scene: PackedScene = load("res://loan_minigame/LoanDesk.tscn")
	var game: LDGame = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(game.playing, "game starts a day on ready")
	_check(game.queue.size() >= 1, "first applicant spawned")
	_check(game.capital == LDGame.START_CAPITAL, "starts with full bank capital")

	# force a known GOOD loan at the window, then approve it
	game.queue[0] = _good_app()
	var cap_before: float = game.capital
	var pay_before: float = game.day_pay
	game.decide("approve")
	_check(game.day_correct == 1, "approving a good loan counts as a correct decision")
	_check(game.day_approved == 1, "approve tally increments")
	_check(game.capital > cap_before, "good approval earns the bank interest")
	_check(game.day_pay > pay_before, "good approval pays the player commission")
	await get_tree().create_timer(0.95).timeout
	_check(not game.deciding, "deciding clears after the resolve delay")

	# force a BAD loan, then DENY it (correct call)
	if game.queue.is_empty():
		game.queue.append(_good_app())
	var bad := _good_app()
	bad["purpose_banned"] = true
	LDData.eval_risk(bad)
	game.queue[0] = bad
	game.deciding = false
	var correct_before: int = game.day_correct
	game.decide("deny")
	_check(game.day_correct == correct_before + 1, "denying a bad loan is a correct decision")
	_check(game.day_denied == 1, "deny tally increments")
	await get_tree().create_timer(0.95).timeout

	# policy modal toggles + pauses the timer-driven loop
	game.toggle_policy()
	_check(game.help_open, "policy modal opens")
	game.toggle_policy()
	_check(not game.help_open, "policy modal closes")

	game.queue_free()
	await get_tree().process_frame

	# ---------- GameState job integration ----------
	var gs := get_node_or_null("/root/GameState")
	_check(gs != null, "GameState autoload present")
	gs.active_job = "bank_accountant"
	gs.selected_pathway = "adult"
	gs.work_days_scheduled = 5
	gs.days_worked_this_week = 0
	gs.current_day = 5
	gs.bank_days_completed = 0
	gs.bank_last_shift_day = -1
	var money_before: float = gs.money
	gs.complete_bank_work_shift(20.0, 4.0)
	_check(gs.money > money_before, "bank shift credits the player's cash")
	_check(gs.bank_days_completed == 1, "bank shift increments the desk-day counter")
	_check(gs.bank_last_shift_day == 5, "bank shift records the in-game day worked")
	_check(gs.shift_block_reason() != "", "cannot work the desk twice in one in-game day")
	gs.current_day = 6
	_check(gs.shift_block_reason() == "", "the next in-game day reopens the desk")

	# ---------- launcher integration ----------
	var launcher: Node = get_node_or_null("/root/LoanLauncher")
	_check(launcher != null, "LoanLauncher autoload present")
	if launcher:
		gs.bank_days_completed = 2
		launcher.open_for_work()
		_check(launcher.is_open(), "launcher opens the work overlay")
		_check(launcher.work_mode, "open_for_work flags a paid shift")
		_check(get_tree().paused, "tree paused while overlay open")
		var node = launcher._layer.get_child(0)
		_check(int(node.day) == 3, "desk difficulty day = bank_days_completed + 1")
		launcher.close()
		await get_tree().process_frame
		_check(not launcher.is_open(), "launcher closes overlay")
		_check(not launcher.work_mode, "work_mode clears on close")
		_check(not get_tree().paused, "tree unpaused after close")
