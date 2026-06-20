extends CanvasLayer
## Popup opened from the HUD "Work" button. Working a shift now happens by
## talking to your manager NPC, so this menu is just for the risky career moves:
## asking for a raise or a promotion. Both can get you fired — the worse your
## standing, the higher that risk — and a firing sends you back to the (shorter)
## job selection screen.

var _info_lbl: Label
var _result_lbl: Label
var _raise_btn: Button
var _promo_btn: Button
var _pf: Font


func _ready() -> void:
	layer = 60  # above the HUD
	_pf = UITheme.get_pixel_font()

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CLR_CREAM
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(48)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	panel.add_child(col)

	var title := Label.new()
	title.text = "YOUR CAREER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if _pf: title.add_theme_font_override("font", _pf)
	col.add_child(title)

	_info_lbl = Label.new()
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_lbl.custom_minimum_size = Vector2(840, 0)
	_info_lbl.add_theme_font_size_override("font_size", 48)
	_info_lbl.add_theme_color_override("font_color", UITheme.CLR_INK)
	if _pf: _info_lbl.add_theme_font_override("font", _pf)
	col.add_child(_info_lbl)

	var hint := Label.new()
	hint.text = "Work shifts by talking to your manager. Asking here is risky!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(840, 0)
	hint.add_theme_font_size_override("font_size", 34)
	hint.add_theme_color_override("font_color", UITheme.CLR_GRAY_DRK)
	if _pf: hint.add_theme_font_override("font", _pf)
	col.add_child(hint)

	var sep := HSeparator.new()
	col.add_child(sep)

	_raise_btn = _make_button("Ask for a Raise  (risky!)")
	_raise_btn.pressed.connect(_on_ask_raise)
	col.add_child(_raise_btn)

	_promo_btn = _make_button("Ask for a Promotion  (risky!)")
	_promo_btn.pressed.connect(_on_ask_promotion)
	col.add_child(_promo_btn)

	_result_lbl = Label.new()
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_result_lbl.custom_minimum_size = Vector2(840, 0)
	_result_lbl.add_theme_font_size_override("font_size", 48)
	_result_lbl.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if _pf: _result_lbl.add_theme_font_override("font", _pf)
	col.add_child(_result_lbl)

	var close_btn := _make_button("Close", true)
	close_btn.pressed.connect(queue_free)
	col.add_child(close_btn)

	_refresh()


func _make_button(text: String, secondary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 120)
	b.add_theme_font_size_override("font_size", 52)
	if _pf: b.add_theme_font_override("font", _pf)
	UITheme.style_pixel_button(b, secondary)
	return b


func _refresh() -> void:
	if GameState.active_job == "none":
		_info_lbl.text = "You don't have a job anymore."
		_raise_btn.disabled = true
		_promo_btn.disabled = true
		return

	var job := GameState.active_job
	var title := GameState.get_job_title(job)
	var standing := int(round(GameState.get_promotion_standing(job) * 100.0))
	var worked := GameState.days_worked_this_week
	var limit := GameState.weekly_shift_limit()

	var pay_line := ""
	if job == "burger_cashier":
		var boost := int(round((GameState.get_promotion_multiplier(job) - 1.0) * 100.0))
		pay_line = "Grill earnings & tips boosted %d%%" % boost
	else:
		pay_line = "$%.2f per shift" % GameState.get_current_job_pay()

	var promo_line := "Top rank reached." if GameState.is_at_max_rank(job) else "Promotion standing: %d%%" % standing

	_info_lbl.text = "%s — %s\n%s   •   Shifts this week: %d/%d\n%s" % [
		GameState.active_job_display_name, title, pay_line, worked, limit, promo_line
	]

	_raise_btn.disabled = false
	_promo_btn.disabled = GameState.is_at_max_rank(job)


func _on_ask_raise() -> void:
	_finish_request(GameState.request_raise())


func _on_ask_promotion() -> void:
	_finish_request(GameState.request_promotion())


func _finish_request(result: Dictionary) -> void:
	_result_lbl.text = str(result.get("message", ""))
	if result.get("fired", false):
		# The job selection menu opens itself (GameState.trigger_job_selection).
		# Close after a short beat so the player can read the bad news.
		_raise_btn.disabled = true
		_promo_btn.disabled = true
		await get_tree().create_timer(1.4).timeout
		queue_free()
	else:
		_refresh()
