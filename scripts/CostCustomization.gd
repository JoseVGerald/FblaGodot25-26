# CostCustomization.gd -> PathwaySelection.gd
# Highly polished, adaptive sidebar pathway presets + dynamic cost customization grids.
extends Control

@onready var scroll_container = $ScrollContainer

# Inputs references
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

# New dynamic grid inputs
var adult_section_header: Label = null
var adult_grid: GridContainer = null
var career_section_header: Label = null
var career_grid: GridContainer = null

var rent_input: LineEdit = null
var house_price_input: LineEdit = null
var news_boy_input: LineEdit = null
var burger_cashier_input: LineEdit = null
var bank_accountant_input: LineEdit = null
var promotion_boost_input: LineEdit = null

var daycare_section_header: Label = null
var daycare_grid: GridContainer = null
var daycare_cheap_input: LineEdit = null
var daycare_premium_input: LineEdit = null

var _selected_pathway: String = "kid"
var pathway_cards: VBoxContainer = null

func _ready() -> void:
	UITheme.apply_theme(self)
	
	# Instantly construct new dynamic grids inside the scroll container
	setup_new_variables()
	
	# Populate values from GameState defaults
	populate_from_state()
	
	# Rearrange the layout into a responsive parent HBoxContainer
	# This holds ScrollContainer on the left and the Sidebar on the right perfectly, scaling to any screen resolution.
	setup_layout()
	
	# Connect buttons
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		UITheme.style_button(continue_button, Color("#4CAF50"))

	# Style all SpinBox/LineEdit inputs with cream background
	call_deferred("_style_all_inputs")

func _style_all_inputs() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ffe3c6")  # CLR_CREAM_LT — warm cream, not white
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	_style_inputs_recursive(scroll_container, sb)

func _style_inputs_recursive(node: Node, sb: StyleBoxFlat) -> void:
	for child in node.get_children():
		if child is SpinBox:
			var le: LineEdit = child.get_line_edit()
			if le:
				le.add_theme_stylebox_override("normal", sb)
				le.add_theme_color_override("font_color", UITheme.CLR_INK)
		elif child is LineEdit:
			child.add_theme_stylebox_override("normal", sb)
			child.add_theme_color_override("font_color", UITheme.CLR_INK)
		_style_inputs_recursive(child, sb)

func setup_layout() -> void:
	"""Creates a highly responsive HBox layout separating custom grids and preset sidebar."""
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 24)
	
	# Full stretch matching screen dimensions with margins
	main_hbox.position = Vector2(40, 165)
	main_hbox.size = Vector2(1200, 460)
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 40
	main_hbox.offset_top = 165
	main_hbox.offset_right = -40
	main_hbox.offset_bottom = -110
	main_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(main_hbox)
	
	# Wrap scroll container in a cream panel so form labels are readable
	var form_panel := PanelContainer.new()
	UITheme.style_cream_panel(form_panel)
	form_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_panel.size_flags_stretch_ratio = 2.4
	form_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(form_panel)

	if scroll_container:
		remove_child(scroll_container)
		form_panel.add_child(scroll_container)
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.show()
		
	# Setup Sidebar on the right side of HBox
	setup_sidebar(main_hbox)

