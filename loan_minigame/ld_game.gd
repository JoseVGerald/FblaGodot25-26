@tool
class_name LDGame
extends Control
## Bank Blitz — Loan Decision Desk. Builds the whole 1280x720 stage in code
## (also at editor time, so opening LoanDesk.tscn previews the real UI).
## Reuses the Burger Blitz art/style/sfx helpers (BBStyle / BBPix / BBSfx / BBCrt).

const STAGE := Vector2(1280, 720)
const START_CAPITAL := 6000.0

# ---- run state (port of bank/game.js S) ----
var playing := false
var paused := false
var help_open := false
var deciding := false
var day := 1
var capital := START_CAPITAL
var score := 0
var streak := 0
var day_length := 100.0
var day_time_left := 100.0
var day_applicants := 6
var spawned_count := 0
var spawn_interval := 7.0
var spawn_timer := 0.0
var queue: Array = []
var day_approved := 0
var day_denied := 0
var day_correct := 0
var day_wrong := 0
var day_missed := 0
var day_defaults := 0
var day_profit := 0.0
var best_capital := START_CAPITAL
# player pay (the bank's capital is the in-game economy; the player earns commission)
var day_pay := 0.0
var day_bonus := 0.0

# ---- modules ----
var sfx: BBSfx = null

# ---- nodes ----
var _stage: Control = null
var _chips: Dictionary = {}
var _daybar_fill: ColorRect = null
var _daybar_w := 220.0
var _applicant_box: Control = null
var _queue_strip: Control = null
var _patience_fill: ColorRect = null
var _patience_w := 0.0
var _tally_approved: Label = null
var _tally_denied: Label = null
var _appfile: Panel = null
var _appfile_body: Control = null
var _appfile_num: Label = null
var _stamp: Label = null
var _btn_approve: Button = null
var _btn_deny: Button = null
var _crt: BBCrt = null
var _crt_btn: Button = null
var _mute_btn: Button = null
var _policy_btn: Button = null
var _policy_layer: Control = null
var _result_layer: Control = null
var _banner: Label = null

var _flash_clock := 0.0


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

	_build_hud()
	_build_window_panel()
	_build_main_panel()

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

	# left: an APPLICATION tab badge (purely cosmetic, mirrors the reference)
	var tab := PanelContainer.new()
	var tsb := BBStyle.flat(BBStyle.PANEL)
	tsb.border_width_bottom = 6
	tsb.border_color = BBStyle.YELLOW
	tsb.content_margin_left = 16.0
	tsb.content_margin_right = 16.0
	tab.add_theme_stylebox_override("panel", tsb)
	tab.add_child(BBStyle.label("📋 APPLICATION", BBStyle.px(11), BBStyle.INK))
	_stage.add_child(tab)
	tab.position = Vector2(0, 0)
	tab.size = Vector2(0, 62)
	tab.reset_size()
	tab.size.y = 62

	var x := tab.size.x + 14.0
	for c in [["day", "DAY", "1"], ["time", "SEC", "100"]]:
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

	var done_chip := BBStyle.chip("DONE", "0/6")
	_stage.add_child(done_chip)
	done_chip.reset_size()
	done_chip.position = Vector2(x, (62.0 - done_chip.size.y) / 2.0)
	_chips["done"] = done_chip.get_meta("val")

	# right side, laid right-to-left
	var rx := STAGE.x - 14.0
	_policy_btn = _place_right(_icon_btn("? POLICY"), rx)
	rx = _policy_btn.get_parent().position.x - 10.0
	_policy_btn.pressed.connect(toggle_policy)
	_crt_btn = _place_right(_icon_btn("CRT ON"), rx)
	rx = _crt_btn.get_parent().position.x - 10.0
	_crt_btn.pressed.connect(_toggle_crt)
	_mute_btn = _place_right(_icon_btn("🔊 ON"), rx)
	rx = _mute_btn.get_parent().position.x - 10.0
	var cap_chip := BBStyle.chip("CAPITAL", "$6,000", BBStyle.GREEN)
	_stage.add_child(cap_chip)
	cap_chip.reset_size()
	cap_chip.position = Vector2(rx - cap_chip.size.x, (62.0 - cap_chip.size.y) / 2.0)
	_chips["capital"] = cap_chip.get_meta("val")
	rx = cap_chip.position.x - 10.0
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


