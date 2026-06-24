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

# Separators references
var adult_sep: HSeparator = null
var career_sep: HSeparator = null
var daycare_sep: HSeparator = null

func _ready() -> void:
	UITheme.apply_theme(self)
	
	# Instantly construct new dynamic grids inside the scroll container
	setup_new_variables()
	
	# Populate values from GameState defaults
	populate_from_state()
	
	# Rearrange the layout into a responsive parent HBoxContainer
	setup_layout()
	
	# Connect buttons
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

	# Style all SpinBox/LineEdit inputs with cream background
	call_deferred("_style_all_inputs")
	
	# Set up input validation for all LineEdits (only digits/decimals allowed)
	_setup_all_input_validation()

func _style_all_inputs() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CLR_CREAM_LT  # Use helper constant
	sb.border_color = UITheme.CLR_INK   # Use helper constant
	sb.set_border_width_all(3)          # match pixel border
	sb.set_corner_radius_all(0)         # sharp corners for pixel art
	sb.set_content_margin_all(8)
	sb.anti_aliasing = false
	
	var sb_focus := sb.duplicate() as StyleBoxFlat
	sb_focus.border_color = UITheme.CLR_GOLD
	sb_focus.border_width_bottom = 5
	
	_style_inputs_recursive(scroll_container, sb, sb_focus)

func _style_inputs_recursive(node: Node, sb: StyleBoxFlat, sb_focus: StyleBoxFlat) -> void:
	var font_bold := SystemFont.new()
	font_bold.font_weight = 700
	
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500

	_style_inputs_recursive_internal(node, sb, sb_focus, font_bold, font_medium)

func _style_inputs_recursive_internal(node: Node, sb: StyleBoxFlat, sb_focus: StyleBoxFlat, font_bold: SystemFont, font_medium: SystemFont) -> void:
	for child in node.get_children():
		if child is SpinBox:
			var le: LineEdit = child.get_line_edit()
			if le:
				le.add_theme_stylebox_override("normal", sb)
				le.add_theme_stylebox_override("focus", sb_focus)
				le.add_theme_color_override("font_color", Color.BLACK)
				le.add_theme_color_override("font_selected_color", Color.WHITE)
				le.add_theme_color_override("selection_color", UITheme.CLR_INK)
				le.add_theme_font_size_override("font_size", 24)
				le.alignment = HORIZONTAL_ALIGNMENT_CENTER
				le.add_theme_font_override("font", font_medium)
		elif child is LineEdit:
			child.add_theme_stylebox_override("normal", sb)
			child.add_theme_stylebox_override("focus", sb_focus)
			child.add_theme_color_override("font_color", Color.BLACK)
			child.add_theme_color_override("font_selected_color", Color.WHITE)
			child.add_theme_color_override("selection_color", UITheme.CLR_INK)
			child.add_theme_font_size_override("font_size", 24)
			child.alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.add_theme_font_override("font", font_medium)
		elif child is Label:
			if child.name.ends_with("Header") or child.text.contains("Settings") or child.text.contains("Values") or child.text.contains("Costs") or child.text.contains("Limits") or child.text.contains("Modifiers"):
				child.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
				child.add_theme_font_size_override("font_size", 28)
				child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				child.add_theme_font_override("font", font_bold)
			else:
				child.add_theme_color_override("font_color", UITheme.CLR_INK)
				child.add_theme_font_size_override("font_size", 22)
				child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				child.add_theme_font_override("font", font_medium)
			
			child.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.15))
			child.add_theme_constant_override("shadow_offset_x", 2)
			child.add_theme_constant_override("shadow_offset_y", 2)
		elif child is HSeparator:
			var sb_sep := StyleBoxLine.new()
			sb_sep.color = UITheme.CLR_INK
			sb_sep.thickness = 4
			child.add_theme_stylebox_override("separator", sb_sep)
			child.add_theme_constant_override("separation", 32)
			
		_style_inputs_recursive_internal(child, sb, sb_focus, font_bold, font_medium)

