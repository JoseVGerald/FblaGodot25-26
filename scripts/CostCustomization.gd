extends Control

# Starting values
@onready var starting_cash_input:    LineEdit = $ScrollContainer/Sections/StartingGrid/StartingCashInput
@onready var starting_savings_input: LineEdit = $ScrollContainer/Sections/StartingGrid/StartingSavingsInput
@onready var weekly_allowance_input: LineEdit = $ScrollContainer/Sections/StartingGrid/WeeklyAllowanceInput

# Item & service costs
@onready var food_input:     LineEdit = $ScrollContainer/Sections/CostsGrid/FoodInput
@onready var water_input:    LineEdit = $ScrollContainer/Sections/CostsGrid/WaterInput
@onready var medicine_input: LineEdit = $ScrollContainer/Sections/CostsGrid/MedicineInput
@onready var vet_input:      LineEdit = $ScrollContainer/Sections/CostsGrid/VetInput
@onready var taxi_input:     LineEdit = $ScrollContainer/Sections/CostsGrid/TaxiInput
@onready var ball_input:     LineEdit = $ScrollContainer/Sections/CostsGrid/BallInput

# Budget limits
@onready var food_budget_input:   LineEdit = $ScrollContainer/Sections/BudgetGrid/FoodBudgetInput
@onready var vet_budget_input:    LineEdit = $ScrollContainer/Sections/BudgetGrid/VetBudgetInput
@onready var travel_budget_input: LineEdit = $ScrollContainer/Sections/BudgetGrid/TravelBudgetInput

# Economy modifiers
@onready var interest_input:  LineEdit = $ScrollContainer/Sections/ModifiersGrid/InterestInput
@onready var penalty_input:   LineEdit = $ScrollContainer/Sections/ModifiersGrid/PenaltyInput
@onready var loan_rate_input: LineEdit = $ScrollContainer/Sections/ModifiersGrid/LoanRateInput
@onready var max_loan_input:  LineEdit = $ScrollContainer/Sections/ModifiersGrid/MaxLoanInput

@onready var continue_button: Button = $ButtonContainer/ContinueButton
@onready var back_button:     Button = $ButtonContainer/BackButton

var _status_label: Label = null
var _status_tween: Tween = null

func _ready() -> void:
	UITheme.apply_theme(self)

	# Starting values
	starting_cash_input.text    = str(GameState.starting_money)
	starting_savings_input.text = str(GameState.starting_savings)
	weekly_allowance_input.text = str(GameState.weekly_allowance)

	# Costs
	food_input.text     = str(GameState.food_cost)
	water_input.text    = str(GameState.water_cost)
	medicine_input.text = str(GameState.medicine_cost)
	vet_input.text      = str(GameState.vet_fee)
	taxi_input.text     = str(GameState.taxi_cost)
	ball_input.text     = str(GameState.ball_chore)

	# Budgets
	food_budget_input.text   = str(GameState.starting_food_budget)
	vet_budget_input.text    = str(GameState.starting_vet_budget)
	travel_budget_input.text = str(GameState.starting_travel_budget)

	# Modifiers (stored as floats 0..1, shown as percentages)
	interest_input.text  = str(int(round(GameState.savings_interest_rate * 100.0)))
	penalty_input.text   = str(int(round(GameState.withdrawal_penalty_rate * 100.0)))
	loan_rate_input.text = str(int(round(GameState.loan_interest_rate * 100.0)))
	max_loan_input.text  = str(GameState.max_loan_amount)

	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_wire_numeric_validation()
	_setup_status_label()

	starting_cash_input.grab_focus()

func _all_money_inputs() -> Array:
	return [starting_cash_input, starting_savings_input, weekly_allowance_input,
		food_input, water_input, medicine_input, vet_input, taxi_input, ball_input,
		food_budget_input, vet_budget_input, travel_budget_input,
		interest_input, penalty_input, loan_rate_input, max_loan_input]

func _wire_numeric_validation() -> void:
	for inp in _all_money_inputs():
		if inp:
			inp.text_changed.connect(_on_money_text_changed.bind(inp))

func _on_money_text_changed(new_text: String, inp: LineEdit) -> void:
	if new_text.strip_edges() == "":
		return
	if not _is_valid_money(new_text):
		inp.text = ""
		inp.caret_column = 0
		_show_status("Only numbers and decimals allowed")