func _build_window_panel() -> void:
	var panel := BBStyle.framed_panel(Rect2(14, 80, 300, 626), "AT THE WINDOW", "who's next")
	_stage.add_child(panel)
	var body: Control = panel.get_meta("body")

	_applicant_box = Control.new()
	_applicant_box.position = Vector2(12, 12)
	_applicant_box.size = Vector2(body.size.x - 24.0, 96)
	body.add_child(_applicant_box)

	var line_lbl := BBStyle.label("▾ IN LINE", BBStyle.px(9), BBStyle.LINE)
	line_lbl.position = Vector2(12, 120)
	body.add_child(line_lbl)

	_queue_strip = Control.new()
	_queue_strip.position = Vector2(12, 142)
	_queue_strip.size = Vector2(body.size.x - 24.0, 40)
	body.add_child(_queue_strip)

	# tally pinned near the bottom
	var tally_y := body.size.y - 96.0
	_tally_approved = _build_tally(body, 12.0, tally_y, (body.size.x - 24.0 - 8.0) / 2.0, "APPROVED", BBStyle.GREEN_D)
	_tally_denied = _build_tally(body, 12.0 + (body.size.x - 24.0 - 8.0) / 2.0 + 8.0, tally_y, (body.size.x - 24.0 - 8.0) / 2.0, "DENIED", BBStyle.RED_D)


func _build_tally(parent: Control, x: float, y: float, w: float, label_text: String, accent: Color) -> Label:
	var card := Panel.new()
	card.position = Vector2(x, y)
	card.size = Vector2(w, 84)
	card.add_theme_stylebox_override("panel", BBStyle.flat(Color("fffbee"), 3, BBStyle.INK))
	parent.add_child(card)
	var n := BBStyle.label("0", BBStyle.px(22), accent)
	n.position = Vector2(0, 12)
	n.size = Vector2(w, 40)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(n)
	var k := BBStyle.label(label_text, BBStyle.px(9), BBStyle.INK)
	k.position = Vector2(0, 56)
	k.size = Vector2(w, 20)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(k)
	return n


func _build_main_panel() -> void:
	var panel := BBStyle.framed_panel(Rect2(328, 80, 938, 626), "LOAN APPLICATION", "[A]pprove · [D]eny · [?] policy")
	_stage.add_child(panel)
	var body: Control = panel.get_meta("body")

	var pad := 14.0
	var decide_h := 64.0
	# the application file (cream paper) fills the panel above the decide row
	var file_w := body.size.x - pad * 2.0
	var file_h := body.size.y - pad * 2.0 - decide_h - 10.0

	var file_root := Control.new()
	file_root.position = Vector2(pad, pad)
	file_root.size = Vector2(file_w, file_h)
	body.add_child(file_root)

	_appfile = Panel.new()
	_appfile.size = Vector2(file_w, file_h)
	_appfile.add_theme_stylebox_override("panel", BBStyle.flat(Color("fffbee"), 3, BBStyle.INK))
	file_root.add_child(_appfile)

	# appfile header bar
	var head := Panel.new()
	head.size = Vector2(file_w, 34)
	var hsb := BBStyle.flat(BBStyle.LINE)
	head.add_theme_stylebox_override("panel", hsb)
	_appfile.add_child(head)
	var ht := BBStyle.label("FIRST FEDERAL SAVINGS & LOAN", BBStyle.px(11), BBStyle.CREAM)
	ht.position = Vector2(12, 0)
	ht.size = Vector2(file_w - 120.0, 34)
	ht.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(ht)
	_appfile_num = BBStyle.label("#00000", BBStyle.px(10), BBStyle.YELLOW)
	_appfile_num.position = Vector2(file_w - 120.0, 0)
	_appfile_num.size = Vector2(108, 34)
	_appfile_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_appfile_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_appfile_num)

	_appfile_body = Control.new()
	_appfile_body.position = Vector2(0, 34)
	_appfile_body.size = Vector2(file_w, file_h - 34.0)
	_appfile.add_child(_appfile_body)

	# the slam stamp, centered over the file
	_stamp = BBStyle.label("", BBStyle.px(34), BBStyle.GREEN_D)
	_stamp.z_index = 10
	_stamp.visible = false
	file_root.add_child(_stamp)

	# decide row
	var by := body.size.y - pad - decide_h
	var gap := 14.0
	var btn_w := (body.size.x - pad * 2.0 - gap) / 2.0
	var deny_wrap := BBStyle.big_btn("✕  DENY   [D / ←]", BBStyle.RED, Color.WHITE, Vector2(btn_w, decide_h - 5.0), BBStyle.px(13))
	deny_wrap.position = Vector2(pad, by)
	body.add_child(deny_wrap)
	_btn_deny = deny_wrap.get_meta("btn")
	_btn_deny.pressed.connect(decide.bind("deny"))
	var app_wrap := BBStyle.big_btn("✓  APPROVE   [A / →]", BBStyle.GREEN, Color.WHITE, Vector2(btn_w, decide_h - 5.0), BBStyle.px(13))
	app_wrap.position = Vector2(pad + btn_w + gap, by)
	body.add_child(app_wrap)
	_btn_approve = app_wrap.get_meta("btn")
	_btn_approve.pressed.connect(decide.bind("approve"))


