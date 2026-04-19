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

var money: int = 150
var starting_money: int = 150

# Customizable Costs
var food_cost: int = 20
var water_cost: int = 10
var medicine_cost: int = 40
var vet_fee: int = 50
var taxi_cost: int = 10
var ball_chore: int = 2
var master_volume: int = 70
var current_day: int = 0
var days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
var day_timer: float = 0.0
var DAY_DURATION: float = 300.0

# Economy Modifiers (player-customizable)
var starting_savings: int = 200                 # Initial savings on new game
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

# Signal emitted when a new day starts
signal day_started(day_number: int)

# Finance System
var weekly_allowance: int = 150
var savings_balance: int = 200 # Starts at $200
var budget_data: Dictionary = {
	"Food": {"limit": 50, "spent": 0},
	"Vet": {"limit": 50, "spent": 0},
	"Travel": {"limit": 50, "spent": 0}
}
var weekly_report: Dictionary = {
	"income": 0,
	"total_spent": 0,
	"category_breakdown": {},
	"emergency_usage": 0
}
var transaction_history: Array = [] # Stores {day, description, amount, category}
var all_time_spent: int = 0

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

# Catch minigame
var catch_played_today: bool = false
var catch_last_played_day: int = -1
var catch_total_earnings: int = 0

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

