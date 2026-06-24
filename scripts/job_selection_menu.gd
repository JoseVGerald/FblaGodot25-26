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
	
	# Semi-transparent dark background overlay.
	# NOTE: do not call UITheme.apply_theme here — it deletes full-rect
	# ColorRects (this overlay) and replaces them with the maroon checker.
	var bg_overlay := ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.75)
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg_overlay)

	var pf := UITheme.get_pixel_font()
	
	# Single centered column keeps everything centered at any window size.
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	root_control.add_child(layout)

	# Title
	var title := Label.new()
	title.text = "SELECT YOUR JOB"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("#53d8fb")) # cyan neon
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pf: title.add_theme_font_override("font", pf)
	layout.add_child(title)

	# Every job and the talking points shown on its card. Each starts at its
	# entry rank — managers explain the promotion ladder once you're hired.
	var all_jobs := [
		{
			"id": "news_boy", "title": "Mail Boy", "emoji": "🗞️", "accent": Color("#4CAF50"),
			"desc": "Run the route out of the Post Office!\n\n" +
				"• Start Pay: $10.00 / shift\n" +
				"• Ranks: Paper Boy → Route Captain → Postmaster\n\n" +
				"Benefit: Every taxi ride is FREE. Pay climbs with each promotion.",
		},
		{
			"id": "burger_cashier", "title": "The Cook", "emoji": "🍔", "accent": Color("#FFA726"),
			"desc": "Cook and serve at the Burger Barn!\n\n" +
				"• Start Pay: $15.00 / shift + tips\n" +
				"• Ranks: Trainee → Hard Worker → Grill Master\n\n" +
				"Benefit: TIPS go straight to your cash, plus a free employee meal. Both grow with rank.",
		},
		{
			"id": "bank_accountant", "title": "Bank Accountant", "emoji": "🏦", "accent": Color("#EF5350"),
			"desc": "Handle the ledgers at First City Bank!\n\n" +
				"• Start Pay: $25.00 / shift\n" +
				"• Ranks: Bank Teller → Loan Officer → Branch Manager\n\n" +
				"Benefit: No savings withdrawal penalty and rising interest (6% → 10%).",
		},
	]

	# Only jobs you haven't been fired from are still open. Each firing drops
	# the number of available cards (3 → 2 → 1 → 0).
	var available := []
	for job in all_jobs:
		if not job["id"] in GameState.fired_jobs_history:
			available.append(job)

	# Subtitle reflects how many positions are left in town.
	var subtitle := Label.new()
	if available.is_empty():
		subtitle.text = "You've been fired from every job in town."
	elif available.size() < all_jobs.size():
		subtitle.text = "%d position(s) still open — choose carefully, firings close doors for good!" % available.size()
	else:
		subtitle.text = "Earn cash to buy supplies & save for your pet's future!"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("#a0b2d6"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pf: subtitle.add_theme_font_override("font", pf)
	layout.add_child(subtitle)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	layout.add_child(gap)

	# HBoxContainer for the remaining Job Cards
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 30)
	card_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(card_row)

	if available.is_empty():
		# No jobs left — soft dead end. Let the player close and carry on jobless.
		var none_lbl := Label.new()
		none_lbl.text = "No positions are available.\nYou'll have to get by without a job for now."
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.add_theme_font_size_override("font_size", 22)
		none_lbl.add_theme_color_override("font_color", Color("#f0f4ff"))
		if pf: none_lbl.add_theme_font_override("font", pf)
		card_row.add_child(none_lbl)
	else:
		for job in available:
			_create_job_card(card_row, job["id"], job["title"], job["emoji"], job["desc"], job["accent"])

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 12)
	layout.add_child(gap2)

	# Continue / Close button
	var accept_btn := Button.new()
	accept_btn.text = "CLOSE" if available.is_empty() else "CONTINUE"
	accept_btn.add_theme_font_size_override("font_size", 28)
	if pf: accept_btn.add_theme_font_override("font", pf)
	accept_btn.custom_minimum_size = Vector2(300, 60)
	accept_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(accept_btn, Color("#4CAF50"))
	layout.add_child(accept_btn)
	if available.is_empty():
		accept_btn.pressed.connect(queue_free)
	else:
		accept_btn.pressed.connect(_on_accept_pressed)
		# Select the first available job by default
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
	emoji_lbl.text = ""
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
	# Fresh start at rank 1 — clears raises, resets the manager day-one briefing.
	GameState.start_job(_selected_job)
	print("[JobSelectionMenu] Player accepted job: ", _selected_job)

	# For teenagers, limit to 3 work days max. For Adults, default to 5, allow 1-7.
	if GameState.selected_pathway == "teenager":
		GameState.work_days_scheduled = 3
	else:
		GameState.work_days_scheduled = 5
		
	# Emit signal and dismiss
	job_selected.emit(_selected_job)
	queue_free()