# =========================================================== run / day

func start_day() -> void:
	playing = true
	paused = false
	deciding = false
	help_open = false
	day_length = 100.0
	day_time_left = day_length
	day_applicants = 5 + day
	spawned_count = 0
	spawn_interval = maxf(4.5, 7.0 - day * 0.3)
	spawn_timer = 0.0
	queue = []
	day_approved = 0
	day_denied = 0
	day_correct = 0
	day_wrong = 0
	day_missed = 0
	day_defaults = 0
	day_profit = 0.0
	day_pay = 0.0
	day_bonus = 0.0
	if _policy_layer:
		_policy_layer.queue_free()
		_policy_layer = null
	if _result_layer:
		_result_layer.queue_free()
		_result_layer = null
	_show_banner("DAY %d" % day)
	spawn_applicant()
	render_active()
	_update_hud()
	if sfx:
		sfx.play("start")


func next_day() -> void:
	day += 1
	start_day()


func spawn_applicant() -> void:
	if spawned_count >= day_applicants:
		return
	queue.append(LDData.generate_application(day))
	spawned_count += 1
	spawn_timer = spawn_interval
	if queue.size() == 1:
		render_active()
	else:
		_render_queue_strip()


# =========================================================== render

func render_active() -> void:
	_render_window_box()
	render_application(queue[0] if not queue.is_empty() else {})
	_render_queue_strip()
	_render_tally()


func _render_window_box() -> void:
	for c in _applicant_box.get_children():
		c.queue_free()
	_patience_fill = null
	if queue.is_empty():
		var l := BBStyle.label("Window closed…", 16, Color("9a865f"))
		l.position = Vector2(4, 8)
		_applicant_box.add_child(l)
		return
	var app: Dictionary = queue[0]
	var av := _make_avatar(app["avatar_seed"], app["mood"], 62.0)
	av.position = Vector2(0, 0)
	_applicant_box.add_child(av)
	var nm := BBStyle.label(str(app["name"]), BBStyle.px(11), BBStyle.INK)
	nm.position = Vector2(74, 6)
	_applicant_box.add_child(nm)
	var oc := BBStyle.label(str(app["occupation"]), 15, Color("6a5a3a"))
	oc.position = Vector2(74, 32)
	_applicant_box.add_child(oc)
	var pat := Panel.new()
	pat.position = Vector2(74, 60)
	pat.size = Vector2(_applicant_box.size.x - 74.0, 13)
	pat.add_theme_stylebox_override("panel", BBStyle.flat(Color("d8c49a"), 2, BBStyle.INK))
	_applicant_box.add_child(pat)
	_patience_fill = ColorRect.new()
	_patience_fill.color = BBStyle.GREEN
	_patience_fill.position = Vector2(2, 2)
	_patience_fill.size = Vector2(pat.size.x - 4.0, 9)
	pat.add_child(_patience_fill)
	_patience_w = pat.size.x - 4.0


func _render_queue_strip() -> void:
	for c in _queue_strip.get_children():
		c.queue_free()
	var x := 0.0
	for o in queue.slice(1, 4):
		var av := _make_avatar(o["avatar_seed"], "neutral", 38.0)
		av.position = Vector2(x, 0)
		_queue_strip.add_child(av)
		x += 44.0
	var remaining: int = day_applicants - spawned_count + maxi(0, queue.size() - 4)
	if remaining > 0:
		var more := BBStyle.label("+%d" % remaining, 16, BBStyle.LINE)
		more.position = Vector2(x + 2.0, 8)
		_queue_strip.add_child(more)


func _render_tally() -> void:
	_tally_approved.text = str(day_approved)
	_tally_denied.text = str(day_denied)


