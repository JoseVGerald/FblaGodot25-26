# job_selection_menu.gd
# Programmatic 3-card Job Selection UI with beautiful HSL accents and clear benefit summaries.
extends CanvasLayer

signal job_selected(job_name: String)

var _selected_job: String = "news_boy"
var root_control: Control = null

func _ready() -> void:
	# Add a root Control node that covers the screen
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)
	
	# Semi-transparent dark background overlay
	var bg_overlay := ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.75)
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg_overlay)
	
	# Apply overall theme
	UITheme.apply_theme(root_control)
	var pf := UITheme.get_pixel_font()
	
	# Title
	var title := Label.new()
	title.text = "SELECT YOUR JOB"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("#53d8fb")) # cyan neon
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pf: title.add_theme_font_override("font", pf)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 60
	title.offset_bottom = 140
	root_control.add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Earn cash to buy supplies & save for your pet's future!"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("#a0b2d6"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pf: subtitle.add_theme_font_override("font", pf)
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 130
	subtitle.offset_bottom = 170
	root_control.add_child(subtitle)
	
	# HBoxContainer for 3 Job Cards
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 30)
	card_row.set_anchors_preset(Control.PRESET_CENTER)
	card_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card_row.grow_vertical = Control.GROW_DIRECTION_BOTH
	card_row.custom_minimum_size = Vector2(960, 420)
	card_row.position = Vector2(160, 180)
	root_control.add_child(card_row)
	
	# Card 1: News Boy
	_create_job_card(card_row, "news_boy", "News Boy", "🗞️", 
		"Deliver morning papers around town!\n\n" +
		"• Day Pay: $10.00 / day\n" +
		"• Commute Cost: FREE\n\n" +
		"Benefit: Taxi travel is 100% free! Save cash on every trip to town.", Color("#4CAF50"))
		
	# Card 2: Burger Cashier
	_create_job_card(card_row, "burger_cashier", "Burger Cashier", "🍔", 
		"Serve juicy burgers at the Diner!\n\n" +
		"• Day Pay: $15.00 / day\n" +
		"• Daily Shift Limit applies\n\n" +
		"Benefit: Free Employee Meal! Gain 3 food supply for every 7 days worked.", Color("#FFA726"))
		
	# Card 3: Bank Accountant
	_create_job_card(card_row, "bank_accountant", "Bank Accountant", "🏦", 
		"Manage ledgers & financial assets!\n\n" +
		"• Day Pay: $25.00 / day\n" +
		"• Demanding responsibilities\n\n" +
		"Benefit: Financial Perk! Waives the 15% savings penalty & boosts interest to 7%!", Color("#EF5350"))
		
	# Confirm button
	var accept_btn := Button.new()
	accept_btn.text = "Accept Job offer"
	accept_btn.add_theme_font_size_override("font_size", 28)
	if pf: accept_btn.add_theme_font_override("font", pf)
	accept_btn.custom_minimum_size = Vector2(300, 60)
	accept_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	accept_btn.position = Vector2(490, 630)
	UITheme.style_button(accept_btn, Color("#4CAF50"))
	root_control.add_child(accept_btn)
	accept_btn.pressed.connect(_on_accept_pressed)
	
	# Select News Boy by default
	call_deferred("_select_default", card_row)

func _select_default(card_row: HBoxContainer) -> void:
	_selected_job = "none"
	for child in card_row.get_children():
		var btn = child.get_node("VBoxContainer/SelectBtn") as Button
		if btn and not btn.disabled:
			btn.pressed.emit()
			break

func _create_job_card(parent: Control, id: String, title: String, emoji: String, desc: String, accent_color: Color) -> void:
	var panel := PanelContainer.new()
	panel.set_meta("job_id", id)
	panel.custom_minimum_size = Vector2(290, 380)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Card styling
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#162240") # Dark navy base
	sb.border_color = accent_color.darkened(0.2)
	sb.border_width_bottom = 4
	sb.border_width_top = 4
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var emoji_lbl := Label.new()
	emoji_lbl.text = emoji
	emoji_lbl.add_theme_font_size_override("font_size", 44)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji_lbl)
	
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", accent_color)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pf := UITheme.get_pixel_font()
	if pf: title_lbl.add_theme_font_override("font", pf)
	vbox.add_child(title_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color("#f0f4ff"))
	vbox.add_child(desc_lbl)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	var select_btn := Button.new()
	select_btn.name = "SelectBtn"
	if id in GameState.fired_jobs_history:
		select_btn.text = "🚫 Fired"
		select_btn.disabled = true
		select_btn.add_theme_font_size_override("font_size", 20)
		if pf: select_btn.add_theme_font_override("font", pf)
		select_btn.custom_minimum_size = Vector2(140, 44)
		select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UITheme.style_button(select_btn, Color("#555555"))
	else:
		select_btn.text = "Choose"
		select_btn.add_theme_font_size_override("font_size", 20)
		if pf: select_btn.add_theme_font_override("font", pf)
		select_btn.custom_minimum_size = Vector2(140, 44)
		select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UITheme.style_button(select_btn, Color("#2d6aad"))
	vbox.add_child(select_btn)
	
	# Card selection handling
	select_btn.pressed.connect(func():
		_selected_job = id
		
		# Reset other cards bg color
		for child in parent.get_children():
			var card_sb = child.get_theme_stylebox("panel") as StyleBoxFlat
			if card_sb:
				card_sb.bg_color = Color("#162240")
		sb.bg_color = Color("#0d1b36").lightened(0.08) # Glowing select dark
		
		# Reset other buttons
		for child in parent.get_children():
			var btn = child.get_node("VBoxContainer/SelectBtn") as Button
			if btn:
				btn.text = "Choose"
				UITheme.style_button(btn, Color("#2d6aad"))
		select_btn.text = "✓ Selected"
		UITheme.style_button(select_btn, accent_color)
	)

func _on_accept_pressed() -> void:
	if _selected_job == "none" or _selected_job in GameState.fired_jobs_history:
		return
	GameState.active_job = _selected_job
	print("[JobSelectionMenu] Player accepted job: ", _selected_job)
	
	# For teenagers, limit to 3 work days max. For Adults, default to 5, allow 1-7.
	if GameState.selected_pathway == "teenager":
		GameState.work_days_scheduled = 3
	else:
		GameState.work_days_scheduled = 5
		
	# Emit signal and dismiss
	job_selected.emit(_selected_job)
	queue_free()
