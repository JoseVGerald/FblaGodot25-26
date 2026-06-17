# COMMIT: Achievements and Catch Minigame Update
extends Node

var character_id: int = 1
var character_variant: String = "male"
var dog_breed: String = "Golden_Retriever"
var pet_name: String = ""
var player_name: String = ""

# Component-based character customization (layered system)
var char_body: int = 1
var char_hairstyle: int = 1
var char_outfit: int = 1
var char_eyes: int = 1
var char_accessory: int = 1
var uses_component_system: bool = false # true when new customizer is used

const CharacterAssets = preload("res://scripts/CharacterAssets.gd")

## Maps component index (1-N) to SpriteFrames .tres paths for in-game animations
var COMPONENT_ANIM_PATHS: Dictionary = CharacterAssets.COMPONENT_ANIM_PATHS

var money: float = 150.0
var starting_money: float = 150.0

# Pathway & Job properties
var selected_pathway: String = "kid"       # "kid", "teenager", "adult"
var active_job: String = "none":
	set(val):
		if val != active_job:
			active_job = val
			weeks_worked_at_current_job = 0
			weeks_quota_missed_row = 0
var weeks_quota_missed_row: int = 0
var weeks_worked_at_current_job: int = 0
var fired_jobs_history: Array = []
var work_days_scheduled: int = 3           # Work shifts planned per week (1-7)
var days_worked_this_week: int = 0
var rent_timer: int = 28                   # Days remaining until rent is due
var monthly_rent: float = 200.0
var house_owned: bool = false
var house_price: float = 1000.0
var news_boy_pay: float = 10.0
var burger_cashier_pay: float = 15.0
var bank_accountant_pay: float = 25.0

# ──────────────────────────────────────────────────────────────────────────
#  CAREER PROGRESSION (promotion ladders, per-job benefits, tips)
# ──────────────────────────────────────────────────────────────────────────
# Each job has 3 ranks. Benefits scale with rank. Managers (NPCs at each
# building) explain these on the first day of a new job. The player asks for a
# raise or promotion from the Work button — both carry a firing risk.
#
# Fields per level:
#   title           — rank name shown to the player
#   pay             — cash earned per work shift at this rank
#   weeks_to_promote— full work-weeks required before a promotion can be earned
#   manager         — (job-level) the manager NPC's display name
#   food_bonus      — (burger) food supply gained per shift
#   tip_min/tip_max — (burger) random tip range added to cash per shift
#   interest        — (bank) daily savings interest rate at this rank
const JOB_PROGRESSION := {
	"news_boy": {
		"manager": "Postmaster Gus",
		"location": "Post Office",
		"levels": [
			{"title": "Paper Boy",     "pay": 10.0, "weeks_to_promote": 1},
			{"title": "Route Captain", "pay": 16.0, "weeks_to_promote": 2},
			{"title": "Postmaster",    "pay": 24.0, "weeks_to_promote": -1},
		],
	},
	"burger_cashier": {
		"manager": "Chef Tony",
		"location": "Burger Barn",
		"levels": [
			{"title": "Trainee",      "pay": 15.0, "weeks_to_promote": 1, "food_bonus": 1, "tip_min": 0.0, "tip_max": 3.0},
			{"title": "Hard Worker",  "pay": 22.0, "weeks_to_promote": 2, "food_bonus": 2, "tip_min": 2.0, "tip_max": 7.0},
			{"title": "Grill Master", "pay": 32.0, "weeks_to_promote": -1, "food_bonus": 3, "tip_min": 5.0, "tip_max": 14.0},
		],
	},
	"bank_accountant": {
		"manager": "Ms. Vault",
		"location": "First City Bank",
		"levels": [
			{"title": "Bank Teller",    "pay": 25.0, "weeks_to_promote": 1, "interest": 0.06},
			{"title": "Loan Officer",   "pay": 34.0, "weeks_to_promote": 2, "interest": 0.08},
			{"title": "Branch Manager", "pay": 46.0, "weeks_to_promote": -1, "interest": 0.10},
		],
	},
}

# Maps a building/manager NPC to the job it employs you for.
const JOB_FOR_LOCATION := {
	"burger": "burger_cashier",
	"bank": "bank_accountant",
	"post": "news_boy",
}

# Current rank per job (1-based). Persisted across save/load.
var job_levels: Dictionary = {"news_boy": 1, "burger_cashier": 1, "bank_accountant": 1}
# Permanent per-shift pay bumps earned by successfully asking for a raise.
var job_raise_bonus: Dictionary = {"news_boy": 0.0, "burger_cashier": 0.0, "bank_accountant": 0.0}
# How many times the player has been fired from each job.
var job_fired_counts: Dictionary = {"news_boy": 0, "burger_cashier": 0, "bank_accountant": 0}
# Jobs whose manager has already given the day-one briefing.
var manager_briefed_jobs: Array = []
# Lifetime tips earned (burger job). Tips are added straight to cash on hand.
var total_tips_earned: float = 0.0
# Accumulating promotion chance per job (0..1). Grows with each shift and each
# week worked (less impact the higher your rank), and a random roll on every
# shift can promote you. Resets to 0 the moment you're promoted.
var job_promo_chance: Dictionary = {"news_boy": 0.0, "burger_cashier": 0.0, "bank_accountant": 0.0}
# How much each promotion boosts pay/earnings, as a percent of base pay.
# Editable in the Cost Customizer. Rank pay = base * (1 + boost% * (rank-1)).
var promotion_boost_percent: float = 40.0
# Bank job (Loan Decision Desk mini-game): how many desk days the player has
# finished (drives the mini-game's difficulty ramp), and the in-game day of the
# last shift so the desk can only be worked once per in-game day.
var bank_days_completed: int = 0
var bank_last_shift_day: int = -1

# Customizable Costs
var food_cost: int = 20
var water_cost: int = 10
var medicine_cost: int = 40
var vet_fee: int = 50
var taxi_cost: int = 10
var ball_chore: float = 2.0                # Float to support 20 cents ($0.20) for kid chore
var master_volume: int = 70
var current_day: int = 0
var days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
var day_timer: float = 0.0
var DAY_DURATION: float = 300.0

# Economy Modifiers (player-customizable)
var starting_savings: float = 200.0                 # Initial savings on new game
var withdrawal_penalty_rate: float = 0.15       # 15% penalty for early savings withdrawal
var savings_interest_rate: float = 0.05         # 5% daily interest on savings
var loan_interest_rate: float = 0.10            # 10% weekly interest on outstanding loans
var max_loan_amount: int = 500                  # Cap on total outstanding loan balance
var starting_food_budget: int = 50              # Starting weekly Food budget limit
var starting_vet_budget: int = 50               # Starting weekly Vet budget limit
var starting_travel_budget: int = 50            # Starting weekly Travel budget limit

# Loan System (runtime state)
var loan_balance: int = 0                       # Amount currently owed
var loan_interest_accrued: int = 0              # Running tally of interest charged this playthrough

# Back-compat alias for any old code that referenced the former const
const WITHDRAWAL_PENALTY_RATE := 0.15

# Supplies Group (player inventory, NOT pet needs)
var food: int = 0 # Days of food remaining
var water: int = 0 # Days of water remaining
var medication: String = "none" # Current medication status
var dog_health: float = 30.0 # Utility for dialogue/UI (Low start for notification demo)
var has_prescription: bool = false # Added to track vet orders

# Tutorial state
var is_tutorial_complete: bool = false
var is_day_one: bool = true
var tutorial_blocks_movement: bool = false # When true, blocks movement but allows menu inputs
var is_dog_sleeping: bool = false # Freeze needs when dog sleeps

# Location + conversation flags (set by Area2D + DialogueManager signals)
var is_in_house: bool = false
var is_dialogue_active: bool = false

