@tool
class_name BBGrill
extends Control
## Burger Blitz — GRILL station: 4 cook slots + the shared ready tray.

const SLOTS := 4

var game: Node = null       # BBGame
var tray_grid: Control = null

var slots: Array = [null, null, null, null]
var ready_patties: Array = []       # [{doneness, even_sear, seed}]

var _surface: BBGrillSurface = null
var _slot_nodes: Array = []
var _slot_w := 0.0
var _slot_h := 0.0
var _sizzle_clock := 0.0


func build(panel_body: Control) -> void:
	var inner_w := panel_body.size.x
	var inner_h := panel_body.size.y
	_surface = BBGrillSurface.new()
	_surface.position = Vector2(12, 12)
	_surface.size = Vector2(inner_w - 24, inner_h - 24 - 49 - 12)
	panel_body.add_child(_surface)

	_slot_w = (_surface.size.x - 28.0 - 42.0) / 4.0
	_slot_h = _surface.size.y - 28.0
	for i in range(SLOTS):
		var holder := Control.new()
		holder.position = Vector2(14.0 + i * (_slot_w + 14.0), 14.0)
		holder.size = Vector2(_slot_w, _slot_h)
		_surface.add_child(holder)
		_slot_nodes.append(holder)
		_render_slot(i)

	var btn := BBStyle.big_btn("+ RAW PATTY  [A]", BBStyle.YELLOW, BBStyle.INK, Vector2(inner_w - 24, 44))
	btn.position = Vector2(12, 12 + _surface.size.y + 12)
	panel_body.add_child(btn)
	(btn.get_meta("btn") as Button).pressed.connect(add_patty)

	render_tray()


func reset() -> void:
	slots = [null, null, null, null]
	ready_patties = []
	for i in range(SLOTS):
		_render_slot(i)
	render_tray()
	if game and game.sfx:
		game.sfx.stop_sizzle()


func free_slot() -> int:
	for i in range(SLOTS):
		if slots[i] == null:
			return i
	return -1


func add_patty() -> void:
	var i := free_slot()
	if i < 0:
		game.toast("Grill is full!")
		game.sfx.play("error")
		return
	if game.tab != "grill":
		game.set_tab("grill")
	slots[i] = {"cook": 0.0, "flipped": false, "even_sear": false, "seed": randi()}
	game.sfx.play("place")
	game.sfx.start_sizzle()
	_render_slot(i)


func flip(i: int) -> void:
	var p = slots[i]
	if p == null:
		return
	p["flipped"] = true
	if p["cook"] >= 40.0 and p["cook"] <= 80.0:
		p["even_sear"] = true
	game.sfx.play("flip")
	var nodes: Dictionary = _slot_nodes[i].get_meta("nodes", {})
	if nodes.has("patty"):
		var patty: Control = nodes["patty"]
		var fb: Button = nodes["flip_btn"]
		fb.text = "FLIP✓"
		# squash flip: 280ms, ease-out (matches reference flipa keyframes)
		patty.pivot_offset = patty.size / 2.0
		var tw: Tween = patty.create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(patty, "scale:y", 0.25, 0.14)
		tw.parallel().tween_property(patty, "position:y", patty.position.y - 10.0, 0.14)
		tw.tween_property(patty, "scale:y", 1.0, 0.14)
		tw.parallel().tween_property(patty, "position:y", patty.position.y, 0.14)


func pull(i: int) -> void:
	var p = slots[i]
	if p == null:
		return
	var dn := BBData.doneness_from_cook(p["cook"])
	if dn == "Raw":
		game.toast("Too raw!")
		game.sfx.play("error")
		return
	ready_patties.append({"doneness": dn, "even_sear": p["even_sear"], "seed": p["seed"]})
	slots[i] = null
	game.sfx.play("burn" if dn == "Burnt" else "pull")
	if not _any_cooking():
		game.sfx.stop_sizzle()
	_render_slot(i)
	render_tray()


func trash_slot(i: int) -> void:
	if slots[i] == null:
		return
	slots[i] = null
	game.sfx.play("trash")
	if not _any_cooking():
		game.sfx.stop_sizzle()
	_render_slot(i)


func trash_ready(idx: int) -> void:
	if idx >= ready_patties.size():
		return
	ready_patties.remove_at(idx)
	game.sfx.play("trash")
	render_tray()


func _any_cooking() -> bool:
	for s in slots:
		if s != null:
			return true
	return false


