# finance_menu.gd
# Financial Hub overlay — paper/ink pixel-art chrome (matches burger-minigame Finance HTML).
# Left rail (account card + nav + tip) · main content area · bottom status bar.
# Views: Overview | Spending | BudgetPlanner | WeeklyReport | Loans | AllTimeHistory.
extends CanvasLayer

signal menu_closed


# ── Colour palette (paper/ink — matches finance/styles.css :root) ─────────────
const CLR_PAPER      := Color("#f9dcab")
const CLR_PAPER2     := Color("#f3cf95")
const CLR_PAPER_EDGE := Color("#ecc483")
const CLR_INK        := Color("#3a2616")
const CLR_INK2       := Color("#5c3d23")
const CLR_MUTED      := Color("#8a6a44")
const CLR_NAVY       := Color("#16273e")
const CLR_NAVY_TX    := Color("#c7d6e8")
const CLR_NAVY_DIM   := Color("#7f93ab")
const CLR_NAVY_LINE  := Color("#314c6e")
const CLR_GREEN      := Color("#5ea83c")
const CLR_GREEN_D    := Color("#3f7e28")
const CLR_GREEN_TX   := Color("#7fd05a")
const CLR_RED        := Color("#d24a3d")
const CLR_RED_D      := Color("#a8352b")
const CLR_RED_TX     := Color("#ef8276")
const CLR_GOLD       := Color("#e8b53f")
const CLR_GOLD_D     := Color("#c4902a")
const CLR_BLUE       := Color("#57b6df")
const CLR_BLUE_D     := Color("#3d8bb0")
const CLR_ORANGE     := Color("#e0852e")

# Category colours (pie / bars / pills)
const CLR_CAT_FOOD   := Color("#5ea83c")
const CLR_CAT_VET    := Color("#57b6df")
const CLR_CAT_TRAVEL := Color("#e0852e")
const CLR_CAT_RENT   := Color("#a86fc4")
const CLR_CAT_INCOME := Color("#5ea83c")
const CLR_CAT_LOAN   := Color("#d24a3d")

# ── View nodes ────────────────────────────────────────────────────────────────
@onready var views_container = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views
@onready var overview_tab    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview
@onready var spending_view   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Spending
@onready var budget_tab      = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner
@onready var report_tab      = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport

# Overview
# Overview — THIS WEEK / NET / GOAL / EMERGENCY
@onready var income_value     = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/Stat2/IncomeCard/VBox/IncomeValue
@onready var expense_value    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/Stat2/ExpenseCard/VBox/ExpenseValue
@onready var net_value        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/NetCard/VBox/NetValue
@onready var ov_budgets       = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/OvBudgets
@onready var savings_goal_label = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/SavingsGoalLabel
@onready var goal_card        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/GoalCard
@onready var goal_name        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/GoalCard/VBox/GoalHeader/GoalName
@onready var goal_amt         = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/GoalCard/VBox/GoalHeader/GoalAmt
@onready var goal_bar: Control = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/GoalCard/VBox/GoalBar
@onready var buy_home_btn     = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/GoalCard/VBox/BuyHomeBtn
@onready var savings_label    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/EmergencyCard/VBox/SavingsLabel
@onready var deposit_input    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/EmergencyCard/VBox/DepositInput

# Title / status
@onready var close_btn   = $Window/VBox/StatusBar/StatusHBox/CloseBtn
@onready var day_label   = $Window/VBox/StatusBar/StatusHBox/DayLabel
@onready var status_cash = $Window/VBox/StatusBar/StatusHBox/StatusCash

# Left-rail account card
@onready var checking_label    = $Window/VBox/BodyMargin/Body/Rail/AcctCard/AcctVBox/CheckingRow/CheckingLabel
@onready var savings_bal_label = $Window/VBox/BodyMargin/Body/Rail/AcctCard/AcctVBox/SavingsRow/SavingsBalLabel
@onready var debt_label        = $Window/VBox/BodyMargin/Body/Rail/AcctCard/AcctVBox/DebtRow/DebtLabel
@onready var net_label         = $Window/VBox/BodyMargin/Body/Rail/AcctCard/AcctVBox/NetRow/NetLabel

# Nav buttons
@onready var nav_overview = $Window/VBox/BodyMargin/Body/Rail/Nav/NavOverview
@onready var nav_spending = $Window/VBox/BodyMargin/Body/Rail/Nav/NavSpending
@onready var nav_budget   = $Window/VBox/BodyMargin/Body/Rail/Nav/NavBudget
@onready var nav_loans    = $Window/VBox/BodyMargin/Body/Rail/Nav/NavLoans
@onready var nav_report   = $Window/VBox/BodyMargin/Body/Rail/Nav/NavReport
@onready var nav_history  = $Window/VBox/BodyMargin/Body/Rail/Nav/NavHistory

# Main header
@onready var main_title_label = $Window/VBox/BodyMargin/Body/Main/MainVBox/MainHead/HeadRow/MainTitle
@onready var main_hint        = $Window/VBox/BodyMargin/Body/Main/MainVBox/MainHead/HeadRow/MainHint

# Budget Planner
@onready var food_card      = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/FoodCard
@onready var vet_card       = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/VetCard
@onready var travel_card    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/TravelCard
@onready var budget_warning = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/WarningStrip
@onready var food_slider        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/FoodCard/VBox/FoodSlider
@onready var vet_slider         = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/VetCard/VBox/VetSlider
@onready var travel_slider      = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/TravelCard/VBox/TravelSlider
@onready var food_limit_label   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/FoodCard/VBox/HeaderRow/FoodLimitLabel
@onready var vet_limit_label    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/VetCard/VBox/HeaderRow/VetLimitLabel
@onready var travel_limit_label = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/TravelCard/VBox/HeaderRow/TravelLimitLabel
@onready var food_progress_bar: Control   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/FoodCard/VBox/FoodProgressBar
@onready var vet_progress_bar: Control    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/VetCard/VBox/VetProgressBar
@onready var travel_progress_bar: Control = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/TravelCard/VBox/TravelProgressBar
@onready var food_spent_label    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/FoodCard/VBox/MetaRow/SpentLabel
@onready var food_limit_meta     = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/FoodCard/VBox/MetaRow/LimitLabel
@onready var vet_spent_label     = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/VetCard/VBox/MetaRow/SpentLabel
@onready var vet_limit_meta      = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/VetCard/VBox/MetaRow/LimitLabel
@onready var travel_spent_label  = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/TravelCard/VBox/MetaRow/SpentLabel
@onready var travel_limit_meta   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/BudgetPlanner/TravelCard/VBox/MetaRow/LimitLabel

# Weekly Report
@onready var week_strip        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/WeekStrip
@onready var week_label        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/WeekStrip/HBox/WeekLabel
@onready var report_income_val = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/WeekStrip/HBox/IncomeStat/Value
@onready var report_spent_val  = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/WeekStrip/HBox/SpentStat/Value
@onready var report_net_val    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/WeekStrip/HBox/NetStat/Value
@onready var report_emer_val   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/WeekStrip/HBox/EmergencyStat/Value
@onready var breakdown_title   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/BreakdownTitle
@onready var breakdown_card    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/BreakdownCard
@onready var breakdown_grid    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/BreakdownCard/BreakdownGrid
@onready var events_title      = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/EventsTitle
@onready var events_card       = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/EventsCard
@onready var events_grid       = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/WeeklyReport/EventsCard/EventsGrid

# History
@onready var history_cash_label  = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/CashHeader
@onready var history_spent_label = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/SpentTotalLabel
@onready var history_list        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/BreakdownView/ScrollContainer/HistoryList
@onready var breakdown_btn  = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/ViewToggleContainer/BreakdownBtn
@onready var graphs_btn     = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/ViewToggleContainer/GraphsBtn
@onready var breakdown_view = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/BreakdownView
@onready var graph_view     = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/GraphView
@onready var graph_canvas   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/AllTimeHistory/GraphView/GraphCanvas