# Explicit flag set by the house-enter/exit teleport (E key). Prints on every
# change so we can verify in the console that the trigger is actually firing.
var Inside_house: bool = false:
	set(value):
		if value != Inside_house:
			print("[Inside_house] ", Inside_house, " → ", value)
		Inside_house = value

# Signal emitted when a new day starts
signal day_started(day_number: int)

# Finance System
var weekly_allowance: float = 150.0
var savings_balance: float = 200.0 # Starts at $200
var budget_data: Dictionary = {
	"Food": {"limit": 50, "spent": 0.0},
	"Vet": {"limit": 50, "spent": 0.0},
	"Travel": {"limit": 50, "spent": 0.0}
}
var weekly_report: Dictionary = {
	"income": 0.0,
	"total_spent": 0.0,
	"category_breakdown": {},
	"emergency_usage": 0.0
}
var transaction_history: Array = [] # Stores {day, description, amount, category}
var all_time_spent: float = 0.0

# Pet Advanced Features
var inflation_rate: float = 1.0
var pet_age_days: int = 0
var foods: Array = ["Cheap Kibble", "Healthy Veggies", "Premium Meat"]
var favorite_food: String = "Premium Meat"
var disliked_food: String = "Cheap Kibble"
var achievements: Dictionary = {
	# Pet Care
	"Penny Pincher":        false, # $200 in savings
	"Master Chef":          false, # Feed 10 times
	"Hydration Hero":       false, # Water 10 times
	"Dr. Doolittle":        false, # Medicate 5 times
	"Clean Bill of Health": false, # Dog health reaches 100
	"Vet Regular":          false, # Visit vet 3 times
	"On the Mend":          false, # Health rises from <30 to >60 in one session
	# Economy
	"Rainy Day Fund":       false, # Savings >= $500
	"Big Spender":          false, # Total spent >= $300
	"Taxi Tycoon":          false, # 10 taxi rides
	"First Paycheck":       false, # Receive first weekly allowance
	"Shopaholic":           false, # Visit store 5 times
	"Tightwad":             false, # Finish a week spending <= $30
	# Catch Minigame
	"Catch Pro":            false, # Earn $40 in one catch round
	"Catch Master":         false, # Earn $200 total from catch
	"First Fetch":          false, # Complete first catch game
	"Into the Frenzy":      false, # Reach FRENZY MODE
	"Ball Machine":         false, # Catch 15 balls in one session
	"Daily Exercise":       false, # Play catch 5 different days
	# Day / Time
	"Golden Years":         false, # Reach Day 30
	"Survivor":             false, # Reach Day 7
	"Dedicated":            false, # Reach Day 14
	"Graduated":            false, # Complete Day 1 tutorial
	# Character Customization
	"Dressed to the Nines": false, # All 5 layers active at game start
	"Hat Collector":        false, # Equip 4 different hat accessories
	"Identity Crisis":      false, # Change full look 2 times
	# Social / Exploration
	"Neighborhood Friend":  false, # Talk to 5 different NPCs
	"World Explorer":       false, # Visit all 4 taxi destinations
	# Bonus
	"Nap Champion":         false, # Dog sleeps 5 times
	"Week One Down":        false, # Complete all Day 1 actions
}
var times_fed: int = 0

# Achievement tracking counters
var times_watered:     int   = 0
var times_medicated:   int   = 0
var vet_visit_count:   int   = 0
var taxi_ride_count:   int   = 0
var total_spent:       int   = 0  # cumulative across all sessions
var store_visit_count: int   = 0
var catch_games_played: int  = 0
var max_balls_one_session: int = 0
var npcs_talked:       int   = 0
var locations_visited: Array = []  # ["Home","Store","Vet","Park"]
var hats_collected:    Array = []  # accessory indices that are hat-type
var full_look_changes: int   = 0   # times all 5 components changed from prior save
var nap_count:         int   = 0
var catch_days_played: Array = []  # list of days catch was played (for Daily Exercise)
var dog_health_was_low: bool = false  # for On the Mend tracking
var weekly_spend_at_reset: int = 0   # snapshot at week start, for Tightwad

# Hat-type accessory indices (1-based, matching CharacterAssets)
const HAT_ACCESSORY_INDICES: Array = [4, 5, 6, 7, 8, 11, 18, 19]

# Preloaded scenes (populated by LoadingScreen before MainMenu)
var preloaded_map: PackedScene = null

# Catch minigame
var catch_played_today: bool = false
var catch_last_played_day: int = -1
var catch_total_earnings: int = 0

# Daycare system
enum DaycareTier { NONE, CHEAP, PREMIUM }
var dog_at_daycare: bool = false
var daycare_used_today: bool = false
var daycare_tier_today: DaycareTier = DaycareTier.NONE
var daycare_cheap_price: float = 15.0
var daycare_premium_price: float = 30.0
var worked_today: bool = false

signal event_triggered(message: String)
signal achievement_unlocked(name: String)

# Signals
signal budget_updated
signal savings_updated
signal loan_updated
signal emergency_fund_used(item_name: String)
signal history_updated
@warning_ignore("unused_signal")
signal vet_talk_finished
@warning_ignore("unused_signal")
signal open_shop_requested
signal job_selection_requested

func _enter_tree():
	get_tree().debug_collisions_hint = false

func _ready():
	get_tree().debug_collisions_hint = false
	apply_volume()
	# Apply any user-saved keybinds on top of the project.godot defaults.
	load("res://scripts/KeybindsMenu.gd").load_saved_keybinds()
	# Defer so the DialogueManager autoload (registered later) is guaranteed
	# to be in the tree before we connect to its signals.
	_connect_dialogue_tracking.call_deferred()

# Track whether a DialogueManager balloon is currently open so NPCs can refuse
# to spawn a second one on top of an active conversation.
func _connect_dialogue_tracking() -> void:
	if DialogueManager == null:
		return
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_started(_res) -> void:
	is_dialogue_active = true

func _on_dialogue_ended(_res) -> void:
	is_dialogue_active = false

func apply_volume():
	var db = linear_to_db(master_volume / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), master_volume == 0)



func advance_day():
	# Decrement supplies
	food = max(0, food - 1)
	water = max(0, water - 1)
	_advance_day_after_supply_decrement()


