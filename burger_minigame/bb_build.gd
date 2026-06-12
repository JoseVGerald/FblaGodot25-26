@tool
class_name BBBuild
extends Control
## Burger Blitz — ASSEMBLE station: plate, ingredient bins, stack animations.

var game: Node = null  # BBGame

var build: Array = []  # [{type[,doneness,even_sear,seed]}]

var _plate_wrap: Control = null
var _stack_root: Control = null
var _hint: Label = null
var _bins: Dictionary = {}
var _serve_btn: Button = null
var _undo_btn: Button = null


func build_ui(panel_body: Control) -> void:
	var inner_w := panel_body.size.x - 24.0
	var area_h := panel_body.size.y - 24.0 - 49.0 - 12.0
	var plate_w := inner_w - 440.0 - 14.0

	# --- plate area ---
	_plate_wrap = Control.new()
	_plate_wrap.position = Vector2(12, 12)
	_plate_wrap.size = Vector2(plate_w, area_h)
	_plate_wrap.clip_contents = true
	panel_body.add_child(_plate_wrap)
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.colors = PackedColorArray([Color("f1ddb3"), Color("e6cd9a")])
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = grad
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_wrap.add_child(bg)
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 3.0
	ring.offset_top = 3.0
	ring.offset_right = -3.0
	ring.offset_bottom = -3.0
	var rsb := BBStyle.flat(Color.TRANSPARENT, 3, BBStyle.CREAM)
	rsb.draw_center = false
	ring.add_theme_stylebox_override("panel", rsb)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_wrap.add_child(ring)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fsb := BBStyle.flat(Color.TRANSPARENT, 3, BBStyle.INK, 6)
	fsb.draw_center = false
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_wrap.add_child(frame)

	_hint = BBStyle.label("Stack ingredients\nto match the ticket", 17, Color("b09a6c"))
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_wrap.add_child(_hint)

	var plate := BBPlate.new()
	plate.size = Vector2(230, 18)
	plate.scale = Vector2(1.25, 1.25)
	plate.pivot_offset = Vector2(115, 18)
	plate.position = Vector2((plate_w - 230.0) / 2.0, area_h - 3.0 - 18.0 - 4.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_wrap.add_child(plate)

	_stack_root = Control.new()
	_stack_root.position = Vector2(plate_w / 2.0, area_h - 3.0 - 22.0 - 10.0)
	_stack_root.scale = Vector2(1.25, 1.25)
	_stack_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_wrap.add_child(_stack_root)

	# --- bins ---
	var bins_x := 12.0 + plate_w + 14.0
	var bin_w := (440.0 - 9.0) / 2.0
	var i := 0
	for type in BBData.BIN_ORDER:
		var col := i % 2
		var row := i / 2
		var bin := _make_bin(type)
		bin.position = Vector2(bins_x + col * (bin_w + 9.0), 12.0 + row * 59.0)
		bin.size = Vector2(bin_w, 50)
		panel_body.add_child(bin)
		i += 1

	# --- action buttons ---
	var unit := (inner_w - 20.0) / 2.4
	var clear_w := snappedf(unit * 0.7, 1.0)
	var serve_w := inner_w - 20.0 - clear_w * 2.0
	var by := 12.0 + area_h + 12.0
	var cb := BBStyle.big_btn("CLEAR", BBStyle.RED, Color.WHITE, Vector2(clear_w, 44))
	cb.position = Vector2(12, by)
	panel_body.add_child(cb)
	(cb.get_meta("btn") as Button).pressed.connect(clear_plate)
	var ub := BBStyle.big_btn("UNDO", BBStyle.YELLOW, BBStyle.INK, Vector2(clear_w, 44))
	ub.position = Vector2(12 + clear_w + 10.0, by)
	panel_body.add_child(ub)
	_undo_btn = ub.get_meta("btn")
	_undo_btn.pressed.connect(undo)
	var sb := BBStyle.big_btn("SERVE  [SPACE]", BBStyle.GREEN, Color.WHITE, Vector2(serve_w, 44))
	sb.position = Vector2(12 + (clear_w + 10.0) * 2.0, by)
	panel_body.add_child(sb)
	_serve_btn = sb.get_meta("btn")
	_serve_btn.pressed.connect(func() -> void:
		if not build.is_empty():
			game.serve_order())
	render()


func _make_bin(type: String) -> Control:
	var wrap := Control.new()
	wrap.add_child(BBStyle.shadow_panel(Vector2(215, 50), 4))
	var p := Panel.new()
	p.size = Vector2(215, 50)
	p.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.CREAM, 3, BBStyle.INK))
	wrap.add_child(p)
	var key_bg := PanelContainer.new()
	var ksb := BBStyle.flat(BBStyle.INK, 0, BBStyle.INK, 2)
	ksb.content_margin_left = 5.0
	ksb.content_margin_right = 5.0
	ksb.content_margin_top = 4.0
	ksb.content_margin_bottom = 4.0
	key_bg.add_theme_stylebox_override("panel", ksb)
	key_bg.add_child(BBStyle.label(BBData.INGREDIENTS[type]["key"], BBStyle.px(9), BBStyle.YELLOW))
	p.add_child(key_bg)
	key_bg.reset_size()
	key_bg.position = Vector2(9, (50.0 - key_bg.size.y) / 2.0)

	var iconbox := Panel.new()
	iconbox.position = Vector2(34, 10)
	iconbox.size = Vector2(46, 30)
	iconbox.clip_contents = true
	iconbox.add_theme_stylebox_override("panel", BBStyle.flat(Color("fffaf0"), 2, BBStyle.LINE))
	p.add_child(iconbox)
	var slab := BBSlab.make(type)
	slab.scale = Vector2(0.3, 0.3)
	slab.position = Vector2(23.0 - slab.size.x * 0.15, 15.0 - slab.size.y * 0.15)
	iconbox.add_child(slab)

	var nm := BBStyle.label(BBData.INGREDIENTS[type]["name"], 17, BBStyle.INK)
	nm.position = Vector2(90, 0)
	nm.size = Vector2(120, 50)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(nm)

	var base_x := 0.0
	p.mouse_entered.connect(func() -> void: p.position.x = base_x + 3.0)
	p.mouse_exited.connect(func() -> void: p.position.x = base_x)
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			add_ingredient(type))
	_bins[type] = p
	return wrap