func setup_new_variables() -> void:
	"""Programmatically adds the new pathway rent/house costs and career day pays inputs."""
	var sections = $ScrollContainer/Sections
	if not sections:
		return
		
	var pf := UITheme.get_pixel_font()
	
	# HSeparator
	var sep1 := HSeparator.new()
	sections.add_child(sep1)
	
	# Section Header: Adult Settings
	adult_section_header = Label.new()
	adult_section_header.text = "Adult Pathway Settings"
	adult_section_header.add_theme_font_size_override("font_size", 28)
	adult_section_header.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if pf: adult_section_header.add_theme_font_override("font", pf)
	sections.add_child(adult_section_header)
	
	# Grid: Adult Settings
	adult_grid = GridContainer.new()
	adult_grid.columns = 3
	adult_grid.add_theme_constant_override("h_separation", 20)
	adult_grid.add_theme_constant_override("v_separation", 12)
	sections.add_child(adult_grid)
	
	# Row 1 Labels
	var rent_lbl := Label.new()
	rent_lbl.text = "Monthly Rent"
	rent_lbl.add_theme_font_size_override("font_size", 22)
	rent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adult_grid.add_child(rent_lbl)
	
	var hp_lbl := Label.new()
	hp_lbl.text = "House Purchase Price"
	hp_lbl.add_theme_font_size_override("font_size", 22)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adult_grid.add_child(hp_lbl)
	
	var spacer1 := Control.new()
	adult_grid.add_child(spacer1)
	
	# Row 2 LineEdits
	rent_input = LineEdit.new()
	rent_input.custom_minimum_size = Vector2(220, 56)
	rent_input.add_theme_font_size_override("font_size", 28)
	rent_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	adult_grid.add_child(rent_input)
	
	house_price_input = LineEdit.new()
	house_price_input.custom_minimum_size = Vector2(220, 56)
	house_price_input.add_theme_font_size_override("font_size", 28)
	house_price_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	adult_grid.add_child(house_price_input)
	
	var spacer2 := Control.new()
	adult_grid.add_child(spacer2)
	
	# HSeparator
	var sep2 := HSeparator.new()
	sections.add_child(sep2)
	
	# Section Header: Career Settings
	career_section_header = Label.new()
	career_section_header.text = "Career Day Pay Settings"
	career_section_header.add_theme_font_size_override("font_size", 28)
	career_section_header.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if pf: career_section_header.add_theme_font_override("font", pf)
	sections.add_child(career_section_header)
	
	# Grid: Career Settings
	career_grid = GridContainer.new()
	career_grid.columns = 3
	career_grid.add_theme_constant_override("h_separation", 20)
	career_grid.add_theme_constant_override("v_separation", 12)
	sections.add_child(career_grid)
	
	# Row 1 Labels
	var nb_lbl := Label.new()
	nb_lbl.text = "Mail Boy Day Pay"
	nb_lbl.add_theme_font_size_override("font_size", 22)
	nb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(nb_lbl)
	
	var bc_lbl := Label.new()
	bc_lbl.text = "The Cook Day Pay"
	bc_lbl.add_theme_font_size_override("font_size", 22)
	bc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(bc_lbl)
	
	var ba_lbl := Label.new()
	ba_lbl.text = "Bank Accountant Day Pay"
	ba_lbl.add_theme_font_size_override("font_size", 22)
	ba_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(ba_lbl)
	
	# Row 2 LineEdits
	news_boy_input = LineEdit.new()
	news_boy_input.custom_minimum_size = Vector2(220, 56)
	news_boy_input.add_theme_font_size_override("font_size", 28)
	news_boy_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(news_boy_input)
	
	burger_cashier_input = LineEdit.new()
	burger_cashier_input.custom_minimum_size = Vector2(220, 56)
	burger_cashier_input.add_theme_font_size_override("font_size", 28)
	burger_cashier_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(burger_cashier_input)
	
	bank_accountant_input = LineEdit.new()
	bank_accountant_input.custom_minimum_size = Vector2(220, 56)
	bank_accountant_input.add_theme_font_size_override("font_size", 28)
	bank_accountant_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(bank_accountant_input)

	# Row 3: promotion boost percent (how much each promotion raises pay/earnings)
	var boost_lbl := Label.new()
	boost_lbl.text = "Promotion Boost %"
	boost_lbl.add_theme_font_size_override("font_size", 22)
	boost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pf: boost_lbl.add_theme_font_override("font", pf)
	career_grid.add_child(boost_lbl)

	promotion_boost_input = LineEdit.new()
	promotion_boost_input.custom_minimum_size = Vector2(220, 56)
	promotion_boost_input.add_theme_font_size_override("font_size", 28)
	promotion_boost_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(promotion_boost_input)

	var boost_spacer := Control.new()
	career_grid.add_child(boost_spacer)

	# HSeparator
	var sep3 := HSeparator.new()
	sections.add_child(sep3)

	# Section header: Daycare Settings
	daycare_section_header = Label.new()
	daycare_section_header.text = "Daycare Settings"
	daycare_section_header.add_theme_font_size_override("font_size", 28)
	daycare_section_header.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if pf: daycare_section_header.add_theme_font_override("font", pf)
	sections.add_child(daycare_section_header)

	daycare_grid = GridContainer.new()
	daycare_grid.columns = 3
	daycare_grid.add_theme_constant_override("h_separation", 20)
	daycare_grid.add_theme_constant_override("v_separation", 12)
	sections.add_child(daycare_grid)

	var dc_cheap_lbl := Label.new()
	dc_cheap_lbl.text = "Cheap Daycare Price"
	dc_cheap_lbl.add_theme_font_size_override("font_size", 22)
	dc_cheap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daycare_grid.add_child(dc_cheap_lbl)

	var dc_premium_lbl := Label.new()
	dc_premium_lbl.text = "Premium Daycare Price"
	dc_premium_lbl.add_theme_font_size_override("font_size", 22)
	dc_premium_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daycare_grid.add_child(dc_premium_lbl)

	var dc_spacer := Control.new()
	daycare_grid.add_child(dc_spacer)

	daycare_cheap_input = LineEdit.new()
	daycare_cheap_input.custom_minimum_size = Vector2(220, 56)
	daycare_cheap_input.add_theme_font_size_override("font_size", 28)
	daycare_cheap_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	daycare_grid.add_child(daycare_cheap_input)

	daycare_premium_input = LineEdit.new()
	daycare_premium_input.custom_minimum_size = Vector2(220, 56)
	daycare_premium_input.add_theme_font_size_override("font_size", 28)
	daycare_premium_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	daycare_grid.add_child(daycare_premium_input)

	var dc_spacer2 := Control.new()
	daycare_grid.add_child(dc_spacer2)