func render_application(app: Dictionary) -> void:
	for c in _appfile_body.get_children():
		c.queue_free()
	if app.is_empty():
		_appfile_num.text = "#----"
		_btn_approve.disabled = true
		_btn_deny.disabled = true
		var l := BBStyle.label("No application at the window.", 18, Color("9a8c63"))
		l.position = Vector2(20, 24)
		_appfile_body.add_child(l)
		return
	_btn_approve.disabled = false
	_btn_deny.disabled = false
	_appfile_num.text = "#%05d" % (int(app["avatar_seed"]) % 100000)

	var w := _appfile_body.size.x
	var pad := 18.0
	var inner := w - pad * 2.0
	var y := 14.0

	# --- app-id row: avatar + name/occupation + REQUESTS ---
	var av := _make_avatar(app["avatar_seed"], app["mood"], 54.0)
	av.position = Vector2(pad, y)
	_appfile_body.add_child(av)
	var nm := BBStyle.label(str(app["name"]), BBStyle.px(13), BBStyle.INK)
	nm.position = Vector2(pad + 66.0, y + 4.0)
	_appfile_body.add_child(nm)
	var oc := BBStyle.label(str(app["occupation"]), 16, Color("6a5a3a"))
	oc.position = Vector2(pad + 66.0, y + 32.0)
	_appfile_body.add_child(oc)
	var ask := Panel.new()
	ask.position = Vector2(w - pad - 230.0, y)
	ask.size = Vector2(230, 56)
	ask.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.PANEL2, 3, BBStyle.INK))
	_appfile_body.add_child(ask)
	var ask_k := BBStyle.label("REQUESTS", BBStyle.px(8), BBStyle.LINE)
	ask_k.position = Vector2(12, 8)
	ask.add_child(ask_k)
	var ask_v := BBStyle.label(LDData.fmt_money(app["amount"]), BBStyle.px(16), BBStyle.RED_D)
	ask_v.position = Vector2(12, 26)
	ask.add_child(ask_v)
	y += 70.0

	# --- stat grid: 3 columns x 2 rows ---
	var gap := 10.0
	var cell_w := (inner - gap * 2.0) / 3.0
	var cell_h := 54.0
	var coll := "none — unsecured"
	if str(app["collateral_label"]) != "":
		coll = "%s · %s" % [app["collateral_label"], LDData.fmt_money(app["collateral_value"])]
	var stats := [
		["MONTHLY INCOME", LDData.fmt_money(app["income"])],
		["EXISTING DEBT /mo", LDData.fmt_money(app["debt"])],
		["CREDIT SCORE", str(app["credit_score"])],
		["LOAN TERM", "%d mo" % int(app["term"])],
		["EST. PAYMENT /mo", LDData.fmt_money(app["payment"])],
		["COLLATERAL", coll],
	]
	for i in range(stats.size()):
		var col := i % 3
		var row := i / 3
		_stat_cell(pad + col * (cell_w + gap), y + row * (cell_h + gap), cell_w, cell_h, stats[i][0], stats[i][1])
	y += cell_h * 2.0 + gap + 14.0

	# --- purpose row ---
	var purp := Panel.new()
	purp.position = Vector2(pad, y)
	purp.size = Vector2(inner, 56)
	purp.add_theme_stylebox_override("panel", BBStyle.flat(Color("fff4d8"), 3, BBStyle.INK))
	_appfile_body.add_child(purp)
	var pk := BBStyle.label("PURPOSE OF LOAN", BBStyle.px(8), BBStyle.LINE)
	pk.position = Vector2(12, 8)
	purp.add_child(pk)
	var pv := BBStyle.label(str(app["purpose"]), 18, BBStyle.INK)
	pv.position = Vector2(12, 26)
	purp.add_child(pv)
	var tag_x := inner - 12.0
	var sec_tag := _tag("SECURED" if app["secured"] else "UNSECURED", BBStyle.INK if app["secured"] else Color("8a7a5a"))
	purp.add_child(sec_tag)
	sec_tag.reset_size()
	sec_tag.position = Vector2(tag_x - sec_tag.size.x, 14)
	tag_x -= sec_tag.size.x + 8.0
	var purpose_tag := _tag("SPECULATIVE" if app["purpose_banned"] else "PRODUCTIVE",
		BBStyle.RED_D if app["purpose_banned"] else BBStyle.GREEN_D)
	purp.add_child(purpose_tag)
	purpose_tag.reset_size()
	purpose_tag.position = Vector2(tag_x - purpose_tag.size.x, 14)
	y += 70.0

	# --- worksheet gauges ---
	var dti_ok: bool = app["dti_after"] <= LDData.MAX_DTI
	var dti_fill: float = minf(app["dti_after"] / 0.6, 1.0)
	_gauge(pad, y, inner, "DEBT-TO-INCOME", dti_fill, dti_ok, LDData.fmt_pct(app["dti_after"]), 0.40 / 0.6, "40% MAX")
	y += 50.0
	var credit_ok: bool = int(app["credit_score"]) >= LDData.MIN_CREDIT
	var credit_fill: float = clampf((float(app["credit_score"]) - 300.0) / 550.0, 0.0, 1.0)
	_gauge(pad, y, inner, "CREDIT SCORE", credit_fill, credit_ok, str(app["credit_score"]), (600.0 - 300.0) / 550.0, "600 MIN")


