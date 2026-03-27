# finance_menu.gd
# Financial Hub overlay — sky-blue / green pixel-art identity.
# Tabs: Overview | BudgetPlanner | WeeklyReport | AllTimeHistory.
# Panel sized to 90% of viewport (anchor-based), graph fills 65%+ of height.
extends CanvasLayer

signal menu_closed

# ── Colour palette ────────────────────────────────────────────────────────────
const CLR_NAVY       := Color("#1a2a4a")
const CLR_NAVY_LIGHT := Color("#1e3a6e")
const CLR_NAVY_DEEP  := Color("#0d1b36")
const CLR_SKY        := Color("#4A90D9")
const CLR_CYAN       := Color("#53d8fb")
const CLR_GREEN      := Color("#4CAF50")
const CLR_ORANGE     := Color("#FFA726")
const CLR_RED        := Color("#EF5350")
const CLR_WHITE      := Color.WHITE
const CLR_CAT_FOOD   := Color("#4CAF50")   # Green
const CLR_CAT_VET    := Color("#4A90D9")   # Blue
const CLR_CAT_TRAVEL := Color("#FFA726")   # Orange

# ── Scene node refs ──────────────────────────────────────────────────────────
@onready var overview_tab    = $Panel/VBox/Content/TabContainer/Overview
@onready var budget_tab      = $Panel/VBox/Content/TabContainer/BudgetPlanner
@onready var report_tab      = $Panel/VBox/Content/TabContainer/WeeklyReport
@onready var spendable_label = $Panel/VBox/Content/TabContainer/Overview/SpendableLabel
@onready var savings_label   = $Panel/VBox/Content/TabContainer/Overview/SavingsLabel
@onready var deposit_input   = $Panel/VBox/Content/TabContainer/Overview/DepositInput
@onready var food_slider      = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodSlider
@onready var vet_slider       = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetSlider
@onready var travel_slider    = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelSlider
@onready var food_limit_label   = $Panel/VBox/Content/TabContainer/BudgetPlanner/FoodLimitLabel
@onready var vet_limit_label    = $Panel/VBox/Content/TabContainer/BudgetPlanner/VetLimitLabel
@onready var travel_limit_label = $Panel/VBox/Content/TabContainer/BudgetPlanner/TravelLimitLabel
@onready var history_cash_label  = $Panel/VBox/Content/TabContainer/AllTimeHistory/CashHeader
@onready var history_spent_label = $Panel/VBox/Content/TabContainer/AllTimeHistory/SpentTotalLabel
@onready var history_list        = $Panel/VBox/Content/TabContainer/AllTimeHistory/BreakdownView/ScrollContainer/HistoryList
@onready var breakdown_btn  = $Panel/VBox/Content/TabContainer/AllTimeHistory/ViewToggleContainer/BreakdownBtn
@onready var graphs_btn     = $Panel/VBox/Content/TabContainer/AllTimeHistory/ViewToggleContainer/GraphsBtn
@onready var breakdown_view = $Panel/VBox/Content/TabContainer/AllTimeHistory/BreakdownView
@onready var graph_view     = $Panel/VBox/Content/TabContainer/AllTimeHistory/GraphView
@onready var graph_canvas   = $Panel/VBox/Content/TabContainer/AllTimeHistory/GraphView/GraphCanvas
@onready var report_text    = $Panel/VBox/Content/TabContainer/WeeklyReport/ReportLabel
@onready var close_btn      = $Panel/VBox/Header/CloseBtn

# ── Pie chart state ────────────────────────────────────────────────────────────

var _pie_canvas      : Control = null   # Canvas that we draw the pie on
var _pie_tooltip     : Label   = null   # Hover tooltip label
var _pie_slices      : Array   = []     # [{name, pct, color, start_angle, end_angle}]
var _pie_center      : Vector2 = Vector2.ZERO
var _pie_radius      : float   = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_style_root_panel()
	_grow_panel_to_viewport()
	_apply_finance_panel_scale_and_close_style()
	_style_toggle_buttons()
	_style_deposit_withdraw_buttons()
	_style_header_title()
	_grow_tab_fonts()
	GameState.budget_updated.connect(update_ui)
	GameState.savings_updated.connect(update_ui)
	GameState.history_updated.connect(update_history)
	update_ui()

