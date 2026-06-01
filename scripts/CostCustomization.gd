# CostCustomization.gd — Levels of Difficulty + custom variable tuning
extends Control

@onready var scroll_container = $ScrollContainer

# Input references
@onready var starting_cash_input = $ScrollContainer/Sections/StartingGrid/StartingCashInput
@onready var starting_savings_input = $ScrollContainer/Sections/StartingGrid/StartingSavingsInput
@onready var weekly_allowance_input = $ScrollContainer/Sections/StartingGrid/WeeklyAllowanceInput

@onready var food_input = $ScrollContainer/Sections/CostsGrid/FoodInput
@onready var water_input = $ScrollContainer/Sections/CostsGrid/WaterInput
@onready var medicine_input = $ScrollContainer/Sections/CostsGrid/MedicineInput
@onready var vet_input = $ScrollContainer/Sections/CostsGrid/VetInput
@onready var taxi_input = $ScrollContainer/Sections/CostsGrid/TaxiInput
@onready var ball_input = $ScrollContainer/Sections/CostsGrid/BallInput

@onready var food_budget_input = $ScrollContainer/Sections/BudgetGrid/FoodBudgetInput
@onready var vet_budget_input = $ScrollContainer/Sections/BudgetGrid/VetBudgetInput
@onready var travel_budget_input = $ScrollContainer/Sections/BudgetGrid/TravelBudgetInput

@onready var interest_input = $ScrollContainer/Sections/ModifiersGrid/InterestInput
@onready var penalty_input = $ScrollContainer/Sections/ModifiersGrid/PenaltyInput
@onready var loan_rate_input = $ScrollContainer/Sections/ModifiersGrid/LoanRateInput
@onready var max_loan_input = $ScrollContainer/Sections/ModifiersGrid/MaxLoanInput

@onready var back_button = $ButtonContainer/BackButton
@onready var continue_button = $ButtonContainer/ContinueButton

var _selected_difficulty: String = "medium"
var difficulty_cards: VBoxContainer = null

# Difficulty presets
const PRESETS = {
	"easy": {
		"starting_cash": 250.0,
		"starting_savings": 300.0,
		"weekly_allowance": 150.0,
		"food_cost": 15,
		"water_cost": 8,
		"medicine_cost": 30,
		"vet_fee": 35,
		"taxi_cost": 8,
		"ball_chore": 0.30,
		"food_budget": 60,
		"vet_budget": 60,
		"travel_budget": 60,
		"interest": 8,
		"penalty": 10,
		"loan_rate": 5,
		"max_loan": 750,
		"label": "Easy",
		"stats": "Cash: $250  Savings: $300\nAllowance: $150/wk\nLow costs · High rewards",
		"color": Color("#4CAF50"),
	},
	"medium": {
		"starting_cash": 150.0,
		"starting_savings": 200.0,
		"weekly_allowance": 100.0,
		"food_cost": 20,
		"water_cost": 10,
		"medicine_cost": 40,
		"vet_fee": 50,
		"taxi_cost": 10,
		"ball_chore": 0.20,
		"food_budget": 50,
		"vet_budget": 50,
		"travel_budget": 50,
		"interest": 5,
		"penalty": 15,
		"loan_rate": 10,
		"max_loan": 500,
		"label": "Medium",
		"stats": "Cash: $150  Savings: $200\nAllowance: $100/wk\nBalanced challenge",
		"color": Color("#FFA726"),
	},
	"hard": {
		"starting_cash": 75.0,
		"starting_savings": 100.0,
		"weekly_allowance": 40.0,
		"food_cost": 30,
		"water_cost": 15,
		"medicine_cost": 60,
		"vet_fee": 75,
		"taxi_cost": 15,
		"ball_chore": 0.10,
		"food_budget": 40,
		"vet_budget": 40,
		"travel_budget": 40,
		"interest": 3,
		"penalty": 20,
		"loan_rate": 15,
		"max_loan": 300,
		"label": "Hard",
		"stats": "Cash: $75  Savings: $100\nAllowance: $40/wk\nHigh costs · Tight margins",
		"color": Color("#EF5350"),
	},
}

func _ready() -> void:
	UITheme.apply_theme(self)
	populate_from_state()
	setup_layout()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		UITheme.style_button(continue_button, Color("#4CAF50"))