# Loans
@onready var credit_card        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditCard
@onready var loan_balance_label = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditCard/VBox/LoanBalanceLabel
@onready var loan_limit_label   = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditBarSection/BarHeader/LoanLimitLabel
@onready var loan_rate_label    = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditCard/VBox/FooterRow/RateStat/LoanRateLabel
@onready var loan_accrued_label = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditCard/VBox/FooterRow/AccruedStat/LoanAccruedLabel
@onready var loan_impact_label  = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditCard/VBox/FooterRow/NextStat/ImpactLabel
@onready var credit_bar: Control = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditBarSection/CreditBar
@onready var action_card        = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/ActionCard
@onready var loan_input         = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/ActionCard/VBox/ActionRow/LoanInput
@onready var borrow_btn         = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/ActionCard/VBox/ActionRow/BorrowBtn
@onready var repay_btn          = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/ActionCard/VBox/ActionRow/RepayBtn
@onready var loan_warning       = $Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/LoanWarning

# ── Pie chart state ─────────────────────────────────────────────────────────────
var _pie_canvas  : Control = null
var _pie_tooltip : Label   = null
var _pie_slices  : Array   = []
var _pie_center  : Vector2 = Vector2.ZERO
var _pie_radius  : float   = 0.0

var _credit_bar_ratio : float = 0.0
var _budget_progress : Dictionary = {
	"Food":   {"ratio": 0.0, "color": CLR_CAT_FOOD},
	"Vet":    {"ratio": 0.0, "color": CLR_CAT_VET},
	"Travel": {"ratio": 0.0, "color": CLR_CAT_TRAVEL},
	"Rent":   {"ratio": 0.0, "color": CLR_CAT_RENT},
}

var _active_view : String = "Overview"

# Rent & Housing (adult-only, built at runtime)
var _rent_card       : PanelContainer = null
var _rent_slider     : HSlider        = null
var _rent_limit_lbl  : Label          = null
var _rent_spent_lbl  : Label          = null
var _rent_limit_meta : Label          = null
var _rent_progress   : Control        = null

# ── Lifecycle ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_style_window_chrome()
	_style_nav_buttons()
	_style_acct_card()
	_style_tip_card()
	_style_status_bar()
	_style_deposit_withdraw_buttons()
	_style_toggle_buttons()
	_style_budget_cards()
	_style_report_panels()
	_style_loan_panels()
	_hook_progress_canvases()
	_hook_credit_bar_canvas()

	GameState.budget_updated.connect(update_ui)
	GameState.savings_updated.connect(update_ui)
	GameState.loan_updated.connect(update_ui)
	GameState.history_updated.connect(update_history)
	if GameState.has_signal("day_started"):
		GameState.day_started.connect(func(_d): _update_day_label())
	_style_loan_buttons()
	_wire_numeric_validation()

	_build_overview_budgets()
	goal_bar.draw.connect(_draw_goal_bar)
	UITheme.style_pixel_button(buy_home_btn)

	# Adult pathway: house savings-goal card + Rent & Housing budget card.
	# Non-adults never see the savings-goal section.
	if GameState.selected_pathway == "adult":
		_add_rent_budget_card()
	else:
		savings_goal_label.visible = false
		goal_card.visible = false

	_switch_view("Overview")
	update_ui()

# ── Numeric input validation ────────────────────────────────────────────────────
func _wire_numeric_validation() -> void:
	if deposit_input:
		deposit_input.text_changed.connect(_on_money_text_changed.bind(deposit_input))
	if loan_input:
		loan_input.text_changed.connect(_on_money_text_changed.bind(loan_input))

func _on_money_text_changed(new_text: String, inp: LineEdit) -> void:
	if new_text.strip_edges() == "":
		return
	if not _is_valid_money(new_text):
		inp.text = ""
		inp.caret_column = 0
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Only numbers and decimals allowed", CLR_RED)

func _is_valid_money(s: String) -> bool:
	var t := s.strip_edges().lstrip("$").strip_edges()
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

# ── Public API ───────────────────────────────────────────────────────────────────
func show_menu() -> void:
	visible = true
	update_ui()
	update_history()

func hide_menu() -> void:
	visible = false
	menu_closed.emit()

func update_ui() -> void:
	_update_day_label()
	_update_acct_rail()
	_update_statusbar()
	update_overview()
	update_budget_inputs()
	update_report()
	update_loans()
	update_history_header()

# ── View switching ────────────────────────────────────────────────────────────────
const _VIEW_META := {
	"Overview":       {"title": "OVERVIEW",      "hint": "your money at a glance"},
	"Spending":       {"title": "SPENDING",      "hint": "where it went this week"},
	"BudgetPlanner":  {"title": "BUDGET",        "hint": "set your spending limits"},
	"WeeklyReport":   {"title": "WEEKLY REPORT", "hint": "this week at a glance"},
	"Loans":          {"title": "LOANS",         "hint": "what you owe"},
	"AllTimeHistory": {"title": "HISTORY",       "hint": "recent transactions"},
}

func _switch_view(view_name: String) -> void:
	_active_view = view_name
	for child in views_container.get_children():
		child.visible = false
	var target := views_container.get_node_or_null(view_name)
	if target:
		target.visible = true

	var meta: Dictionary = _VIEW_META.get(view_name, {})
	if main_title_label: main_title_label.text = meta.get("title", "")
	if main_hint:        main_hint.text = meta.get("hint", "")

	_update_nav_active(view_name)

	if view_name == "Spending":
		_ensure_pie_canvas()
		if _pie_canvas: _pie_canvas.queue_redraw()

func _update_nav_active(view_name: String) -> void:
	var map := {
		"Overview": nav_overview, "Spending": nav_spending, "BudgetPlanner": nav_budget,
		"WeeklyReport": nav_report, "Loans": nav_loans, "AllTimeHistory": nav_history,
	}
	for key in map:
		var btn: Button = map[key]
		if not btn: continue
		if key == view_name: _style_nav_active(btn)
		else:                _style_nav_inactive(btn)

# ── Header / status / rail ──────────────────────────────────────────────────────
func _update_day_label() -> void:
	if not day_label: return
	var day := GameState.current_day
	var week: int = int(float(day) / 7.0) + 1
	day_label.text = "DAY %d · WEEK %d" % [max(1, day), week]
	var font := UITheme.get_pixel_font()
	if font: day_label.add_theme_font_override("font", font)

func _update_statusbar() -> void:
	if status_cash:
		status_cash.text = "CASH  $%.2f" % GameState.money
		var font := UITheme.get_pixel_font()
		if font: status_cash.add_theme_font_override("font", font)

func _update_acct_rail() -> void:
	if not checking_label: return
	checking_label.text    = "$%.2f" % GameState.money
	savings_bal_label.text = "$%.2f" % GameState.savings_balance
	debt_label.text        = "-$%.2f" % GameState.loan_balance
	var net := GameState.money + GameState.savings_balance - float(GameState.loan_balance)
	net_label.text = "$%.2f" % net
	var px := UITheme.get_pixel_font()
	for lbl in [checking_label, savings_bal_label, debt_label, net_label]:
		if px: lbl.add_theme_font_override("font", px)
	checking_label.add_theme_color_override("font_color", CLR_GREEN_TX)
	savings_bal_label.add_theme_color_override("font_color", CLR_GREEN_TX)
	debt_label.add_theme_color_override("font_color", CLR_RED_TX if GameState.loan_balance > 0 else CLR_GREEN_TX)
	net_label.add_theme_color_override("font_color", CLR_GOLD)