# ── Public API ─────────────────────────────────────────────────────────────────

func show_menu() -> void:
	visible = true
	update_ui()
	update_history()

func hide_menu() -> void:
	visible = false
	menu_closed.emit()

func update_ui() -> void:
	update_overview()
	update_budget_inputs()
	update_report()
	update_history_header()

# ── Overview tab ──────────────────────────────────────────────────────────────

func update_overview() -> void:
	spendable_label.text = "Spending Money: $%d" % GameState.money
	spendable_label.add_theme_color_override("font_color", CLR_GREEN)
	savings_label.text = "Emergency Savings: $%d" % GameState.savings_balance
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

	# Build slice data for the pie chart
	_pie_slices.clear()
	var food_limit   = GameState.budget_data["Food"]["limit"]
	var vet_limit    = GameState.budget_data["Vet"]["limit"]
	var travel_limit = GameState.budget_data["Travel"]["limit"]

	if total_spent > 0:
		if food_pct > 0:
			_pie_slices.append({"name": "Food & Water", "pct": food_pct, "color": CLR_CAT_FOOD,
				"detail": "$%d / $%d" % [food_spent, food_limit]})
		if vet_pct > 0:
			_pie_slices.append({"name": "Vet & Medicine", "pct": vet_pct, "color": CLR_CAT_VET,
				"detail": "$%d / $%d" % [vet_spent, vet_limit]})
		if travel_pct > 0:
			_pie_slices.append({"name": "Travel", "pct": travel_pct, "color": CLR_CAT_TRAVEL,
				"detail": "$%d / $%d" % [travel_spent, travel_limit]})
	else:
		# Nothing spent yet — show equal placeholder slices
		_pie_slices.append({"name": "Food & Water", "pct": 33.3, "color": CLR_CAT_FOOD,
			"detail": "$0 / $%d" % food_limit})
		_pie_slices.append({"name": "Vet & Medicine", "pct": 33.3, "color": CLR_CAT_VET,
			"detail": "$0 / $%d" % vet_limit})
		_pie_slices.append({"name": "Travel", "pct": 33.4, "color": CLR_CAT_TRAVEL,
			"detail": "$0 / $%d" % travel_limit})

	# Compute start/end angles for each slice
	var angle := -PI / 2.0  # start at 12 o'clock
	for i in _pie_slices.size():
		var sweep : float = _pie_slices[i]["pct"] / 100.0 * TAU
		_pie_slices[i]["start_angle"] = angle
		_pie_slices[i]["end_angle"]   = angle + sweep
		angle += sweep

	_ensure_pie_canvas()
	if _pie_canvas:
		_pie_canvas.queue_redraw()

# ──────────────────────────────────────────────────────────────────────────────
#  PIE CHART — Canvas + hover
# ──────────────────────────────────────────────────────────────────────────────

## Replace the old progress-bar nodes with a custom pie-chart canvas.
## Called once; safe to call again (idempotent).
func _ensure_pie_canvas() -> void:
	if _pie_canvas:
		return

	var overview = $Panel/VBox/Content/TabContainer/Overview

	# Hide old progress bars and labels (they stay in the scene tree)
	for node_name in ["BudgetsTitle", "FoodLabel", "FoodProgress",
					   "VetLabel", "VetProgress", "TravelLabel", "TravelProgress"]:
		var n = overview.get_node_or_null(node_name)
		if n:
			n.visible = false

	# Create pie chart canvas
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

	# Tooltip label (floats above pie)
	_pie_tooltip = Label.new()
	_pie_tooltip.visible = false
	_pie_tooltip.add_theme_font_size_override("font_size", 28)
	_pie_tooltip.add_theme_color_override("font_color", CLR_WHITE)
	var font := UITheme.get_pixel_font()
	if font:
		_pie_tooltip.add_theme_font_override("font", font)
	# Give the tooltip a small styled background
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0, 0, 0, 0.85)
	tip_sb.border_color = CLR_SKY
	tip_sb.set_border_width_all(2)
	tip_sb.set_corner_radius_all(6)
	tip_sb.set_content_margin_all(10)
	_pie_tooltip.add_theme_stylebox_override("normal", tip_sb)
	_pie_canvas.add_child(_pie_tooltip)


