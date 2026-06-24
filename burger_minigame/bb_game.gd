@tool
class_name BBGame
extends Control
## Burger Blitz — root controller. Builds the whole 1280x720 stage in code
## (also at editor time, so opening BurgerBlitz.tscn previews the real UI).

const STAGE := Vector2(1280, 720)

# ---- run state ----
var tab := "grill"
var trash_mode := false
var paused := false
var playing := false
var day := 1
var money := 0.0
var score := 0
var day_length := 95.0
var day_time_left := 95.0
var day_customers := 1
var spawned_count := 0
var spawn_interval := 8.0
var spawn_timer := 0.0
var queue: Array = []
var day_served := 0
var day_missed := 0
var day_earnings := 0.0
var day_tips := 0.0
var day_stars := 0
var day_perfect := 0
var best_day := 0.0

# ---- modules ----
var sfx: BBSfx = null
var grill_station: BBGrill = null
var build_station: BBBuild = null

# ---- nodes ----
var _stage: Control = null
var _grill_panel: Control = null
var _build_panel: Control = null
var _tab_grill: Button = null
var _tab_build: Button = null
var _chips: Dictionary = {}
var _daybar_fill: ColorRect = null
var _daybar_w := 220.0
var _cust_box: Control = null
var _ticket_box: Control = null
var _queue_strip: Control = null
var _patience_fill: ColorRect = null
var _patience_w := 0.0
var _trash_btn: Button = null
var _trash_wrap: Control = null
var _tray_grid: Control = null
var _crt: BBCrt = null
var _crt_btn: Button = null
var _mute_btn: Button = null
var _result_layer: Control = null
var _banner: Label = null

var _grill_alert := false
var _flash_clock := 0.0
var _tab_active_sb: StyleBoxFlat
var _tab_idle_sb: StyleBoxFlat
var _tab_alert_sb: StyleBoxFlat


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_stage()
	if Engine.is_editor_hint():
		_populate_demo()
		return
	sfx = BBSfx.new()
	add_child(sfx)
	start_day()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _stage != null:
		_fit()


func _fit() -> void:
	var s: float = minf(size.x / STAGE.x, size.y / STAGE.y)
	if s <= 0.0:
		return
	_stage.scale = Vector2(s, s)
	_stage.position = (size - STAGE * s) / 2.0


# =========================================================== build

func _build_stage() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0a0705")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = STAGE
	add_child(_stage)
	_fit()

	var bg := BBStageBG.new()
	bg.size = STAGE
	_stage.add_child(bg)
	var stage_frame := Panel.new()
	stage_frame.size = STAGE
	var sfb := BBStyle.flat(Color.TRANSPARENT, 6, Color("0a0705"))
	sfb.draw_center = false
	stage_frame.add_theme_stylebox_override("panel", sfb)
	stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_frame.z_index = 50
	_stage.add_child(stage_frame)

	_build_hud()
	_build_order_panel()
	_build_grill_panel()
	_build_build_panel()
	_build_tray_panel()

	_banner = BBStyle.label("DAY 1", BBStyle.px(48), BBStyle.YELLOW)
	_banner.add_theme_color_override("font_shadow_color", BBStyle.RED_D)
	_banner.add_theme_constant_override("shadow_offset_y", 5)
	_banner.z_index = 60
	_banner.modulate.a = 0.0
	_stage.add_child(_banner)

	_crt = BBCrt.new()
	_crt.size = STAGE
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt.z_index = 70
	_stage.add_child(_crt)

	set_tab("grill", true)


func _icon_btn(text: String) -> Control:
	var wrap := BBStyle.big_btn(text, Color("3a2414"), BBStyle.CREAM, Vector2(0, 0), BBStyle.px(11), 3)
	var b: Button = wrap.get_meta("btn")
	b.add_theme_stylebox_override("normal", BBStyle.flat(Color("3a2414"), 3, Color("0a0705")))
	b.add_theme_stylebox_override("hover", BBStyle.flat(Color("3a2414"), 3, Color("0a0705")))
	b.add_theme_stylebox_override("pressed", BBStyle.flat(Color("2f1d10"), 3, Color("0a0705")))
	return wrap


