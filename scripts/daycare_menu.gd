extends CanvasLayer
## Popup that lets teens/adults choose cheap or premium daycare before a shift.

var _cheap_btn: Button
var _premium_btn: Button
var _pf: Font


func _ready() -> void:
	layer = 60
	_pf = UITheme.get_pixel_font()
	visible = false
	_build_ui()


func open() -> void:
	_refresh()
	visible = true


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CLR_CREAM
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "DOG DAYCARE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	if _pf: title.add_theme_font_override("font", _pf)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Send your pup while you work. Pick a plan:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.custom_minimum_size = Vector2(460, 0)
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", UITheme.CLR_GRAY_DRK)
	if _pf: sub.add_theme_font_override("font", _pf)
	col.add_child(sub)

	col.add_child(HSeparator.new())

	_cheap_btn = _make_tier_button("Cheap Daycare", "Basic care. Health at risk.")
	_cheap_btn.pressed.connect(func(): _pick(GameState.DaycareTier.CHEAP, GameState.daycare_cheap_price))
	col.add_child(_cheap_btn)

	_premium_btn = _make_tier_button("Premium Daycare", "Safe + health protected.")
	_premium_btn.pressed.connect(func(): _pick(GameState.DaycareTier.PREMIUM, GameState.daycare_premium_price))
	col.add_child(_premium_btn)

	col.add_child(HSeparator.new())

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 56)
	cancel_btn.add_theme_font_size_override("font_size", 22)
	if _pf: cancel_btn.add_theme_font_override("font", _pf)
	UITheme.style_pixel_button(cancel_btn, true)
	cancel_btn.pressed.connect(func(): visible = false)
	col.add_child(cancel_btn)


func _make_tier_button(tier_name: String, desc: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 22)
	if _pf: b.add_theme_font_override("font", _pf)
	UITheme.style_pixel_button(b)
	return b


func _refresh() -> void:
	var cheap := GameState.daycare_cheap_price
	var premium := GameState.daycare_premium_price
	var money := GameState.money

	_cheap_btn.text = "Cheap Daycare — $%.2f\nBasic care. Health at risk." % cheap
	_premium_btn.text = "Premium Daycare — $%.2f\nSafe + health protected." % premium

	_cheap_btn.disabled = money < cheap
	_premium_btn.disabled = money < premium

	# Red tint on disabled buttons
	var red_mod := Color(1.0, 0.5, 0.5, 1.0)
	var normal_mod := Color.WHITE
	_cheap_btn.self_modulate = red_mod if _cheap_btn.disabled else normal_mod
	_premium_btn.self_modulate = red_mod if _premium_btn.disabled else normal_mod


func _pick(tier: GameState.DaycareTier, price: float) -> void:
	GameState.money -= price
	GameState.dog_at_daycare = true
	GameState.daycare_used_today = true
	GameState.daycare_tier_today = tier
	visible = false