func _ready():
	apply_volume()

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
	
	# Reset catch minigame availability
	catch_played_today = false
	
	# Banking Interest Logic
	if savings_balance > 0:
		var interest = int(savings_balance * savings_interest_rate)
		if interest > 0:
			savings_balance += interest
			savings_updated.emit()
	
	# Inflation & Random Bills
	if current_day > 0 and current_day % 10 == 0:
		inflation_rate += 0.1
		var tax: int = int(10.0 * inflation_rate)
		if money >= tax:
			spend_money(tax, "Travel") # Put under Travel or general
			event_triggered.emit("Inflation up! Paid pet license tax: $" + str(tax))
		else:
			dog_health -= 20
			event_triggered.emit("Could not pay tax! Dog gets stressed.")
			
	# Achievements check
	check_achievements()
	
	day_started.emit(current_day)
	
	# Random Text Event (20% chance)
	if randf() < 0.2:
		var evs = [
			{"msg": "Pet found a $5 bill!", "amt": 5, "type": "money"},
			{"msg": "Pet chewed your shoe...", "amt": - 15, "type": "money"},
			{"msg": "Pet had a wonderful dream", "amt": 15, "type": "health"}
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
	if weekly_report["total_spent"] <= 30:
		_unlock("Tightwad")

	# Loan interest accrues each new week before allowance arrives
	_apply_weekly_loan_interest()

	# Archive current week's report (could store in a history list if needed)
	weekly_report["income"] = weekly_allowance
	weekly_report["total_spent"] = 0
	weekly_report["category_breakdown"] = {}
	weekly_report["emergency_usage"] = 0

	# Add allowance
	money += weekly_allowance
	record_transaction("Weekly Allowance", weekly_allowance, "Income")
	_unlock("First Paycheck")
	
	# Reset spent amounts, keep limits
	for category in budget_data:
		weekly_report["category_breakdown"][category] = budget_data[category]["spent"]
		budget_data[category]["spent"] = 0
		
	budget_updated.emit()
	print("Weekly budgets reset. Income received.")

func record_transaction(description: String, amount: int, category: String):
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

func spend_money(amount: int, category: String) -> bool:
	if money >= amount:
		money -= amount
		total_spent += amount
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

func deposit_to_savings(amount: int) -> bool:
	if money >= amount:
		money -= amount
		savings_balance += amount
		record_transaction("Deposit to Savings", -amount, "Transfer")
		savings_updated.emit()
		check_achievements()
		return true
	return false


## Withdraw from savings with a 15% early withdrawal penalty.
## Returns the amount actually received (after penalty), or 0 if insufficient.
func withdraw_from_savings(amount: int) -> int:
	if amount <= 0 or savings_balance < amount:
		return 0
	var penalty := int(ceil(float(amount) * withdrawal_penalty_rate))
	var received := amount - penalty
	savings_balance -= amount
	money += received
	record_transaction("Savings Withdrawal", received, "Transfer")
	if penalty > 0:
		record_transaction("Withdrawal Penalty (%d%%)" % int(round(withdrawal_penalty_rate * 100.0)), -penalty, "Emergency")
	weekly_report["emergency_usage"] += penalty
	savings_updated.emit()
	budget_updated.emit()
	event_triggered.emit("Withdrew $%d from savings. Lost $%d penalty!" % [amount, penalty])
	return received

## Borrow money from the bank. Adds cash on hand, grows loan_balance.
## Returns true if the loan was approved.
func take_loan(amount: int) -> bool:
	if amount <= 0:
		return false
	if loan_balance + amount > max_loan_amount:
		return false
	loan_balance += amount
	money += amount
	record_transaction("Loan Taken", amount, "Loan")
	loan_updated.emit()
	savings_updated.emit()
	event_triggered.emit("Loan approved: +$%d. You now owe $%d." % [amount, loan_balance])
	return true


## Pay back part of the loan balance from cash on hand.
## Returns the amount actually paid.
func repay_loan(amount: int) -> int:
	if amount <= 0 or loan_balance <= 0 or money <= 0:
		return 0
	var payment: int = int(min(amount, min(money, loan_balance)))
	money -= payment
	loan_balance -= payment
	total_spent += payment
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
	record_transaction("Loan Interest (%d%%)" % int(round(loan_interest_rate * 100.0)), -interest, "Loan")
	loan_updated.emit()
	event_triggered.emit("Loan interest charged: +$%d owed." % interest)


func check_emergency_fund(cost: int, item_name: String) -> bool:
	# Auto-pay from savings if affordable
	if savings_balance >= cost:
		savings_balance -= cost
		weekly_report["emergency_usage"] += cost
		record_transaction("Emergency: " + item_name, -cost, "Emergency")
		savings_updated.emit()
		emergency_fund_used.emit(item_name)
		return true
	return false

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
	# Finance
	money = starting_money
	savings_balance = starting_savings
	loan_balance = 0
	loan_interest_accrued = 0
	budget_data = {
		"Food": {"limit": starting_food_budget, "spent": 0},
		"Vet":  {"limit": starting_vet_budget, "spent": 0},
		"Travel": {"limit": starting_travel_budget, "spent": 0}
	}
	weekly_report = {"income": 0, "total_spent": 0, "category_breakdown": {}, "emergency_usage": 0}
	transaction_history = []
	all_time_spent = 0
	# Supplies / pet
	food = 0; water = 0; medication = "none"
	dog_health = 30.0; has_prescription = false
	# Day / tutorial
	current_day = 0; day_timer = 0.0
	is_day_one = true; is_tutorial_complete = false
	tutorial_blocks_movement = false; is_dog_sleeping = false
	# Catch minigame
	catch_played_today = false; catch_last_played_day = -1; catch_total_earnings = 0
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
		"Food": {"limit": starting_food_budget, "spent": 0},
		"Vet": {"limit": starting_vet_budget, "spent": 0},
		"Travel": {"limit": starting_travel_budget, "spent": 0}
	}
	dog_health = 30.0
	transaction_history = []
	all_time_spent = 0

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
	money = save_data.get("money", 150)
	starting_money = save_data.get("starting_money", 150)
	current_day = save_data.get("current_day", 0)
	day_timer = save_data.get("day_timer", 0.0)
	food = save_data.get("food", 0)
	water = save_data.get("water", 0)
	medication = save_data.get("medication", "none")
	is_tutorial_complete = save_data.get("is_tutorial_complete", false)
	is_day_one = save_data.get("is_day_one", true)
	master_volume = save_data.get("master_volume", 70)
	
	# Restore Customizable Costs
	food_cost = save_data.get("food_cost", 20)
	water_cost = save_data.get("water_cost", 10)
	medicine_cost = save_data.get("medicine_cost", 40)
	vet_fee = save_data.get("vet_fee", 50)
	taxi_cost = save_data.get("taxi_cost", 10)
	ball_chore = save_data.get("ball_chore", 2)
	
	# Restore Finance Data
	savings_balance = save_data.get("savings_balance", 200)
	starting_savings = save_data.get("starting_savings", 200)
	weekly_allowance = save_data.get("weekly_allowance", 150)
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
		"Food": {"limit": starting_food_budget, "spent": 0},
		"Vet": {"limit": starting_vet_budget, "spent": 0},
		"Travel": {"limit": starting_travel_budget, "spent": 0}
	})
	weekly_report = save_data.get("weekly_report", {
		"income": 0,
		"total_spent": 0,
		"category_breakdown": {},
		"emergency_usage": 0
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