## Calendar + economy events after food/water have been applied (week simulation applies supplies separately).
func _advance_day_after_supply_decrement() -> void:
	# Process medication
	if medication != "none":
		# Medication heals dog by 30 each night
		dog_health = min(100.0, dog_health + 30)
		# Parse remaining days from medication string, e.g. "Antibiotics (5 days)"
		var regex = RegEx.new()
		regex.compile("(\\d+)")
		var result = regex.search(medication)
		if result:
			var days_left = int(result.get_string()) - 1
			if days_left <= 0:
				medication = "none"
				event_triggered.emit("Medication course finished!")
			else:
				medication = "Antibiotics (" + str(days_left) + " days)"
				event_triggered.emit("Medication applied! Health +30. " + str(days_left) + " days left.")
		else:
			# If we can't parse days, just use it once
			medication = "none"
			event_triggered.emit("Medication applied! Health +30.")
	
	# Increment day
	current_day += 1
	is_day_one = false
	
	# Check for weekly reset
	if current_day % 7 == 0:
		reset_weekly_budgets()
	
	# Wake up dog
	is_dog_sleeping = false

	# Apply daycare stat effects before resetting flags
	if daycare_tier_today != DaycareTier.NONE:
		if daycare_tier_today == DaycareTier.CHEAP:
			dog_health = clampf(dog_health + randf_range(-8.0, 3.0), 0.0, 100.0)
		# PREMIUM: health untouched (dog is safe at premium daycare)

	# Reset catch minigame availability
	catch_played_today = false

	# Reset daycare flags and worked_today
	dog_at_daycare = false
	daycare_used_today = false
	daycare_tier_today = DaycareTier.NONE
	worked_today = false
	
	# Banking Interest Logic
	if savings_balance > 0:
		var rate = get_bank_interest_rate()
		var interest = savings_balance * rate
		if interest > 0.01:
			savings_balance += interest
			savings_updated.emit()
	
	# Adult Rent Logic
	if selected_pathway == "adult" and not house_owned:
		rent_timer -= 1
		if rent_timer <= 0:
			rent_timer = 28
			if money >= monthly_rent:
				money -= monthly_rent
				record_transaction("Monthly Rent Payment", -monthly_rent, "Emergency")
				event_triggered.emit("Paid monthly rent: $%.2f" % monthly_rent)
			else:
				var total_avail = money + savings_balance
				if total_avail >= monthly_rent:
					var diff = monthly_rent - money
					money = 0.0
					savings_balance -= diff
					savings_updated.emit()
					record_transaction("Monthly Rent (Savings Fallback)", -monthly_rent, "Emergency")
					event_triggered.emit("Paid monthly rent using savings: $%.2f" % monthly_rent)
				else:
					money = max(0.0, money - monthly_rent)
					dog_health = max(10.0, dog_health - 30.0)
					event_triggered.emit("COULD NOT PAY RENT! Eviction warnings sent. Buddy is extremely stressed!")
	
	# Inflation & Random Bills
	if current_day > 0 and current_day % 10 == 0:
		var multiplier = 1.0 if selected_pathway == "kid" else inflation_rate
		if selected_pathway != "kid":
			inflation_rate += 0.1
		var tax: float = 10.0 * multiplier
		if money >= tax:
			spend_money(tax, "Travel") # Put under Travel or general
			event_triggered.emit("Inflation up! Paid pet license tax: $%.2f" % tax)
		else:
			dog_health -= 20
			event_triggered.emit("Could not pay tax! Dog gets stressed.")
			
	# Achievements check
	check_achievements()
	
	day_started.emit(current_day)
	
	# Random Text Event (20% chance)
	if randf() < 0.2:
		var evs = [
			{"msg": "Pet found a $5 bill!", "amt": 5.0, "type": "money"},
			{"msg": "Pet chewed your shoe...", "amt": -15.0, "type": "money"},
			{"msg": "Pet had a wonderful dream", "amt": 15.0, "type": "health"}
		]
		var ev = evs[randi() % evs.size()]
		event_triggered.emit(ev["msg"])
		if ev["type"] == "money":
			if ev["amt"] > 0:
				money += ev["amt"]
			else:
				spend_money(abs(ev["amt"]), "Emergency")
		elif ev["type"] == "health":
			dog_health = min(100.0, dog_health + ev["amt"])


## Week simulation: random nightly health roll (called before calendar advance).
func apply_random_night_event() -> void:
	var dog = get_tree().get_first_node_in_group("dog") if get_tree() else null
	if dog and dog.has_method("apply_random_night_health_roll"):
		dog.apply_random_night_health_roll()
		dog_health = dog.health


## Week simulation: advance calendar after food/water were already applied for this day.
func advance_day_after_simulation_supply() -> void:
	_advance_day_after_supply_decrement()


func old_process_disabled(delta):
	if get_tree().paused:
		return
		
	day_timer += delta
	if day_timer >= DAY_DURATION:
		day_timer = 0.0
		current_day += 1
		is_day_one = false
		
		# Consume supplies each day (cap at 0)
		food = max(0, food - 1)
		water = max(0, water - 1)
		
		if current_day % 7 == 0:
			reset_weekly_budgets()
		
		day_started.emit(current_day)

signal budget_warning(category: String, message: String)

func reset_weekly_budgets():
	# Tightwad check: if total weekly spend was <= $30
	if weekly_report["total_spent"] <= 30.0:
		_unlock("Tightwad")

	# Career Firing Mechanic
	if active_job != "none":
		weeks_worked_at_current_job += 1
		# Sticking around steadily improves promotion odds (less so higher up).
		if not is_at_max_rank(active_job):
			job_promo_chance[active_job] = clampf(
				get_promotion_standing(active_job) + _promo_week_gain(get_job_level(active_job)), 0.0, 0.9)
		var quota_met := (days_worked_this_week >= work_days_scheduled)
		if not quota_met:
			weeks_quota_missed_row += 1
			# Fired if missed quota in first week OR missed 3 weeks in a row
			if weeks_worked_at_current_job == 1 or weeks_quota_missed_row >= 3:
				var fired_job = active_job
				if not fired_job in fired_jobs_history:
					fired_jobs_history.append(fired_job)
				
				var job_display = active_job_display_name
				active_job = "none"
				
				event_triggered.emit("⚠️ Fired! You didn't meet your shift quota for " + job_display + " (" + str(days_worked_this_week) + "/" + str(work_days_scheduled) + " days). Cannot re-apply!")
				call_deferred("trigger_job_selection")
		else:
			weeks_quota_missed_row = 0

	# Loan interest accrues each new week before allowance arrives
	_apply_weekly_loan_interest()

	# Set weekly allowance based on pathway
	if selected_pathway == "kid":
		weekly_allowance = 100.0
	elif selected_pathway == "teenager":
		weekly_allowance = 50.0
	elif selected_pathway == "adult":
		weekly_allowance = 0.0

	# Reset work days worked this week
	days_worked_this_week = 0

	# Archive current week's report (could store in a history list if needed)
	weekly_report["income"] = weekly_allowance
	weekly_report["total_spent"] = 0.0
	weekly_report["category_breakdown"] = {}
	weekly_report["emergency_usage"] = 0.0

	# Add allowance
	if weekly_allowance > 0.0:
		money += weekly_allowance
		record_transaction("Weekly Allowance", weekly_allowance, "Income")
		_unlock("First Paycheck")
	
	# Reset spent amounts, keep limits
	for category in budget_data:
		weekly_report["category_breakdown"][category] = budget_data[category]["spent"]
		budget_data[category]["spent"] = 0.0
		
	budget_updated.emit()
	print("Weekly budgets reset. Income received: $", weekly_allowance)

func record_transaction(description: String, amount: float, category: String):
	var entry = {
		"day": current_day,
		"description": description,
		"amount": amount,
		"category": category
	}
	transaction_history.push_front(entry) # Newest first
	if amount < 0:
		all_time_spent += abs(amount)
	history_updated.emit()

func spend_money(amount: float, category: String) -> bool:
	if money >= amount:
		money -= amount
		total_spent += int(amount)
		record_transaction("Purchase: " + category, -amount, category)
		
		# Update budget if category exists
		if category in budget_data:
			var limit = budget_data[category]["limit"]
			if limit > 0:
				var old_spent = budget_data[category]["spent"]
				var old_pct = float(old_spent) / float(limit) * 100.0
				
				budget_data[category]["spent"] += amount
				
				var new_pct = float(old_spent + amount) / float(limit) * 100.0
				
				if new_pct >= 100 and old_pct < 100:
					budget_warning.emit(category, "Over Budget!")
				elif new_pct >= 90 and old_pct < 90:
					budget_warning.emit(category, "90% Used!")
				
			else:
				budget_data[category]["spent"] += amount
				
			weekly_report["total_spent"] += amount
			budget_updated.emit()
		return true
	
	# Emergency Logic for Essentials
	if category in ["Food", "Vet"]:
		if check_emergency_fund(amount, category):
			return true
			
	return false

func deposit_to_savings(amount: float) -> bool:
	if money >= amount:
		money -= amount
		savings_balance += amount
		record_transaction("Deposit to Savings", -amount, "Transfer")
		savings_updated.emit()
		check_achievements()
		return true
	return false