# ── Overview tab ───────────────────────────────────────────────────────────────
func update_overview() -> void:
	# THIS WEEK — income / expenses / net
	var w_income: float = GameState.weekly_report.get("income", 0.0)
	var w_spent: float  = GameState.weekly_report.get("total_spent", 0.0)
	var w_net: float    = w_income - w_spent
	income_value.text  = "$%.2f" % w_income
	expense_value.text = "$%.2f" % w_spent
	net_value.text     = ("+$%.2f" % w_net) if w_net >= 0 else "-$%.2f" % abs(w_net)
	net_value.add_theme_color_override("font_color", CLR_GREEN_D if w_net >= 0 else CLR_RED_D)
	# BUDGETS summary bars + (adult) savings goal
	_update_overview_budgets()
	_update_goal_card()
	# Emergency savings
	savings_label.text = "Emergency Savings: $%.2f" % GameState.savings_balance
	savings_label.add_theme_color_override("font_color", CLR_BLUE_D)

	var food_spent   = GameState.budget_data["Food"]["spent"]
	var vet_spent    = GameState.budget_data["Vet"]["spent"]
	var travel_spent = GameState.budget_data["Travel"]["spent"]
	var total_spent  = food_spent + vet_spent + travel_spent

	var food_pct := 0.0
	var vet_pct := 0.0
	var travel_pct := 0.0
	if total_spent > 0:
		food_pct   = float(food_spent)   / float(total_spent) * 100.0
		vet_pct    = float(vet_spent)    / float(total_spent) * 100.0
		travel_pct = float(travel_spent) / float(total_spent) * 100.0

	_pie_slices.clear()
	var food_limit   = GameState.budget_data["Food"]["limit"]
	var vet_limit    = GameState.budget_data["Vet"]["limit"]
	var travel_limit = GameState.budget_data["Travel"]["limit"]

	if total_spent > 0:
		if food_pct > 0:
			_pie_slices.append({"name": "Food & Water", "pct": food_pct, "color": CLR_CAT_FOOD,
				"detail": "$%.2f / $%.2f" % [food_spent, food_limit]})
		if vet_pct > 0:
			_pie_slices.append({"name": "Vet & Medicine", "pct": vet_pct, "color": CLR_CAT_VET,
				"detail": "$%.2f / $%.2f" % [vet_spent, vet_limit]})
		if travel_pct > 0:
			_pie_slices.append({"name": "Travel", "pct": travel_pct, "color": CLR_CAT_TRAVEL,
				"detail": "$%.2f / $%.2f" % [travel_spent, travel_limit]})
	else:
		_pie_slices.append({"name": "Food & Water", "pct": 33.3, "color": CLR_CAT_FOOD,
			"detail": "$0.00 / $%.2f" % food_limit})
		_pie_slices.append({"name": "Vet & Medicine", "pct": 33.3, "color": CLR_CAT_VET,
			"detail": "$0.00 / $%.2f" % vet_limit})
		_pie_slices.append({"name": "Travel", "pct": 33.4, "color": CLR_CAT_TRAVEL,
			"detail": "$0.00 / $%.2f" % travel_limit})

	var angle := -PI / 2.0
	for i in _pie_slices.size():
		var sweep : float = _pie_slices[i]["pct"] / 100.0 * TAU
		_pie_slices[i]["start_angle"] = angle
		_pie_slices[i]["end_angle"]   = angle + sweep
		angle += sweep

	if _active_view == "Spending":
		_ensure_pie_canvas()
		if _pie_canvas: _pie_canvas.queue_redraw()
	_update_pie_legend()

# ── Overview: budget summary bars (HTML "BUDGETS" section) ───────────────────────
var _ov_bars: Array = []   # [{ctrl, amt, cat}]

func _cat_display(cat: String) -> String:
	match cat:
		"Food":   return "Food & Water"
		"Vet":    return "Vet & Medicine"
		"Travel": return "Travel & Transport"
		"Rent":   return "Rent & Housing"
		_:        return cat

func _build_overview_budgets() -> void:
	for child in ov_budgets.get_children(): child.queue_free()
	_ov_bars.clear()
	var px := UITheme.get_pixel_font()
	var cats := ["Food", "Vet", "Travel"]
	if GameState.selected_pathway == "adult":
		cats.append("Rent")
	for cat in cats:
		var card := PanelContainer.new()
		_apply_sb(card, _sb_paper_card())
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(vb)
		var hr := HBoxContainer.new()
		vb.add_child(hr)
		var nm := Label.new()
		nm.text = _cat_display(cat)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", 34)
		nm.add_theme_color_override("font_color", CLR_INK)
		if px: nm.add_theme_font_override("font", px)
		hr.add_child(nm)
		var amt := Label.new()
		amt.add_theme_font_size_override("font_size", 32)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if px: amt.add_theme_font_override("font", px)
		hr.add_child(amt)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 30)
		var this_cat: String = cat
		bar.draw.connect(func(): _draw_ov_budget_bar(bar, this_cat))
		vb.add_child(bar)
		ov_budgets.add_child(card)
		_ov_bars.append({"ctrl": bar, "amt": amt, "cat": cat})

func _update_overview_budgets() -> void:
	for row in _ov_bars:
		var cat: String = row["cat"]
		if not GameState.budget_data.has(cat): continue
		var spent: float = GameState.budget_data[cat]["spent"]
		var limit: float = GameState.budget_data[cat]["limit"]
		var over := spent > limit
		var amt: Label = row["amt"]
		amt.text = "$%.2f / $%.2f" % [spent, limit]
		amt.add_theme_color_override("font_color", CLR_RED_D if over else CLR_GREEN_D)
		row["ctrl"].queue_redraw()

func _draw_ov_budget_bar(ctrl: Control, cat: String) -> void:
	var spent: float = GameState.budget_data[cat]["spent"] if GameState.budget_data.has(cat) else 0.0
	var limit: float = GameState.budget_data[cat]["limit"] if GameState.budget_data.has(cat) else 1.0
	var ratio := 0.0
	if limit > 0.0: ratio = clamp(spent / limit, 0.0, 1.0)
	var fill := CLR_RED if spent > limit else CLR_GOLD
	_draw_seg_bar(ctrl, ratio, fill)

# ── Overview: adult-only house savings goal ──────────────────────────────────────
func _update_goal_card() -> void:
	var is_adult := GameState.selected_pathway == "adult"
	savings_goal_label.visible = is_adult
	goal_card.visible = is_adult
	if not is_adult: return
	goal_name.text = "Buy a House"
	if GameState.house_owned:
		goal_amt.text = "Purchased!"
		goal_amt.add_theme_color_override("font_color", CLR_GREEN_D)
		buy_home_btn.visible = false
	else:
		var price: float = GameState.house_price
		var pct := 0
		if price > 0: pct = int(round(clamp(GameState.money / price, 0.0, 1.0) * 100.0))
		goal_amt.text = "$%.2f / $%.2f · %d%%" % [GameState.money, price, pct]
		goal_amt.add_theme_color_override("font_color", CLR_GREEN_D)
		buy_home_btn.text = "Buy House ($%.2f)" % price
		buy_home_btn.visible = true
		buy_home_btn.disabled = GameState.money < price
	goal_bar.queue_redraw()

func _draw_goal_bar() -> void:
	var ratio := 0.0
	if GameState.house_owned:
		ratio = 1.0
	elif GameState.house_price > 0:
		ratio = clamp(GameState.money / GameState.house_price, 0.0, 1.0)
	_draw_seg_bar(goal_bar, ratio, CLR_GREEN)

