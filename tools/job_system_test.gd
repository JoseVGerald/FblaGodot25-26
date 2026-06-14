extends Node
## Headless smoke test for the career / manager-NPC / tips system.
## Run with:
##   Godot --headless --path . tools/JobSystemTest.tscn
## Boots the full engine so autoloads (GameState, DialogueManager) are live.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	print("\n========== JOB SYSTEM TEST ==========")
	_test_dialogue_compiles()
	_test_boost_multiplier()
	_test_work_shift_and_tips()
	await _test_burger_workmode_wiring()
	_test_promotion_progress()
	_test_request_outcomes()
	_test_inverse_fire_correlation()
	_test_shift_limits()
	_test_bank_interest()
	_test_available_jobs()
	print("------------------------------------")
	print("RESULT: %d passed, %d failed" % [_pass, _fail])
	print("====================================\n")
	get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)


func _build_text(lines: Array, speaker: String) -> String:
	var out := "~ start\n"
	for line in lines:
		var safe := str(line).replace("\n", " ").replace("\t", " ").strip_edges()
		if safe.is_empty():
			continue
		out += "%s: %s\n" % [speaker, safe]
	out += "=> END\n"
	return out


func _compiles(lines: Array, speaker: String) -> bool:
	var res = DialogueManager.create_resource_from_text(_build_text(lines, speaker))
	return res != null and res.lines.size() > 0


func _test_dialogue_compiles() -> void:
	print("[Manager dialogue compiles in every state]")
	GameState.reset_all()
	for loc in ["burger", "bank", "post"]:
		var job: String = GameState.JOB_FOR_LOCATION[loc]
		var mgr := GameState.get_job_manager_name(job)
		_check("%s recruiting compiles" % loc, _compiles(GameState.get_manager_dialogue_lines(loc), mgr))
		GameState.active_job = job
		GameState.start_job(job)
		var brief := GameState.get_manager_dialogue_lines(loc)
		_check("%s briefing >= 5 lines" % loc, brief.size() >= 5)
		_check("%s briefing compiles" % loc, _compiles(brief, mgr))
		GameState.mark_manager_briefed(job)
		_check("%s status compiles" % loc, _compiles(GameState.get_manager_dialogue_lines(loc), mgr))
		GameState.active_job = "none"


func _test_boost_multiplier() -> void:
	print("[Promotion boost multiplier scales pay]")
	GameState.reset_all()
	GameState.promotion_boost_percent = 40.0
	GameState.active_job = "bank_accountant"
	GameState.start_job("bank_accountant")
	GameState.bank_accountant_pay = 25.0
	_check("rank1 mult = 1.0", abs(GameState.get_promotion_multiplier("bank_accountant") - 1.0) < 0.001)
	_check("rank1 pay = base 25", abs(GameState.get_current_job_pay() - 25.0) < 0.001)
	GameState.job_levels["bank_accountant"] = 2
	_check("rank2 mult = 1.4 (40% boost)", abs(GameState.get_promotion_multiplier("bank_accountant") - 1.4) < 0.001)
	_check("rank2 pay = 35", abs(GameState.get_current_job_pay() - 35.0) < 0.001)
	# Boost percent is configurable.
	GameState.promotion_boost_percent = 100.0
	_check("rank2 mult = 2.0 at 100% boost", abs(GameState.get_promotion_multiplier("bank_accountant") - 2.0) < 0.001)
	_check("rank2 pay = 50 at 100% boost", abs(GameState.get_current_job_pay() - 50.0) < 0.001)