func setup_layout() -> void:
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 24)
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 40
	main_hbox.offset_top = 165
	main_hbox.offset_right = -40
	main_hbox.offset_bottom = -110
	main_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(main_hbox)

	if scroll_container:
		remove_child(scroll_container)
		main_hbox.add_child(scroll_container)
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_stretch_ratio = 2.4
		scroll_container.show()

	setup_sidebar(main_hbox)

func populate_from_state() -> void:
	starting_cash_input.text = "%.2f" % GameState.starting_money
	starting_savings_input.text = "%.2f" % GameState.starting_savings
	weekly_allowance_input.text = "%.2f" % GameState.weekly_allowance

	food_input.text = str(GameState.food_cost)
	water_input.text = str(GameState.water_cost)
	medicine_input.text = str(GameState.medicine_cost)
	vet_input.text = str(GameState.vet_fee)
	taxi_input.text = str(GameState.taxi_cost)
	ball_input.text = "%.2f" % GameState.ball_chore

	food_budget_input.text = str(GameState.budget_data["Food"]["limit"])
	vet_budget_input.text = str(GameState.budget_data["Vet"]["limit"])
	travel_budget_input.text = str(GameState.budget_data["Travel"]["limit"])

	interest_input.text = str(int(GameState.savings_interest_rate * 100))
	penalty_input.text = str(int(GameState.withdrawal_penalty_rate * 100))
	loan_rate_input.text = str(int(GameState.loan_interest_rate * 100))
	max_loan_input.text = str(GameState.max_loan_amount)

func apply_preset(difficulty: String) -> void:
	_selected_difficulty = difficulty
	var p = PRESETS[difficulty]

	starting_cash_input.text = "%.2f" % p["starting_cash"]
	starting_savings_input.text = "%.2f" % p["starting_savings"]
	weekly_allowance_input.text = "%.2f" % p["weekly_allowance"]

	food_input.text = str(p["food_cost"])
	water_input.text = str(p["water_cost"])
	medicine_input.text = str(p["medicine_cost"])
	vet_input.text = str(p["vet_fee"])
	taxi_input.text = str(p["taxi_cost"])
	ball_input.text = "%.2f" % p["ball_chore"]

	food_budget_input.text = str(p["food_budget"])
	vet_budget_input.text = str(p["vet_budget"])
	travel_budget_input.text = str(p["travel_budget"])

	interest_input.text = str(p["interest"])
	penalty_input.text = str(p["penalty"])
	loan_rate_input.text = str(p["loan_rate"])
	max_loan_input.text = str(p["max_loan"])

