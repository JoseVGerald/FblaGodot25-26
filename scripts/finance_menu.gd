# finance_menu.gd
# Financial Hub overlay — sky-blue / green pixel-art identity.
# Tabs: Overview | BudgetPlanner | WeeklyReport | Loans | AllTimeHistory.
extends CanvasLayer

signal menu_closed

var buy_home_btn: Button = null
var home_progress_lbl: Label = null

# ── Colour palette (design tokens from handoff) ──────────────────────────────
const CLR_NAVY_DEEP  := Color("#0d1b36")
const CLR_NAVY       := Color("#1a2a4a")
const CLR_NAVY_LIGHT := Color("#1e3a6e")
const CLR_NAVY_CARD  := Color("#162240")
const CLR_SKY        := Color("#4A90D9")
const CLR_SKY_DIM    := Color("#2d6aad")
const CLR_CYAN       := Color("#53d8fb")
const CLR_GREEN      := Color("#4CAF50")
const CLR_ORANGE     := Color("#FFA726")
const CLR_RED        := Color("#EF5350")
const CLR_GOLD       := Color("#FFD700")
const CLR_WHITE      := Color("#f0f4ff")
const CLR_DIM        := Color(0.94, 0.96, 1.0, 0.45)
const CLR_CAT_FOOD   := Color("#4CAF50")
const CLR_CAT_VET    := Color("#4A90D9")
const CLR_CAT_TRAVEL := Color("#FFA726")
const CLR_CAT_INCOME := Color("#53d8fb")
const CLR_CAT_LOAN   := Color("#EF5350")

# ── Scene node refs ──────────────────────────────────────────────────────────
@onready var overview_tab    = $Panel/VBox/Content/TabContainer/Overview
@onready var budget_tab      = $Panel/VBox/Content/TabContainer/BudgetPlanner
@onready var report_tab      = $Panel/VBox/Content/TabContainer/WeeklyReport
@onready var spendable_label = $Panel/VBox/Content/TabContainer/Overview/SpendableLabel
@onready var savings_label   = $Panel/VBox/Content/TabContainer/Overview/SavingsLabel
@onready var deposit_input   = $Panel/VBox/Content/TabContainer/Overview/DepositInput
@onready var day_label       = $Panel/VBox/Header/TitleBlock/DayLabel

# Budget Planner — cards
@onready var food_card    = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodCard
@onready var vet_card     = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetCard
@onready var travel_card  = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelCard
@onready var budget_warning = $Panel/VBox/Content/TabContainer/BudgetPlanner/WarningStrip

@onready var food_slider        = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodCard/VBox/FoodSlider
@onready var vet_slider         = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetCard/VBox/VetSlider
@onready var travel_slider      = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelCard/VBox/TravelSlider
@onready var food_limit_label   = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodCard/VBox/HeaderRow/FoodLimitLabel
@onready var vet_limit_label    = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetCard/VBox/HeaderRow/VetLimitLabel
@onready var travel_limit_label = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelCard/VBox/HeaderRow/TravelLimitLabel

@onready var food_progress_bar: Control   = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodCard/VBox/FoodProgressBar
@onready var vet_progress_bar: Control    = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetCard/VBox/VetProgressBar
@onready var travel_progress_bar: Control = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelCard/VBox/TravelProgressBar

@onready var food_spent_label    = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodCard/VBox/MetaRow/SpentLabel
@onready var food_limit_meta     = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodCard/VBox/MetaRow/LimitLabel
@onready var vet_spent_label     = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetCard/VBox/MetaRow/SpentLabel
@onready var vet_limit_meta      = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetCard/VBox/MetaRow/LimitLabel
@onready var travel_spent_label  = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelCard/VBox/MetaRow/SpentLabel
@onready var travel_limit_meta   = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelCard/VBox/MetaRow/LimitLabel