func _build_hud() -> void:
	var hud := Panel.new()
	hud.size = Vector2(STAGE.x, 66)
	var hsb := BBStyle.flat(BBStyle.INK)
	hsb.border_width_bottom = 4
	hsb.border_color = Color("0a0705")
	hud.add_theme_stylebox_override("panel", hsb)
	_stage.add_child(hud)

	_tab_active_sb = BBStyle.flat(BBStyle.PANEL)
	_tab_active_sb.border_width_bottom = 6
	_tab_active_sb.border_color = BBStyle.YELLOW
	_tab_idle_sb = BBStyle.flat(Color("241509"))
	_tab_idle_sb.border_width_right = 4
	_tab_idle_sb.border_color = Color("0a0705")
	_tab_alert_sb = BBStyle.flat(BBStyle.RED)
	_tab_alert_sb.border_width_right = 4
	_tab_alert_sb.border_color = Color("0a0705")

	_tab_grill = _make_tab("🔥 GRILL", 0.0)
	_tab_grill.pressed.connect(set_tab.bind("grill", false))
	_tab_build = _make_tab("🍔 ASSEMBLE", _tab_grill.size.x)
	_tab_build.pressed.connect(set_tab.bind("build", false))
	_stage.add_child(_tab_grill)
	_stage.add_child(_tab_build)

	var x := _tab_grill.size.x + _tab_build.size.x + 14.0
	for c in [["day", "DAY", "1"], ["time", "SEC", "95"]]:
		var chip := BBStyle.chip(c[1], c[2])
		_stage.add_child(chip)
		chip.reset_size()
		chip.position = Vector2(x, (62.0 - chip.size.y) / 2.0)
		_chips[c[0]] = chip.get_meta("val")
		x += chip.size.x + 10.0

	var daybar := Panel.new()
	daybar.position = Vector2(x, (62.0 - 18.0) / 2.0)
	daybar.size = Vector2(_daybar_w, 18)
	daybar.add_theme_stylebox_override("panel", BBStyle.flat(Color("3a2414"), 3, Color("0a0705")))
	_stage.add_child(daybar)
	_daybar_fill = ColorRect.new()
	_daybar_fill.color = BBStyle.GREEN
	_daybar_fill.position = Vector2(3, 3)
	_daybar_fill.size = Vector2(_daybar_w - 6.0, 12)
	daybar.add_child(_daybar_fill)
	x += _daybar_w + 10.0

	var cust_chip := BBStyle.chip("CUST", "0/5")
	_stage.add_child(cust_chip)
	cust_chip.reset_size()
	cust_chip.position = Vector2(x, (62.0 - cust_chip.size.y) / 2.0)
	_chips["cust"] = cust_chip.get_meta("val")

	# right side, laid right-to-left
	var rx := STAGE.x - 14.0
	_crt_btn = _place_right(_icon_btn("CRT ON"), rx)
	rx = _crt_btn.get_parent().position.x - 10.0
	_crt_btn.pressed.connect(_toggle_crt)
	_mute_btn = _place_right(_icon_btn("🔊 ON"), rx)
	rx = _mute_btn.get_parent().position.x - 10.0
	_mute_btn.pressed.connect(_toggle_mute)
	var cash_chip := BBStyle.chip("CASH", "$0.00", BBStyle.GREEN)
	_stage.add_child(cash_chip)
	cash_chip.reset_size()
	cash_chip.position = Vector2(rx - cash_chip.size.x, (62.0 - cash_chip.size.y) / 2.0)
	_chips["money"] = cash_chip.get_meta("val")
	rx = cash_chip.position.x - 10.0
	var score_chip := BBStyle.chip("SCORE", "0")
	_stage.add_child(score_chip)
	score_chip.reset_size()
	score_chip.position = Vector2(rx - score_chip.size.x, (62.0 - score_chip.size.y) / 2.0)
	_chips["score"] = score_chip.get_meta("val")


func _place_right(wrap: Control, right_edge: float) -> Button:
	_stage.add_child(wrap)
	var b: Button = wrap.get_meta("btn")
	b.reset_size()
	b.size.y = 34.0
	wrap.position = Vector2(right_edge - b.size.x, (62.0 - 34.0) / 2.0)
	return b


func _make_tab(text: String, x: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", BBStyle.font())
	b.add_theme_font_size_override("font_size", BBStyle.px(11))
	b.add_theme_stylebox_override("focus", BBStyle.empty_box())
	b.position = Vector2(x, 0)
	var w := BBStyle.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BBStyle.px(11)).x
	b.size = Vector2(w + 44.0, 62)
	return b