## Draw the pie chart.
func _on_pie_draw() -> void:
	if not _pie_canvas or _pie_slices.is_empty():
		return

	var sz := _pie_canvas.size
	_pie_radius = min(sz.x, sz.y) * 0.38
	_pie_center = sz * 0.5

	var seg := 64  # segments per slice for smoothness

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

	# Outline circle
	var outline_pts := PackedVector2Array()
	for j in range(129):
		var a := float(j) / 128.0 * TAU
		outline_pts.append(_pie_center + Vector2(cos(a), sin(a)) * _pie_radius)
	_pie_canvas.draw_polyline(outline_pts, CLR_SKY, 2.0)

	# Slice divider lines
	for slice in _pie_slices:
		var p1 := _pie_center + Vector2(cos(slice["start_angle"]), sin(slice["start_angle"])) * _pie_radius
		_pie_canvas.draw_line(_pie_center, p1, CLR_NAVY, 2.0)




## Check which slice the mouse is over and show tooltip.
func _on_pie_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos : Vector2 = event.position
		var dist := local_pos.distance_to(_pie_center)
		if dist > _pie_radius or _pie_radius == 0.0:
			_hide_pie_tooltip()
			return

		# Find which slice the angle falls into
		var angle := (_pie_center.angle_to_point(local_pos) + PI)  # 0..TAU
		# Convert from angle_to_point (points FROM center TO pos, but inverted) to our system
		angle = atan2(local_pos.y - _pie_center.y, local_pos.x - _pie_center.x)

		for slice in _pie_slices:
			var sa : float = slice["start_angle"]
			var ea : float = slice["end_angle"]
			# Normalize angle to match our range
			var a_norm := angle
			if a_norm < sa:
				a_norm += TAU
			if a_norm >= sa and a_norm < ea:
				_show_pie_tooltip(slice, local_pos)
				return

		# Also try with +TAU for wrap-around slices
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
	# Highlight: slightly brighten the canvas (optional visual feedback)


func _hide_pie_tooltip() -> void:
	if _pie_tooltip:
		_pie_tooltip.visible = false

# ── Budget Planner tab ────────────────────────────────────────────────────────

func update_budget_inputs() -> void:
	if not food_slider.has_focus():
		food_slider.value = GameState.budget_data["Food"]["limit"]
		food_limit_label.text = "$%d" % food_slider.value
	if not vet_slider.has_focus():
		vet_slider.value = GameState.budget_data["Vet"]["limit"]
		vet_limit_label.text = "$%d" % vet_slider.value
	if not travel_slider.has_focus():
		travel_slider.value = GameState.budget_data["Travel"]["limit"]
		travel_limit_label.text = "$%d" % travel_slider.value

# ── Weekly Report tab ────────────────────────────────────────────────────────

func update_report() -> void:
	var r    := GameState.weekly_report
	var week := int(float(GameState.current_day) / 7.0) + 1
	var text := "Weekly Financial Report  (Week %d)\n\n" % week
	text += "Income Received:  +$%d\n" % r["income"]
	text += "Total Spending:   -$%d\n" % r["total_spent"]
	text += "─────────────────────────\n"
	text += "Category Breakdown:\n"
	for cat in r["category_breakdown"]:
		text += "   %s:  $%d\n" % [cat, r["category_breakdown"][cat]]
	text += "─────────────────────────\n"
	text += "Emergency Fund Used:  $%d" % r["emergency_usage"]
	report_text.text = text

# ── History header ───────────────────────────────────────────────────────────

func update_history_header() -> void:
	history_cash_label.text  = "Spending Cash: $%d" % GameState.money
	history_cash_label.add_theme_color_override("font_color", CLR_GREEN)
	history_spent_label.text = "All-Time Total Spent: $%d" % GameState.all_time_spent
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

		var day_label := Label.new()
		day_label.text = "  [Day %d]  " % entry["day"]
		day_label.custom_minimum_size.x = 140
		day_label.add_theme_font_size_override("font_size", FONT_SIZE)
		day_label.add_theme_color_override("font_color", CLR_CYAN)
		if pixel_font:
			day_label.add_theme_font_override("font", pixel_font)
		h_box.add_child(day_label)

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
		amount_label.text = "%s$%d" % [prefix, entry["amount"]]
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

