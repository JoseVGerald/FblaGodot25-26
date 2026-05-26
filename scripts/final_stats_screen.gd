# final_stats_screen.gd
# Spectacular final statistics report rendering compound charts, category curves, and detailed transaction logs.
extends CanvasLayer

var font_pixel: Font = null

func _ready() -> void:
	# Keep game active while displaying stats
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	font_pixel = UITheme.get_pixel_font()
	
	# Root container
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	UITheme.apply_theme(root)
	
	# Solid dark navy background
	var bg := ColorRect.new()
	bg.color = Color("#070f21")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	
	# Split Layout: Left Panel (Stats & Log), Right Panel (3 Charts)
	var main_split := HBoxContainer.new()
	main_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_split.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_split.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_split.add_theme_constant_override("separation", 24)
	main_split.offset_left = 30
	main_split.offset_top = 30
	main_split.offset_right = -30
	main_split.offset_bottom = -110
	root.add_child(main_split)
	
	# LEFT PANEL
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.1
	left_vbox.add_theme_constant_override("separation", 14)
	main_split.add_child(left_vbox)
	
	# Congratulatory Header
	var title_lbl := Label.new()
	title_lbl.text = "CONGRATULATIONS!"
	title_lbl.add_theme_font_size_override("font_size", 46)
	title_lbl.add_theme_color_override("font_color", Color("#FFD700")) # Gold glow
	if font_pixel: title_lbl.add_theme_font_override("font", font_pixel)
	left_vbox.add_child(title_lbl)
	
	# Thank you message
	var msg_lbl := Label.new()
	msg_lbl.text = "You purchased the home and secured a permanent home for %s!" % GameState.pet_name
	msg_lbl.add_theme_font_size_override("font_size", 18)
	msg_lbl.add_theme_color_override("font_color", Color("#53d8fb")) # Cyan neon
	left_vbox.add_child(msg_lbl)
	
	# Stats Cards Container
	var stats_panel := PanelContainer.new()
	var stats_sb := StyleBoxFlat.new()
	stats_sb.bg_color = Color("#111e38")
	stats_sb.border_color = Color("#223a6b")
	stats_sb.border_width_bottom = 2
	stats_sb.border_width_top = 2
	stats_sb.border_width_left = 2
	stats_sb.border_width_right = 2
	stats_sb.set_corner_radius_all(10)
	stats_sb.set_content_margin_all(14)
	stats_panel.add_theme_stylebox_override("panel", stats_sb)
	left_vbox.add_child(stats_panel)
	
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 40)
	stats_grid.add_theme_constant_override("v_separation", 6)
	stats_panel.add_child(stats_grid)
	
	_add_stat_row(stats_grid, "Player Name:", GameState.player_name)
	_add_stat_row(stats_grid, "Buddy's Name:", GameState.pet_name)
	_add_stat_row(stats_grid, "Days Played:", str(GameState.current_day))
	_add_stat_row(stats_grid, "Starting Cash:", "$%.2f" % GameState.starting_money)
	_add_stat_row(stats_grid, "Ending Cash Balance:", "$%.2f" % GameState.money)
	_add_stat_row(stats_grid, "Ending Savings Balance:", "$%.2f" % GameState.savings_balance)
	_add_stat_row(stats_grid, "Stock Portfolio Value:", "$0.00 (Locked)")
	
	# Purchase Logs Section
	var log_header := Label.new()
	log_header.text = "TRANSACTION REGISTRY"
	log_header.add_theme_font_size_override("font_size", 20)
	log_header.add_theme_color_override("font_color", Color("#a0b2d6"))
	if font_pixel: log_header.add_theme_font_override("font", font_pixel)
	left_vbox.add_child(log_header)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)
	
	var registry_panel := PanelContainer.new()
	var reg_sb := StyleBoxFlat.new()
	reg_sb.bg_color = Color("#0a1224")
	reg_sb.set_content_margin_all(8)
	registry_panel.add_theme_stylebox_override("panel", reg_sb)
	scroll.add_child(registry_panel)
	
	var registry_grid := GridContainer.new()
	registry_grid.columns = 4
	registry_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	registry_grid.add_theme_constant_override("h_separation", 16)
	registry_grid.add_theme_constant_override("v_separation", 8)
	registry_panel.add_child(registry_grid)
	
	# Table Headers
	_add_table_header(registry_grid, "Day")
	_add_table_header(registry_grid, "Category")
	_add_table_header(registry_grid, "Description")
	_add_table_header(registry_grid, "Amount")
	
	# Populate Table Rows from GameState.transaction_history
	var sorted_history := GameState.transaction_history.duplicate()
	sorted_history.sort_custom(func(a, b): return a["day"] < b["day"])
	
	for entry in sorted_history:
		var day_num: int = entry.get("day", 0)
		var cat: String = entry.get("category", "General")
		var desc: String = entry.get("description", "Transaction")
		var amt: float = entry.get("amount", 0.0)
		
		var amt_str := ""
		var amt_color := Color("#4CAF50")
		if amt >= 0:
			amt_str = "+$%.2f" % amt
		else:
			amt_str = "-$%.2f" % abs(amt)
			amt_color = Color("#EF5350")
			
		_add_table_cell(registry_grid, "Day %d" % day_num)
		_add_table_cell(registry_grid, cat)
		_add_table_cell(registry_grid, desc)
		_add_table_cell(registry_grid, amt_str, amt_color)
		
	# RIGHT PANEL (3 Visual Custom Graphs)
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 16)
	main_split.add_child(right_vbox)
	
	# Graph Tabs Container
	var tab_container := TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(tab_container)
	
	# Tab 1: Compounded Savings Graph
	var savings_chart := CustomLineGraph.new()
	savings_chart.name = "Savings Curve"
	savings_chart.graph_title = "Compounded Savings Balance"
	savings_chart.line_color = Color("#4CAF50") # Green
	savings_chart.points = _calculate_savings_curve(sorted_history)
	tab_container.add_child(savings_chart)
	
	# Tab 2: Category Spending Graph (Multiple Lines)
	var spending_chart := CategorySpendingGraph.new()
	spending_chart.name = "Spending Over Time"
	spending_chart.history_data = sorted_history
	tab_container.add_child(spending_chart)
	
	# Tab 3: Stock Portfolio Graph (Dynamic Placeholder)
	var stocks_chart := CustomLineGraph.new()
	stocks_chart.name = "Stocks Valuations"
	stocks_chart.graph_title = "Stock Investments Performance"
	stocks_chart.line_color = Color("#FFA726") # Orange
	stocks_chart.points = _generate_mock_stocks_curve()
	tab_container.add_child(stocks_chart)
	
	# BOTTOM BUTTONS BAR
	var bottom_bar := HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 50)
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_bottom = -24
	bottom_bar.offset_top = -100
	root.add_child(bottom_bar)
	
	# Restart Button
	var restart_btn := Button.new()
	restart_btn.text = "Return to Main Menu"
	restart_btn.custom_minimum_size = Vector2(320, 60)
	restart_btn.add_theme_font_size_override("font_size", 28)
	if font_pixel: restart_btn.add_theme_font_override("font", font_pixel)
	UITheme.style_button(restart_btn, Color("#4CAF50"))
	bottom_bar.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart_pressed)