func set_tab(name_: String, silent: bool = false) -> void:
	tab = name_
	if name_ == "grill":
		_grill_alert = false
	_apply_tab_styles()
	if _grill_panel:
		_grill_panel.visible = (name_ == "grill")
	if _build_panel:
		_build_panel.visible = (name_ == "build")
	if not silent and sfx:
		sfx.play("click")


func _apply_tab_styles() -> void:
	var alert_on := _grill_alert and fmod(_flash_clock, 0.45) < 0.225
	for setup in [[_tab_grill, tab == "grill", alert_on], [_tab_build, tab == "build", false]]:
		var b: Button = setup[0]
		if b == null:
			continue
		var active: bool = setup[1]
		var sb := _tab_active_sb if active else (_tab_alert_sb if setup[2] else _tab_idle_sb)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var fg := BBStyle.INK if active else (Color.WHITE if setup[2] else Color("a08866"))
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(cn, fg)


func set_grill_alert(b: bool) -> void:
	if b != _grill_alert:
		_grill_alert = b
		_apply_tab_styles()


func _build_order_panel() -> void:
	var panel := BBStyle.framed_panel(Rect2(14, 80, 258, 626), "ORDER UP", "who's next")
	_stage.add_child(panel)
	var body: Control = panel.get_meta("body")
	_cust_box = Control.new()
	_cust_box.position = Vector2(12, 12)
	_cust_box.size = Vector2(body.size.x - 24.0, 78)
	body.add_child(_cust_box)
	_ticket_box = Control.new()
	_ticket_box.position = Vector2(12, 102)
	_ticket_box.size = Vector2(body.size.x - 24.0, 360)
	body.add_child(_ticket_box)
	_queue_strip = Control.new()
	_queue_strip.size = Vector2(body.size.x - 24.0, 40)
	body.add_child(_queue_strip)


func _build_grill_panel() -> void:
	_grill_panel = BBStyle.framed_panel(Rect2(286, 80, 980, 522), "🔥 GRILL STATION", "flip · pull")
	_stage.add_child(_grill_panel)
	grill_station = BBGrill.new()
	grill_station.game = self
	_grill_panel.add_child(grill_station)
	grill_station.build(_grill_panel.get_meta("body"))


func _build_build_panel() -> void:
	_build_panel = BBStyle.framed_panel(Rect2(286, 80, 980, 522), "🍳 ASSEMBLE", "click to stack")
	_stage.add_child(_build_panel)
	build_station = BBBuild.new()
	build_station.game = self
	_build_panel.add_child(build_station)
	build_station.build_ui(_build_panel.get_meta("body"))