func populate_from_state() -> void:
	"""Prefill inputs based on current GameState values."""
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
	
	# New dynamic fields
	if rent_input:
		rent_input.text = "%.2f" % GameState.monthly_rent
	if house_price_input:
		house_price_input.text = "%.2f" % GameState.house_price
	if news_boy_input:
		news_boy_input.text = "%.2f" % GameState.news_boy_pay
	if burger_cashier_input:
		burger_cashier_input.text = "%.2f" % GameState.burger_cashier_pay
	if bank_accountant_input:
		bank_accountant_input.text = "%.2f" % GameState.bank_accountant_pay
	if promotion_boost_input:
		promotion_boost_input.text = str(int(round(GameState.promotion_boost_percent)))
	if daycare_cheap_input:
		daycare_cheap_input.text = "%.2f" % GameState.daycare_cheap_price
	if daycare_premium_input:
		daycare_premium_input.text = "%.2f" % GameState.daycare_premium_price

func apply_preset(pathway: String) -> void:
	"""Apply pathway presets to left input fields and dynamically manage visibility."""
	_selected_pathway = pathway
	
	# Update active LineEdit visibilities dynamically
	_update_field_visibilities(pathway)
	
	if pathway == "kid":
		starting_cash_input.text = "150.00"
		starting_savings_input.text = "200.00"
		weekly_allowance_input.text = "100.00"
		ball_input.text = "0.20"
	elif pathway == "teenager":
		starting_cash_input.text = "150.00"
		starting_savings_input.text = "200.00"
		weekly_allowance_input.text = "50.00"
		ball_input.text = "0.20"
		news_boy_input.text = "10.00"
		burger_cashier_input.text = "15.00"
		bank_accountant_input.text = "25.00"
		promotion_boost_input.text = "40"
		if daycare_cheap_input: daycare_cheap_input.text = "15.00"
		if daycare_premium_input: daycare_premium_input.text = "30.00"
	elif pathway == "adult":
		starting_cash_input.text = "150.00"
		starting_savings_input.text = "200.00"
		weekly_allowance_input.text = "0.00"
		ball_input.text = "0.00"
		rent_input.text = "200.00"
		house_price_input.text = "1000.00"
		news_boy_input.text = "10.00"
		burger_cashier_input.text = "15.00"
		bank_accountant_input.text = "25.00"
		promotion_boost_input.text = "40"
		if daycare_cheap_input: daycare_cheap_input.text = "15.00"
		if daycare_premium_input: daycare_premium_input.text = "30.00"