## Segmented pixel progress bar (paper track + ink border + blocky accent fill).
func _draw_seg_bar(ctrl: Control, ratio: float, fill_color: Color) -> void:
	var sz := ctrl.size
	var track := StyleBoxFlat.new()
	track.bg_color = CLR_PAPER2
	track.border_color = CLR_INK
	track.set_border_width_all(3)
	track.set_corner_radius_all(0)
	ctrl.draw_style_box(track, Rect2(Vector2.ZERO, sz))
	var inner_x := 3.0
	var inner_w: float = sz.x - 6.0
	var inner_y := 3.0
	var inner_h: float = sz.y - 6.0
	var fill_w: float = inner_w * clampf(ratio, 0.0, 1.0)
	if fill_w <= 0.0: return
	var seg := 22.0
	var gap := 4.0
	var x := inner_x
	var i := 0
	while x < inner_x + fill_w:
		var bw: float = min(seg - gap, inner_x + fill_w - x)
		if bw > 0.0:
			var c: Color = fill_color if i % 2 == 0 else fill_color.darkened(0.18)
			ctrl.draw_rect(Rect2(x, inner_y, bw, inner_h), c)
		x += seg
		i += 1

# ── Pie chart + legend (Spending view) ───────────────────────────────────────────
func _ensure_pie_canvas() -> void:
	if _pie_canvas: return
	_pie_canvas = Control.new()
	_pie_canvas.name = "PieChartCanvas"
	_pie_canvas.custom_minimum_size = Vector2(440, 440)
	_pie_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pie_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	var pie_holder := spending_view.get_node_or_null("PieHolder")
	if pie_holder: pie_holder.add_child(_pie_canvas)
	else:          spending_view.add_child(_pie_canvas)

	_pie_canvas.draw.connect(_on_pie_draw)
	_pie_canvas.gui_input.connect(_on_pie_input)
	_pie_canvas.mouse_exited.connect(func(): _hide_pie_tooltip())

	_pie_tooltip = Label.new()
	_pie_tooltip.visible = false
	_pie_tooltip.add_theme_font_size_override("font_size", 28)
	_pie_tooltip.add_theme_color_override("font_color", CLR_PAPER)
	var font := UITheme.get_pixel_font()
	if font: _pie_tooltip.add_theme_font_override("font", font)
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0, 0, 0, 0.85)
	tip_sb.border_color = CLR_INK
	tip_sb.set_border_width_all(2)
	tip_sb.set_corner_radius_all(6)
	tip_sb.set_content_margin_all(10)
	_pie_tooltip.add_theme_stylebox_override("normal", tip_sb)
	_pie_canvas.add_child(_pie_tooltip)

func _on_pie_draw() -> void:
	if not _pie_canvas or _pie_slices.is_empty(): return
	var sz := _pie_canvas.size
	_pie_radius = min(sz.x, sz.y) * 0.42
	_pie_center = sz * 0.5
	var seg := 64
	for slice in _pie_slices:
		var points := PackedVector2Array()
		points.append(_pie_center)
		var start_a : float = slice["start_angle"]
		var sweep   : float = slice["end_angle"] - start_a
		for j in range(seg + 1):
			var a := start_a + sweep * (float(j) / float(seg))
			points.append(_pie_center + Vector2(cos(a), sin(a)) * _pie_radius)
		_pie_canvas.draw_colored_polygon(points, slice["color"])
	var outline_pts := PackedVector2Array()
	for j in range(129):
		var a := float(j) / 128.0 * TAU
		outline_pts.append(_pie_center + Vector2(cos(a), sin(a)) * _pie_radius)
	_pie_canvas.draw_polyline(outline_pts, CLR_INK, 3.0)
	for slice in _pie_slices:
		var p1 := _pie_center + Vector2(cos(slice["start_angle"]), sin(slice["start_angle"])) * _pie_radius
		_pie_canvas.draw_line(_pie_center, p1, CLR_INK, 2.0)

func _on_pie_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos : Vector2 = event.position
		var dist := local_pos.distance_to(_pie_center)
		if dist > _pie_radius or _pie_radius == 0.0:
			_hide_pie_tooltip(); return
		var angle := atan2(local_pos.y - _pie_center.y, local_pos.x - _pie_center.x)
		for slice in _pie_slices:
			var sa : float = slice["start_angle"]
			var ea : float = slice["end_angle"]
			var a_norm := angle
			if a_norm < sa: a_norm += TAU
			if a_norm >= sa and a_norm < ea:
				_show_pie_tooltip(slice, local_pos); return
		for slice in _pie_slices:
			var sa : float = slice["start_angle"]
			var ea : float = slice["end_angle"]
			var a_norm := angle + TAU
			if a_norm >= sa and a_norm < ea:
				_show_pie_tooltip(slice, local_pos); return
		_hide_pie_tooltip()

func _show_pie_tooltip(slice: Dictionary, pos: Vector2) -> void:
	if not _pie_tooltip: return
	_pie_tooltip.text = "%s\n%.1f%%  %s" % [slice["name"], slice["pct"], slice["detail"]]
	_pie_tooltip.visible = true
	_pie_tooltip.position = pos + Vector2(16, -50)

func _hide_pie_tooltip() -> void:
	if _pie_tooltip: _pie_tooltip.visible = false

## Build the HTML-style vertical legend (swatch · name · mini-bar · amount/pct).
func _update_pie_legend() -> void:
	var legend := spending_view.get_node_or_null("Legend")
	if not legend: return
	for child in legend.get_children(): child.queue_free()
	var px := UITheme.get_pixel_font()
	for slice in _pie_slices:
		var row := PanelContainer.new()
		_apply_sb(row, _sb_paper_card())
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		row.add_child(hb)
		var sw := ColorRect.new()
		sw.color = slice["color"]
		sw.custom_minimum_size = Vector2(32, 32)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(sw)
		var nm := Label.new()
		nm.text = slice["name"]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", 32)
		nm.add_theme_color_override("font_color", CLR_INK)
		if px: nm.add_theme_font_override("font", px)
		hb.add_child(nm)
		var amt := Label.new()
		amt.text = "%.0f%%" % slice["pct"]
		amt.add_theme_font_size_override("font_size", 32)
		amt.add_theme_color_override("font_color", CLR_MUTED)
		if px: amt.add_theme_font_override("font", px)
		hb.add_child(amt)
		legend.add_child(row)

# ── Budget Planner ───────────────────────────────────────────────────────────────
func _style_budget_cards() -> void:
	_style_accent_card(food_card,   CLR_CAT_FOOD)
	_style_accent_card(vet_card,    CLR_CAT_VET)
	_style_accent_card(travel_card, CLR_CAT_TRAVEL)
	UITheme.style_warning_strip(budget_warning, "orange")
	_style_slider(food_slider,   CLR_CAT_FOOD)
	_style_slider(vet_slider,    CLR_CAT_VET)
	_style_slider(travel_slider, CLR_CAT_TRAVEL)