func _build_tray_panel() -> void:
	var panel := BBStyle.framed_panel(Rect2(286, 616, 980, 90), "", "")
	_stage.add_child(panel)
	var body: Control = panel.get_meta("body")
	var title := BBStyle.label("▸ READY TRAY", BBStyle.px(10), BBStyle.LINE)
	title.position = Vector2(14, 0)
	title.size = Vector2(150, body.size.y)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(title)

	_tray_grid = Panel.new()
	_tray_grid.position = Vector2(170, 10)
	_tray_grid.size = Vector2(body.size.x - 170.0 - 110.0 - 14.0, body.size.y - 20.0)
	_tray_grid.add_theme_stylebox_override("panel", BBStyle.flat(Color("e3cd9c"), 3, BBStyle.INK, 4))
	body.add_child(_tray_grid)
	grill_station.tray_grid = _tray_grid
	grill_station.render_tray()

	_trash_wrap = Control.new()
	_trash_wrap.position = Vector2(body.size.x - 110.0, 8.0)
	body.add_child(_trash_wrap)
	_trash_wrap.add_child(BBStyle.shadow_panel(Vector2(96, 58), 4))
	var b := Button.new()
	b.size = Vector2(96, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", BBStyle.font())
	b.add_theme_font_size_override("font_size", BBStyle.px(8))
	b.text = "🗑\nTRASH"
	b.add_theme_color_override("font_color", BBStyle.CREAM)
	b.add_theme_stylebox_override("normal", BBStyle.flat(Color("5a564f"), 3, BBStyle.INK))
	b.add_theme_stylebox_override("hover", BBStyle.flat(Color("5a564f"), 3, BBStyle.INK))
	b.add_theme_stylebox_override("pressed", BBStyle.flat(Color("4a463f"), 3, BBStyle.INK))
	b.add_theme_stylebox_override("focus", BBStyle.empty_box())
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trash_wrap.add_child(b)
	_trash_btn = b
	b.pressed.connect(toggle_trash)


# =========================================================== customers / orders

func toggle_trash(force_off: bool = false) -> void:
	trash_mode = false if force_off else not trash_mode
	if _trash_btn:
		_trash_btn.add_theme_stylebox_override("normal",
			BBStyle.flat(BBStyle.RED if trash_mode else Color("5a564f"), 3, BBStyle.INK))
		_trash_btn.add_theme_stylebox_override("hover",
			BBStyle.flat(BBStyle.RED if trash_mode else Color("5a564f"), 3, BBStyle.INK))
	if _tray_grid:
		_tray_grid.add_theme_stylebox_override("panel",
			BBStyle.flat(Color("e3cd9c"), 3, BBStyle.RED if trash_mode else BBStyle.INK, 4))
	if sfx:
		sfx.play("click")
	if trash_mode:
		toast("TRASH MODE — click a tray patty to bin it")
	grill_station.render_tray()


func start_day() -> void:
	playing = true
	paused = false
	day_length = 95.0
	day_time_left = day_length
	day_customers = 1
	spawned_count = 0
	spawn_interval = maxf(5.5, 8.0 - day * 0.3)
	spawn_timer = 0.0
	queue = []
	day_served = 0
	day_missed = 0
	day_earnings = 0.0
	day_tips = 0.0
	day_stars = 0
	day_perfect = 0
	grill_station.reset()
	build_station.reset()
	if trash_mode:
		toggle_trash(true)
	set_tab("grill", true)
	if _result_layer:
		_result_layer.queue_free()
		_result_layer = null
	_show_banner("DAY %d" % day)
	spawn_customer()
	render_active_order()
	_update_hud()
	sfx.play("start")


func next_day() -> void:
	day += 1
	start_day()


func spawn_customer() -> void:
	if spawned_count >= day_customers:
		return
	queue.append(BBData.generate_order(day))
	spawned_count += 1
	spawn_timer = spawn_interval
	if queue.size() == 1:
		render_active_order()
	else:
		_render_queue_strip()


func render_active_order() -> void:
	for c in _cust_box.get_children():
		c.queue_free()
	for c in _ticket_box.get_children():
		c.queue_free()
	_patience_fill = null
	if queue.is_empty():
		var l := BBStyle.label("Waiting for customer…", 16, Color("9a865f"))
		l.position = Vector2(4, 8)
		_cust_box.add_child(l)
		_render_queue_strip()
		return
	var order: Dictionary = queue[0]

	# customer card
	var card := Control.new()
	card.size = _cust_box.size
	_cust_box.add_child(card)
	card.add_child(BBStyle.shadow_panel(card.size, 4))
	var cp := Panel.new()
	cp.size = card.size
	cp.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.CREAM, 3, BBStyle.INK))
	card.add_child(cp)
	var av := _make_avatar(order["avatar_seed"], order["mood"], 58.0)
	av.position = Vector2(10, 10)
	cp.add_child(av)
	cp.set_meta("avatar", av)
	var nm := BBStyle.label(order["name"], BBStyle.px(11), BBStyle.INK)
	nm.position = Vector2(78, 14)
	cp.add_child(nm)
	var pat := Panel.new()
	pat.position = Vector2(78, 40)
	pat.size = Vector2(card.size.x - 78.0 - 12.0, 13)
	pat.add_theme_stylebox_override("panel", BBStyle.flat(Color("d8c49a"), 2, BBStyle.INK))
	cp.add_child(pat)
	_patience_fill = ColorRect.new()
	_patience_fill.color = BBStyle.GREEN
	_patience_fill.position = Vector2(2, 2)
	_patience_fill.size = Vector2(pat.size.x - 4.0, 9)
	pat.add_child(_patience_fill)
	_patience_w = pat.size.x - 4.0

	# ticket
	var tk := Control.new()
	tk.position = Vector2(0, 10)
	tk.size = Vector2(_ticket_box.size.x, 40.0 + order["items"].size() * 27.0)
	_ticket_box.add_child(tk)
	tk.add_child(BBStyle.shadow_panel(tk.size, 4))
	var tbg := Panel.new()
	tbg.size = tk.size
	tbg.add_theme_stylebox_override("panel", BBStyle.flat(Color("fffbee")))
	tk.add_child(tbg)
	var dash := BBDashedRect.new()
	dash.line_color = BBStyle.LINE
	dash.size = tk.size
	tk.add_child(dash)
	var order_tag := PanelContainer.new()
	var osb := BBStyle.flat(BBStyle.RED, 2, BBStyle.INK)
	osb.content_margin_left = 8.0
	osb.content_margin_right = 8.0
	osb.content_margin_top = 4.0
	osb.content_margin_bottom = 4.0
	order_tag.add_theme_stylebox_override("panel", osb)
	order_tag.add_child(BBStyle.label("ORDER", BBStyle.px(9), Color.WHITE))
	order_tag.position = Vector2(12, -11)
	tk.add_child(order_tag)

	var y := 22.0
	for it in order["items"]:
		var row := Control.new()
		row.position = Vector2(10, y)
		row.size = Vector2(tk.size.x - 20.0, 27)
		tk.add_child(row)
		var dot := Panel.new()
		dot.position = Vector2(0, 7)
		dot.size = Vector2(13, 13)
		dot.add_theme_stylebox_override("panel", BBStyle.flat(BBData.SWATCH.get(it["type"], Color("999999")), 2, BBStyle.INK))
		row.add_child(dot)
		var nl := BBStyle.label(BBData.label_of(it["type"]), 17, BBStyle.INK)
		nl.position = Vector2(20, 0)
		nl.size = Vector2(120, 27)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nl)
		if it["type"] == "patty":
			var dt := PanelContainer.new()
			var dsb := BBStyle.flat(BBData.DONE_TAG_COLOR.get(it["doneness"], Color("666666")), 2, BBStyle.INK)
			dsb.content_margin_left = 5.0
			dsb.content_margin_right = 5.0
			dsb.content_margin_top = 2.0
			dsb.content_margin_bottom = 2.0
			dt.add_theme_stylebox_override("panel", dsb)
			dt.add_child(BBStyle.label(it["doneness"], BBStyle.px(8), Color.WHITE))
			row.add_child(dt)
			dt.reset_size()
			dt.position = Vector2(row.size.x - dt.size.x, (27.0 - dt.size.y) / 2.0)
		var sep := ColorRect.new()
		sep.color = Color("c9b487")
		sep.position = Vector2(0, 26)
		sep.size = Vector2(row.size.x, 1)
		row.add_child(sep)
		y += 27.0

	_queue_strip.position.y = _ticket_box.position.y + tk.size.y + 24.0
	_render_queue_strip()