func _update_field_visibilities(pathway: String) -> void:
	"""Selectively toggles grid elements so pathway-ineligible variables remain clean and hidden."""
	var show_allowance := (pathway == "kid" or pathway == "teenager")
	var show_ball := (pathway == "kid" or pathway == "teenager")
	var show_adult := (pathway == "adult")
	var show_career := (pathway == "teenager" or pathway == "adult")
	
	# Allowance row cell toggle
	var allowance_lbl = get_node_or_null("ScrollContainer/Sections/StartingGrid/WeeklyAllowanceLabel")
	if allowance_lbl: allowance_lbl.visible = show_allowance
	if weekly_allowance_input: weekly_allowance_input.visible = show_allowance
	
	# Chores row cell toggle
	var ball_lbl = get_node_or_null("ScrollContainer/Sections/CostsGrid/BallLabel")
	if ball_lbl: ball_lbl.visible = show_ball
	if ball_input: ball_input.visible = show_ball
	
	# Adult Settings row toggle
	if adult_section_header: adult_section_header.visible = show_adult
	if adult_grid: adult_grid.visible = show_adult
	
	# Career Settings row toggle
	if career_section_header: career_section_header.visible = show_career
	if career_grid: career_grid.visible = show_career

	# Daycare Settings row toggle
	if daycare_section_header: daycare_section_header.visible = show_career
	if daycare_grid: daycare_grid.visible = show_career

func setup_sidebar(parent_hbox: HBoxContainer) -> void:
	"""Build a highly scaled-up sidebar panel on the right side of the main HBox."""
	var sidebar := PanelContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(680, 0) # 3x scaled and wide!
	sidebar.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3d1a1e")
	sb.border_color = UITheme.CLR_INK
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
	title.text = "SELECT PATHWAY"
	title.add_theme_font_size_override("font_size", 44) # 3x scaled!
	title.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pf := UITheme.get_pixel_font()
	if pf: title.add_theme_font_override("font", pf)
	vbox.add_child(title)
	
	pathway_cards = VBoxContainer.new()
	pathway_cards.add_theme_constant_override("separation", 18)
	vbox.add_child(pathway_cards)
	
	_create_sidebar_card(pathway_cards, "kid", "Kid Pathway", "Allow: $100\nChore: $0.20\nRent: Free", Color("#4CAF50"))
	_create_sidebar_card(pathway_cards, "teenager", "Teenager", "Allow: $50\nChore: $0.20\nRent: Free\nJobs: Part-Time", Color("#FFA726"))
	_create_sidebar_card(pathway_cards, "adult", "Adult", "Allow: $0\nRent: $200\nJobs: Full-Time\nGoal: Buy Home", Color("#EF5350"))
	
	# Select Kid by default
	call_deferred("_select_default")

func _select_default() -> void:
	if pathway_cards and pathway_cards.get_child_count() > 0:
		var first_card = pathway_cards.get_child(0)
		var btn = first_card.find_child("SelectBtn", true, false) as Button
		if btn:
			btn.pressed.emit()

func _create_sidebar_card(parent: Control, id: String, title_text: String, stats: String, accent_color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 240) # 3x scaled!
	panel.set_meta("pathway_id", id)
	panel.set_meta("accent_color", accent_color)
	panel.set_meta("base_title", title_text)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2d1215")
	sb.border_color = UITheme.CLR_INK
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
	title_btn.add_theme_font_size_override("font_size", 34) # 3x scaled!
	title_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	var pf := UITheme.get_pixel_font()
	if pf: title_btn.add_theme_font_override("font", pf)
	vbox.add_child(title_btn)
	
	var stats_lbl := Label.new()
	stats_lbl.text = stats
	stats_lbl.add_theme_font_size_override("font_size", 24) # 3x scaled!
	stats_lbl.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(stats_lbl)
	
	# Selection logic extracted so both the button and the panel can trigger it
	var do_select := func():
		apply_preset(id)
		
		# Reset all cards to normal thin borders
		for child in parent.get_children():
			var card_id = child.get_meta("pathway_id")
			var card_accent = child.get_meta("accent_color")
			var card_base_title = child.get_meta("base_title")
			var child_sb = child.get_theme_stylebox("panel") as StyleBoxFlat
			var child_btn = child.find_child("SelectBtn", true, false) as Button
			
			if child_sb:
				if card_id == id:
					# Thicker border (12px) + custom tinted background of that pathway's theme color!
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
					# Reset thin borders (4px)
					child_sb.bg_color = Color("#182645")
					child_sb.border_color = Color("#22335c")
					child_sb.border_width_bottom = 4
					child_sb.border_width_top = 4
					child_sb.border_width_left = 4
					child_sb.border_width_right = 4
					
					if child_btn:
						child_btn.text = card_base_title
						child_btn.add_theme_color_override("font_color", card_accent)
	
	# Click the title button text — fires selection
	title_btn.pressed.connect(do_select)
	
	# Click ANYWHERE on the card panel — also fires selection
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			do_select.call()
	)