func _style_slider(slider: HSlider, accent: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = CLR_PAPER2
	track.border_color = CLR_INK
	track.set_border_width_all(3)
	track.set_corner_radius_all(0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.border_color = CLR_INK
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(0)
	slider.add_theme_stylebox_override("grabber_area", fill)
	# grabber_area_highlight slightly brighter for press feedback (Emil rule)
	var fill_hi: StyleBoxFlat = fill.duplicate()
	fill_hi.bg_color = accent.lightened(0.12)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hi)

func _hook_progress_canvases() -> void:
	food_progress_bar.draw.connect(func(): _draw_progress_bar(food_progress_bar, "Food"))
	vet_progress_bar.draw.connect(func(): _draw_progress_bar(vet_progress_bar, "Vet"))
	travel_progress_bar.draw.connect(func(): _draw_progress_bar(travel_progress_bar, "Travel"))

func _draw_progress_bar(ctrl: Control, category: String) -> void:
	var sz := ctrl.size
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = CLR_PAPER2
	track_sb.border_color = CLR_INK
	track_sb.set_border_width_all(2)
	track_sb.set_corner_radius_all(0)
	ctrl.draw_style_box(track_sb, Rect2(Vector2.ZERO, sz))
	var info: Dictionary = _budget_progress.get(category, {"ratio": 0.0, "color": CLR_BLUE})
	var ratio: float = clamp(info.get("ratio", 0.0), 0.0, 1.0)
	if ratio <= 0.0: return
	var fill_color: Color = info.get("color", CLR_BLUE)
	if ratio > 0.85:   fill_color = CLR_RED
	elif ratio > 0.60: fill_color = CLR_ORANGE
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.border_color = CLR_INK
	fill_sb.set_border_width_all(2)
	fill_sb.set_corner_radius_all(0)
	ctrl.draw_style_box(fill_sb, Rect2(Vector2.ZERO, Vector2(sz.x * ratio, sz.y)))

func update_budget_inputs() -> void:
	if not food_slider.has_focus():
		food_slider.value = GameState.budget_data["Food"]["limit"]
		food_limit_label.text = "$%.2f" % food_slider.value
	if not vet_slider.has_focus():
		vet_slider.value = GameState.budget_data["Vet"]["limit"]
		vet_limit_label.text = "$%.2f" % vet_slider.value
	if not travel_slider.has_focus():
		travel_slider.value = GameState.budget_data["Travel"]["limit"]
		travel_limit_label.text = "$%.2f" % travel_slider.value
	for category in ["Food", "Vet", "Travel"]:
		var limit: float = GameState.budget_data[category]["limit"]
		var spent: float = GameState.budget_data[category]["spent"]
		var ratio := 0.0
		if limit > 0: ratio = clamp(spent / limit, 0.0, 1.0)
		_budget_progress[category]["ratio"] = ratio
	food_spent_label.text   = "Spent: $%.2f" % GameState.budget_data["Food"]["spent"]
	food_limit_meta.text    = "Limit: $%.2f" % GameState.budget_data["Food"]["limit"]
	vet_spent_label.text    = "Spent: $%.2f" % GameState.budget_data["Vet"]["spent"]
	vet_limit_meta.text     = "Limit: $%.2f" % GameState.budget_data["Vet"]["limit"]
	travel_spent_label.text = "Spent: $%.2f" % GameState.budget_data["Travel"]["spent"]
	travel_limit_meta.text  = "Limit: $%.2f" % GameState.budget_data["Travel"]["limit"]
	food_progress_bar.queue_redraw()
	vet_progress_bar.queue_redraw()
	travel_progress_bar.queue_redraw()
	_update_rent_card()

# ── Adult-only Rent & Housing budget card ─────────────────────────────────────────
func _add_rent_budget_card() -> void:
	if not budget_tab: return
	if not GameState.budget_data.has("Rent"):
		GameState.budget_data["Rent"] = {"limit": 280.0, "spent": 0.0}
	_budget_progress["Rent"] = {"ratio": 0.0, "color": CLR_CAT_RENT}

	_rent_card = PanelContainer.new()
	_rent_card.name = "RentCard"
	_style_accent_card(_rent_card, CLR_CAT_RENT)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_rent_card.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var px := UITheme.get_pixel_font()
	var title_lbl := Label.new()
	title_lbl.text = "Rent & Housing"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 44)
	title_lbl.add_theme_color_override("font_color", CLR_CAT_RENT)
	header.add_child(title_lbl)
	_rent_limit_lbl = Label.new()
	_rent_limit_lbl.text = "$%.2f" % GameState.budget_data["Rent"]["limit"]
	_rent_limit_lbl.add_theme_font_size_override("font_size", 52)
	_rent_limit_lbl.add_theme_color_override("font_color", CLR_CAT_RENT)
	_rent_limit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if px: _rent_limit_lbl.add_theme_font_override("font", px)
	header.add_child(_rent_limit_lbl)

	_rent_progress = Control.new()
	_rent_progress.name = "RentProgressBar"
	_rent_progress.custom_minimum_size = Vector2(0, 27)
	_rent_progress.draw.connect(func(): _draw_progress_bar(_rent_progress, "Rent"))
	vbox.add_child(_rent_progress)

	var meta := HBoxContainer.new()
	vbox.add_child(meta)
	_rent_spent_lbl = Label.new()
	_rent_spent_lbl.text = "Spent: $%.2f" % GameState.budget_data["Rent"]["spent"]
	_rent_spent_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rent_spent_lbl.add_theme_font_size_override("font_size", 33)
	_rent_spent_lbl.add_theme_color_override("font_color", CLR_INK2)
	if px: _rent_spent_lbl.add_theme_font_override("font", px)
	meta.add_child(_rent_spent_lbl)
	_rent_limit_meta = Label.new()
	_rent_limit_meta.text = "Limit: $%.2f" % GameState.budget_data["Rent"]["limit"]
	_rent_limit_meta.add_theme_font_size_override("font_size", 33)
	_rent_limit_meta.add_theme_color_override("font_color", CLR_INK2)
	_rent_limit_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if px: _rent_limit_meta.add_theme_font_override("font", px)
	meta.add_child(_rent_limit_meta)

	_rent_slider = HSlider.new()
	_rent_slider.name = "RentSlider"
	_rent_slider.custom_minimum_size = Vector2(0, 54)
	_rent_slider.min_value = 0.0
	_rent_slider.max_value = 1000.0
	_rent_slider.step = 10.0
	_rent_slider.value = GameState.budget_data["Rent"]["limit"]
	_style_slider(_rent_slider, CLR_CAT_RENT)
	vbox.add_child(_rent_slider)
	_rent_slider.value_changed.connect(_on_rent_slider_changed)

	# Insert before the warning strip so the strip stays at the bottom.
	budget_tab.add_child(_rent_card)
	budget_tab.move_child(_rent_card, budget_warning.get_index())

func _on_rent_slider_changed(value: float) -> void:
	GameState.budget_data["Rent"]["limit"] = value
	if _rent_limit_lbl: _rent_limit_lbl.text = "$%.2f" % value
	_update_rent_card()

func _update_rent_card() -> void:
	if not _rent_card: return
	var limit: float = GameState.budget_data["Rent"]["limit"]
	var spent: float = GameState.budget_data["Rent"]["spent"]
	if _rent_spent_lbl:  _rent_spent_lbl.text  = "Spent: $%.2f" % spent
	if _rent_limit_meta: _rent_limit_meta.text = "Limit: $%.2f" % limit
	if _rent_limit_lbl:  _rent_limit_lbl.text  = "$%.2f" % limit
	var ratio := 0.0
	if limit > 0.0: ratio = clamp(spent / limit, 0.0, 1.0)
	_budget_progress["Rent"]["ratio"] = ratio
	if _rent_progress: _rent_progress.queue_redraw()

# ── Weekly Report ────────────────────────────────────────────────────────────────
func _style_report_panels() -> void:
	_apply_sb(week_strip, _sb_paper_card())
	_apply_sb(breakdown_card, _sb_paper_card())
	_apply_sb(events_card, _sb_paper_card())
	var font := UITheme.get_pixel_font()
	for lbl in [breakdown_title, events_title]:
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_color_override("font_color", CLR_INK2)
	if week_label:
		week_label.add_theme_color_override("font_color", CLR_INK)