func _stat_cell(x: float, y: float, w: float, h: float, k: String, v: String) -> void:
	var cell := Panel.new()
	cell.position = Vector2(x, y)
	cell.size = Vector2(w, h)
	cell.add_theme_stylebox_override("panel", BBStyle.flat(Color("fff4d8"), 2, Color("c9b487")))
	_appfile_body.add_child(cell)
	var kl := BBStyle.label(k, BBStyle.px(7), BBStyle.LINE)
	kl.position = Vector2(10, 8)
	kl.size = Vector2(w - 20.0, 16)
	cell.add_child(kl)
	var vl := BBStyle.label(v, 18, BBStyle.INK)
	vl.position = Vector2(10, 26)
	vl.size = Vector2(w - 20.0, 24)
	cell.add_child(vl)


func _tag(text: String, color: Color) -> PanelContainer:
	var t := PanelContainer.new()
	var sb := BBStyle.flat(color, 2, BBStyle.INK)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	t.add_theme_stylebox_override("panel", sb)
	t.add_child(BBStyle.label(text, BBStyle.px(8), Color.WHITE))
	return t


func _gauge(x: float, y: float, w: float, glabel: String, fill_frac: float, ok: bool, value_text: String, mark_frac: float, mark_text: String) -> void:
	var label_w := 200.0
	var val_w := 90.0
	var track_w := w - label_w - val_w - 24.0
	var gl := BBStyle.label(glabel, 16, BBStyle.INK)
	gl.position = Vector2(x, y + 4.0)
	gl.size = Vector2(label_w, 24)
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_appfile_body.add_child(gl)
	var tx := x + label_w + 12.0
	var track := Panel.new()
	track.position = Vector2(tx, y)
	track.size = Vector2(track_w, 22)
	track.add_theme_stylebox_override("panel", BBStyle.flat(Color("d8cca6"), 2, BBStyle.INK))
	_appfile_body.add_child(track)
	var fill := ColorRect.new()
	fill.color = BBStyle.GREEN if ok else BBStyle.RED
	fill.position = Vector2(2, 2)
	fill.size = Vector2((track_w - 4.0) * clampf(fill_frac, 0.0, 1.0), 18)
	track.add_child(fill)
	# threshold mark + caption
	var mark := ColorRect.new()
	mark.color = BBStyle.INK
	mark.position = Vector2(clampf(mark_frac, 0.0, 1.0) * track_w - 1.0, -3)
	mark.size = Vector2(3, 28)
	track.add_child(mark)
	var mk := BBStyle.label(mark_text, BBStyle.px(7), BBStyle.LINE)
	mk.position = Vector2(clampf(mark_frac, 0.0, 1.0) * track_w - 30.0, -18)
	mk.size = Vector2(60, 14)
	mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track.add_child(mk)
	var gv := BBStyle.label(value_text, BBStyle.px(14), BBStyle.GREEN_D if ok else BBStyle.RED_D)
	gv.position = Vector2(tx + track_w + 12.0, y)
	gv.size = Vector2(val_w, 24)
	gv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_appfile_body.add_child(gv)


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
	_render_window_box()


# =========================================================== decisions