# Weekly Report
@onready var week_strip         = $Panel/VBox/Content/TabContainer/WeeklyReport/WeekStrip
@onready var week_label         = $Panel/VBox/Content/TabContainer/WeeklyReport/WeekStrip/HBox/WeekLabel
@onready var report_income_val  = $Panel/VBox/Content/TabContainer/WeeklyReport/WeekStrip/HBox/IncomeStat/Value
@onready var report_spent_val   = $Panel/VBox/Content/TabContainer/WeeklyReport/WeekStrip/HBox/SpentStat/Value
@onready var report_net_val     = $Panel/VBox/Content/TabContainer/WeeklyReport/WeekStrip/HBox/NetStat/Value
@onready var report_emer_val    = $Panel/VBox/Content/TabContainer/WeeklyReport/WeekStrip/HBox/EmergencyStat/Value
@onready var breakdown_title    = $Panel/VBox/Content/TabContainer/WeeklyReport/BreakdownTitle
@onready var breakdown_card     = $Panel/VBox/Content/TabContainer/WeeklyReport/BreakdownCard
@onready var breakdown_grid     = $Panel/VBox/Content/TabContainer/WeeklyReport/BreakdownCard/BreakdownGrid
@onready var events_title       = $Panel/VBox/Content/TabContainer/WeeklyReport/EventsTitle
@onready var events_card        = $Panel/VBox/Content/TabContainer/WeeklyReport/EventsCard
@onready var events_grid        = $Panel/VBox/Content/TabContainer/WeeklyReport/EventsCard/EventsGrid

# History
@onready var history_cash_label  = $Panel/VBox/Content/TabContainer/AllTimeHistory/CashHeader
@onready var history_spent_label = $Panel/VBox/Content/TabContainer/AllTimeHistory/SpentTotalLabel
@onready var history_list        = $Panel/VBox/Content/TabContainer/AllTimeHistory/BreakdownView/ScrollContainer/HistoryList
@onready var breakdown_btn  = $Panel/VBox/Content/TabContainer/AllTimeHistory/ViewToggleContainer/BreakdownBtn
@onready var graphs_btn     = $Panel/VBox/Content/TabContainer/AllTimeHistory/ViewToggleContainer/GraphsBtn
@onready var breakdown_view = $Panel/VBox/Content/TabContainer/AllTimeHistory/BreakdownView
@onready var graph_view     = $Panel/VBox/Content/TabContainer/AllTimeHistory/GraphView
@onready var graph_canvas   = $Panel/VBox/Content/TabContainer/AllTimeHistory/GraphView/GraphCanvas
@onready var close_btn      = $Panel/VBox/Header/CloseBtn

# Loans tab
@onready var credit_card         = $Panel/VBox/Content/TabContainer/Loans/CreditCard
@onready var loan_balance_label  = $Panel/VBox/Content/TabContainer/Loans/CreditCard/VBox/LoanBalanceLabel
@onready var loan_limit_label    = $Panel/VBox/Content/TabContainer/Loans/CreditBarSection/BarHeader/LoanLimitLabel
@onready var loan_rate_label     = $Panel/VBox/Content/TabContainer/Loans/CreditCard/VBox/FooterRow/RateStat/LoanRateLabel
@onready var loan_accrued_label  = $Panel/VBox/Content/TabContainer/Loans/CreditCard/VBox/FooterRow/AccruedStat/LoanAccruedLabel
@onready var loan_impact_label   = $Panel/VBox/Content/TabContainer/Loans/CreditCard/VBox/FooterRow/NextStat/ImpactLabel
@onready var credit_bar: Control = $Panel/VBox/Content/TabContainer/Loans/CreditBarSection/CreditBar
@onready var action_card         = $Panel/VBox/Content/TabContainer/Loans/ActionCard
@onready var loan_input          = $Panel/VBox/Content/TabContainer/Loans/ActionCard/VBox/ActionRow/LoanInput
@onready var borrow_btn          = $Panel/VBox/Content/TabContainer/Loans/ActionCard/VBox/ActionRow/BorrowBtn
@onready var repay_btn           = $Panel/VBox/Content/TabContainer/Loans/ActionCard/VBox/ActionRow/RepayBtn
@onready var loan_warning        = $Panel/VBox/Content/TabContainer/Loans/LoanWarning

# ── Pie chart state ────────────────────────────────────────────────────────────

var _pie_canvas      : Control = null
var _pie_tooltip     : Label   = null
var _pie_slices      : Array   = []
var _pie_center      : Vector2 = Vector2.ZERO
var _pie_radius      : float   = 0.0

# Cached credit-bar fill ratio for _draw()
var _credit_bar_ratio : float = 0.0