func _setup_header() -> void:
	var header = get_node_or_null("Header")
	if not header:
		return
	
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 6)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 40
	header.offset_left = 0
	header.offset_right = 0
	
	var title: Label = header.get_node_or_null("Title")
	if title:
		var title_parent = title.get_parent()
		if title_parent.name != "TitlePlaque":
			var plaque := PanelContainer.new()
			plaque.name = "TitlePlaque"
			
			var plaque_sb := StyleBoxFlat.new()
			plaque_sb.bg_color = UITheme.CLR_CREAM
			plaque_sb.border_color = UITheme.CLR_INK
			plaque_sb.border_width_left = 4
			plaque_sb.border_width_top = 4
			plaque_sb.border_width_right = 4
			plaque_sb.border_width_bottom = 8 # 3D Depth
			plaque_sb.content_margin_left = 36
			plaque_sb.content_margin_right = 36
			plaque_sb.content_margin_top = 10
			plaque_sb.content_margin_bottom = 10
			plaque_sb.anti_aliasing = false
			plaque_sb.set_corner_radius_all(0)
			plaque.add_theme_stylebox_override("panel", plaque_sb)
			
			plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			
			var title_idx = title.get_index()
			header.remove_child(title)
			plaque.add_child(title)
			header.add_child(plaque)
			header.move_child(plaque, title_idx)

		var title_font := SystemFont.new()
		title_font.font_weight = 900 # Heavy/Black weight SystemFont
		title.add_theme_font_override("font", title_font)
		title.add_theme_font_size_override("font_size", 48)
		title.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
		title.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
		title.add_theme_constant_override("outline_size", 14) # thick outline
		title.add_theme_constant_override("shadow_offset_x", 3)
		title.add_theme_constant_override("shadow_offset_y", 3)
		title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))

	var subtitle: Label = header.get_node_or_null("Subtitle")
	if subtitle:
		subtitle.add_theme_font_size_override("font_size", 24)
		subtitle.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.add_theme_constant_override("line_spacing", 6)
		subtitle.add_theme_constant_override("shadow_offset_x", 0)
		subtitle.add_theme_constant_override("shadow_offset_y", 0)
		subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		subtitle.remove_theme_font_override("font")
		var bold_font := SystemFont.new()
		bold_font.font_weight = 700
		subtitle.add_theme_font_override("font", bold_font)

	# Dynamic spacer between plaque and subheading
	var plaque_spacer = header.get_node_or_null("PlaqueSpacer")
	if not plaque_spacer:
		plaque_spacer = Control.new()
		plaque_spacer.name = "PlaqueSpacer"
		plaque_spacer.custom_minimum_size = Vector2(0, 8)
		header.add_child(plaque_spacer)
		var plaque_node = header.get_node_or_null("TitlePlaque")
		if plaque_node:
			header.move_child(plaque_spacer, plaque_node.get_index() + 1)

	# Decorative separator (IntroCutscene overview style, colored CLR_CREAM_LT for red bg contrast)
	var divider = header.get_node_or_null("Divider")
	if not divider:
		var container := HBoxContainer.new()
		container.name = "Divider"
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var left_line := ColorRect.new()
		left_line.color = UITheme.CLR_CREAM_LT
		left_line.custom_minimum_size = Vector2(150, 4)
		left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var center_lbl := Label.new()
		center_lbl.text = " ✦ ❖ ✦ "
		center_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
		center_lbl.add_theme_font_size_override("font_size", 24)
		center_lbl.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
		
		var right_line := ColorRect.new()
		right_line.color = UITheme.CLR_CREAM_LT
		right_line.custom_minimum_size = Vector2(150, 4)
		right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		container.add_child(left_line)
		container.add_child(center_lbl)
		container.add_child(right_line)
		
		var top_spacer := Control.new()
		top_spacer.custom_minimum_size = Vector2(0, 6)
		
		var bottom_spacer := Control.new()
		bottom_spacer.custom_minimum_size = Vector2(0, 6)
		
		header.add_child(top_spacer)
		header.add_child(container)
		header.add_child(bottom_spacer)

func _on_pathway_selected(pathway: String) -> void:
	apply_preset(pathway)
	_update_card_styles(pathway)

func _update_card_styles(selected_id: String) -> void:
	if not pathway_cards:
		return
		
	for child in pathway_cards.get_children():
		var card_id = child.get_meta("pathway_id")
		var accent = child.get_meta("accent_color")
		var sb = child.get_theme_stylebox("panel") as StyleBoxFlat
		if not sb:
			continue
		
		var new_sb = sb.duplicate() as StyleBoxFlat
		var fill = child.find_child("Fill", true, false) as Control
		
		if card_id == selected_id:
			# Selected: Solid colored border (simple 3px on all sides)
			new_sb.border_color = accent
			if fill:
				fill.show()
		else:
			# Unselected: Simple ink border (3px on all sides)
			new_sb.border_color = UITheme.CLR_INK
			if fill:
				fill.hide()
				
		child.add_theme_stylebox_override("panel", new_sb)