func _test_work_shift_and_tips() -> void:
	print("[Shifts pay out; burger tips come from the mini-game]")
	GameState.reset_all()
	# Bank shift via complete_work_shift
	GameState.active_job = "bank_accountant"
	GameState.start_job("bank_accountant")
	GameState.money = 0.0
	var summary := GameState.complete_work_shift()
	_check("bank shift paid base 25", abs(GameState.money - 25.0) < 0.001)
	_check("bank shift incremented days", GameState.days_worked_this_week == 1)
	_check("shift summary is a string", summary is String and summary.length() > 0)

	# Burger shift credited from mini-game earnings + tips (rank1 mult = 1.0)
	GameState.reset_all()
	GameState.active_job = "burger_cashier"
	GameState.start_job("burger_cashier")
	GameState.money = 0.0
	GameState.total_tips_earned = 0.0
	GameState.food = 0
	GameState.complete_burger_work_shift(10.00, 4.00)
	_check("burger earnings credited (10.00)", abs(GameState.money - 10.00) < 0.001)
	_check("tips from mini-game tracked (4.00)", abs(GameState.total_tips_earned - 4.00) < 0.001)
	_check("burger shift gave employee meal", GameState.food >= 1)
	_check("burger shift incremented days", GameState.days_worked_this_week == 1)

	# At rank 2 (40% boost) the SAME mini-game result pays more.
	GameState.money = 0.0
	GameState.total_tips_earned = 0.0
	GameState.job_levels["burger_cashier"] = 2
	GameState.complete_burger_work_shift(10.00, 4.00)
	_check("rank2 burger earnings boosted (14.00)", abs(GameState.money - 14.00) < 0.001)
	_check("rank2 tips boosted (5.60)", abs(GameState.total_tips_earned - 5.60) < 0.001)