func reset() -> void:
	build = []
	render()


func add_ingredient(type: String) -> void:
	if type == "bunBottom" and not build.is_empty():
		game.toast("Bottom bun goes first!")
		game.sfx.play("error")
		return
	if game.tab != "build":
		game.set_tab("build")
	build.append({"type": type})
	game.sfx.play_add(build.size())
	_flash_bin(type)
	render(true)


func add_ready_patty(idx: int) -> void:
	var grill: BBGrill = game.grill_station
	if idx >= grill.ready_patties.size():
		return
	var rp: Dictionary = grill.ready_patties[idx]
	build.append({"type": "patty", "doneness": rp["doneness"], "even_sear": rp["even_sear"], "seed": rp["seed"]})
	grill.ready_patties.remove_at(idx)
	game.sfx.play_add(build.size())
	if game.tab != "build":
		game.set_tab("build")
	grill.render_tray()
	render(true)


func undo() -> void:
	if build.is_empty():
		return
	var removed: Dictionary = build.pop_back()
	if removed["type"] == "patty":
		game.grill_station.ready_patties.append({"doneness": removed["doneness"], "even_sear": removed["even_sear"], "seed": removed["seed"]})
		game.grill_station.render_tray()
	game.sfx.play("click")
	render()


func clear_plate() -> void:
	for b in build:
		if b["type"] == "patty":
			game.grill_station.ready_patties.append({"doneness": b["doneness"], "even_sear": b["even_sear"], "seed": b["seed"]})
	build = []
	game.grill_station.render_tray()
	game.sfx.play("click")
	render()