func setup_layout() -> void:
	"""Creates a highly responsive HBox layout separating custom grids and preset sidebar."""
	# Construct header
	_setup_header()
	
	# Style and center bottom buttons
	var btn_container = get_node_or_null("ButtonContainer")
	if btn_container:
		btn_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		btn_container.offset_top = -100
		btn_container.offset_bottom = -30
		btn_container.offset_left = 0
		btn_container.offset_right = 0
		btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_container.add_theme_constant_override("separation", 60)
		
		if back_button:
			UITheme.style_pixel_button_colored(back_button, UITheme.CLR_RED)
		if continue_button:
			UITheme.style_pixel_button_colored(continue_button, UITheme.CLR_GREEN)
			
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 24)
	
	# Full stretch matching screen dimensions with margins
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 40
	main_hbox.offset_top = 220
	main_hbox.offset_right = -40
	main_hbox.offset_bottom = -120
	main_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(main_hbox)
	
	# Wrap scroll container in a cream panel so form labels are readable
	var form_panel := PanelContainer.new()
	UITheme.style_cream_panel(form_panel)
	form_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_panel.size_flags_stretch_ratio = 1.6 # Give more relative width to the right sidebar
	form_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(form_panel)
	
	var form_vbox := VBoxContainer.new()
	form_vbox.name = "FormVBox"
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 10)
	form_panel.add_child(form_vbox)

	# Preferences Title
	var pref_title := Label.new()
	pref_title.text = "Preferences"
	var pref_font := SystemFont.new()
	pref_font.font_weight = 850
	pref_title.add_theme_font_override("font", pref_font)
	pref_title.add_theme_font_size_override("font_size", 32)
	pref_title.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
	pref_title.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
	pref_title.add_theme_constant_override("outline_size", 10)
	pref_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	pref_title.add_theme_constant_override("shadow_offset_x", 2)
	pref_title.add_theme_constant_override("shadow_offset_y", 2)
	pref_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_vbox.add_child(pref_title)

	# Separator line below Preferences title (like the black line below Starting Values)
	var pref_sep := HSeparator.new()
	var sb_sep := StyleBoxLine.new()
	sb_sep.color = UITheme.CLR_INK
	sb_sep.thickness = 4
	pref_sep.add_theme_stylebox_override("separator", sb_sep)
	pref_sep.add_theme_constant_override("separation", 24)
	form_vbox.add_child(pref_sep)

	if scroll_container:
		remove_child(scroll_container)
		form_vbox.add_child(scroll_container)
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
	
	# HSeparator before Adult
	adult_sep = HSeparator.new()
	sections.add_child(adult_sep)
	
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
	
	# HSeparator before Career
	career_sep = HSeparator.new()
	sections.add_child(career_sep)
	
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

	# Row 3: promotion boost percent label (Aligned vertically like other rows)
	var boost_lbl := Label.new()
	boost_lbl.text = "Promotion Boost %"
	boost_lbl.add_theme_font_size_override("font_size", 22)
	boost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pf: boost_lbl.add_theme_font_override("font", pf)
	career_grid.add_child(boost_lbl)

	var boost_spacer_lbl1 := Control.new()
	career_grid.add_child(boost_spacer_lbl1)

	var boost_spacer_lbl2 := Control.new()
	career_grid.add_child(boost_spacer_lbl2)

	# Row 4: promotion boost input
	promotion_boost_input = LineEdit.new()
	promotion_boost_input.custom_minimum_size = Vector2(220, 56)
	promotion_boost_input.add_theme_font_size_override("font_size", 28)
	promotion_boost_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	career_grid.add_child(promotion_boost_input)

	var boost_spacer_input1 := Control.new()
	career_grid.add_child(boost_spacer_input1)

	var boost_spacer_input2 := Control.new()
	career_grid.add_child(boost_spacer_input2)

	# HSeparator before Daycare
	daycare_sep = HSeparator.new()
	sections.add_child(daycare_sep)

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
		daycare_cheap_price_check()
	if daycare_premium_input:
		daycare_premium_price_check()

func daycare_cheap_price_check() -> void:
	daycare_cheap_input.text = "%.2f" % GameState.daycare_cheap_price