## Withdraw from savings with early withdrawal penalty. Waived for bank accountant.
## Returns the amount actually received.
func withdraw_from_savings(amount: float) -> float:
	if amount <= 0.0 or savings_balance < amount:
		return 0.0
	var penalty := 0.0
	if active_job != "bank_accountant":
		penalty = amount * withdrawal_penalty_rate
	var received := amount - penalty
	savings_balance -= amount
	money += received
	record_transaction("Savings Withdrawal", received, "Transfer")
	if penalty > 0.0:
		record_transaction("Withdrawal Penalty (%d%%)" % int(round(withdrawal_penalty_rate * 100.0)), -penalty, "Emergency")
		weekly_report["emergency_usage"] += penalty
	savings_updated.emit()
	budget_updated.emit()
	if penalty > 0.0:
		event_triggered.emit("Withdrew $%.2f from savings. Lost $%.2f penalty!" % [amount, penalty])
	else:
		event_triggered.emit("Withdrew $%.2f from savings. Penalty Waived!" % amount)
	return received

## Borrow money from the bank. Adds cash on hand, grows loan_balance.
## Returns true if the loan was approved.
func take_loan(amount: float) -> bool:
	if amount <= 0.0:
		return false
	if loan_balance + int(amount) > max_loan_amount:
		return false
	loan_balance += int(amount)
	money += amount
	record_transaction("Loan Taken", amount, "Loan")
	loan_updated.emit()
	savings_updated.emit()
	event_triggered.emit("Loan approved: +$%.2f. You now owe $%d." % [amount, loan_balance])
	return true


## Pay back part of the loan balance from cash on hand.
## Returns the amount actually paid.
func repay_loan(amount: float) -> float:
	if amount <= 0.0 or loan_balance <= 0 or money <= 0.0:
		return 0.0
	var payment: float = min(amount, min(money, float(loan_balance)))
	money -= payment
	loan_balance -= int(payment)
	total_spent += int(payment)
	record_transaction("Loan Repayment", -payment, "Loan")
	loan_updated.emit()
	savings_updated.emit()
	return payment


## Apply weekly loan interest. Called from reset_weekly_budgets.
func _apply_weekly_loan_interest() -> void:
	if loan_balance <= 0:
		return
	var interest: int = int(ceil(float(loan_balance) * loan_interest_rate))
	if interest <= 0:
		return
	loan_balance += interest
	loan_interest_accrued += interest
	record_transaction("Loan Interest (%d%%)" % int(round(loan_interest_rate * 100.0)), -float(interest), "Loan")
	loan_updated.emit()
	event_triggered.emit("Loan interest charged: +$%d owed." % interest)


func check_emergency_fund(cost: float, item_name: String) -> bool:
	# Auto-pay from savings if affordable
	if savings_balance >= cost:
		savings_balance -= cost
		weekly_report["emergency_usage"] += cost
		record_transaction("Emergency: " + item_name, -cost, "Emergency")
		savings_updated.emit()
		emergency_fund_used.emit(item_name)
		return true
	return false

func work_shift() -> void:
	# Back-compat shim — work now flows through the manager NPCs.
	complete_work_shift()


## Complete one non-minigame work shift (bank / post, or a burger fallback).
## Pays base pay scaled by promotion rank. Returns a short summary line.
func complete_work_shift() -> String:
	if active_job == "none":
		return "You don't have a job."
	var job := active_job
	var job_name := active_job_display_name
	var pay := get_current_job_pay()
	money += pay
	days_worked_this_week += 1
	record_transaction("Work Shift: " + job_name, pay, "Income")

	var extra := ""
	if job == "burger_cashier":
		# Fallback only — normally the burger shift is the grill mini-game.
		var level_data := get_job_level_data(job, get_job_level(job))
		var food_bonus := int(level_data.get("food_bonus", 1))
		food += food_bonus
		var tip := _roll_tip(level_data) * get_promotion_multiplier(job)
		if tip > 0.0:
			money += tip
			total_tips_earned += tip
			record_transaction("Tips: " + job_name, tip, "Income")
			extra = " +$%.2f tips, +%d food" % [tip, food_bonus]

	event_triggered.emit("Completed work shift! Earned $%.2f%s" % [pay, extra])
	budget_updated.emit()
	_advance_promotion_progress(job)
	return "Shift done! You earned $%.2f%s.\nPromotion standing: %d%%." % [pay, extra, int(round(get_promotion_standing(job) * 100.0))]


## Credit a finished burger grill shift. earnings/tips come straight from the
## mini-game; both scale by the promotion-rank multiplier. The tips here are the
## tips the player actually earned in the mini-game.
func complete_burger_work_shift(earnings: float, tips: float) -> void:
	var job := "burger_cashier"
	if active_job != job:
		return
	var mult := get_promotion_multiplier(job)
	var tip_credit := snappedf(max(0.0, tips) * mult, 0.01)
	var base_credit := snappedf(max(0.0, earnings - tips) * mult, 0.01)
	money += base_credit + tip_credit
	total_tips_earned += tip_credit
	days_worked_this_week += 1
	record_transaction("Burger Shift", base_credit, "Income")
	if tip_credit > 0.0:
		record_transaction("Tips: Burger Cashier", tip_credit, "Income")
	var food_bonus := int(get_job_level_data(job, get_job_level(job)).get("food_bonus", 1))
	food += food_bonus
	event_triggered.emit("Shift done! Earned $%.2f ($%.2f tips), +%d food." % [base_credit + tip_credit, tip_credit, food_bonus])
	budget_updated.emit()
	_advance_promotion_progress(job)


## Credit a finished Loan Decision Desk shift. earnings is the player's total
## commission from the desk; bonus is the streak-bonus portion of it. Both scale
## by the promotion-rank multiplier. Records the shift so the desk can't be
## re-played until the next in-game day, and advances promotion standing.
func complete_bank_work_shift(earnings: float, bonus: float) -> void:
	var job := "bank_accountant"
	if active_job != job:
		return
	var mult := get_promotion_multiplier(job)
	var bonus_credit := snappedf(max(0.0, bonus) * mult, 0.01)
	var base_credit := snappedf(max(0.0, earnings - bonus) * mult, 0.01)
	money += base_credit + bonus_credit
	total_tips_earned += bonus_credit
	days_worked_this_week += 1
	bank_days_completed += 1
	bank_last_shift_day = current_day
	record_transaction("Bank Shift", base_credit, "Income")
	if bonus_credit > 0.0:
		record_transaction("Commission: Bank", bonus_credit, "Income")
	event_triggered.emit("Shift done! Earned $%.2f ($%.2f commission) at the desk." % [base_credit + bonus_credit, bonus_credit])
	budget_updated.emit()
	_advance_promotion_progress(job)


## Random tip for a shift, rounded to cents, from the level's tip range.
func _roll_tip(level_data: Dictionary) -> float:
	var tmax: float = float(level_data.get("tip_max", 0.0))
	if tmax <= 0.0:
		return 0.0
	var tmin: float = float(level_data.get("tip_min", 0.0))
	return round(randf_range(tmin, tmax) * 100.0) / 100.0


# ──────────────────────────────────────────────────────────────────────────
#  CAREER PROGRESSION HELPERS
# ──────────────────────────────────────────────────────────────────────────

func get_job_level(job: String) -> int:
	return int(job_levels.get(job, 1))


## Level data dictionary for a job at a 1-based rank (clamped to valid range).
func get_job_level_data(job: String, level: int) -> Dictionary:
	if not JOB_PROGRESSION.has(job):
		return {}
	var levels: Array = JOB_PROGRESSION[job]["levels"]
	var idx: int = clampi(level - 1, 0, levels.size() - 1)
	return levels[idx]


func get_raise_bonus(job: String) -> float:
	return float(job_raise_bonus.get(job, 0.0))


## Rank-1 (base) pay for a job — set in the Cost Customizer.
func get_job_base_pay(job: String) -> float:
	match job:
		"news_boy": return news_boy_pay
		"burger_cashier": return burger_cashier_pay
		"bank_accountant": return bank_accountant_pay
	return 0.0