func update(dt: float) -> void:
	var any := false
	var danger := false
	_sizzle_clock += dt
	var glow_on := fmod(_sizzle_clock, 0.5) < 0.25
	for i in range(SLOTS):
		var p = slots[i]
		if p == null:
			continue
		any = true
		p["cook"] = minf(BBData.COOK_MAX, p["cook"] + dt * BBData.COOK_RATE)
		if p["cook"] >= 96.0:
			danger = true
		_update_slot_live(i, p, glow_on)
	if not any:
		game.sfx.stop_sizzle()
	game.set_grill_alert(danger and game.tab != "grill")


func _update_slot_live(i: int, p: Dictionary, glow_on: bool) -> void:
	var nodes: Dictionary = _slot_nodes[i].get_meta("nodes", {})
	if nodes.is_empty():
		return
	var dn := BBData.doneness_from_cook(p["cook"])
	if nodes["dn"] != dn:
		nodes["dn"] = dn
		var tex := BBPix.patty_texture(dn, 27, 9, p["seed"])
		(nodes["patty_img"] as TextureRect).texture = tex
		(nodes["glow"] as TextureRect).texture = tex
		(nodes["label"] as Label).text = dn.to_upper()
		(nodes["pull_btn"] as Button).disabled = (dn == "Raw")
	(nodes["needle"] as Control).position.x = p["cook"] / BBData.COOK_MAX * 150.0 - 2.5
	(nodes["glow"] as TextureRect).visible = glow_on
	var burning := dn == "Burnt"
	(nodes["burn_flash"] as Control).visible = burning and glow_on


func _render_slot(i: int) -> void:
	var holder: Control = _slot_nodes[i]
	for c in holder.get_children():
		c.queue_free()
	holder.remove_meta("nodes")
	var p = slots[i]
	if p == null:
		var dashed := BBDashedRect.new()
		dashed.size = holder.size
		holder.add_child(dashed)
		var l := BBStyle.label("empty", 15, Color(0.49, 0.478, 0.447, 0.6))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(l)
		return

	# occupied slot: solid frame + darker pit
	var pit := Panel.new()
	pit.size = holder.size
	pit.add_theme_stylebox_override("panel", BBStyle.flat(Color(0, 0, 0, 0.25), 3, BBStyle.EDGE, 6))
	holder.add_child(pit)
	var burn_flash := Panel.new()
	burn_flash.size = holder.size
	var bsb := BBStyle.flat(Color.TRANSPARENT, 3, BBStyle.RED, 6)
	bsb.draw_center = false
	burn_flash.add_theme_stylebox_override("panel", bsb)
	burn_flash.visible = false
	burn_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(burn_flash)

	var dn := BBData.doneness_from_cook(p["cook"])
	var tex := BBPix.patty_texture(dn, 27, 9, p["seed"])
	var cy := (holder.size.y - 188.0) / 2.0

	var patty_holder := Control.new()
	patty_holder.position = Vector2((holder.size.x - 135.0) / 2.0, cy)
	patty_holder.size = Vector2(135, 45)
	holder.add_child(patty_holder)
	var glow := BBPix.tex_rect(tex, Vector2(135, 45))
	glow.modulate = Color(1.0, 0.7, 0.3, 0.5)
	glow.position = Vector2(0, 2)
	glow.scale = Vector2(1.06, 1.15)
	glow.pivot_offset = glow.size / 2.0
	patty_holder.add_child(glow)
	var img := BBPix.tex_rect(tex, Vector2(135, 45))
	patty_holder.add_child(img)

	var bar := Panel.new()
	bar.position = Vector2((holder.size.x - 150.0) / 2.0, cy + 45.0 + 14.0)
	bar.size = Vector2(150, 18)
	bar.add_theme_stylebox_override("panel", BBStyle.flat(Color("cccccc"), 2, BBStyle.INK))
	holder.add_child(bar)
	var zx := 2.0
	for z in BBData.COOK_ZONES:
		var zw: float = (z[2] - z[1]) / BBData.COOK_MAX * 146.0
		var zr := ColorRect.new()
		zr.color = z[3]
		zr.position = Vector2(zx, 2)
		zr.size = Vector2(zw, 14)
		zr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(zr)
		zx += zw
	var needle := Control.new()
	needle.position = Vector2(p["cook"] / BBData.COOK_MAX * 150.0 - 2.5, -3)
	needle.size = Vector2(5, 24)
	var nb := ColorRect.new()
	nb.color = Color.BLACK
	nb.size = Vector2(5, 24)
	needle.add_child(nb)
	var nw := ColorRect.new()
	nw.color = Color.WHITE
	nw.position = Vector2(1, 1)
	nw.size = Vector2(3, 22)
	needle.add_child(nw)
	bar.add_child(needle)

	var lbl_bg := PanelContainer.new()
	var lsb := BBStyle.flat(BBStyle.INK)
	lsb.content_margin_left = 5.0
	lsb.content_margin_right = 5.0
	lsb.content_margin_top = 2.0
	lsb.content_margin_bottom = 2.0
	lbl_bg.add_theme_stylebox_override("panel", lsb)
	var lbl := BBStyle.label(dn.to_upper(), BBStyle.px(8), BBStyle.CREAM)
	lbl_bg.add_child(lbl)
	holder.add_child(lbl_bg)
	lbl_bg.reset_size()
	lbl_bg.position = Vector2((holder.size.x - lbl_bg.size.x) / 2.0, cy + 45.0 + 14.0 + 18.0 + 11.0)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	holder.add_child(btns)
	var fb := BBStyle.mini_btn("FLIP✓" if p["flipped"] else "FLIP", BBStyle.BLUE, Vector2(62, 26))
	var pb := BBStyle.mini_btn("PULL", BBStyle.GREEN, Vector2(62, 26))
	var tb := BBStyle.mini_btn("✕", Color("8a3b30"), Vector2(32, 26))
	btns.add_child(fb)
	btns.add_child(pb)
	btns.add_child(tb)
	btns.reset_size()
	btns.position = Vector2((holder.size.x - btns.size.x) / 2.0, cy + 45.0 + 14.0 + 18.0 + 11.0 + 24.0 + 11.0)
	var flip_btn: Button = fb.get_meta("btn")
	var pull_btn: Button = pb.get_meta("btn")
	var trash_btn: Button = tb.get_meta("btn")
	pull_btn.disabled = (dn == "Raw")
	flip_btn.pressed.connect(flip.bind(i))
	pull_btn.pressed.connect(pull.bind(i))
	trash_btn.pressed.connect(trash_slot.bind(i))

	holder.set_meta("nodes", {
		"dn": dn, "patty": patty_holder, "patty_img": img, "glow": glow,
		"needle": needle, "label": lbl, "pull_btn": pull_btn,
		"flip_btn": flip_btn, "burn_flash": burn_flash,
	})