func daycare_premium_price_check() -> void:
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
	var allowance_lbl = scroll_container.get_node_or_null("Sections/StartingGrid/WeeklyAllowanceLabel")
	if allowance_lbl: allowance_lbl.visible = show_allowance
	if weekly_allowance_input: weekly_allowance_input.visible = show_allowance
	
	# Chores row cell toggle
	var ball_lbl = scroll_container.get_node_or_null("Sections/CostsGrid/BallLabel")
	if ball_lbl: ball_lbl.visible = show_ball
	if ball_input: ball_input.visible = show_ball
	
	# Separators visibilities
	if adult_sep: adult_sep.visible = show_adult
	if career_sep: career_sep.visible = show_career
	if daycare_sep: daycare_sep.visible = show_career
	
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
	sidebar.custom_minimum_size = Vector2(440, 0) # Scaled up and wider
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_stretch_ratio = 1.0
	
	# Style the sidebar as cream panel
	UITheme.style_cream_panel(sidebar)
	parent_hbox.add_child(sidebar)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	sidebar.add_child(vbox)
	
	var title := Label.new()
	title.text = "SELECT PATHWAY"
	var title_font := SystemFont.new()
	title_font.font_weight = 850 # Extra bold SystemFont
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
	title.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	pathway_cards = VBoxContainer.new()
	pathway_cards.add_theme_constant_override("separation", 14)
	vbox.add_child(pathway_cards)
	
	_create_sidebar_card(pathway_cards, "kid", "Kid Pathway", "Allow: $100\nChore: $0.20\nRent: Free", UITheme.CLR_GREEN)
	_create_sidebar_card(pathway_cards, "teenager", "Teenager", "Allow: $50\nChore: $0.20\nRent: Free\nJobs: Part-Time", UITheme.CLR_ORANGE_PX)
	_create_sidebar_card(pathway_cards, "adult", "Adult", "Allow: $0\nRent: $200\nJobs: Full-Time\nGoal: Buy Home", UITheme.CLR_RED)
	
	# Select preset from GameState or default to Kid
	call_deferred("_select_default")

func _select_default() -> void:
	var target_pathway = GameState.selected_pathway
	if target_pathway == "":
		target_pathway = "kid"
	
	_selected_pathway = target_pathway
	
	# Just update visibilities and styles (do not call apply_preset, to preserve loaded settings)
	_update_field_visibilities(target_pathway)
	_update_card_styles(target_pathway)

func _create_sidebar_card(parent: Control, id: String, title_text: String, stats: String, accent_color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 160) # Increased size to fit larger fonts
	panel.set_meta("pathway_id", id)
	panel.set_meta("accent_color", accent_color)
	panel.set_meta("base_title", title_text)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Card base style box: Cream background with clean 3px ink border
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CLR_CREAM_LT
	sb.border_color = UITheme.CLR_INK
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	
	# Inner HBox to hold the left accent stripe, the text vbox, and the checkbox indicator
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(hbox)
	
	# Left accent stripe (distinguishable colored accent)
	var stripe := ColorRect.new()
	stripe.color = accent_color
	stripe.custom_minimum_size = Vector2(12, 0) # Wider stripe
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(stripe)
	
	# Margin container for the labels (increased padding)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_top", 16)
	margins.add_theme_constant_override("margin_right", 12)
	margins.add_theme_constant_override("margin_bottom", 16)
	margins.mouse_filter = Control.MOUSE_FILTER_PASS
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(margins)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margins.add_child(vbox)
	
	# Use a bold SystemFont for card title (increased size to 36)
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = title_text
	title_lbl.add_theme_color_override("font_color", accent_color)
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	var title_font := SystemFont.new()
	title_font.font_weight = 750 # Bold
	title_lbl.add_theme_font_override("font", title_font)
	vbox.add_child(title_lbl)
	
	# Use medium SystemFont for card stats/content (increased size to 22)
	var stats_lbl := Label.new()
	stats_lbl.text = stats
	stats_lbl.add_theme_font_size_override("font_size", 22)
	stats_lbl.add_theme_color_override("font_color", UITheme.CLR_INK)
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	var stats_font := SystemFont.new()
	stats_font.font_weight = 500 # Medium
	stats_lbl.add_theme_font_override("font", stats_font)
	vbox.add_child(stats_lbl)
	
	# Right-aligned custom checkbox-like selection indicator
	var indicator_margin := MarginContainer.new()
	indicator_margin.add_theme_constant_override("margin_right", 24)
	indicator_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(indicator_margin)
	
	var indicator_box := PanelContainer.new()
	indicator_box.custom_minimum_size = Vector2(30, 30)
	indicator_margin.add_child(indicator_box)
	
	var ib_sb := StyleBoxFlat.new()
	ib_sb.bg_color = UITheme.CLR_CREAM_LT
	ib_sb.border_color = UITheme.CLR_INK
	ib_sb.set_border_width_all(3)
	ib_sb.set_corner_radius_all(0)
	indicator_box.add_theme_stylebox_override("panel", ib_sb)
	
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = accent_color
	fill.custom_minimum_size = Vector2(16, 16)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.visible = false
	indicator_box.add_child(fill)
	
	# Clicking triggers synchronization
	var do_select := func():
		_on_pathway_selected(id)
		
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


# ── Input Validation & Warnings ──────────────────────────────────────────────
func _setup_all_input_validation() -> void:
	_connect_validation_recursive(self)

func _connect_validation_recursive(node: Node) -> void:
	if node is LineEdit:
		InputValidator.register_number_field(node)
	for child in node.get_children():
		_connect_validation_recursive(child)