func _render_queue_strip() -> void:
	for c in _queue_strip.get_children():
		c.queue_free()
	var x := 0.0
	var waiting: Array = queue.slice(1, 4)
	for o in waiting:
		var av := _make_avatar(o["avatar_seed"], "neutral", 34.0)
		av.position = Vector2(x, 0)
		_queue_strip.add_child(av)
		x += 40.0
	var remaining: int = day_customers - spawned_count + maxi(0, queue.size() - 4)
	if remaining > 0:
		var more := BBStyle.label("+%d" % remaining, 16, BBStyle.LINE)
		more.position = Vector2(x + 2.0, 7)
		_queue_strip.add_child(more)


func _make_avatar(seed_val: int, mood: String, px_size: float) -> Control:
	var holder := Control.new()
	holder.size = Vector2(px_size, px_size)
	var frame := Panel.new()
	frame.size = holder.size
	var fsb := BBStyle.flat(Color.TRANSPARENT, 3, BBStyle.INK)
	fsb.draw_center = false
	frame.add_theme_stylebox_override("panel", fsb)
	var img := BBPix.tex_rect(BBPix.avatar_texture(seed_val, mood), Vector2(px_size - 6.0, px_size - 6.0))
	img.position = Vector2(3, 3)
	holder.add_child(img)
	holder.add_child(frame)
	return holder


func react_avatar(mood: String) -> void:
	if queue.is_empty():
		return
	queue[0]["mood"] = mood
	render_active_order()
	# pop: quick scale punch on the refreshed card
	var card := _cust_box.get_child(_cust_box.get_child_count() - 1) if _cust_box.get_child_count() else null
	if card is Control:
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(1.12, 1.12)
		var tw := card.create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(card, "scale", Vector2.ONE, 0.18)