func decide(choice: String) -> void:
	if not playing or paused or deciding or help_open:
		return
	if queue.is_empty() or queue[0]["resolved"]:
		return
	var app: Dictionary = queue[0]
	deciding = true
	app["resolved"] = true

	_show_stamp(choice)
	if choice == "approve":
		day_approved += 1
	else:
		day_denied += 1

	var correct: bool = (choice == app["correct"])
	var interest: float = round(app["amount"] * (0.08 + app["term"] / 900.0))
	var default_loss: float = round(app["amount"] * 0.55)
	var delta := 0.0
	var label := ""
	var good := false

	if correct:
		streak += 1
		day_correct += 1
		good = true
		var sb: float = 1.0 + minf(streak * 0.05, 0.5)
		# bank capital change (in-game economy)
		if choice == "approve":
			delta = round(interest * sb)
			label = "GOOD LOAN  +%s interest" % LDData.fmt_money(delta)
		else:
			delta = round(interest * 0.25 * sb)
			label = "GOOD CALL  avoided a bad loan"
		score += int(round(120 * sb))
		# player commission (what flows back to cash)
		var base_comm: float = clampf(app["amount"] * 0.0008, 1.0, 4.0) if choice == "approve" else 1.5
		var comm := snappedf(base_comm * sb, 0.01)
		day_pay += comm
		day_bonus += snappedf(base_comm * (sb - 1.0), 0.01)
	else:
		streak = 0
		day_wrong += 1
		if choice == "approve":
			delta = -default_loss
			day_defaults += 1
			label = "DEFAULT!  %s can't repay  %s" % [app["name"], LDData.fmt_money(delta)]
		else:
			delta = 0.0
			label = "TOO HARSH  %s was a safe bet" % app["name"]
		score = maxi(0, score - 40)

	capital += delta
	day_profit += delta

	react_avatar("happy" if choice == "approve" else "angry")
	_flash_appfile(good)
	if delta != 0.0:
		float_text(("+" if delta > 0.0 else "") + LDData.fmt_money(delta), Color("3a7a26") if delta > 0.0 else BBStyle.RED_D)
	toast(label, good)
	if sfx:
		if good:
			sfx.play("cash")
		elif choice == "approve":
			get_tree().create_timer(0.2).timeout.connect(func() -> void: sfx.play("error"))
	_update_hud()

	if capital < 0.0:
		get_tree().create_timer(0.7).timeout.connect(game_over)
		return

	get_tree().create_timer(0.85).timeout.connect(_after_resolve)


func applicant_leaves() -> void:
	if queue.is_empty() or queue[0]["resolved"]:
		return
	var app: Dictionary = queue[0]
	app["resolved"] = true
	day_missed += 1
	streak = 0
	if sfx:
		sfx.play("leave")
	react_avatar("angry")
	toast("%s got tired of waiting and left" % app["name"], false)
	_update_hud()
	get_tree().create_timer(0.45).timeout.connect(_after_resolve)


func _after_resolve() -> void:
	deciding = false
	if not queue.is_empty():
		queue.pop_front()
	if queue.is_empty() and spawned_count < day_applicants:
		spawn_timer = minf(spawn_timer, 0.6)
	render_active()
	_check_day_end()


func _check_day_end() -> void:
	if spawned_count >= day_applicants and queue.is_empty() and playing:
		end_day("clear")


# =========================================================== day end

func _work_launcher() -> Node:
	return get_node_or_null("/root/LoanLauncher")


func _credit_shift() -> void:
	var launcher := _work_launcher()
	if Engine.is_editor_hint() or launcher == null or not launcher.work_mode:
		return
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("complete_bank_work_shift"):
		gs.complete_bank_work_shift(day_pay, day_bonus)


func end_day(reason: String) -> void:
	if not playing:
		return
	playing = false
	paused = true
	best_capital = maxf(best_capital, capital)
	_credit_shift()
	var total := day_correct + day_wrong
	var acc := int(round(float(day_correct) / maxf(float(total), 1.0) * 100.0))
	var rows := [
		["Correct decisions", "%d/%d" % [day_correct, total], BBStyle.GREEN_D],
		["Loans defaulted", str(day_defaults), BBStyle.RED_D if day_defaults > 0 else BBStyle.INK],
		["Applicants lost", str(day_missed), BBStyle.RED_D if day_missed > 0 else BBStyle.INK],
		["Underwriting rating", "%d%%" % acc, BBStyle.INK],
		["Your commission", LDData.fmt_money(day_pay), BBStyle.GREEN_D],
		["Bank capital", LDData.fmt_money(capital), BBStyle.GREEN_D if capital >= 0.0 else BBStyle.RED_D],
	]
	_show_result("BANK CLOSES" if reason == "time" else "DAY %d DONE" % day, rows)


func game_over() -> void:
	if not playing:
		return
	playing = false
	paused = true
	best_capital = maxf(best_capital, capital)
	_credit_shift()
	var rows := [
		["Made it to", "DAY %d" % day, BBStyle.INK],
		["Loans defaulted", str(day_defaults), BBStyle.RED_D],
		["Your commission", LDData.fmt_money(day_pay), BBStyle.GREEN_D],
		["Final capital", LDData.fmt_money(capital), BBStyle.RED_D],
	]
	_show_result("🏦 BANK INSOLVENT", rows)