# Per-card progress fill ratio + colour for _draw()
var _budget_progress : Dictionary = {
	"Food":   {"ratio": 0.0, "color": CLR_CAT_FOOD},
	"Vet":    {"ratio": 0.0, "color": CLR_CAT_VET},
	"Travel": {"ratio": 0.0, "color": CLR_CAT_TRAVEL},
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_style_root_panel()
	_grow_panel_to_viewport()
	_apply_finance_panel_scale_and_close_style()
	_style_toggle_buttons()
	_style_deposit_withdraw_buttons()
	_style_header_title()
	_grow_tab_fonts()
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

	# Dynamic Buy House controls for Adult pathway
	var overview = $Panel/VBox/Content/TabContainer/Overview
	if overview and GameState.selected_pathway == "adult":
		home_progress_lbl = Label.new()
		home_progress_lbl.name = "HomeProgressLabel"
		home_progress_lbl.add_theme_font_size_override("font_size", 28)
		home_progress_lbl.add_theme_color_override("font_color", CLR_GOLD)
		var font := UITheme.get_pixel_font()
		if font: home_progress_lbl.add_theme_font_override("font", font)
		overview.add_child(home_progress_lbl)
		
		buy_home_btn = Button.new()
		buy_home_btn.name = "BuyHomeButton"
		buy_home_btn.text = "Buy House ($%.2f)" % GameState.house_price
		buy_home_btn.add_theme_font_size_override("font_size", 30)
		buy_home_btn.custom_minimum_size = Vector2(240, 60)
		UITheme.style_button(buy_home_btn, CLR_GREEN)
		overview.add_child(buy_home_btn)
		buy_home_btn.pressed.connect(_on_buy_home_pressed)

	update_ui()

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

# ── Public API ─────────────────────────────────────────────────────────────────

func show_menu() -> void:
	visible = true
	update_ui()
	update_history()

func hide_menu() -> void:
	visible = false
	menu_closed.emit()

func update_ui() -> void:
	_update_day_label()
	update_overview()
	update_budget_inputs()
	update_report()
	update_loans()
	update_history_header()

# ── Header ────────────────────────────────────────────────────────────────────

func _update_day_label() -> void:
	if not day_label:
		return
	var day := GameState.current_day
	var week: int = int(float(day) / 7.0) + 1
	day_label.text = "DAY %d · WEEK %d" % [max(1, day), week]
	day_label.add_theme_color_override("font_color", CLR_DIM)
	var font := UITheme.get_pixel_font()
	if font: day_label.add_theme_font_override("font", font)

# ── Overview tab ──────────────────────────────────────────────────────────────

func update_overview() -> void:
	spendable_label.text = "Spending Money: $%.2f" % GameState.money
	spendable_label.add_theme_color_override("font_color", CLR_GREEN)
	savings_label.text = "Emergency Savings: $%.2f" % GameState.savings_balance
	savings_label.add_theme_color_override("font_color", CLR_CYAN)

	var food_spent   = GameState.budget_data["Food"]["spent"]
	var vet_spent    = GameState.budget_data["Vet"]["spent"]
	var travel_spent = GameState.budget_data["Travel"]["spent"]
	var total_spent  = food_spent + vet_spent + travel_spent

	var food_pct   := 0.0
	var vet_pct    := 0.0
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

	_ensure_pie_canvas()
	if _pie_canvas:
		_pie_canvas.queue_redraw()

	if is_instance_valid(home_progress_lbl):
		if GameState.house_owned:
			home_progress_lbl.text = "CONGRATULATIONS! House Purchased!"
			buy_home_btn.visible = false
		else:
			home_progress_lbl.text = "Goal: Buy House ($%.2f) - Cash: $%.2f / $%.2f" % [GameState.house_price, GameState.money, GameState.house_price]
			buy_home_btn.text = "Buy House ($%.2f)" % GameState.house_price
			buy_home_btn.visible = true
			buy_home_btn.disabled = GameState.money < GameState.house_price

# ──────────────────────────────────────────────────────────────────────────────
#  PIE CHART — Canvas + hover
# ──────────────────────────────────────────────────────────────────────────────

func _ensure_pie_canvas() -> void:
	if _pie_canvas:
		return

	var overview = $Panel/VBox/Content/TabContainer/Overview

	for node_name in ["BudgetsTitle", "FoodLabel", "FoodProgress",
					   "VetLabel", "VetProgress", "TravelLabel", "TravelProgress"]:
		var n = overview.get_node_or_null(node_name)
		if n:
			n.visible = false

	_pie_canvas = Control.new()
	_pie_canvas.name = "PieChartCanvas"
	_pie_canvas.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_pie_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pie_canvas.custom_minimum_size   = Vector2(200, 200)
	_pie_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	overview.add_child(_pie_canvas)

	_pie_canvas.draw.connect(_on_pie_draw)
	_pie_canvas.gui_input.connect(_on_pie_input)
	_pie_canvas.mouse_exited.connect(func(): _hide_pie_tooltip())

	_pie_tooltip = Label.new()
	_pie_tooltip.visible = false
	_pie_tooltip.add_theme_font_size_override("font_size", 28)
	_pie_tooltip.add_theme_color_override("font_color", CLR_WHITE)
	var font := UITheme.get_pixel_font()
	if font:
		_pie_tooltip.add_theme_font_override("font", font)
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0, 0, 0, 0.85)
	tip_sb.border_color = CLR_SKY
	tip_sb.set_border_width_all(2)
	tip_sb.set_corner_radius_all(6)
	tip_sb.set_content_margin_all(10)
	_pie_tooltip.add_theme_stylebox_override("normal", tip_sb)
	_pie_canvas.add_child(_pie_tooltip)