func _test_burger_workmode_wiring() -> void:
	print("[Burger mini-game shift credits GameState in work mode]")
	GameState.reset_all()
	GameState.active_job = "burger_cashier"
	GameState.start_job("burger_cashier")
	GameState.money = 0.0
	GameState.total_tips_earned = 0.0
	var launcher = get_node_or_null("/root/BurgerLauncher")
	_check("BurgerLauncher autoload present", launcher != null)
	if launcher == null:
		return
	_check("launcher has open_for_work()", launcher.has_method("open_for_work"))
	launcher.work_mode = true
	var g = load("res://burger_minigame/BurgerBlitz.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	# Simulate a finished shift, then end it the way the auto-flow would.
	g.day_earnings = 20.0
	g.day_tips = 6.0
	g.playing = true
	g.end_day("clear")
	await get_tree().process_frame
	_check("work-mode shift credited earnings (20.00)", abs(GameState.money - 20.0) < 0.001)
	_check("work-mode shift credited tips (6.00)", abs(GameState.total_tips_earned - 6.0) < 0.001)
	_check("work-mode shift incremented days", GameState.days_worked_this_week == 1)
	if launcher:
		launcher.work_mode = false
	g.queue_free()
	await get_tree().process_frame


func _test_promotion_progress() -> void:
	print("[Promotion chance accrues from good work and auto-promotes]")
	GameState.reset_all()
	GameState.active_job = "post"  # invalid id guard
	GameState.active_job = "news_boy"
	GameState.start_job("news_boy")
	_check("standing starts at 0", GameState.get_promotion_standing("news_boy") == 0.0)
	# Working shifts raises standing (each shift adds, diminishing by rank).
	var auto_promoted := false
	for i in range(60):
		var lvl_before := GameState.get_job_level("news_boy")
		GameState.complete_work_shift()
		if GameState.get_job_level("news_boy") > lvl_before:
			auto_promoted = true
			_check("standing resets to 0 after auto-promotion", GameState.get_promotion_standing("news_boy") == 0.0)
			break
	_check("a shift eventually auto-promotes", auto_promoted)
	_check("level advanced past 1", GameState.get_job_level("news_boy") >= 2)


func _test_request_outcomes() -> void:
	print("[Ask-for-promotion can promote, fire, or stall; top rank is safe]")
	# Eventually promotes when retried.
	var promoted := false
	for attempt in range(300):
		GameState.reset_all()
		GameState.active_job = "burger_cashier"
		GameState.start_job("burger_cashier")
		GameState.job_promo_chance["burger_cashier"] = 0.9  # strong standing
		var r := GameState.request_promotion()
		if r.get("ok", false):
			promoted = true
			_check("promotion advanced rank to 2", GameState.get_job_level("burger_cashier") == 2)
			break
	_check("ask-for-promotion eventually succeeds", promoted)

	# Top rank never fires, never promotes further.
	GameState.reset_all()
	GameState.active_job = "burger_cashier"
	GameState.start_job("burger_cashier")
	GameState.job_levels["burger_cashier"] = 3
	var top := GameState.request_promotion()
	_check("top rank not fired", not top.get("fired", false))
	_check("top rank not promoted", not top.get("ok", false))

	# Asking eventually gets you fired, which clears + locks the job.
	var fired := false
	for attempt in range(300):
		GameState.reset_all()
		GameState.active_job = "burger_cashier"
		GameState.start_job("burger_cashier")
		GameState.job_promo_chance["burger_cashier"] = 0.0  # weak standing -> risky
		var rr := GameState.request_raise()
		if rr.get("fired", false):
			fired = true
			break
	_check("asking with weak standing eventually fires", fired)
	_check("fired clears active_job", GameState.active_job == "none")
	_check("fired job locked in history", "burger_cashier" in GameState.fired_jobs_history)


func _test_inverse_fire_correlation() -> void:
	print("[Fire chance is inversely correlated with standing]")
	var fires_low := 0
	var fires_high := 0
	for i in range(400):
		GameState.reset_all()
		GameState.active_job = "bank_accountant"
		GameState.start_job("bank_accountant")
		GameState.job_promo_chance["bank_accountant"] = 0.0
		if GameState.request_raise().get("fired", false):
			fires_low += 1
	for i in range(400):
		GameState.reset_all()
		GameState.active_job = "bank_accountant"
		GameState.start_job("bank_accountant")
		GameState.job_promo_chance["bank_accountant"] = 0.9
		if GameState.request_raise().get("fired", false):
			fires_high += 1
	print("    (low-standing fires=%d, high-standing fires=%d / 400)" % [fires_low, fires_high])
	_check("low standing fires far more than high standing", fires_low > fires_high + 50)


func _test_shift_limits() -> void:
	print("[Teen over-work and weekly limits]")
	GameState.reset_all()
	GameState.selected_pathway = "teenager"
	GameState.active_job = "burger_cashier"
	GameState.start_job("burger_cashier")
	GameState.days_worked_this_week = 0
	_check("teen weekly limit is 3", GameState.weekly_shift_limit() == 3)
	_check("teen can work at 0 days", GameState.shift_block_reason() == "")
	GameState.days_worked_this_week = 2
	_check("teen can work at 2 days", GameState.shift_block_reason() == "")
	GameState.days_worked_this_week = 3
	_check("teen blocked at 3 days (gets a message)", GameState.shift_block_reason() != "")
	# Adults follow their scheduled count.
	GameState.selected_pathway = "adult"
	GameState.work_days_scheduled = 5
	GameState.days_worked_this_week = 4
	_check("adult limit follows schedule (5)", GameState.weekly_shift_limit() == 5)
	_check("adult can work at 4/5", GameState.shift_block_reason() == "")
	GameState.days_worked_this_week = 5
	_check("adult blocked at 5/5", GameState.shift_block_reason() != "")


func _test_bank_interest() -> void:
	print("[Bank interest scales with rank]")
	GameState.reset_all()
	GameState.active_job = "bank_accountant"
	GameState.start_job("bank_accountant")
	_check("teller interest = 6%", abs(GameState.get_bank_interest_rate() - 0.06) < 0.0001)
	GameState.job_levels["bank_accountant"] = 3
	_check("branch manager interest = 10%", abs(GameState.get_bank_interest_rate() - 0.10) < 0.0001)
	GameState.active_job = "none"
	_check("no bank job -> default interest", abs(GameState.get_bank_interest_rate() - GameState.savings_interest_rate) < 0.0001)


func _test_available_jobs() -> void:
	print("[Available job count shrinks with firings]")
	GameState.reset_all()
	_check("3 jobs available at start", GameState.get_available_job_count() == 3)
	GameState.fired_jobs_history = ["burger_cashier"]
	_check("2 jobs after 1 firing", GameState.get_available_job_count() == 2)
	GameState.fired_jobs_history = ["burger_cashier", "bank_accountant"]
	_check("1 job after 2 firings", GameState.get_available_job_count() == 1)
	GameState.fired_jobs_history = ["burger_cashier", "bank_accountant", "news_boy"]
	_check("0 jobs after 3 firings", GameState.get_available_job_count() == 0)
	GameState.reset_all()