func _show_result(title: String, rows: Array) -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.z_index = 65
	_stage.add_child(_result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(dim)

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
	var hl := BBStyle.label(title, BBStyle.px(20), BBStyle.CREAM)
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
	# Single button. No "next day" — the next day comes from working your next
	# shift back in the main game (one bank shift per in-game day).
	var launcher := _work_launcher()
	var exit_text := "FINISH SHIFT" if (launcher and launcher.work_mode) else "EXIT"
	var tq := BBStyle.big_btn(exit_text, BBStyle.GREEN, Color.WHITE, Vector2(300, 44))
	tq.position = Vector2((card.size.x - 300.0) / 2.0, y)
	card.add_child(tq)
	(tq.get_meta("btn") as Button).pressed.connect(_exit_game)

	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	if sfx:
		sfx.play("star")


func _exit_game() -> void:
	var launcher := _work_launcher()
	if launcher and launcher.has_method("close"):
		launcher.close()
	else:
		day = 1
		capital = START_CAPITAL
		score = 0
		streak = 0
		start_day()


# =========================================================== policy modal

func toggle_policy() -> void:
	if help_open:
		_close_policy()
	else:
		_open_policy()


func _open_policy() -> void:
	if help_open:
		return
	help_open = true
	if sfx:
		sfx.play("click")
	_policy_layer = Control.new()
	_policy_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_policy_layer.z_index = 68
	_stage.add_child(_policy_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_btn := Button.new()
	dim_btn.flat = true
	dim_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_btn.add_theme_stylebox_override("focus", BBStyle.empty_box())
	dim_btn.pressed.connect(_close_policy)
	_policy_layer.add_child(dim)
	_policy_layer.add_child(dim_btn)

	var card := Control.new()
	card.size = Vector2(820, 560)
	card.position = (STAGE - card.size) / 2.0
	_policy_layer.add_child(card)
	card.add_child(BBStyle.shadow_panel(card.size, 8, 0))
	var cp := Panel.new()
	cp.size = card.size
	cp.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.PANEL, 4, BBStyle.INK))
	card.add_child(cp)
	var head := Panel.new()
	head.position = Vector2(4, 4)
	head.size = Vector2(card.size.x - 8.0, 50)
	var hsb := BBStyle.flat(BBStyle.LINE)
	hsb.border_width_bottom = 4
	hsb.border_color = BBStyle.INK
	head.add_theme_stylebox_override("panel", hsb)
	card.add_child(head)
	var hl := BBStyle.label("📕 LENDING POLICY", BBStyle.px(14), BBStyle.CREAM)
	hl.position = Vector2(14, 0)
	hl.size = Vector2(400, 50)
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(hl)
	var close_wrap := _icon_btn("✕ CLOSE")
	head.add_child(close_wrap)
	var close_btn: Button = close_wrap.get_meta("btn")
	close_btn.reset_size()
	close_btn.size.y = 32.0
	close_wrap.position = Vector2(head.size.x - close_btn.size.x - 12.0, 9)
	close_btn.pressed.connect(_close_policy)

	var intro := BBStyle.label(
		"Approve loans the townsfolk can REPAY; deny the ones they can't.\nA repaid loan earns interest — a default loses real capital.",
		16, BBStyle.INK)
	# autowrap must be enabled before sizing, or the size setter clamps the label
	# up to its full unwrapped text width and wrapping never engages.
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.position = Vector2(20, 64)
	intro.custom_minimum_size = Vector2(card.size.x - 40.0, 50)
	intro.size = Vector2(card.size.x - 40.0, 50)
	card.add_child(intro)

	var rules := [
		["1", "DEBT-TO-INCOME ≤ 40%", "After this loan, total monthly debt must be at most 40% of income. Over 40% → DENY."],
		["2", "CREDIT SCORE ≥ 600", "Scores under 600 are too risky unless secured by collateral worth the loan. Under 600 & unsecured → DENY."],
		["3", "NO SPECULATION", "The bank never funds gambling or get-rich schemes, however good the numbers look. Speculative purpose → DENY."],
		["4", "OTHERWISE, APPROVE", "Passes all three checks? It's a good loan — approve it and collect the interest."],
	]
	var ry := 122.0
	for r in rules:
		var num := Panel.new()
		num.position = Vector2(20, ry)
		num.size = Vector2(42, 42)
		num.add_theme_stylebox_override("panel", BBStyle.flat(BBStyle.LINE, 3, BBStyle.INK))
		card.add_child(num)
		var nl := BBStyle.label(r[0], BBStyle.px(14), BBStyle.YELLOW)
		nl.set_anchors_preset(Control.PRESET_FULL_RECT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.add_child(nl)
		var rh := BBStyle.label(r[1], BBStyle.px(11), BBStyle.INK)
		rh.position = Vector2(74, ry)
		card.add_child(rh)
		var rb := BBStyle.label(r[2], 16, Color("4a4030"))
		rb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rb.position = Vector2(74, ry + 24.0)
		rb.custom_minimum_size = Vector2(card.size.x - 74.0 - 28.0, 44)
		rb.size = Vector2(card.size.x - 74.0 - 28.0, 44)
		card.add_child(rb)
		ry += 100.0


func _close_policy() -> void:
	help_open = false
	if sfx:
		sfx.play("click")
	if _policy_layer:
		_policy_layer.queue_free()
		_policy_layer = null


# =========================================================== feedback

func _show_stamp(choice: String) -> void:
	if Engine.is_editor_hint():
		return
	_stamp.text = "APPROVED" if choice == "approve" else "DENIED"
	_stamp.add_theme_color_override("font_color", BBStyle.GREEN_D if choice == "approve" else BBStyle.RED_D)
	_stamp.visible = true
	_stamp.reset_size()
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.position = (_appfile.size - _stamp.size) / 2.0
	_stamp.rotation = deg_to_rad(-13.0 if choice == "approve" else 11.0)
	_stamp.scale = Vector2(1.8, 1.8)
	_stamp.modulate.a = 0.0
	var tw := _stamp.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.set_parallel(true)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.22)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.16)