func update_report() -> void:
	var r    := GameState.weekly_report
	var week := int(float(GameState.current_day) / 7.0) + 1
	week_label.text = "WEEK %d" % week
	var income: float    = r.get("income", 0.0)
	var spent: float     = r.get("total_spent", 0.0)
	var net: float       = income - spent
	var emergency: float = r.get("emergency_usage", 0.0)
	report_income_val.text = "+$%.2f" % income
	report_spent_val.text  = "-$%.2f" % spent
	report_net_val.text    = ("+$%.2f" % net) if net >= 0 else "-$%.2f" % abs(net)
	report_net_val.add_theme_color_override("font_color", CLR_GREEN_D if net >= 0 else CLR_RED_D)
	report_emer_val.text   = "$%.2f" % emergency
	_populate_breakdown_grid(r)
	_populate_events_grid(r, week)

func _populate_breakdown_grid(r: Dictionary) -> void:
	for child in breakdown_grid.get_children(): child.queue_free()
	_add_grid_header(breakdown_grid, "CATEGORY")
	_add_grid_header(breakdown_grid, "SPENT")
	_add_grid_header(breakdown_grid, "BUDGET")
	_add_grid_header(breakdown_grid, "REMAINING")
	_add_grid_header(breakdown_grid, "STATUS")
	var categories := ["Food", "Vet", "Travel"]
	var breakdown: Dictionary = r.get("category_breakdown", {})
	for cat in categories:
		var spent: float     = breakdown.get(cat, 0.0)
		var limit: float     = GameState.budget_data[cat]["limit"]
		var remaining: float = limit - spent
		var pill := UITheme.make_cat_pill(cat, 33)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		breakdown_grid.add_child(pill)
		var spent_color := CLR_RED_D if spent > 0 else CLR_INK
		breakdown_grid.add_child(_make_cell("$%.2f" % spent, spent_color))
		breakdown_grid.add_child(_make_cell("$%.2f" % limit, CLR_INK))
		var remaining_color := CLR_GREEN_D
		if remaining <= 0:  remaining_color = CLR_RED_D
		elif spent == 0:    remaining_color = CLR_INK
		breakdown_grid.add_child(_make_cell("$%.2f" % remaining, remaining_color))
		var status_text: String
		var status_color: Color
		if spent == 0:
			status_text = "Unused";       status_color = CLR_MUTED
		elif remaining <= 0:
			status_text = "Over";         status_color = CLR_RED_D
		elif spent / max(1.0, limit) > 0.85:
			status_text = "Near limit";   status_color = CLR_ORANGE
		else:
			status_text = "On track";     status_color = CLR_GREEN_D
		breakdown_grid.add_child(_make_cell(status_text, status_color))

func _populate_events_grid(r: Dictionary, _week: int) -> void:
	for child in events_grid.get_children(): child.queue_free()
	_add_grid_header(events_grid, "EVENT")
	_add_grid_header(events_grid, "EFFECT")
	var inflation: float = GameState.inflation_rate if "inflation_rate" in GameState else 1.0
	var inflation_pct: float = (inflation - 1.0) * 100.0
	events_grid.add_child(_make_cell("Inflation rate", CLR_INK))
	events_grid.add_child(_make_cell("%+0.1f%% on all costs" % inflation_pct, CLR_ORANGE))
	var emergency: float = r.get("emergency_usage", 0.0)
	if emergency > 0:
		events_grid.add_child(_make_cell("Emergency coverage", CLR_INK))
		events_grid.add_child(_make_cell("-$%.2f from savings" % emergency, CLR_RED_D))
	var income: float = r.get("income", 0.0)
	if income > 0:
		events_grid.add_child(_make_cell("Weekly allowance", CLR_INK))
		events_grid.add_child(_make_cell("+$%.2f income" % income, CLR_GREEN_D))
	if GameState.loan_balance > 0:
		events_grid.add_child(_make_cell("Active loan", CLR_INK))
		events_grid.add_child(_make_cell("Owed: $%d" % GameState.loan_balance, CLR_RED_D))