## Pay multiplier from promotions. Each rank above 1 adds promotion_boost_percent
## of the base. e.g. 40% boost -> rank 2 = 1.4x, rank 3 = 1.8x.
func get_promotion_multiplier(job: String) -> float:
	return 1.0 + (promotion_boost_percent / 100.0) * float(get_job_level(job) - 1)


## Per-shift base pay for the active job at its current rank, including raises.
func get_current_job_pay() -> float:
	if active_job == "none":
		return 0.0
	return get_job_base_pay(active_job) * get_promotion_multiplier(active_job) + get_raise_bonus(active_job)


## Daily savings interest rate, boosted for bank employees by rank.
func get_bank_interest_rate() -> float:
	if active_job == "bank_accountant":
		var data := get_job_level_data("bank_accountant", get_job_level("bank_accountant"))
		return float(data.get("interest", savings_interest_rate))
	return savings_interest_rate


## Current accumulated promotion chance for a job (0..1).
func get_promotion_standing(job: String) -> float:
	return float(job_promo_chance.get(job, 0.0))


func is_at_max_rank(job: String) -> bool:
	if not JOB_PROGRESSION.has(job):
		return true
	return get_job_level(job) >= JOB_PROGRESSION[job]["levels"].size()


## Promotion-chance gained per shift. Smaller the higher your rank.
func _promo_shift_gain(level: int) -> float:
	match level:
		1: return 0.07
		2: return 0.035
	return 0.0


## Promotion-chance gained for each full week worked. Smaller higher up.
func _promo_week_gain(level: int) -> float:
	match level:
		1: return 0.10
		2: return 0.05
	return 0.0


## Earn promotion progress from a completed shift, then roll for a random
## promotion whose odds are exactly the accumulated standing.
func _advance_promotion_progress(job: String) -> void:
	if is_at_max_rank(job):
		return
	var lvl := get_job_level(job)
	job_promo_chance[job] = clampf(get_promotion_standing(job) + _promo_shift_gain(lvl), 0.0, 0.9)
	if randf() < get_promotion_standing(job):
		_do_promote(job, true)


## Apply a promotion: bump rank, reset standing, announce it.
func _do_promote(job: String, automatic: bool = false) -> void:
	if is_at_max_rank(job):
		return
	job_levels[job] = get_job_level(job) + 1
	job_promo_chance[job] = 0.0
	weeks_worked_at_current_job = 0
	var title := get_job_title(job)
	if automatic:
		event_triggered.emit("🎉 Your hard work paid off — promoted to %s!" % title)
	else:
		event_triggered.emit("🎉 Promoted to %s!" % title)
	budget_updated.emit()


func get_job_title(job: String) -> String:
	var data := get_job_level_data(job, get_job_level(job))
	return str(data.get("title", ""))


func get_job_manager_name(job: String) -> String:
	return str(JOB_PROGRESSION.get(job, {}).get("manager", "Manager"))


func has_manager_briefed(job: String) -> bool:
	return job in manager_briefed_jobs


func mark_manager_briefed(job: String) -> void:
	if not job in manager_briefed_jobs:
		manager_briefed_jobs.append(job)


## How many job openings remain (out of 3) after firings.
func get_available_job_count() -> int:
	var count := 0
	for job in JOB_PROGRESSION.keys():
		if not job in fired_jobs_history:
			count += 1
	return count


## Reset rank/raise/briefing state when the player takes on a brand-new job.
func start_job(job: String) -> void:
	job_levels[job] = 1
	job_raise_bonus[job] = 0.0
	job_promo_chance[job] = 0.0
	manager_briefed_jobs.erase(job)
	weeks_worked_at_current_job = 0
	weeks_quota_missed_row = 0
	days_worked_this_week = 0
	if job == "bank_accountant":
		bank_days_completed = 0
		bank_last_shift_day = -1


## Max shifts the player may work per week (teens are capped at 3).
func weekly_shift_limit() -> int:
	if selected_pathway == "teenager":
		return 3
	return work_days_scheduled


## Called when player arrives at work with dog (no daycare). Docks $25 and
## reduces promotion standing — lower standing already raises fire risk.
func apply_dog_at_work_penalty() -> String:
	money -= 25.0
	if active_job != "none" and active_job in job_promo_chance:
		job_promo_chance[active_job] = maxf(0.0, job_promo_chance[active_job] - 0.15)
	return "$25 fine. Your standing took a hit."


## Returns "" if the player may work another shift now, otherwise the manager's
## reason for turning them away (e.g. a teen who tried to work a 4th day).
func shift_block_reason() -> String:
	if active_job == "none":
		return "You don't work here."
	# The Loan Decision Desk runs one day per in-game day — finish today's loans
	# and you can't open the next day until you've slept and a new day begins.
	if active_job == "bank_accountant" and bank_last_shift_day == current_day:
		return "You've balanced today's books at the desk. Come back tomorrow for the next day's loans."
	if days_worked_this_week >= weekly_shift_limit():
		if selected_pathway == "teenager":
			return "Whoa there — you've already worked your 3 days this week. You're still a teen, so no more than that. Head home and rest!"
		return "You've finished all your shifts for the week. Come back next week!"
	return ""


## Lose the current job: lock it out of the job menu and re-open job selection.
func _fire_from_current_job(reason: String) -> void:
	var job := active_job
	if job == "none":
		return
	if not job in fired_jobs_history:
		fired_jobs_history.append(job)
	job_fired_counts[job] = int(job_fired_counts.get(job, 0)) + 1
	var disp := active_job_display_name
	active_job = "none"
	event_triggered.emit("⚠️ Fired from %s! %s" % [disp, reason])
	call_deferred("trigger_job_selection")


## Ask the boss for a raise. The better your standing (the more good work you've
## put in), the lower the chance you get fired for asking. Returns {ok,fired,message}.
func request_raise() -> Dictionary:
	if active_job == "none":
		return {"ok": false, "fired": false, "message": "You don't have a job right now."}
	var pc := get_promotion_standing(active_job)
	var fire_chance := clampf(0.35 * (1.0 - pc), 0.04, 0.35)
	if randf() < fire_chance:
		_fire_from_current_job("They didn't appreciate you pushing for more pay.")
		return {"ok": false, "fired": true, "message": "Bad move — the boss fired you for being greedy!"}
	job_raise_bonus[active_job] = min(get_raise_bonus(active_job) + 2.0, 12.0)
	budget_updated.emit()
	var msg := "Raise approved! You now earn $%.2f per shift." % get_current_job_pay()
	event_triggered.emit(msg)
	return {"ok": true, "fired": false, "message": msg}


## Ask the boss for a promotion. Success odds equal your accumulated standing,
## and the fire chance shrinks as that standing rises. Returns {ok,fired,message}.
func request_promotion() -> Dictionary:
	if active_job == "none":
		return {"ok": false, "fired": false, "message": "You don't have a job right now."}
	if is_at_max_rank(active_job):
		return {"ok": false, "fired": false, "message": "You're already at the top rank here!"}
	var pc := get_promotion_standing(active_job)
	var fire_chance := clampf(0.55 * (1.0 - pc), 0.05, 0.55)
	if randf() < fire_chance:
		_fire_from_current_job("You pushed for a promotion you hadn't earned.")
		return {"ok": false, "fired": true, "message": "You overreached and got fired!"}
	if randf() < (pc + 0.10):
		_do_promote(active_job, false)
		return {"ok": true, "fired": false,
			"message": "Promoted to %s! Pay is now $%.2f per shift." % [get_job_title(active_job), get_current_job_pay()]}
	return {"ok": false, "fired": false,
		"message": "Not yet — your standing is only %d%%. Keep working and try again." % int(round(pc * 100.0))}