## Return the colour associated with a budget category.
func _category_color(category: String) -> Color:
	match category:
		"Food":   return CLR_CAT_FOOD
		"Vet":    return CLR_CAT_VET
		"Travel": return CLR_CAT_TRAVEL
		"Income": return CLR_GREEN
		_:        return CLR_CYAN

# ── Root panel styling ────────────────────────────────────────────────────────

func _style_root_panel() -> void:
	var panel_node := get_node_or_null("Panel")
	if not panel_node:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_NAVY
	sb.border_color = CLR_SKY
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	if panel_node is PanelContainer or panel_node is Panel:
		panel_node.add_theme_stylebox_override("panel", sb)
	panel_node.modulate.a = 1.0

## Scale entire Financial Hub panel to 85%; center pivot so it shrinks visually from the middle.
## Style close button like Shop (red #EF5350, white "X").
func _apply_finance_panel_scale_and_close_style() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node:
		panel_node.scale = Vector2(0.85, 0.85)
		call_deferred("_center_finance_panel_pivot")
	if close_btn:
		UITheme.style_button(close_btn, CLR_RED)
		close_btn.add_theme_font_size_override("font_size", 32)


func _center_finance_panel_pivot() -> void:
	var panel_node := get_node_or_null("Panel")
	if panel_node:
		panel_node.pivot_offset = panel_node.size * 0.5


## Grow the panel to fill ~90% of the viewport using anchors.
## Graph area takes 65%+ of panel height.
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
	# Enforce minimums
	panel_node.custom_minimum_size = Vector2(900, 700)

	# Make the graph canvas fill at least 65% of its container
	if graph_view:
		graph_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		graph_view.custom_minimum_size.y = 300
	if graph_canvas:
		graph_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		graph_canvas.custom_minimum_size.y = 260

## Style the "Financial Hub" title at 28px and cyan colour.
func _style_header_title() -> void:
	var title_node = get_node_or_null("Panel/VBox/Header/Title")
	if not title_node:
		# Try alternative path
		title_node = get_node_or_null("Panel/VBox/Title")
	if title_node and title_node is Label:
		title_node.add_theme_font_size_override("font_size", 64)
		title_node.add_theme_color_override("font_color", CLR_WHITE)

## Increase tab label font sizes to at least 15px.
func _grow_tab_fonts() -> void:
	var tab_container = get_node_or_null("Panel/VBox/Content/TabContainer")
	if not tab_container:
		return
	tab_container.add_theme_font_size_override("font_size", 38)

# ── Toggle button styling ─────────────────────────────────────────────────────

func _style_toggle_buttons() -> void:
	if breakdown_btn:
		UITheme.style_button(breakdown_btn, CLR_GREEN)
	if graphs_btn:
		UITheme.style_button(graphs_btn, CLR_GREEN)

## Style the Deposit (green) and Withdraw (orange/red) buttons.
func _style_deposit_withdraw_buttons() -> void:
	var deposit_btn = get_node_or_null("Panel/VBox/Content/TabContainer/Overview/DepositBtn")
	var withdraw_btn = get_node_or_null("Panel/VBox/Content/TabContainer/Overview/WithdrawBtn")
	if deposit_btn:
		UITheme.style_button(deposit_btn, CLR_GREEN)
	if withdraw_btn:
		UITheme.style_button(withdraw_btn, CLR_ORANGE)

# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_close_btn_pressed() -> void:
	hide_menu()

func _on_deposit_btn_pressed() -> void:
	var amount := int(deposit_input.text)
	if amount > 0:
		if GameState.deposit_to_savings(amount):
			deposit_input.text = ""
			update_ui()

func _on_withdraw_btn_pressed() -> void:
	var amount := int(deposit_input.text)
	if amount > 0:
		var received := GameState.withdraw_from_savings(amount)
		if received > 0:
			deposit_input.text = ""
			update_ui()

func _on_food_slider_value_changed(value: float) -> void:
	GameState.budget_data["Food"]["limit"] = int(value)
	food_limit_label.text = "$%d" % value
	update_overview()

func _on_vet_slider_value_changed(value: float) -> void:
	GameState.budget_data["Vet"]["limit"] = int(value)
	vet_limit_label.text = "$%d" % value
	update_overview()

func _on_travel_slider_value_changed(value: float) -> void:
	GameState.budget_data["Travel"]["limit"] = int(value)
	travel_limit_label.text = "$%d" % value
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