func setup_sidebar(parent_hbox: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(680, 0)
	sidebar.size_flags_horizontal = Control.SIZE_SHRINK_END

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#111a30")
	sb.border_color = Color("#22335c")
	sb.border_width_bottom = 4
	sb.border_width_top = 4
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(20)
	sidebar.add_theme_stylebox_override("panel", sb)
	parent_hbox.add_child(sidebar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	sidebar.add_child(vbox)

	var title := Label.new()
	title.text = "LEVELS OF DIFFICULTY"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#53d8fb"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pf := UITheme.get_pixel_font()
	if pf: title.add_theme_font_override("font", pf)
	vbox.add_child(title)

	difficulty_cards = VBoxContainer.new()
	difficulty_cards.add_theme_constant_override("separation", 18)
	vbox.add_child(difficulty_cards)

	for key in ["easy", "medium", "hard"]:
		var p = PRESETS[key]
		_create_difficulty_card(difficulty_cards, key, p["label"], p["stats"], p["color"])

	call_deferred("_select_default")

func _select_default() -> void:
	if difficulty_cards and difficulty_cards.get_child_count() > 0:
		# Select Medium (index 1) as default
		var medium_card = difficulty_cards.get_child(1)
		var btn = medium_card.find_child("SelectBtn", true, false) as Button
		if btn:
			btn.pressed.emit()

func _create_difficulty_card(parent: Control, id: String, title_text: String, stats: String, accent_color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 200)
	panel.set_meta("difficulty_id", id)
	panel.set_meta("accent_color", accent_color)
	panel.set_meta("base_title", title_text)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#182645")
	sb.border_color = Color("#22335c")
	sb.border_width_bottom = 4
	sb.border_width_top = 4
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.set_corner_radius_all(15)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)

	var title_btn := Button.new()
	title_btn.name = "SelectBtn"
	title_btn.text = title_text
	title_btn.flat = true
	title_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_btn.add_theme_color_override("font_color", accent_color)
	title_btn.add_theme_font_size_override("font_size", 38)
	title_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	var pf := UITheme.get_pixel_font()
	if pf: title_btn.add_theme_font_override("font", pf)
	vbox.add_child(title_btn)

	var stats_lbl := Label.new()
	stats_lbl.text = stats
	stats_lbl.add_theme_font_size_override("font_size", 22)
	stats_lbl.add_theme_color_override("font_color", Color("#a0b2d6"))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(stats_lbl)

	var do_select := func():
		apply_preset(id)

		for child in parent.get_children():
			var card_id = child.get_meta("difficulty_id")
			var card_accent = child.get_meta("accent_color")
			var card_base_title = child.get_meta("base_title")
			var child_sb = child.get_theme_stylebox("panel") as StyleBoxFlat
			var child_btn = child.find_child("SelectBtn", true, false) as Button

			if child_sb:
				if card_id == id:
					child_sb.bg_color = card_accent.darkened(0.85)
					child_sb.border_color = card_accent
					child_sb.border_width_bottom = 12
					child_sb.border_width_top = 12
					child_sb.border_width_left = 12
					child_sb.border_width_right = 12
					if child_btn:
						child_btn.text = "✓ " + card_base_title
						child_btn.add_theme_color_override("font_color", Color.WHITE)
				else:
					child_sb.bg_color = Color("#182645")
					child_sb.border_color = Color("#22335c")
					child_sb.border_width_bottom = 4
					child_sb.border_width_top = 4
					child_sb.border_width_left = 4
					child_sb.border_width_right = 4
					if child_btn:
						child_btn.text = card_base_title
						child_btn.add_theme_color_override("font_color", card_accent)

	title_btn.pressed.connect(do_select)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			do_select.call()
	)

func _on_back_pressed() -> void:
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn", {"pattern": "curtains"})

func _on_continue_pressed() -> void:
	var starting_cash := float(starting_cash_input.text)
	var starting_savings := float(starting_savings_input.text)
	var allowance := float(weekly_allowance_input.text)

	var food_c := int(food_input.text)
	var water_c := int(water_input.text)
	var med_c := int(medicine_input.text)
	var vet_f := int(vet_input.text)
	var taxi_c := int(taxi_input.text)
	var ball_c := float(ball_input.text)

	var food_b := int(food_budget_input.text)
	var vet_b := int(vet_budget_input.text)
	var travel_b := int(travel_budget_input.text)

	var interest_r := float(interest_input.text) / 100.0
	var penalty_r := float(penalty_input.text) / 100.0
	var loan_r := float(loan_rate_input.text) / 100.0
	var max_loan := int(max_loan_input.text)

	# Always kid pathway; difficulty tracks preset selection
	GameState.selected_pathway = "kid"
	GameState.difficulty = _selected_difficulty

	GameState.starting_money = starting_cash
	GameState.starting_savings = starting_savings
	GameState.weekly_allowance = allowance

	GameState.food_cost = food_c
	GameState.water_cost = water_c
	GameState.medicine_cost = med_c
	GameState.vet_fee = vet_f
	GameState.taxi_cost = taxi_c
	GameState.ball_chore = ball_c

	GameState.budget_data["Food"]["limit"] = food_b
	GameState.budget_data["Vet"]["limit"] = vet_b
	GameState.budget_data["Travel"]["limit"] = travel_b

	GameState.savings_interest_rate = interest_r
	GameState.withdrawal_penalty_rate = penalty_r
	GameState.loan_interest_rate = loan_r
	GameState.max_loan_amount = max_loan

	GameState.money = starting_cash
	GameState.savings_balance = starting_savings

	GameState.active_job = "none"

	print("[CostCustomization] Difficulty: ", _selected_difficulty)
	SceneManager.change_scene("res://scenes/ui/ConfirmSelection.tscn", {"pattern": "curtains"})