## Build the manager NPC's dialogue (one balloon page per array entry).
## location_key is "burger" / "bank" / "post".
func get_manager_dialogue_lines(location_key: String) -> Array:
	var job: String = JOB_FOR_LOCATION.get(location_key, "")
	if job == "" or not JOB_PROGRESSION.has(job):
		return ["...", "Sorry, I can't help you with that."]
	var info: Dictionary = JOB_PROGRESSION[job]
	var levels: Array = info["levels"]
	var place: String = str(info.get("location", "work"))

	# Rank pays computed from base pay + the configurable promotion boost.
	var base := get_job_base_pay(job)
	var b := promotion_boost_percent / 100.0
	var p1 := int(round(base))
	var p2 := int(round(base * (1.0 + b)))
	var p3 := int(round(base * (1.0 + 2.0 * b)))
	var boost_pct := int(round(promotion_boost_percent))

	# Not employed here (safety — managers normally only talk to their own staff).
	if active_job != job:
		if job in fired_jobs_history:
			return ["We had to let you go, remember? That position's closed."]
		return ["Welcome to %s! Pick this job when you choose a career, then come see me." % place]

	# Employed here, first day — full briefing.
	if not has_manager_briefed(job):
		match job:
			"burger_cashier":
				return [
					"Welcome to the %s! I'm %s, your manager." % [place, info["manager"]],
					"Talk to me whenever you're ready to work and I'll put you on the grill — that's the burger mini-game. The better you cook, the more you earn.",
					"Tips are yours to keep. Whatever you make in tips on the grill goes straight into your pocket.",
					"Ranks go %s, then %s, then %s. Each promotion boosts your earnings and tips by about %d percent." % [levels[0]["title"], levels[1]["title"], levels[2]["title"], boost_pct],
					"Promotions come from steady good work — the more shifts you pull and the longer you stick around, the better your odds. It can happen on any shift.",
					"Each rank is harder to climb, and your odds reset after every promotion.",
					"You can also ask me for a raise or promotion from your Work button — but if your standing is low, there's a real chance I'll let you go. Now get cooking!",
				]
			"bank_accountant":
				return [
					"Welcome to %s. I'm %s, the branch manager." % [place, info["manager"]],
					"Your job is the Loan Decision Desk. Townsfolk line up with loan applications — APPROVE the ones the bank can trust and DENY the risky ones before the day's clock runs out.",
					"Four rules decide every loan. One: keep debt-to-income at 40 percent or less. Two: require a credit score of 600 or more, unless the loan is secured by collateral worth at least the amount. Three: never fund gambling or get-rich schemes. Four: if it passes all three, approve it.",
					"Approve a good loan and we earn interest, and your commission grows with a streak of good calls. Approve a bad one and the borrower defaults, costing the bank real capital. Let the vault hit zero and the day's over.",
					"Tips to do well: read the two gauges on every file, watch each applicant's patience bar so nobody storms off, and tap the POLICY button any time for a refresher. A streak of correct calls pays bonus commission.",
					"You'll start as a %s and can rise to %s, then %s. Pay climbs with rank — $%d a shift, then $%d, then $%d." % [levels[0]["title"], levels[1]["title"], levels[2]["title"], p1, p2, p3],
					"Our perk is your savings — we waive the early-withdrawal penalty and pay strong interest, %d, %d, then %d percent as you rise." % [int(levels[0]["interest"] * 100), int(levels[1]["interest"] * 100), int(levels[2]["interest"] * 100)],
					"Promotions come from steady good work — more shifts and more weeks improve your odds, though each rank is harder to reach and your odds reset after each promotion.",
					"You can also ask me for a raise or promotion at your Work button, but a weak track record means a real risk of being fired. You can only work the desk once a day, so make every call count. Welcome aboard!",
				]
			"news_boy":
				return [
					"Morning! I'm %s. Welcome to the %s." % [info["manager"], place],
					"Talk to me when you're ready to run the route and work a shift. You'll start as a %s and can reach %s, then %s." % [levels[0]["title"], levels[1]["title"], levels[2]["title"]],
					"Pay rises each rank — $%d a shift, then $%d, then $%d." % [p1, p2, p3],
					"Our perk keeps you moving — every taxi ride across town is free while you carry the mailbag.",
					"Promotions come from steady good work — the more shifts and weeks you put in, the better your odds, though it gets harder near the top and resets after each promotion.",
					"You can also ask me for a raise or promotion from your Work button, but pushing it with a weak record risks getting fired. Now hit the streets!",
				]
		return ["Welcome aboard!"]

	# Employed here, already briefed — short status update.
	var title := get_job_title(job)
	var status: Array = ["Good to see you, %s." % title]
	if job == "burger_cashier":
		status.append("Your grill earnings and tips are boosted %d percent at %s rank." % [int(round((get_promotion_multiplier(job) - 1.0) * 100.0)), title])
	else:
		status.append("You're earning $%.2f a shift right now." % get_current_job_pay())
	if is_at_max_rank(job):
		status.append("You've reached the top of the ladder. Nicely done!")
	else:
		status.append("Promotion standing: %d percent. Keep working to raise it." % int(round(get_promotion_standing(job) * 100.0)))
	return status

func buy_home() -> bool:
	if money >= house_price:
		money -= house_price
		house_owned = true
		record_transaction("Purchased House", -house_price, "Emergency")
		event_triggered.emit("CONGRATULATIONS! You have purchased the house and secured a permanent home for Buddy!")
		return true
	return false

var active_job_display_name: String:
	get:
		match active_job:
			"news_boy": return "News Boy"
			"burger_cashier": return "Burger Cashier"
			"bank_accountant": return "Bank Accountant"
			_: return "None"

var active_job_benefit_description: String:
	get:
		match active_job:
			"news_boy": return "That free taxi ride benefit will help you get around town."
			"burger_cashier": return "That employee meal benefit will help feed your buddy."
			"bank_accountant": return "That bank interest and penalty waiver will keep your savings safe."
			_: return ""

func trigger_job_selection() -> void:
	job_selection_requested.emit()
	# Prevent double spawning of job menu overlay
	if get_tree():
		for child in get_tree().root.get_children():
			if child.name == "JobSelectionMenu" or child.name.begins_with("JobSelectionMenu"):
				return
		var job_menu_scene = load("res://scenes/ui/JobSelectionMenu.tscn")
		if job_menu_scene:
			var job_menu = job_menu_scene.instantiate()
			job_menu.name = "JobSelectionMenu"
			get_tree().root.add_child(job_menu)

func get_budget_status(category: String) -> float:
	if category in budget_data and budget_data[category]["limit"] > 0:
		return float(budget_data[category]["spent"]) / float(budget_data[category]["limit"]) * 100.0
	return 0.0