# ---------- ready tray ----------

func render_tray() -> void:
	if tray_grid == null:
		return
	for c in tray_grid.get_children():
		c.queue_free()
	if ready_patties.is_empty():
		var l := BBStyle.label("cooked patties land here → click to stack", 16, Color("9a865f"))
		l.position = Vector2(12, 0)
		l.size = Vector2(tray_grid.size.x - 24, tray_grid.size.y)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tray_grid.add_child(l)
		return
	var x := 12.0
	for idx in range(ready_patties.size()):
		var rp: Dictionary = ready_patties[idx]
		var item := Control.new()
		item.position = Vector2(x, (tray_grid.size.y - 32.0) / 2.0)
		item.size = Vector2(72, 32)
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		tray_grid.add_child(item)
		var img := BBPix.tex_rect(BBPix.patty_texture(rp["doneness"], 18, 8, rp["seed"]), Vector2(72, 32))
		item.add_child(img)
		var dn := BBStyle.label(str(rp["doneness"]).to_upper(), BBStyle.px(7), Color.WHITE)
		dn.set_anchors_preset(Control.PRESET_FULL_RECT)
		dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dn.add_theme_constant_override("shadow_offset_y", 1)
		dn.add_theme_color_override("font_shadow_color", Color.BLACK)
		dn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(dn)
		var base_y := item.position.y
		item.mouse_entered.connect(func() -> void: item.position.y = base_y - 3.0)
		item.mouse_exited.connect(func() -> void: item.position.y = base_y)
		item.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_RIGHT or game.trash_mode:
					trash_ready(idx)
				elif ev.button_index == MOUSE_BUTTON_LEFT:
					game.build_station.add_ready_patty(idx))
		if game and game.trash_mode:
			item.pivot_offset = item.size / 2.0
			var tw: Tween = item.create_tween()
			tw.set_loops()
			tw.tween_property(item, "rotation_degrees", 3.0, 0.175)
			tw.tween_property(item, "rotation_degrees", -3.0, 0.175)
		x += 82.0