func _is_valid_money(s: String) -> bool:
	var t := s.strip_edges().lstrip("$").rstrip("%").strip_edges()
	if t == "":
		return true
	var dots := 0
	for c in t:
		if c == ".":
			dots += 1
			if dots > 1: return false
		elif c < "0" or c > "9":
			return false
	return true

func _setup_status_label() -> void:
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 28)
	_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	var font := UITheme.get_pixel_font()
	if font: _status_label.add_theme_font_override("font", font)
	_status_label.modulate.a = 0.0
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status_label.offset_left = 24
	_status_label.offset_bottom = -24
	_status_label.offset_top = -70
	_status_label.offset_right = 800
	add_child(_status_label)

func _show_status(text: String) -> void:
	if not _status_label: return
	_status_label.text = text
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
	_status_label.modulate.a = 1.0
	_status_tween = create_tween()
	_status_tween.tween_interval(2.5)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_continue_pressed()

func _on_continue_pressed() -> void:
	# Starting values
	GameState.starting_money   = _parse_int(starting_cash_input.text,    GameState.starting_money)
	GameState.starting_savings = _parse_int(starting_savings_input.text, GameState.starting_savings)
	GameState.weekly_allowance = _parse_int(weekly_allowance_input.text, GameState.weekly_allowance)

	# Costs
	GameState.food_cost     = _parse_int(food_input.text,     GameState.food_cost)
	GameState.water_cost    = _parse_int(water_input.text,    GameState.water_cost)
	GameState.medicine_cost = _parse_int(medicine_input.text, GameState.medicine_cost)
	GameState.vet_fee       = _parse_int(vet_input.text,      GameState.vet_fee)
	GameState.taxi_cost     = _parse_int(taxi_input.text,     GameState.taxi_cost)
	GameState.ball_chore    = _parse_int(ball_input.text,     GameState.ball_chore)

	# Budget limits
	GameState.starting_food_budget   = _parse_int(food_budget_input.text,   GameState.starting_food_budget)
	GameState.starting_vet_budget    = _parse_int(vet_budget_input.text,    GameState.starting_vet_budget)
	GameState.starting_travel_budget = _parse_int(travel_budget_input.text, GameState.starting_travel_budget)
	# Apply immediately so the live budget matches new starts
	GameState.budget_data["Food"]["limit"]   = GameState.starting_food_budget
	GameState.budget_data["Vet"]["limit"]    = GameState.starting_vet_budget
	GameState.budget_data["Travel"]["limit"] = GameState.starting_travel_budget

	# Modifiers — percentage inputs clamped to sane ranges, loans/max as ints
	GameState.savings_interest_rate   = _parse_percent(interest_input.text,  GameState.savings_interest_rate)
	GameState.withdrawal_penalty_rate = _parse_percent(penalty_input.text,   GameState.withdrawal_penalty_rate)
	GameState.loan_interest_rate      = _parse_percent(loan_rate_input.text, GameState.loan_interest_rate)
	GameState.max_loan_amount         = _parse_int(max_loan_input.text,      GameState.max_loan_amount)

	SceneManager.change_scene("res://scenes/ui/ConfirmSelection.tscn", {"pattern": "curtains"})

func _on_back_pressed() -> void:
	SceneManager.change_scene("res://scenes/ui/PetName.tscn", {"pattern": "curtains"})

func _parse_int(text: String, default_value: int) -> int:
	var stripped := text.strip_edges().lstrip("$").strip_edges()
	if stripped.is_valid_int():
		return max(0, int(stripped))
	return default_value

## Parse a percentage input (e.g. "5" or "5%") and return it as a 0..1 fraction.
## Clamped to [0, 1] so a 120% penalty can't wipe the player out.
func _parse_percent(text: String, default_value: float) -> float:
	var stripped := text.strip_edges().rstrip("%").strip_edges()
	if stripped.is_valid_int():
		return clamp(float(int(stripped)) / 100.0, 0.0, 1.0)
	if stripped.is_valid_float():
		return clamp(float(stripped) / 100.0, 0.0, 1.0)
	return default_value

# Updated on 2026-04-19