# Initialize Day 1 supplies
func reset_all() -> void:
	"""Reset every in-memory variable to its new-game default."""
	# Character
	character_id = 1
	character_variant = "male"
	dog_breed = "Golden_Retriever"
	pet_name = ""
	player_name = ""
	char_body = 1; char_hairstyle = 1; char_outfit = 1; char_eyes = 1; char_accessory = 1
	uses_component_system = false
	# Pathways & Jobs
	selected_pathway = "kid"
	active_job = "none"
	work_days_scheduled = 3
	days_worked_this_week = 0
	weeks_quota_missed_row = 0
	weeks_worked_at_current_job = 0
	fired_jobs_history = []
	job_levels = {"news_boy": 1, "burger_cashier": 1, "bank_accountant": 1}
	job_raise_bonus = {"news_boy": 0.0, "burger_cashier": 0.0, "bank_accountant": 0.0}
	job_fired_counts = {"news_boy": 0, "burger_cashier": 0, "bank_accountant": 0}
	job_promo_chance = {"news_boy": 0.0, "burger_cashier": 0.0, "bank_accountant": 0.0}
	promotion_boost_percent = 40.0
	manager_briefed_jobs = []
	total_tips_earned = 0.0
	bank_days_completed = 0
	bank_last_shift_day = -1
	rent_timer = 28
	monthly_rent = 200.0
	house_owned = false
	# Finance
	money = starting_money
	savings_balance = starting_savings
	loan_balance = 0
	loan_interest_accrued = 0
	budget_data = {
		"Food": {"limit": starting_food_budget, "spent": 0.0},
		"Vet":  {"limit": starting_vet_budget, "spent": 0.0},
		"Travel": {"limit": starting_travel_budget, "spent": 0.0}
	}
	weekly_report = {"income": 0.0, "total_spent": 0.0, "category_breakdown": {}, "emergency_usage": 0.0}
	transaction_history = []
	all_time_spent = 0.0
	# Supplies / pet
	food = 0; water = 0; medication = "none"
	dog_health = 30.0; has_prescription = false
	# Day / tutorial
	current_day = 0; day_timer = 0.0
	is_day_one = true; is_tutorial_complete = false
	tutorial_blocks_movement = false; is_dog_sleeping = false
	is_in_house = false; is_dialogue_active = false
	# Catch minigame
	catch_played_today = false; catch_last_played_day = -1; catch_total_earnings = 0
	# Daycare system
	dog_at_daycare = false
	daycare_used_today = false
	daycare_tier_today = DaycareTier.NONE
	worked_today = false
	# Achievement trackers
	times_fed = 0; times_watered = 0; times_medicated = 0
	vet_visit_count = 0; taxi_ride_count = 0; total_spent = 0
	store_visit_count = 0; catch_games_played = 0; max_balls_one_session = 0
	npcs_talked = 0; nap_count = 0; full_look_changes = 0
	dog_health_was_low = false; weekly_spend_at_reset = 0
	locations_visited = []; hats_collected = []; catch_days_played = []
	# Inflation / age
	inflation_rate = 1.0; pet_age_days = 0
	# Reset all achievements to false
	for key in achievements.keys():
		achievements[key] = false

func initialize_day_one():
	food = 0
	water = 0
	medication = "none"
	is_day_one = true
	is_tutorial_complete = false
	# Reset finances for new game
	money = starting_money
	savings_balance = starting_savings
	loan_balance = 0
	loan_interest_accrued = 0
	budget_data = {
		"Food": {"limit": starting_food_budget, "spent": 0.0},
		"Vet": {"limit": starting_vet_budget, "spent": 0.0},
		"Travel": {"limit": starting_travel_budget, "spent": 0.0}
	}
	dog_health = 30.0
	transaction_history = []
	all_time_spent = 0.0

func save_character(id: int, variant: String):
	character_id = id
	character_variant = variant
	uses_component_system = false

func save_character_components(body: int, hairstyle: int, outfit: int, eyes: int, accessory: int) -> void:
	char_body = body
	char_hairstyle = hairstyle
	char_outfit = outfit
	char_eyes = eyes
	char_accessory = accessory
	uses_component_system = true

func get_character_components() -> Dictionary:
	return {
		"body": char_body,
		"hairstyle": char_hairstyle,
		"outfit": char_outfit,
		"eyes": char_eyes,
		"accessory": char_accessory,
	}

func get_component_sprite_frames(category: String, option: int) -> SpriteFrames:
	var paths: Array = COMPONENT_ANIM_PATHS.get(category, [])
	var idx := clampi(option, 1, paths.size()) - 1
	var path: String = paths[idx] if idx < paths.size() else paths[0]
	return load(path) as SpriteFrames

func save_pet(breed: String):
	dog_breed = breed

func save_pet_name(p_name: String):
	pet_name = p_name

func save_player_name(p_name: String):
	player_name = p_name

func get_time_string() -> String:
	var day_name = days_of_week[current_day % 7]
	var week_num: int = int(float(current_day) / 7.0) + 1
	return "%s Week %d" % [day_name, week_num]

func _unlock(achievement: String) -> void:
	if not achievements.has(achievement) or achievements[achievement]:
		return
	achievements[achievement] = true
	achievement_unlocked.emit(achievement)


func check_achievements():
	# Pet Care
	if savings_balance >= 200:  _unlock("Penny Pincher")
	if times_fed >= 10:         _unlock("Master Chef")
	if times_watered >= 10:     _unlock("Hydration Hero")
	if times_medicated >= 5:    _unlock("Dr. Doolittle")
	if vet_visit_count >= 3:    _unlock("Vet Regular")
	# Economy
	if savings_balance >= 500:  _unlock("Rainy Day Fund")
	if total_spent >= 300:      _unlock("Big Spender")
	if taxi_ride_count >= 10:   _unlock("Taxi Tycoon")
	if store_visit_count >= 5:  _unlock("Shopaholic")
	if hats_collected.size() >= 4: _unlock("Hat Collector")
	if full_look_changes >= 2:  _unlock("Identity Crisis")
	if npcs_talked >= 5:        _unlock("Neighborhood Friend")
	if locations_visited.size() >= 4: _unlock("World Explorer")
	if nap_count >= 5:          _unlock("Nap Champion")
	if catch_days_played.size() >= 5: _unlock("Daily Exercise")
	# Day / Time
	if current_day >= 7:        _unlock("Survivor")
	if current_day >= 14:       _unlock("Dedicated")
	if current_day >= 30:       _unlock("Golden Years")

const SAVE_PATH = "user://save_game.dat"