func _on_pie_draw() -> void:
	if not _pie_canvas or _pie_slices.is_empty():
		return

	var sz := _pie_canvas.size
	_pie_radius = min(sz.x, sz.y) * 0.38
	_pie_center = sz * 0.5

	var seg := 64

	for slice in _pie_slices:
		var points := PackedVector2Array()
		points.append(_pie_center)
		var start_a : float = slice["start_angle"]
		var end_a   : float = slice["end_angle"]
		var sweep   := end_a - start_a
		for j in range(seg + 1):
			var a := start_a + sweep * (float(j) / float(seg))
			points.append(_pie_center + Vector2(cos(a), sin(a)) * _pie_radius)
		_pie_canvas.draw_colored_polygon(points, slice["color"])

	var outline_pts := PackedVector2Array()
	for j in range(129):
		var a := float(j) / 128.0 * TAU
		outline_pts.append(_pie_center + Vector2(cos(a), sin(a)) * _pie_radius)
	_pie_canvas.draw_polyline(outline_pts, CLR_SKY, 2.0)

	for slice in _pie_slices:
		var p1 := _pie_center + Vector2(cos(slice["start_angle"]), sin(slice["start_angle"])) * _pie_radius
		_pie_canvas.draw_line(_pie_center, p1, CLR_NAVY, 2.0)


func _on_pie_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos : Vector2 = event.position
		var dist := local_pos.distance_to(_pie_center)
		if dist > _pie_radius or _pie_radius == 0.0:
			_hide_pie_tooltip()
			return

		var angle := atan2(local_pos.y - _pie_center.y, local_pos.x - _pie_center.x)

		for slice in _pie_slices:
			var sa : float = slice["start_angle"]
			var ea : float = slice["end_angle"]
			var a_norm := angle
			if a_norm < sa:
				a_norm += TAU
			if a_norm >= sa and a_norm < ea:
				_show_pie_tooltip(slice, local_pos)
				return

		for slice in _pie_slices:
			var sa : float = slice["start_angle"]
			var ea : float = slice["end_angle"]
			var a_norm := angle + TAU
			if a_norm >= sa and a_norm < ea:
				_show_pie_tooltip(slice, local_pos)
				return

		_hide_pie_tooltip()


func _show_pie_tooltip(slice: Dictionary, pos: Vector2) -> void:
	if not _pie_tooltip:
		return
	_pie_tooltip.text = "%s\n%.1f%%  %s" % [slice["name"], slice["pct"], slice["detail"]]
	_pie_tooltip.visible = true
	_pie_tooltip.position = pos + Vector2(16, -50)


func _hide_pie_tooltip() -> void:
	if _pie_tooltip:
		_pie_tooltip.visible = false

# ── Budget Planner tab ────────────────────────────────────────────────────────

func _style_budget_cards() -> void:
	UITheme.style_card(food_card,   CLR_CAT_FOOD,   "left")
	UITheme.style_card(vet_card,    CLR_CAT_VET,    "left")
	UITheme.style_card(travel_card, CLR_CAT_TRAVEL, "left")
	UITheme.style_warning_strip(budget_warning, "orange")
	_style_slider(food_slider,   CLR_CAT_FOOD)
	_style_slider(vet_slider,    CLR_CAT_VET)
	_style_slider(travel_slider, CLR_CAT_TRAVEL)