func _flash_bin(type: String) -> void:
	var bin: Panel = _bins.get(type)
	if bin == null:
		return
	bin.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.YELLOW, 3, BBStyle.INK))
	var t := get_tree().create_timer(0.11)
	t.timeout.connect(func() -> void:
		if is_instance_valid(bin):
			bin.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.CREAM, 3, BBStyle.INK)))


func render(animate_top: bool = false) -> void:
	if _stack_root == null:
		return
	for c in _stack_root.get_children():
		c.queue_free()
	var y := 0.0
	var top_slab: BBSlab = null
	var top_type := ""
	for i in range(build.size()):
		var b: Dictionary = build[i]
		var slab := BBSlab.make(b["type"], b)
		slab.position = Vector2(-slab.size.x / 2.0, y - slab.size.y)
		_stack_root.add_child(slab)
		y -= (slab.size.y - 3.0)
		if i == build.size() - 1:
			top_slab = slab
			top_type = b["type"]
	if _hint:
		_hint.visible = build.is_empty()
	if _serve_btn:
		_serve_btn.disabled = build.is_empty()
	if _undo_btn:
		_undo_btn.disabled = build.is_empty()
	if animate_top and top_slab != null and not Engine.is_editor_hint():
		_drop_in(top_slab)
		_thud()
		var ct := get_tree().create_timer(0.11)
		ct.timeout.connect(_spawn_crumbs.bind(top_slab, top_type))


## reference dropin keyframes: 340ms overshoot squash (cubic-bezier(.22,1.4,.36,1))
func _drop_in(slab: BBSlab) -> void:
	slab.pivot_offset = Vector2(slab.size.x / 2.0, slab.size.y)
	var rest := slab.position.y
	slab.position.y = rest - 110.0
	slab.scale = Vector2(0.92, 1.06)
	slab.modulate.a = 0.0
	var tw := slab.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(slab, "position:y", rest, 0.153)
	tw.parallel().tween_property(slab, "scale", Vector2(1.06, 0.82), 0.153)
	tw.parallel().tween_property(slab, "modulate:a", 1.0, 0.1)
	tw.tween_property(slab, "position:y", rest - 7.0, 0.085)
	tw.parallel().tween_property(slab, "scale", Vector2(0.97, 1.05), 0.085)
	tw.tween_property(slab, "position:y", rest, 0.102)
	tw.parallel().tween_property(slab, "scale", Vector2.ONE, 0.102)


func _thud() -> void:
	var base := _stack_root.position.y
	var tw := _stack_root.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_stack_root, "scale", Vector2(1.25, 1.175), 0.078)
	tw.parallel().tween_property(_stack_root, "position:y", base + 3.0, 0.078)
	tw.tween_property(_stack_root, "scale", Vector2(1.25, 1.25), 0.182)
	tw.parallel().tween_property(_stack_root, "position:y", base, 0.182)


func _spawn_crumbs(slab, type: String) -> void:
	if slab == null or not is_instance_valid(slab) or _plate_wrap == null:
		return
	var colors: Array = BBData.CRUMB_COLORS.get(type, [Color("caa978")])
	var origin: Vector2 = _stack_root.position + (slab.position + Vector2(0, slab.size.y * 0.4)) * 1.25
	for i in range(6):
		var c := ColorRect.new()
		c.color = colors[i % colors.size()]
		c.size = Vector2(7, 7)
		c.position = origin + Vector2(randf() * slab.size.x * 1.25, 0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate_wrap.add_child(c)
		var dx := randf_range(-35.0, 35.0)
		var dy := -randf_range(20.0, 65.0)
		var tw := c.create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.set_parallel(true)
		tw.tween_property(c, "position", c.position + Vector2(dx, dy), 0.45)
		tw.tween_property(c, "scale", Vector2(0.4, 0.4), 0.45)
		tw.tween_property(c, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(c.queue_free)