func customer_leaves() -> void:
	if queue.is_empty() or queue[0]["resolved"]:
		return
	var order: Dictionary = queue[0]
	order["resolved"] = true
	day_missed += 1
	sfx.play("leave")
	react_avatar("angry")
	float_text("LEFT! 😡", BBStyle.RED_D)
	toast("%s stormed off!" % order["name"])
	build_station.clear_plate()
	var t := get_tree().create_timer(0.5)
	t.timeout.connect(_after_resolve)


func _after_resolve() -> void:
	if not queue.is_empty():
		queue.pop_front()
	if queue.is_empty() and spawned_count < day_customers:
		spawn_timer = minf(spawn_timer, 0.7)
	render_active_order()
	_check_day_end()


func serve_order() -> void:
	if queue.is_empty() or queue[0]["resolved"] or build_station.build.is_empty():
		return
	var order: Dictionary = queue[0]
	order["resolved"] = true
	var res := BBData.score_build(build_station.build, order)

	var pay: float = maxf(0.0, order["base_pay"] * res["overall"])
	var tip := 0.0
	if res["stars"] == 3:
		tip = order["base_pay"] * 0.5 + (order["patience"] / order["patience_max"]) * 2.0
	elif res["stars"] == 2:
		tip = order["base_pay"] * 0.2
	tip = maxf(0.0, tip)
	pay = snappedf(pay + tip, 0.01)

	money += pay
	day_earnings += pay
	day_tips += tip
	score += res["points"]
	day_served += 1
	day_stars += res["stars"]
	if res["stars"] == 3:
		day_perfect += 1

	react_avatar(res["mood"])
	float_text(("+" if pay > 0.0 else "") + BBData.fmt_money(pay), Color("3a7a26") if pay > 0.0 else BBStyle.RED_D)
	toast("%s   %s%s" % [res["label"], "★".repeat(res["stars"]), "☆".repeat(3 - res["stars"])])
	if res["stars"] >= 2:
		sfx.play("ding")
		get_tree().create_timer(0.22).timeout.connect(func() -> void: sfx.play("cash"))
	elif res["stars"] == 1:
		sfx.play("cash")
	else:
		sfx.play("error")

	build_station.build = []
	build_station.render()
	get_tree().create_timer(0.52).timeout.connect(_after_resolve)


func _check_day_end() -> void:
	if spawned_count >= day_customers and queue.is_empty() and playing:
		end_day("clear")


func end_day(reason: String) -> void:
	if not playing:
		return
	playing = false
	sfx.stop_sizzle()
	best_day = maxf(best_day, day_earnings)

	# If this was a real work shift (launched by the burger manager), hand the
	# earnings + tips back to the main game. Tips here become real in-game tips.
	var work_launcher = get_node_or_null("/root/BurgerLauncher")
	if not Engine.is_editor_hint() and work_launcher and work_launcher.work_mode:
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("complete_burger_work_shift"):
			gs.complete_burger_work_shift(day_earnings, day_tips)
	var total := day_served + day_missed
	var acc := roundi(float(day_stars) / maxf(float(total * 3), 1.0) * 100.0)

	_result_layer = Control.new()
	_result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.z_index = 65
	_stage.add_child(_result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(dim)

	var rows := [
		["Burgers served", str(day_served), Color("4d8a32")],
		["Customers lost", str(day_missed), BBStyle.RED_D if day_missed > 0 else BBStyle.INK],
		["Perfect orders", "%d ★" % day_perfect, BBStyle.INK],
		["Kitchen rating", "%d%%" % acc, BBStyle.INK],
		["Today's earnings", BBData.fmt_money(day_earnings), Color("4d8a32")],
		["Best day ever", BBData.fmt_money(best_day), BBStyle.INK],
	]
	var card_h := 86.0 + rows.size() * 42.0 + 90.0
	var card := Control.new()
	card.position = (STAGE - Vector2(560, card_h)) / 2.0
	card.size = Vector2(560, card_h)
	_result_layer.add_child(card)
	card.add_child(BBStyle.shadow_panel(card.size, 10, 0))
	var cp := Panel.new()
	cp.size = card.size
	cp.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.PANEL, 4, BBStyle.INK))
	card.add_child(cp)
	var head := Panel.new()
	head.position = Vector2(4, 4)
	head.size = Vector2(552, 56)
	var hsb := BBStyle.flat(BBStyle.LINE)
	hsb.border_width_bottom = 4
	hsb.border_color = BBStyle.INK
	head.add_theme_stylebox_override("panel", hsb)
	card.add_child(head)
	var hl := BBStyle.label("TIME'S UP!" if reason == "time" else "DAY %d DONE" % day, BBStyle.px(20), BBStyle.CREAM)
	hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(hl)
	var y := 78.0
	for r in rows:
		var lbl := BBStyle.label(r[0], 19, BBStyle.INK)
		lbl.position = Vector2(26, y)
		card.add_child(lbl)
		var val := BBStyle.label(r[1], BBStyle.px(15), r[2])
		card.add_child(val)
		val.reset_size()
		val.position = Vector2(534.0 - val.size.x, y)
		var sep := ColorRect.new()
		sep.color = Color("c7b186")
		sep.position = Vector2(26, y + 32.0)
		sep.size = Vector2(508, 2)
		card.add_child(sep)
		y += 42.0
	y += 16.0
	# Single centered button. The "Next Day" button was removed — a new day only
	# comes from working your next shift back in the main game.
	var exit_text := "FINISH SHIFT" if (work_launcher and work_launcher.work_mode) else "EXIT"
	var tq := BBStyle.big_btn(exit_text, BBStyle.GREEN, Color.WHITE, Vector2(300, 44))
	tq.position = Vector2((card.size.x - 300.0) / 2.0, y)
	card.add_child(tq)
	(tq.get_meta("btn") as Button).pressed.connect(_exit_game)

	# entrance: scale up + fade (ease-out, 200ms)
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	sfx.play("star")