func _style_slider(slider: HSlider, accent: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(accent.r, accent.g, accent.b, 0.18)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

func _hook_progress_canvases() -> void:
	food_progress_bar.draw.connect(func(): _draw_progress_bar(food_progress_bar, "Food"))
	vet_progress_bar.draw.connect(func(): _draw_progress_bar(vet_progress_bar, "Vet"))
	travel_progress_bar.draw.connect(func(): _draw_progress_bar(travel_progress_bar, "Travel"))

func _draw_progress_bar(ctrl: Control, category: String) -> void:
	var sz := ctrl.size
	var radius: float = min(8.0, sz.y * 0.5)
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(CLR_SKY.r, CLR_SKY.g, CLR_SKY.b, 0.15)
	track_sb.set_corner_radius_all(int(radius))
	ctrl.draw_style_box(track_sb, Rect2(Vector2.ZERO, sz))

	var info: Dictionary = _budget_progress.get(category, {"ratio": 0.0, "color": CLR_SKY})
	var ratio: float = clamp(info.get("ratio", 0.0), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var fill_color: Color = info.get("color", CLR_SKY)
	if ratio > 0.85:
		fill_color = CLR_RED
	elif ratio > 0.60:
		fill_color = CLR_ORANGE

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.set_corner_radius_all(int(radius))
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
		if limit > 0:
			ratio = clamp(spent / limit, 0.0, 1.0)
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

# ── Weekly Report tab ────────────────────────────────────────────────────────

func _style_report_panels() -> void:
	UITheme.style_card(week_strip,     CLR_SKY_DIM, "all")
	UITheme.style_card(breakdown_card, CLR_SKY,     "all")
	UITheme.style_card(events_card,    CLR_SKY,     "all")
	for lbl in [breakdown_title, events_title]:
		var font := UITheme.get_pixel_font()
		if font: lbl.add_theme_font_override("font", font)

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
	report_net_val.add_theme_color_override("font_color", CLR_GREEN if net >= 0 else CLR_RED)
	report_emer_val.text   = "$%.2f" % emergency

	_populate_breakdown_grid(r)
	_populate_events_grid(r, week)

func _populate_breakdown_grid(r: Dictionary) -> void:
	for child in breakdown_grid.get_children():
		child.queue_free()

	_add_grid_header(breakdown_grid, "CATEGORY")
	_add_grid_header(breakdown_grid, "SPENT")
	_add_grid_header(breakdown_grid, "BUDGET")
	_add_grid_header(breakdown_grid, "REMAINING")
	_add_grid_header(breakdown_grid, "STATUS")

	var categories := ["Food", "Vet", "Travel"]
	var breakdown: Dictionary = r.get("category_breakdown", {})
	for cat in categories:
		var spent: float = breakdown.get(cat, 0.0)
		var limit: float = GameState.budget_data[cat]["limit"]
		var remaining: float = limit - spent

		# Pill cell
		var pill := UITheme.make_cat_pill(cat, 33)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		breakdown_grid.add_child(pill)

		var spent_color := CLR_RED if spent > 0 else CLR_DIM
		breakdown_grid.add_child(_make_cell("$%.2f" % spent, spent_color))
		breakdown_grid.add_child(_make_cell("$%.2f" % limit, CLR_DIM))

		var remaining_color := CLR_GREEN
		if remaining <= 0: remaining_color = CLR_RED
		elif spent == 0:   remaining_color = CLR_CYAN
		breakdown_grid.add_child(_make_cell("$%.2f" % remaining, remaining_color))

		var status_text: String
		var status_color: Color
		if spent == 0:
			status_text = "– Unused"
			status_color = CLR_CYAN
		elif remaining <= 0:
			status_text = "✗ Over"
			status_color = CLR_RED
		elif spent / max(1.0, limit) > 0.85:
			status_text = "! Near limit"
			status_color = CLR_ORANGE
		else:
			status_text = "✓ On track"
			status_color = CLR_GREEN
		breakdown_grid.add_child(_make_cell(status_text, status_color))

func _populate_events_grid(r: Dictionary, _week: int) -> void:
	for child in events_grid.get_children():
		child.queue_free()

	_add_grid_header(events_grid, "EVENT")
	_add_grid_header(events_grid, "EFFECT")

	var inflation: float = GameState.inflation_rate if "inflation_rate" in GameState else 1.0
	var inflation_pct: float = (inflation - 1.0) * 100.0
	events_grid.add_child(_make_cell("Inflation rate", CLR_DIM))
	events_grid.add_child(_make_cell("%+0.1f%% on all costs" % inflation_pct, CLR_ORANGE))

	var emergency: float = r.get("emergency_usage", 0.0)
	if emergency > 0:
		events_grid.add_child(_make_cell("Emergency coverage", CLR_DIM))
		events_grid.add_child(_make_cell("-$%.2f from savings" % emergency, CLR_RED))

	var income: float = r.get("income", 0.0)
	if income > 0:
		events_grid.add_child(_make_cell("Weekly allowance", CLR_DIM))
		events_grid.add_child(_make_cell("+$%.2f income" % income, CLR_GREEN))

	if GameState.loan_balance > 0:
		events_grid.add_child(_make_cell("Active loan", CLR_DIM))
		events_grid.add_child(_make_cell("Owed: $%d" % GameState.loan_balance, CLR_RED))

func _add_grid_header(grid: GridContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", CLR_DIM)
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

# ── History header ───────────────────────────────────────────────────────────

func update_history_header() -> void:
	history_cash_label.text  = "Spending Cash: $%.2f" % GameState.money
	history_cash_label.add_theme_color_override("font_color", CLR_GREEN)
	history_spent_label.text = "All-Time Total Spent: $%.2f" % GameState.all_time_spent
	history_spent_label.add_theme_color_override("font_color", CLR_RED)

# ── History list ──────────────────────────────────────────────────────────────

func update_history() -> void:
	for child in history_list.get_children():
		child.queue_free()

	var pixel_font := UITheme.get_pixel_font()
	var row_idx    := 0

	for entry in GameState.transaction_history:
		var row_bg := ColorRect.new()
		row_bg.color = CLR_NAVY_LIGHT if row_idx % 2 == 1 else CLR_NAVY
		row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var h_box := HBoxContainer.new()
		h_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var FONT_SIZE := 34

		var dot := ColorRect.new()
		dot.color = _category_color(entry["category"])
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h_box.add_child(dot)

		var day_lbl := Label.new()
		day_lbl.text = "  [Day %d]  " % entry["day"]
		day_lbl.custom_minimum_size.x = 140
		day_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		day_lbl.add_theme_color_override("font_color", CLR_CYAN)
		if pixel_font:
			day_lbl.add_theme_font_override("font", pixel_font)
		h_box.add_child(day_lbl)

		var desc_label := Label.new()
		desc_label.text = entry["description"]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.add_theme_font_size_override("font_size", FONT_SIZE)
		desc_label.add_theme_color_override("font_color", CLR_WHITE)
		if pixel_font:
			desc_label.add_theme_font_override("font", pixel_font)
		h_box.add_child(desc_label)

		var amount_label := Label.new()
		var is_income    = entry["amount"] >= 0
		var prefix       := "+" if is_income else ""
		amount_label.text = "%s$%.2f" % [prefix, entry["amount"]]
		amount_label.add_theme_color_override("font_color", CLR_GREEN if is_income else CLR_RED)
		amount_label.add_theme_font_size_override("font_size", FONT_SIZE)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if pixel_font:
			amount_label.add_theme_font_override("font", pixel_font)
		h_box.add_child(amount_label)

		row_bg.anchors_preset = Control.PRESET_FULL_RECT
		row_bg.anchor_right   = 1.0
		row_bg.anchor_bottom  = 1.0
		history_list.add_child(row_bg)
		history_list.add_child(h_box)

		var sep := ColorRect.new()
		sep.color = CLR_SKY
		sep.custom_minimum_size = Vector2(0, 1)
		sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		history_list.add_child(sep)

		row_idx += 1

func _category_color(category: String) -> Color:
	match category:
		"Food":   return CLR_CAT_FOOD
		"Vet":    return CLR_CAT_VET
		"Travel": return CLR_CAT_TRAVEL
		"Income": return CLR_GREEN
		"Loan":   return CLR_ORANGE
		_:        return CLR_CYAN

# ── Root panel styling ────────────────────────────────────────────────────────

func _style_root_panel() -> void:
	var panel_node := get_node_or_null("Panel")
	if not panel_node:
		return
	
	var map = load("res://New Ui/FINAL FINANCIAL HUB/Map.tscn").instantiate()
	map.scale = Vector2(7.5, 7.5)
	if map.has_node("Layer_2_0"):
		map.get_node("Layer_2_0").queue_free()
	
	var bg = Node2D.new()
	bg.name = "Backdrop"
	bg.add_child(map)
	panel_node.add_child(bg)
	panel_node.move_child(bg, 0)

	if panel_node is PanelContainer or panel_node is Panel:
		panel_node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel_node.modulate.a = 1.0

func _apply_finance_panel_scale_and_close_style() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node:
		panel_node.scale = Vector2(0.85, 0.85)
		call_deferred("_center_finance_panel_pivot")
	if close_btn:
		close_btn.text = "X"
		close_btn.custom_minimum_size = Vector2(64, 64)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("#ef5350")
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		close_btn.add_theme_stylebox_override("normal", sb)
		close_btn.add_theme_stylebox_override("hover", sb)
		close_btn.add_theme_stylebox_override("pressed", sb)
		UITheme._do_juice_on(close_btn)
		close_btn.add_theme_font_size_override("font_size", 32)
		
		if not close_btn.pressed.is_connected(hide_menu):
			close_btn.pressed.connect(hide_menu)


func _center_finance_panel_pivot() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node:
		panel_node.pivot_offset = panel_node.size * 0.5


func _grow_panel_to_viewport() -> void:
	var panel_node := get_node_or_null("Panel")
	if not panel_node:
		return
	panel_node.anchor_left   = 0.05
	panel_node.anchor_right  = 0.95
	panel_node.anchor_top    = 0.03
	panel_node.anchor_bottom = 0.95
	panel_node.offset_left   = 0
	panel_node.offset_right  = 0
	panel_node.offset_top    = 0
	panel_node.offset_bottom = 0
	panel_node.custom_minimum_size = Vector2(900, 700)

	if graph_view:
		graph_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		graph_view.custom_minimum_size.y = 300
	if graph_canvas:
		graph_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		graph_canvas.custom_minimum_size.y = 260

func _style_header_title() -> void:
	var title_node = get_node_or_null("Panel/VBox/Header/TitleBlock/Title")
	if not title_node:
		title_node = get_node_or_null("Panel/VBox/Header/Title")
	if title_node and title_node is Label:
		title_node.add_theme_font_size_override("font_size", 64)
		title_node.add_theme_color_override("font_color", CLR_CYAN)
		var font := UITheme.get_pixel_font()
		if font: title_node.add_theme_font_override("font", font)

func _grow_tab_fonts() -> void:
	var tab_container = get_node_or_null("Panel/VBox/Content/TabContainer")
	if not tab_container:
		return
	tab_container.add_theme_font_size_override("font_size", 34)
	tab_container.add_theme_color_override("font_selected_color", CLR_CYAN)
	tab_container.add_theme_color_override("font_unselected_color", CLR_DIM)
	tab_container.add_theme_color_override("font_hovered_color", CLR_WHITE)
	var font := UITheme.get_pixel_font()
	if font:
		tab_container.add_theme_font_override("font", font)

	# Tab strip styling: underline active, no background
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color.TRANSPARENT
	sel.border_color = CLR_CYAN
	sel.border_width_bottom = 4
	sel.set_corner_radius_all(0)
	sel.content_margin_left = 18
	sel.content_margin_right = 18
	sel.content_margin_top = 10
	sel.content_margin_bottom = 10
	tab_container.add_theme_stylebox_override("tab_selected", sel)

	var unsel: StyleBoxFlat = sel.duplicate()
	unsel.border_color = Color.TRANSPARENT
	tab_container.add_theme_stylebox_override("tab_unselected", unsel)

	var hov: StyleBoxFlat = sel.duplicate()
	hov.border_color = Color(CLR_CYAN.r, CLR_CYAN.g, CLR_CYAN.b, 0.4)
	tab_container.add_theme_stylebox_override("tab_hovered", hov)

	var tabbar_bg := StyleBoxFlat.new()
	tabbar_bg.bg_color = CLR_NAVY_DEEP
	tabbar_bg.border_color = CLR_SKY_DIM
	tabbar_bg.border_width_bottom = 2
	tabbar_bg.set_corner_radius_all(0)
	tab_container.add_theme_stylebox_override("tabbar_background", tabbar_bg)

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = CLR_NAVY
	panel_sb.set_corner_radius_all(0)
	panel_sb.content_margin_left = 18
	panel_sb.content_margin_right = 18
	panel_sb.content_margin_top = 18
	panel_sb.content_margin_bottom = 18
	tab_container.add_theme_stylebox_override("panel", panel_sb)

# ── Toggle button styling ─────────────────────────────────────────────────────

func _style_toggle_buttons() -> void:
	if breakdown_btn:
		UITheme.style_button(breakdown_btn, CLR_GREEN)
	if graphs_btn:
		UITheme.style_button(graphs_btn, CLR_GREEN)

func _style_deposit_withdraw_buttons() -> void:
	var deposit_btn = get_node_or_null("Panel/VBox/Content/TabContainer/Overview/DepositBtn")
	var withdraw_btn = get_node_or_null("Panel/VBox/Content/TabContainer/Overview/WithdrawBtn")
	if deposit_btn:
		UITheme.style_button(deposit_btn, CLR_GREEN)
	if withdraw_btn:
		UITheme.style_button(withdraw_btn, CLR_ORANGE)

# ── Loans tab ─────────────────────────────────────────────────────────────────

func _style_loan_panels() -> void:
	# Credit card: dark navy+plum blend via solid card helper, red accent border
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_NAVY_DEEP
	sb.border_color = Color(CLR_RED.r, CLR_RED.g, CLR_RED.b, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	credit_card.add_theme_stylebox_override("panel", sb)

	UITheme.style_card(action_card, CLR_SKY, "all")
	UITheme.style_warning_strip(loan_warning, "red")

	# Style the LoanInput LineEdit
	if loan_input:
		UITheme.style_line_edit(loan_input)

	# Apply pixel font + shadow to key labels
	var font := UITheme.get_pixel_font()
	for lbl in [loan_balance_label, loan_limit_label, loan_rate_label,
				loan_accrued_label, loan_impact_label]:
		if lbl and font: lbl.add_theme_font_override("font", font)

func _hook_credit_bar_canvas() -> void:
	credit_bar.draw.connect(_draw_credit_bar)

func _draw_credit_bar() -> void:
	var sz := credit_bar.size
	var radius: float = min(8.0, sz.y * 0.5)
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(CLR_GREEN.r, CLR_GREEN.g, CLR_GREEN.b, 0.18)
	track_sb.set_corner_radius_all(int(radius))
	credit_bar.draw_style_box(track_sb, Rect2(Vector2.ZERO, sz))

	var ratio: float = clamp(_credit_bar_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = CLR_RED
	fill_sb.set_corner_radius_all(int(radius))
	credit_bar.draw_style_box(fill_sb, Rect2(Vector2.ZERO, Vector2(sz.x * ratio, sz.y)))

func update_loans() -> void:
	if not loan_balance_label:
		return
	var owed := GameState.loan_balance
	var cap  := GameState.max_loan_amount
	var weekly_pct := int(round(GameState.loan_interest_rate * 100.0))
	var next_charge := int(ceil(float(owed) * GameState.loan_interest_rate))

	loan_balance_label.text = "$%d" % owed
	loan_balance_label.add_theme_color_override("font_color", CLR_RED if owed > 0 else CLR_GREEN)
	loan_limit_label.text   = "$%d / $%d available" % [owed, cap]
	loan_rate_label.text    = "%d%%" % weekly_pct
	loan_accrued_label.text = "$%d" % GameState.loan_interest_accrued
	loan_impact_label.text  = "$%d" % next_charge

	_credit_bar_ratio = 0.0 if cap <= 0 else float(owed) / float(cap)
	credit_bar.queue_redraw()

func _style_loan_buttons() -> void:
	if borrow_btn:
		UITheme.style_button(borrow_btn, CLR_GREEN)
	if repay_btn:
		UITheme.style_button(repay_btn, CLR_ORANGE)

# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_close_btn_pressed() -> void:
	hide_menu()

func _on_buy_home_pressed() -> void:
	if GameState.buy_home():
		update_ui()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("House purchased successfully!", CLR_GREEN)
		
		# Yield briefly for cinematic pacing, then curtain transition to the Final Stats report!
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