func _flash_appfile(good: bool) -> void:
	if Engine.is_editor_hint():
		return
	_appfile.modulate = Color(0.7, 1.0, 0.7) if good else Color(1.0, 0.7, 0.7)
	var tw := _appfile.create_tween()
	tw.tween_property(_appfile, "modulate", Color.WHITE, 0.4)


func toast(msg: String, good: bool = true) -> void:
	if Engine.is_editor_hint():
		return
	var t := PanelContainer.new()
	var sb := BBStyle.flat(BBStyle.GREEN_D if good else BBStyle.RED_D, 3, Color("0a0705"))
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 11.0
	sb.content_margin_bottom = 11.0
	t.add_theme_stylebox_override("panel", sb)
	t.add_child(BBStyle.label(msg, BBStyle.px(12), BBStyle.CREAM))
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
	tw.chain().tween_interval(1.6)
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
	f.position = Vector2(720, 200)
	_stage.add_child(f)
	f.modulate.a = 0.0
	var tw := f.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(true)
	tw.tween_property(f, "modulate:a", 1.0, 0.22)
	tw.tween_property(f, "position:y", 150.0, 1.0)
	tw.chain().tween_property(f, "modulate:a", 0.0, 0.3)
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
	if sfx == null:
		return
	var m := sfx.toggle_mute()
	_mute_btn.text = "🔇 OFF" if m else "🔊 ON"


func _toggle_crt() -> void:
	_crt.visible = not _crt.visible
	_crt_btn.text = "CRT ON" if _crt.visible else "CRT OFF"


# =========================================================== loop / input

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not playing or paused or help_open:
		return
	var dt := minf(delta, 0.1)
	_flash_clock += dt
	day_time_left -= dt
	if not queue.is_empty() and not queue[0]["resolved"]:
		queue[0]["patience"] -= dt
		if queue[0]["patience"] <= 0.0:
			applicant_leaves()
	spawn_timer -= dt
	if spawned_count < day_applicants and queue.size() < 3 and spawn_timer <= 0.0:
		spawn_applicant()
	_update_hud()
	if day_time_left <= 0.0:
		end_day("time")


func _update_hud() -> void:
	_chips["day"].text = str(day)
	_chips["time"].text = str(maxi(0, ceili(day_time_left)))
	_chips["done"].text = "%d/%d" % [day_approved + day_denied + day_missed, day_applicants]
	_chips["score"].text = str(score)
	_chips["capital"].text = LDData.fmt_money(capital)
	_chips["capital"].add_theme_color_override("font_color", BBStyle.RED if capital < 2000.0 else BBStyle.GREEN)
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
		KEY_ESCAPE:
			if help_open:
				_close_policy()
			else:
				return
		KEY_QUESTION, KEY_SLASH, KEY_P, KEY_H:
			toggle_policy()
		KEY_A, KEY_RIGHT:
			if not help_open:
				decide("approve")
		KEY_D, KEY_LEFT:
			if not help_open:
				decide("deny")
		_:
			return
	get_viewport().set_input_as_handled()


# =========================================================== editor preview

func _populate_demo() -> void:
	day_applicants = 6
	spawned_count = 3
	var demo := LDData.generate_application(2)
	demo["name"] = "Mabel"
	demo["occupation"] = "Baker"
	queue = [demo, {"avatar_seed": 4242, "mood": "neutral"}, {"avatar_seed": 9001, "mood": "neutral"}]
	render_active()
	_chips["time"].text = "92"
	if _patience_fill:
		_patience_fill.size.x = _patience_w * 0.9