func _exit_game() -> void:
	var launcher := get_node_or_null("/root/BurgerLauncher")
	if launcher and launcher.has_method("close"):
		launcher.close()
	else:
		day = 1
		money = 0.0
		score = 0
		start_day()


# =========================================================== feedback

func toast(msg: String) -> void:
	if Engine.is_editor_hint():
		return
	var t := PanelContainer.new()
	var sb := BBStyle.flat(BBStyle.INK, 3, Color("0a0705"))
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 11.0
	sb.content_margin_bottom = 11.0
	t.add_theme_stylebox_override("panel", sb)
	t.add_child(BBStyle.label(msg, BBStyle.px(13), BBStyle.CREAM))
	t.z_index = 66
	_stage.add_child(t)
	t.reset_size()
	var final := Vector2((STAGE.x - t.size.x) / 2.0, 74.0)
	t.position = final + Vector2(0, -14)
	t.modulate.a = 0.0
	var tw := t.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(true)
	tw.tween_property(t, "position", final, 0.25)
	tw.tween_property(t, "modulate:a", 1.0, 0.25)
	tw.chain().tween_interval(1.5)
	tw.chain().set_ease(Tween.EASE_IN)
	tw.chain().tween_property(t, "position", final + Vector2(0, -14), 0.3)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(t.queue_free)


func float_text(text: String, color: Color) -> void:
	if Engine.is_editor_hint():
		return
	var f := BBStyle.label(text, BBStyle.px(16), color)
	f.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	f.add_theme_constant_override("shadow_offset_y", 2)
	f.z_index = 66
	f.position = Vector2(392, 162)
	_stage.add_child(f)
	f.pivot_offset = Vector2(40, 12)
	f.scale = Vector2(0.6, 0.6)
	f.modulate.a = 0.0
	var tw := f.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(true)
	tw.tween_property(f, "scale", Vector2(1.1, 1.1), 0.22)
	tw.tween_property(f, "modulate:a", 1.0, 0.22)
	tw.tween_property(f, "position:y", 156.0, 0.22)
	tw.chain().set_parallel(true)
	tw.tween_property(f, "scale", Vector2.ONE, 0.88)
	tw.tween_property(f, "position:y", 104.0, 0.88)
	tw.tween_property(f, "modulate:a", 0.0, 0.88)
	tw.chain().tween_callback(f.queue_free)