func save_game(dog_data: Dictionary = {}):
	var save_data = {
		"character_id": character_id,
		"character_variant": character_variant,
		"dog_breed": dog_breed,
		"pet_name": pet_name,
		"player_name": player_name,
		"money": money,
		"starting_money": starting_money,
		"current_day": current_day,
		"day_timer": day_timer,
		"food": food,
		"water": water,
		"medication": medication,
		"is_tutorial_complete": is_tutorial_complete,
		"is_day_one": is_day_one,
		"master_volume": master_volume,
		# Pathways & Jobs
		"selected_pathway": selected_pathway,
		"active_job": active_job,
		"work_days_scheduled": work_days_scheduled,
		"days_worked_this_week": days_worked_this_week,
		"weeks_quota_missed_row": weeks_quota_missed_row,
		"weeks_worked_at_current_job": weeks_worked_at_current_job,
		"fired_jobs_history": fired_jobs_history,
		# Career progression
		"job_levels": job_levels,
		"job_raise_bonus": job_raise_bonus,
		"job_fired_counts": job_fired_counts,
		"job_promo_chance": job_promo_chance,
		"promotion_boost_percent": promotion_boost_percent,
		"manager_briefed_jobs": manager_briefed_jobs,
		"total_tips_earned": total_tips_earned,
		"bank_days_completed": bank_days_completed,
		"bank_last_shift_day": bank_last_shift_day,
		"rent_timer": rent_timer,
		"monthly_rent": monthly_rent,
		"house_owned": house_owned,
		# Customizable Costs
		"food_cost": food_cost,
		"water_cost": water_cost,
		"medicine_cost": medicine_cost,
		"vet_fee": vet_fee,
		"taxi_cost": taxi_cost,
		"ball_chore": ball_chore,
		# Finance Data
		"savings_balance": savings_balance,
		"starting_savings": starting_savings,
		"weekly_allowance": weekly_allowance,
		"budget_data": budget_data,
		"starting_food_budget": starting_food_budget,
		"starting_vet_budget": starting_vet_budget,
		"starting_travel_budget": starting_travel_budget,
		"withdrawal_penalty_rate": withdrawal_penalty_rate,
		"savings_interest_rate": savings_interest_rate,
		"loan_interest_rate": loan_interest_rate,
		"max_loan_amount": max_loan_amount,
		"loan_balance": loan_balance,
		"loan_interest_accrued": loan_interest_accrued,
		"weekly_report": weekly_report,
		"transaction_history": transaction_history,
		"all_time_spent": all_time_spent,
		# Dog needs (passed from dog instance)
		"dog_hunger": dog_data.get("hunger", 100.0),
		"dog_thirst": dog_data.get("thirst", 100.0),
		"dog_energy": dog_data.get("energy", 100.0),
		"dog_health": dog_data.get("health", 30.0),
		"inflation_rate": inflation_rate,
		"times_fed": times_fed,
		"achievements": achievements,
		"catch_last_played_day": catch_last_played_day,
		"catch_total_earnings": catch_total_earnings,
		# Achievement tracking
		"times_watered": times_watered,
		"times_medicated": times_medicated,
		"vet_visit_count": vet_visit_count,
		"taxi_ride_count": taxi_ride_count,
		"total_spent": total_spent,
		"store_visit_count": store_visit_count,
		"catch_games_played": catch_games_played,
		"max_balls_one_session": max_balls_one_session,
		"npcs_talked": npcs_talked,
		"locations_visited": locations_visited,
		"hats_collected": hats_collected,
		"full_look_changes": full_look_changes,
		"nap_count": nap_count,
		"catch_days_played": catch_days_played,
		# Component-based character data
		"uses_component_system": uses_component_system,
		"char_body": char_body,
		"char_hairstyle": char_hairstyle,
		"char_outfit": char_outfit,
		"char_eyes": char_eyes,
		"char_accessory": char_accessory,
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("Game saved successfully!")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var save_data = file.get_var()
	file.close()
	
	if save_data == null:
		return false
	
	# Restore GameState variables
	character_id = save_data.get("character_id", 1)
	character_variant = save_data.get("character_variant", "male")
	dog_breed = save_data.get("dog_breed", "Golden_Retriever")
	pet_name = save_data.get("pet_name", "")
	player_name = save_data.get("player_name", "")
	money = save_data.get("money", 150.0)
	starting_money = save_data.get("starting_money", 150.0)
	current_day = save_data.get("current_day", 0)
	day_timer = save_data.get("day_timer", 0.0)
	food = save_data.get("food", 0)
	water = save_data.get("water", 0)
	medication = save_data.get("medication", "none")
	is_tutorial_complete = save_data.get("is_tutorial_complete", false)
	is_day_one = save_data.get("is_day_one", true)
	master_volume = save_data.get("master_volume", 70)
	
	# Pathways & Jobs
	selected_pathway = save_data.get("selected_pathway", "kid")
	active_job = save_data.get("active_job", "none")
	work_days_scheduled = save_data.get("work_days_scheduled", 3)
	days_worked_this_week = save_data.get("days_worked_this_week", 0)
	weeks_quota_missed_row = save_data.get("weeks_quota_missed_row", 0)
	weeks_worked_at_current_job = save_data.get("weeks_worked_at_current_job", 0)
	fired_jobs_history = save_data.get("fired_jobs_history", [])
	# Career progression (restore AFTER active_job so its setter can't clobber it)
	job_levels = save_data.get("job_levels", {"news_boy": 1, "burger_cashier": 1, "bank_accountant": 1})
	job_raise_bonus = save_data.get("job_raise_bonus", {"news_boy": 0.0, "burger_cashier": 0.0, "bank_accountant": 0.0})
	job_fired_counts = save_data.get("job_fired_counts", {"news_boy": 0, "burger_cashier": 0, "bank_accountant": 0})
	job_promo_chance = save_data.get("job_promo_chance", {"news_boy": 0.0, "burger_cashier": 0.0, "bank_accountant": 0.0})
	promotion_boost_percent = save_data.get("promotion_boost_percent", 40.0)
	manager_briefed_jobs = save_data.get("manager_briefed_jobs", [])
	total_tips_earned = save_data.get("total_tips_earned", 0.0)
	bank_days_completed = int(save_data.get("bank_days_completed", 0))
	bank_last_shift_day = int(save_data.get("bank_last_shift_day", -1))
	rent_timer = save_data.get("rent_timer", 28)
	monthly_rent = save_data.get("monthly_rent", 200.0)
	house_owned = save_data.get("house_owned", false)
	
	# Restore Customizable Costs
	food_cost = save_data.get("food_cost", 20)
	water_cost = save_data.get("water_cost", 10)
	medicine_cost = save_data.get("medicine_cost", 40)
	vet_fee = save_data.get("vet_fee", 50)
	taxi_cost = save_data.get("taxi_cost", 10)
	ball_chore = save_data.get("ball_chore", 2.0)
	
	# Restore Finance Data
	savings_balance = save_data.get("savings_balance", 200.0)
	starting_savings = save_data.get("starting_savings", 200.0)
	weekly_allowance = save_data.get("weekly_allowance", 150.0)
	starting_food_budget = save_data.get("starting_food_budget", 50)
	starting_vet_budget = save_data.get("starting_vet_budget", 50)
	starting_travel_budget = save_data.get("starting_travel_budget", 50)
	withdrawal_penalty_rate = save_data.get("withdrawal_penalty_rate", 0.15)
	savings_interest_rate = save_data.get("savings_interest_rate", 0.05)
	loan_interest_rate = save_data.get("loan_interest_rate", 0.10)
	max_loan_amount = save_data.get("max_loan_amount", 500)
	loan_balance = save_data.get("loan_balance", 0)
	loan_interest_accrued = save_data.get("loan_interest_accrued", 0)
	budget_data = save_data.get("budget_data", {
		"Food": {"limit": starting_food_budget, "spent": 0.0},
		"Vet": {"limit": starting_vet_budget, "spent": 0.0},
		"Travel": {"limit": starting_travel_budget, "spent": 0.0}
	})
	weekly_report = save_data.get("weekly_report", {
		"income": 0.0,
		"total_spent": 0.0,
		"category_breakdown": {},
		"emergency_usage": 0.0
	})
	transaction_history = save_data.get("transaction_history", [])
	all_time_spent = save_data.get("all_time_spent", 0)
	
	inflation_rate = save_data.get("inflation_rate", 1.0)
	times_fed = save_data.get("times_fed", 0)
	var loaded_achievements = save_data.get("achievements", {})
	for k in achievements.keys():
		if loaded_achievements.has(k):
			achievements[k] = loaded_achievements[k]

	# Restore catch game data
	catch_last_played_day = save_data.get("catch_last_played_day", -1)
	catch_total_earnings = save_data.get("catch_total_earnings", 0)
	catch_played_today = (catch_last_played_day == current_day)

	# Restore achievement tracking
	times_watered      = save_data.get("times_watered", 0)
	times_medicated    = save_data.get("times_medicated", 0)
	vet_visit_count    = save_data.get("vet_visit_count", 0)
	taxi_ride_count    = save_data.get("taxi_ride_count", 0)
	total_spent        = save_data.get("total_spent", 0)
	store_visit_count  = save_data.get("store_visit_count", 0)
	catch_games_played = save_data.get("catch_games_played", 0)
	max_balls_one_session = save_data.get("max_balls_one_session", 0)
	npcs_talked        = save_data.get("npcs_talked", 0)
	locations_visited  = save_data.get("locations_visited", [])
	hats_collected     = save_data.get("hats_collected", [])
	full_look_changes  = save_data.get("full_look_changes", 0)
	nap_count          = save_data.get("nap_count", 0)
	catch_days_played  = save_data.get("catch_days_played", [])
	
	# Restore component-based character data
	uses_component_system = save_data.get("uses_component_system", false)
	char_body = save_data.get("char_body", 1)
	char_hairstyle = save_data.get("char_hairstyle", 1)
	char_outfit = save_data.get("char_outfit", 1)
	char_eyes = save_data.get("char_eyes", 1)
	char_accessory = save_data.get("char_accessory", 1)
	
	print("Game loaded successfully!")
	return true

func get_saved_dog_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	
	var save_data = file.get_var()
	file.close()
	
	if save_data == null:
		return {}
	
	return {
		"hunger": save_data.get("dog_hunger", 100.0),
		"thirst": save_data.get("dog_thirst", 100.0),
		"energy": save_data.get("dog_energy", 100.0),
		"health": save_data.get("dog_health", 30.0)
	}

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Updated on 2026-04-19