func _on_back_pressed() -> void:
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn", {"pattern": "curtains"})

func _on_continue_pressed() -> void:
	# Parse inputs safely
	var starting_cash := float(starting_cash_input.text)
	var starting_savings := float(starting_savings_input.text)
	var allowance := float(weekly_allowance_input.text) if weekly_allowance_input.visible else 0.0
	
	var food_c := int(food_input.text)
	var water_c := int(water_input.text)
	var med_c := int(medicine_input.text)
	var vet_f := int(vet_input.text)
	var taxi_c := int(taxi_input.text)
	var ball_c := float(ball_input.text) if ball_input.visible else 0.0
	
	var food_b := int(food_budget_input.text)
	var vet_b := int(vet_budget_input.text)
	var travel_b := int(travel_budget_input.text)
	
	var interest_r := float(interest_input.text) / 100.0
	var penalty_r := float(penalty_input.text) / 100.0
	var loan_r := float(loan_rate_input.text) / 100.0
	var max_loan := int(max_loan_input.text)
	
	# New pathway inputs
	var monthly_rent := GameState.monthly_rent
	var house_price := GameState.house_price
	var news_boy_pay := GameState.news_boy_pay
	var burger_pay := GameState.burger_cashier_pay
	var bank_pay := GameState.bank_accountant_pay
	
	if rent_input and rent_input.visible and not rent_input.text.is_empty():
		monthly_rent = float(rent_input.text)
	if house_price_input and house_price_input.visible and not house_price_input.text.is_empty():
		house_price = float(house_price_input.text)
	if news_boy_input and news_boy_input.visible and not news_boy_input.text.is_empty():
		news_boy_pay = float(news_boy_input.text)
	if burger_cashier_input and burger_cashier_input.visible and not burger_cashier_input.text.is_empty():
		burger_pay = float(burger_cashier_input.text)
	if bank_accountant_input and bank_accountant_input.visible and not bank_accountant_input.text.is_empty():
		bank_pay = float(bank_accountant_input.text)

	var promo_boost := GameState.promotion_boost_percent
	if promotion_boost_input and promotion_boost_input.visible and not promotion_boost_input.text.is_empty():
		promo_boost = clampf(float(promotion_boost_input.text), 0.0, 500.0)
	
	# Apply to GameState variables
	GameState.selected_pathway = _selected_pathway
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
	
	# Dynamic pathway/career values
	GameState.monthly_rent = monthly_rent
	GameState.house_price = house_price
	GameState.news_boy_pay = news_boy_pay
	GameState.burger_cashier_pay = burger_pay
	GameState.bank_accountant_pay = bank_pay
	GameState.promotion_boost_percent = promo_boost

	# Daycare prices — only for teenager/adult, premium must exceed cheap by at least $5
	if _selected_pathway in ["teenager", "adult"]:
		var cheap_price := GameState.daycare_cheap_price
		var premium_price := GameState.daycare_premium_price
		if daycare_cheap_input and not daycare_cheap_input.text.is_empty():
			cheap_price = clampf(float(daycare_cheap_input.text), 5.0, 50.0)
		if daycare_premium_input and not daycare_premium_input.text.is_empty():
			premium_price = clampf(float(daycare_premium_input.text), cheap_price + 5.0, 80.0)
		GameState.daycare_cheap_price = cheap_price
		GameState.daycare_premium_price = premium_price

	# Reset state balances
	GameState.money = starting_cash
	GameState.savings_balance = starting_savings
	
	# Reset career/rent
	GameState.active_job = "none"
	if _selected_pathway == "adult":
		GameState.rent_timer = 28
		GameState.house_owned = false
	
	print("[CostCustomization] Configured Pathway: ", _selected_pathway)
	SceneManager.change_scene("res://scenes/ui/ConfirmSelection.tscn", {"pattern": "curtains"})