func _show_banner(text: String) -> void:
	if Engine.is_editor_hint():
		return
	_banner.text = text
	_banner.reset_size()
	_banner.pivot_offset = _banner.size / 2.0
	_banner.position = (STAGE - _banner.size) / 2.0 - Vector2(0, 30)
	_banner.scale = Vector2(0.4, 0.4)
	_banner.modulate.a = 0.0
	var base_y := _banner.position.y
	var tw := _banner.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(true)
	tw.tween_property(_banner, "scale", Vector2(1.05, 1.05), 0.27)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.27)
	tw.chain().tween_property(_banner, "scale", Vector2.ONE, 0.81)
	tw.chain().set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.42)
	tw.tween_property(_banner, "position:y", base_y - 55.0, 0.42)


func _toggle_mute() -> void:
	var m := sfx.toggle_mute()
	_mute_btn.text = "🔇 OFF" if m else "🔊 ON"


func _toggle_crt() -> void:
	_crt.visible = not _crt.visible
	_crt_btn.text = "CRT ON" if _crt.visible else "CRT OFF"


# =========================================================== loop / input

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not playing or paused:
		return
	var dt := minf(delta, 0.1)
	_flash_clock += dt
	day_time_left -= dt
	if not queue.is_empty() and not queue[0]["resolved"]:
		queue[0]["patience"] -= dt
		if queue[0]["patience"] <= 0.0:
			customer_leaves()
	spawn_timer -= dt
	if spawned_count < day_customers and queue.size() < 3 and spawn_timer <= 0.0:
		spawn_customer()
	grill_station.update(dt)
	if _grill_alert:
		_apply_tab_styles()
	_update_hud()
	if day_time_left <= 0.0:
		end_day("time")


func _update_hud() -> void:
	_chips["day"].text = str(day)
	_chips["time"].text = str(maxi(0, ceili(day_time_left)))
	_chips["cust"].text = "%d/%d" % [day_served + day_missed, day_customers]
	_chips["score"].text = str(score)
	_chips["money"].text = BBData.fmt_money(money)
	var frac := maxf(0.0, day_time_left) / day_length
	_daybar_fill.size.x = (_daybar_w - 6.0) * frac
	_daybar_fill.color = BBStyle.RED if frac < 0.25 else BBStyle.GREEN
	if _patience_fill and not queue.is_empty():
		var pf: float = clampf(queue[0]["patience"] / queue[0]["patience_max"], 0.0, 1.0)
		_patience_fill.size.x = _patience_w * pf
		_patience_fill.color = BBStyle.RED if pf < 0.25 else (BBStyle.YELLOW if pf < 0.5 else BBStyle.GREEN)


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not playing:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_TAB:
			set_tab("build" if tab == "grill" else "grill")
		KEY_G:
			set_tab("grill")
		KEY_B:
			set_tab("build")
		KEY_T:
			toggle_trash()
		KEY_SPACE:
			if not build_station.build.is_empty():
				serve_order()
		KEY_BACKSPACE, KEY_U:
			build_station.undo()
		KEY_A:
			grill_station.add_patty()
		KEY_Q:
			build_station.add_ingredient("bunBottom")
		KEY_E:
			build_station.add_ingredient("bunTop")
		KEY_1, KEY_KP_1:
			build_station.add_ingredient("cheese")
		KEY_2, KEY_KP_2:
			build_station.add_ingredient("lettuce")
		KEY_3, KEY_KP_3:
			build_station.add_ingredient("tomato")
		KEY_4, KEY_KP_4:
			build_station.add_ingredient("onion")
		KEY_5, KEY_KP_5:
			build_station.add_ingredient("pickle")
		KEY_6, KEY_KP_6:
			build_station.add_ingredient("ketchup")
		KEY_7, KEY_KP_7:
			build_station.add_ingredient("mustard")
		_:
			return
	get_viewport().set_input_as_handled()


# =========================================================== editor preview

func _populate_demo() -> void:
	day_customers = 1
	spawned_count = 3
	queue = [
		{
			"name": "Tito",
			"items": [
				{"type": "bunBottom"},
				{"type": "patty", "doneness": "Well"},
				{"type": "cheese"},
				{"type": "lettuce"},
				{"type": "bunTop"},
			],
			"avatar_seed": 1337,
			"base_pay": 6.8,
			"patience_max": 40.0,
			"patience": 38.0,
			"mood": "neutral",
			"resolved": false,
		},
		{"avatar_seed": 4242, "mood": "neutral"},
		{"avatar_seed": 9001, "mood": "neutral"},
	]
	render_active_order()
	_chips["time"].text = "90"
	if _patience_fill:
		_patience_fill.size.x = _patience_w * 0.95