func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("#a0b2d6"))
	grid.add_child(lbl)
	
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color.WHITE)
	grid.add_child(val)

func _add_table_header(grid: GridContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color("#53d8fb"))
	if font_pixel: lbl.add_theme_font_override("font", font_pixel)
	grid.add_child(lbl)

func _add_table_cell(grid: GridContainer, text: String, color: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	grid.add_child(lbl)

func _calculate_savings_curve(history: Array) -> Array:
	var curve := []
	var balance = GameState.starting_savings
	curve.append(Vector2(0, balance))
	
	for entry in history:
		var day = entry.get("day", 0)
		var cat = entry.get("category", "")
		var amt = entry.get("amount", 0.0)
		
		# Trace transactions directed to Savings
		if cat == "Savings" or cat == "Compounding":
			# Deposits are negative cash movements but positive savings increments
			# Let's check descriptions or category types
			balance += amt
			curve.append(Vector2(day, balance))
	
	if curve.size() == 1:
		curve.append(Vector2(max(1, GameState.current_day), balance))
	return curve

func _generate_mock_stocks_curve() -> Array:
	var curve := []
	curve.append(Vector2(0, 0))
	curve.append(Vector2(max(1, GameState.current_day), 0))
	return curve

func _on_restart_pressed() -> void:
	# Completely reset GameState before heading home
	GameState.reset_all()
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn", {"pattern": "curtains"})

# ══════════════════════════════════════════════════════════════════════════════
#  CUSTOM LINE GRAPH COMPONENT
# ══════════════════════════════════════════════════════════════════════════════
class_name CustomLineGraph
extends Control

var graph_title: String = ""
var line_color: Color = Color.WHITE
var points: Array = [] # List of Vector2(day, value)

func _draw() -> void:
	var font := get_theme_default_font()
	var margin_left = 64
	var margin_right = 24
	var margin_top = 40
	var margin_bottom = 44
	
	var graph_w = size.x - margin_left - margin_right
	var graph_h = size.y - margin_top - margin_bottom
	
	# Draw BG panel
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0a1224"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#223a6b"), false, 1.5)
	
	# Title
	draw_string(font, Vector2(16, 26), graph_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	
	if points.is_empty() or graph_w <= 0 or graph_h <= 0:
		return
		
	# Find bounds
	var max_day = 1.0
	var max_val = 10.0
	var min_val = 0.0
	
	for pt in points:
		if pt.x > max_day: max_day = pt.x
		if pt.y > max_val: max_val = pt.y
		if pt.y < min_val: min_val = pt.y
		
	var val_range = max_val - min_val
	if val_range <= 0: val_range = 1.0
	
	# Draw baseline and axis
	var zero_y = margin_top + ((max_val - 0.0) / val_range) * graph_h
	if zero_y >= margin_top and zero_y <= size.y - margin_bottom:
		draw_line(Vector2(margin_left, zero_y), Vector2(size.x - margin_right, zero_y), Color("#1e3a6e"), 1.0)
		
	draw_line(Vector2(margin_left, margin_top), Vector2(margin_left, size.y - margin_bottom), Color("#4A90D9"), 1.5)
	draw_line(Vector2(margin_left, size.y - margin_bottom), Vector2(size.x - margin_right, size.y - margin_bottom), Color("#4A90D9"), 1.5)
	
	# Draw H-grid lines & Labels
	var grid_lines = 5
	for i in range(grid_lines):
		var y = margin_top + (float(i) / (grid_lines - 1)) * graph_h
		var val = max_val - (float(i) / (grid_lines - 1)) * val_range
		draw_line(Vector2(margin_left, y), Vector2(size.x - margin_right, y), Color("#12203b"), 1.0)
		draw_string(font, Vector2(6, y + 4), "$%d" % int(val), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a0b2d6"))
		
	# Plot points
	var polyline := PackedVector2Array()
	for pt in points:
		var x = margin_left + (pt.x / max_day) * graph_w
		var y = margin_top + ((max_val - pt.y) / val_range) * graph_h
		polyline.append(Vector2(x, y))
		
	if polyline.size() >= 2:
		draw_polyline(polyline, line_color, 2.0)
	for p in polyline:
		draw_circle(p, 4.0, line_color)

# ══════════════════════════════════════════════════════════════════════════════
#  CATEGORY SPENDING LINE GRAPH COMPONENT
# ══════════════════════════════════════════════════════════════════════════════
class_name CategorySpendingGraph
extends Control

var history_data: Array = []

func _draw() -> void:
	var font := get_theme_default_font()
	var margin_left = 64
	var margin_right = 24
	var margin_top = 40
	var margin_bottom = 44
	
	var graph_w = size.x - margin_left - margin_right
	var graph_h = size.y - margin_top - margin_bottom
	
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0a1224"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#223a6b"), false, 1.5)
	
	# Title
	draw_string(font, Vector2(16, 26), "Spending Over Time (Categories)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	
	# Calculate category spending over time
	var max_day = max(float(GameState.current_day), 1.0)
	var max_spent = 50.0
	
	# day -> spent
	var food_spent := {}
	var vet_spent := {}
	var travel_spent := {}
	
	var cum_food = 0.0
	var cum_vet = 0.0
	var cum_travel = 0.0
	
	for entry in history_data:
		var day = entry.get("day", 0)
		var cat = entry.get("category", "")
		var amt = abs(entry.get("amount", 0.0))
		
		# Only track actual spending (negative amount movements)
		if entry.get("amount", 0.0) < 0:
			if cat == "Food":
				cum_food += amt
			elif cat == "Vet":
				cum_vet += amt
			elif cat == "Travel":
				cum_travel += amt
				
		food_spent[day] = cum_food
		vet_spent[day] = cum_vet
		travel_spent[day] = cum_travel
		
	# Find max value to bound
	max_spent = max(max(cum_food, cum_vet), max(cum_travel, 50.0)) * 1.1
	
	# Axis lines
	draw_line(Vector2(margin_left, margin_top), Vector2(margin_left, size.y - margin_bottom), Color("#4A90D9"), 1.5)
	draw_line(Vector2(margin_left, size.y - margin_bottom), Vector2(size.x - margin_right, size.y - margin_bottom), Color("#4A90D9"), 1.5)
	
	# H-grid
	var grid_lines = 5
	for i in range(grid_lines):
		var y = margin_top + (float(i) / (grid_lines - 1)) * graph_h
		var val = max_spent - (float(i) / (grid_lines - 1)) * max_spent
		draw_line(Vector2(margin_left, y), Vector2(size.x - margin_right, y), Color("#12203b"), 1.0)
		draw_string(font, Vector2(6, y + 4), "$%d" % int(val), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a0b2d6"))
		
	# Draw food (Red), Vet (Blue), Travel (Purple) lines
	_draw_spending_line(food_spent, Color("#EF5350"), max_day, max_spent, margin_left, margin_top, graph_w, graph_h)
	_draw_spending_line(vet_spent, Color("#53d8fb"), max_day, max_spent, margin_left, margin_top, graph_w, graph_h)
	_draw_spending_line(travel_spent, Color("#AB47BC"), max_day, max_spent, margin_left, margin_top, graph_w, graph_h)
	
	# Legends (Food / Vet / Travel)
	var lx = size.x - margin_right - 250
	var ly = 16
	
	draw_circle(Vector2(lx, ly), 4.0, Color("#EF5350"))
	draw_string(font, Vector2(lx + 8, ly + 4), "Food", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	
	draw_circle(Vector2(lx + 80, ly), 4.0, Color("#53d8fb"))
	draw_string(font, Vector2(lx + 88, ly + 4), "Vet", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	
	draw_circle(Vector2(lx + 160, ly), 4.0, Color("#AB47BC"))
	draw_string(font, Vector2(lx + 168, ly + 4), "Travel", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _draw_spending_line(data: Dictionary, color: Color, max_day: float, max_spent: float, ml: int, mt: int, gw: float, gh: float) -> void:
	var polyline := PackedVector2Array()
	
	# Add point for day 0
	polyline.append(Vector2(ml, mt + gh))
	
	var sorted_days = data.keys()
	sorted_days.sort()
	
	for day in sorted_days:
		var x = ml + (float(day) / max_day) * gw
		var y = mt + ((max_spent - data[day]) / max_spent) * gh
		polyline.append(Vector2(x, y))
		
	if polyline.size() >= 2:
		draw_polyline(polyline, color, 1.8)
	for p in polyline:
		draw_circle(p, 3.5, color)