func _add_grid_header(grid: GridContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", CLR_MUTED)
	lbl.add_theme_font_size_override("font_size", 30)
	var font := UITheme.get_pixel_font()
	if font: lbl.add_theme_font_override("font", font)
	grid.add_child(lbl)

func _make_cell(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 36)
	var font := UITheme.get_pixel_font()
	if font: lbl.add_theme_font_override("font", font)
	return lbl

# ── History ──────────────────────────────────────────────────────────────────────
func update_history_header() -> void:
	history_cash_label.text  = "Spending Cash: $%.2f" % GameState.money
	history_cash_label.add_theme_color_override("font_color", CLR_GREEN_D)
	history_spent_label.text = "All-Time Total Spent: $%.2f" % GameState.all_time_spent
	history_spent_label.add_theme_color_override("font_color", CLR_RED_D)

func update_history() -> void:
	for child in history_list.get_children(): child.queue_free()
	var pixel_font := UITheme.get_pixel_font()
	var row_idx := 0
	for entry in GameState.transaction_history:
		var row_bg := ColorRect.new()
		row_bg.color = CLR_PAPER2 if row_idx % 2 == 1 else CLR_PAPER
		row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h_box := HBoxContainer.new()
		h_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var FONT_SIZE := 34
		var dot := ColorRect.new()
		dot.color = _category_color(entry["category"])
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h_box.add_child(dot)
		var day_lbl := Label.new()
		day_lbl.text = "  [Day %d]  " % entry["day"]
		day_lbl.custom_minimum_size.x = 150
		day_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		day_lbl.add_theme_color_override("font_color", CLR_INK2)
		if pixel_font: day_lbl.add_theme_font_override("font", pixel_font)
		h_box.add_child(day_lbl)
		var desc_label := Label.new()
		desc_label.text = entry["description"]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.add_theme_font_size_override("font_size", FONT_SIZE)
		desc_label.add_theme_color_override("font_color", CLR_INK)
		if pixel_font: desc_label.add_theme_font_override("font", pixel_font)
		h_box.add_child(desc_label)
		var amount_label := Label.new()
		var is_income: bool = (entry["amount"] as float) >= 0
		var prefix: String  = "+" if is_income else ""
		amount_label.text = "%s$%.2f" % [prefix, entry["amount"]]
		amount_label.add_theme_color_override("font_color", CLR_GREEN_D if is_income else CLR_RED_D)
		amount_label.add_theme_font_size_override("font_size", FONT_SIZE)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if pixel_font: amount_label.add_theme_font_override("font", pixel_font)
		h_box.add_child(amount_label)
		row_bg.anchor_right = 1.0
		row_bg.anchor_bottom = 1.0
		history_list.add_child(row_bg)
		history_list.add_child(h_box)
		var sep := ColorRect.new()
		sep.color = Color(CLR_INK.r, CLR_INK.g, CLR_INK.b, 0.18)
		sep.custom_minimum_size = Vector2(0, 2)
		sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		history_list.add_child(sep)
		row_idx += 1

func _category_color(category: String) -> Color:
	match category:
		"Food":   return CLR_CAT_FOOD
		"Vet":    return CLR_CAT_VET
		"Travel": return CLR_CAT_TRAVEL
		"Rent":   return CLR_CAT_RENT
		"Income": return CLR_GREEN
		"Loan":   return CLR_ORANGE
		_:        return CLR_BLUE

# ── Local helpers ──────────────────────────────────────────────────────────────
## Apply the pixel font only when the text has no emoji (Minecraft.ttf lacks emoji glyphs).
func _pf(node) -> void:
	var f := UITheme.get_pixel_font()
	if f and not _has_emoji(node.text):
		node.add_theme_font_override("font", f)

func _has_emoji(text: String) -> bool:
	for i in range(text.length()):
		if text.unicode_at(i) > 0x2000:
			return true
	return false

func _apply_sb(node: Control, sb: StyleBoxFlat) -> void:
	if node is PanelContainer or node is Panel:
		node.add_theme_stylebox_override("panel", sb)

func _sb_paper_card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_PAPER
	sb.border_color = CLR_INK
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(18)
	return sb

func _style_accent_card(panel: PanelContainer, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_PAPER
	sb.border_color = CLR_INK
	sb.set_border_width_all(4)
	sb.border_width_left = 10
	# left accent stripe via a tinted border is not possible with one color,
	# so use the accent for the whole border to read as the category colour.
	sb.border_color = accent
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)

# ── Window chrome / rail / status styling ─────────────────────────────────────────
func _style_window_chrome() -> void:
	var font := UITheme.get_pixel_font()
	var win := get_node_or_null("Window")
	if win:
		var sb := StyleBoxFlat.new()
		sb.bg_color = CLR_PAPER
		sb.border_color = CLR_INK
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(0)
		sb.set_content_margin_all(0)
		win.add_theme_stylebox_override("panel", sb)
	var title_lbl = get_node_or_null("Window/VBox/TitleBarMargin/TitleBar/TitleChip/ChipRow/TitleLabel")
	if title_lbl:
		_pf(title_lbl)
		title_lbl.add_theme_color_override("font_color", CLR_INK)
	var chip = get_node_or_null("Window/VBox/TitleBarMargin/TitleBar/TitleChip")
	if chip:
		var csb := StyleBoxFlat.new()
		csb.bg_color = CLR_PAPER2
		csb.border_color = CLR_INK
		csb.set_border_width_all(4)
		csb.set_corner_radius_all(0)
		csb.content_margin_left = 18
		csb.content_margin_right = 18
		csb.content_margin_top = 10
		csb.content_margin_bottom = 10
		chip.add_theme_stylebox_override("panel", csb)
	var div = get_node_or_null("Window/VBox/Divider")
	if div:
		_pf(div)
		div.add_theme_color_override("font_color", CLR_INK2)
	if main_title_label:
		if font: main_title_label.add_theme_font_override("font", font)
		main_title_label.add_theme_color_override("font_color", CLR_INK)
	if main_hint:
		main_hint.add_theme_color_override("font_color", CLR_MUTED)
	var main_panel = get_node_or_null("Window/VBox/BodyMargin/Body/Main")
	if main_panel:
		var msb := StyleBoxFlat.new()
		msb.bg_color = CLR_PAPER2
		msb.border_color = CLR_INK
		msb.set_border_width_all(4)
		msb.set_corner_radius_all(0)
		msb.set_content_margin_all(0)
		main_panel.add_theme_stylebox_override("panel", msb)
	var head = get_node_or_null("Window/VBox/BodyMargin/Body/Main/MainVBox/MainHead")
	if head:
		var hsb := StyleBoxFlat.new()
		hsb.bg_color = CLR_PAPER
		hsb.border_color = CLR_INK
		hsb.border_width_bottom = 4
		hsb.set_corner_radius_all(0)
		hsb.content_margin_left = 18
		hsb.content_margin_right = 18
		hsb.content_margin_top = 14
		hsb.content_margin_bottom = 14
		head.add_theme_stylebox_override("panel", hsb)

func _style_acct_card() -> void:
	var card = get_node_or_null("Window/VBox/BodyMargin/Body/Rail/AcctCard")
	if card:
		var sb := StyleBoxFlat.new()
		sb.bg_color = CLR_NAVY
		sb.border_color = CLR_INK
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(0)
		sb.set_content_margin_all(16)
		card.add_theme_stylebox_override("panel", sb)
	var font := UITheme.get_pixel_font()
	var acct = get_node_or_null("Window/VBox/BodyMargin/Body/Rail/AcctCard/AcctVBox")
	if acct:
		for path in ["WhoRow/WhoInfo/WalletLabel", "WhoRow/WhoInfo/SubLabel",
					 "CheckingRow/CheckingKey", "SavingsRow/SavingsKey",
					 "DebtRow/DebtKey", "NetRow/NetKey"]:
			var n = acct.get_node_or_null(path)
			if n and font: n.add_theme_font_override("font", font)

func _style_tip_card() -> void:
	var tip = get_node_or_null("Window/VBox/BodyMargin/Body/Rail/TipCard")
	if tip:
		var sb := StyleBoxFlat.new()
		sb.bg_color = CLR_BLUE_D
		sb.border_color = CLR_INK
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(0)
		sb.set_content_margin_all(14)
		tip.add_theme_stylebox_override("panel", sb)
	var font := UITheme.get_pixel_font()
	var tt = get_node_or_null("Window/VBox/BodyMargin/Body/Rail/TipCard/TipVBox/TipTitle")
	var tb = get_node_or_null("Window/VBox/BodyMargin/Body/Rail/TipCard/TipVBox/TipBody")
	if tt and font: tt.add_theme_font_override("font", font)
	if tb and font: tb.add_theme_font_override("font", font)

func _style_status_bar() -> void:
	var bar = get_node_or_null("Window/VBox/StatusBar")
	if bar:
		var sb := StyleBoxFlat.new()
		sb.bg_color = CLR_INK
		sb.border_color = Color("#2a1a0e")
		sb.border_width_top = 5
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		bar.add_theme_stylebox_override("panel", sb)
	if status_cash:
		status_cash.add_theme_color_override("font_color", CLR_GOLD)
	if day_label:
		day_label.add_theme_color_override("font_color", CLR_PAPER)
	if close_btn:
		UITheme.style_close_button(close_btn)
		close_btn.add_theme_font_size_override("font_size", 30)

func _style_nav_buttons() -> void:
	for btn in [nav_overview, nav_spending, nav_budget, nav_loans, nav_report, nav_history]:
		if btn:
			_style_nav_inactive(btn)
			_pf(btn)  # emoji-safe: nav labels carry icons, so keep default font there

func _style_nav_active(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_GREEN
	sb.border_color = CLR_INK
	sb.set_border_width_all(4)
	sb.border_width_bottom = 9
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

func _style_nav_inactive(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_PAPER2
	sb.border_color = CLR_INK
	sb.set_border_width_all(4)
	sb.border_width_bottom = 9
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h: StyleBoxFlat = sb.duplicate()
	sb_h.bg_color = CLR_PAPER
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p: StyleBoxFlat = sb.duplicate()
	sb_p.bg_color = CLR_PAPER2.darkened(0.06)
	sb_p.border_width_bottom = 4
	sb_p.content_margin_top = 19
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_color_override("font_color", CLR_INK)
	btn.add_theme_color_override("font_hover_color", CLR_INK)
	btn.add_theme_color_override("font_pressed_color", CLR_INK)

func _style_toggle_buttons() -> void:
	if breakdown_btn: UITheme.style_pixel_button(breakdown_btn, true)
	if graphs_btn:    UITheme.style_pixel_button(graphs_btn, true)

func _style_deposit_withdraw_buttons() -> void:
	var emer := "Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Overview/EmergencyCard/VBox/"
	var deposit_btn  = get_node_or_null(emer + "BtnRow/DepositBtn")
	var withdraw_btn = get_node_or_null(emer + "BtnRow/WithdrawBtn")
	if deposit_btn:  UITheme.style_pixel_button(deposit_btn)
	if withdraw_btn: UITheme.style_pixel_button(withdraw_btn, true)
	if deposit_input: UITheme.style_line_edit(deposit_input)
	var font := UITheme.get_pixel_font()
	# Pixel font + paper-card styling on the overview's titled cards/labels
	for path in ["ThisWeekLabel", "BudgetsLabel", "SavingsGoalLabel", "EmergencyLabel",
				 "EmergencyCard/VBox/SavingsLabel", "EmergencyCard/VBox/DepositLabel",
				 "EmergencyCard/VBox/PenaltyWarning", "EmergencyCard/VBox/InterestInfo",
				 "Stat2/IncomeCard/VBox/IncomeK", "Stat2/IncomeCard/VBox/IncomeValue", "Stat2/IncomeCard/VBox/IncomeSub",
				 "Stat2/ExpenseCard/VBox/ExpenseK", "Stat2/ExpenseCard/VBox/ExpenseValue", "Stat2/ExpenseCard/VBox/ExpenseSub",
				 "NetCard/VBox/NetHeader/NetTitle", "NetCard/VBox/NetHeader/NetHint", "NetCard/VBox/NetValue",
				 "GoalCard/VBox/GoalHeader/GoalName", "GoalCard/VBox/GoalHeader/GoalAmt"]:
		var n = overview_tab.get_node_or_null(path)
		if n and font: n.add_theme_font_override("font", font)
	# Paper cards + accent-bordered stat cards
	for path in ["NetCard", "GoalCard", "EmergencyCard"]:
		var c = overview_tab.get_node_or_null(path)
		if c is PanelContainer: _apply_sb(c, _sb_paper_card())
	var inc = overview_tab.get_node_or_null("Stat2/IncomeCard")
	if inc is PanelContainer: _style_accent_card(inc, CLR_GREEN_D)
	var exp = overview_tab.get_node_or_null("Stat2/ExpenseCard")
	if exp is PanelContainer: _style_accent_card(exp, CLR_RED_D)

# ── Loans ──────────────────────────────────────────────────────────────────────
func _style_loan_panels() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_PAPER
	sb.border_color = CLR_INK
	sb.set_border_width_all(4)
	sb.border_width_left = 10
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(20)
	credit_card.add_theme_stylebox_override("panel", sb)
	_apply_sb(action_card, _sb_paper_card())
	UITheme.style_warning_strip(loan_warning, "red")
	if loan_input: UITheme.style_line_edit(loan_input)
	var font := UITheme.get_pixel_font()
	for lbl in [loan_balance_label, loan_limit_label, loan_rate_label,
				loan_accrued_label, loan_impact_label]:
		if lbl and font: lbl.add_theme_font_override("font", font)
	_apply_ink_to_labels(credit_card)
	var section := get_node_or_null("Window/VBox/BodyMargin/Body/Main/MainVBox/ViewScroll/Views/Loans/CreditBarSection")
	if section: _apply_ink_to_labels(section)
	_apply_cream_to_labels(loan_warning)

func _apply_ink_to_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", CLR_INK)
		_apply_ink_to_labels(child)

func _apply_cream_to_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color("#ffe3c6"))
		_apply_cream_to_labels(child)

func _hook_credit_bar_canvas() -> void:
	credit_bar.draw.connect(_draw_credit_bar)

func _draw_credit_bar() -> void:
	var sz := credit_bar.size
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = CLR_PAPER2
	track_sb.border_color = CLR_INK
	track_sb.set_border_width_all(3)
	track_sb.set_corner_radius_all(0)
	credit_bar.draw_style_box(track_sb, Rect2(Vector2.ZERO, sz))
	var ratio: float = clamp(_credit_bar_ratio, 0.0, 1.0)
	if ratio <= 0.0: return
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = CLR_RED
	fill_sb.border_color = CLR_INK
	fill_sb.set_border_width_all(3)
	fill_sb.set_corner_radius_all(0)
	credit_bar.draw_style_box(fill_sb, Rect2(Vector2.ZERO, Vector2(sz.x * ratio, sz.y)))

func update_loans() -> void:
	if not loan_balance_label: return
	var owed := GameState.loan_balance
	var cap  := GameState.max_loan_amount
	var weekly_pct  := int(round(GameState.loan_interest_rate * 100.0))
	var next_charge := int(ceil(float(owed) * GameState.loan_interest_rate))
	loan_balance_label.text = "$%d" % owed
	loan_balance_label.add_theme_color_override("font_color", CLR_RED_D if owed > 0 else CLR_GREEN_D)
	loan_limit_label.text   = "$%d / $%d available" % [owed, cap]
	loan_limit_label.add_theme_color_override("font_color", CLR_INK2)
	loan_rate_label.text    = "%d%%" % weekly_pct
	loan_rate_label.add_theme_color_override("font_color", CLR_ORANGE)
	loan_accrued_label.text = "$%d" % GameState.loan_interest_accrued
	loan_accrued_label.add_theme_color_override("font_color", CLR_RED_D)
	loan_impact_label.text  = "$%d" % next_charge
	loan_impact_label.add_theme_color_override("font_color", CLR_INK)
	_credit_bar_ratio = 0.0 if cap <= 0 else float(owed) / float(cap)
	credit_bar.queue_redraw()

func _style_loan_buttons() -> void:
	if borrow_btn: UITheme.style_pixel_button(borrow_btn)
	if repay_btn:  UITheme.style_pixel_button(repay_btn, true)

# ── Signal handlers ──────────────────────────────────────────────────────────────
func _on_close_btn_pressed() -> void: hide_menu()

func _on_buy_home_pressed() -> void:
	if GameState.buy_home():
		update_ui()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("House purchased successfully!", CLR_GREEN)
		await get_tree().create_timer(1.2, false, true).timeout
		SceneManager.change_scene("res://scenes/ui/FinalStatsScreen.tscn", {"pattern": "curtains"})

func _on_deposit_btn_pressed() -> void:
	var amount := float(deposit_input.text)
	if amount > 0.0:
		if GameState.deposit_to_savings(amount):
			deposit_input.text = ""
			update_ui()

func _on_withdraw_btn_pressed() -> void:
	var amount := float(deposit_input.text)
	if amount > 0.0:
		var received := GameState.withdraw_from_savings(amount)
		if received > 0.0:
			deposit_input.text = ""
			update_ui()

func _on_food_slider_value_changed(value: float) -> void:
	GameState.budget_data["Food"]["limit"] = value
	food_limit_label.text = "$%.2f" % value
	update_budget_inputs()
	update_overview()

func _on_vet_slider_value_changed(value: float) -> void:
	GameState.budget_data["Vet"]["limit"] = value
	vet_limit_label.text = "$%.2f" % value
	update_budget_inputs()
	update_overview()

func _on_travel_slider_value_changed(value: float) -> void:
	GameState.budget_data["Travel"]["limit"] = value
	travel_limit_label.text = "$%.2f" % value
	update_budget_inputs()
	update_overview()

func _on_breakdown_btn_pressed() -> void:
	breakdown_btn.button_pressed = true
	graphs_btn.button_pressed    = false
	breakdown_view.visible       = true
	graph_view.visible           = false

func _on_graphs_btn_pressed() -> void:
	breakdown_btn.button_pressed = false
	graphs_btn.button_pressed    = true
	breakdown_view.visible       = false
	graph_view.visible           = true
	graph_canvas.build_graph_data(GameState.transaction_history)

func _on_borrow_btn_pressed() -> void:
	var amount := float(loan_input.text)
	if amount > 0.0:
		if GameState.take_loan(amount):
			loan_input.text = ""
			update_ui()

func _on_repay_btn_pressed() -> void:
	var amount := float(loan_input.text)
	if amount > 0.0:
		var paid := GameState.repay_loan(amount)
		if paid > 0.0:
			loan_input.text = ""
			update_ui()

# Nav handlers
func _on_nav_overview_pressed() -> void: _switch_view("Overview")
func _on_nav_spending_pressed() -> void: _switch_view("Spending")
func _on_nav_budget_pressed()   -> void: _switch_view("BudgetPlanner")
func _on_nav_loans_pressed()    -> void: _switch_view("Loans")
func _on_nav_report_pressed()   -> void: _switch_view("WeeklyReport")
func _on_nav_history_pressed()  -> void: _switch_view("AllTimeHistory")
