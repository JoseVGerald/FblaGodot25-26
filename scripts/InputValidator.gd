# InputValidator.gd
# Autoload singleton — standardized LineEdit validation for every text field in
# the game. Two field types:
#   register_text_field(le)   — letters and spaces only
#   register_number_field(le) — digits and a single decimal point only
#
# When invalid input is typed the character is silently stripped and an error
# toast slides in using the exact same animation as the achievement notification
# in bottom_hud.show_notification() — same font, same position, same timing —
# but in error red with no emoji.  Kept entirely separate from the achievement
# and notification systems.
extends CanvasLayer

const _MSG_TEXT   := "Only letters and spaces are allowed"
const _MSG_NUMBER := "Only numbers and decimals are allowed"
const _ERR_COLOR  := Color(0.72, 0.25, 0.25)

var _active: Array = []


func _ready() -> void:
	layer        = 99
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Public API ─────────────────────────────────────────────────────────────────

## Connect letters-and-spaces-only validation to a LineEdit.
func register_text_field(le: LineEdit) -> void:
	le.set_meta("_iv_reverting", false)
	le.text_changed.connect(_on_text_changed.bind(le))


## Connect digits-and-single-decimal-only validation to a LineEdit.
func register_number_field(le: LineEdit) -> void:
	le.set_meta("_iv_last_valid", le.text)
	le.set_meta("_iv_reverting", false)
	le.text_changed.connect(_on_number_changed.bind(le))


# ── Validation handlers ────────────────────────────────────────────────────────

func _on_text_changed(new_text: String, le: LineEdit) -> void:
	if le.get_meta("_iv_reverting", false):
		return
	var filtered := ""
	for c in new_text:
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or c == " ":
			filtered += c
	if filtered != new_text:
		var caret := le.caret_column - (new_text.length() - filtered.length())
		le.set_meta("_iv_reverting", true)
		le.text = filtered
		le.caret_column = max(0, min(caret, filtered.length()))
		le.set_meta("_iv_reverting", false)
		_show_error(_MSG_TEXT)


func _on_number_changed(new_text: String, le: LineEdit) -> void:
	if le.get_meta("_iv_reverting", false):
		return
	if new_text.is_empty():
		le.set_meta("_iv_last_valid", "")
		return
	var valid := true
	var dots := 0
	for c in new_text:
		if c == ".":
			dots += 1
			if dots > 1:
				valid = false
				break
		elif c < "0" or c > "9":
			valid = false
			break
	if valid:
		le.set_meta("_iv_last_valid", new_text)
	else:
		var last: String = le.get_meta("_iv_last_valid", "")
		le.set_meta("_iv_reverting", true)
		le.text = last
		le.caret_column = last.length()
		le.set_meta("_iv_reverting", false)
		_show_error(_MSG_NUMBER)


# ── Error toast — identical animation to bottom_hud.show_notification() ───────

func _show_error(message: String) -> void:
	# Drop stale entries.
	var live: Array = []
	for e in _active:
		if is_instance_valid(e.label):
			live.append(e)
	_active = live

	var viewport_h := get_viewport().get_visible_rect().size.y
	var base_y     := viewport_h - 215.0

	# Same message already on screen — shake it and reset fade timer.
	for e in _active:
		if e.message == message and is_instance_valid(e.label):
			if e.fade_tween and e.fade_tween.is_valid():
				e.fade_tween.kill()
			e.label.modulate.a = 1.0
			var shake := create_tween()
			shake.tween_property(e.label, "position:x", 48.0, 0.04)
			shake.tween_property(e.label, "position:x", 32.0, 0.04)
			shake.tween_property(e.label, "position:x", 46.0, 0.04)
			shake.tween_property(e.label, "position:x", 34.0, 0.04)
			shake.tween_property(e.label, "position:x", 40.0, 0.04)
			e.fade_tween = create_tween()
			e.fade_tween.tween_interval(2.5)
			e.fade_tween.tween_property(e.label, "modulate:a", 0.0, 0.4)
			e.fade_tween.tween_callback(e.label.queue_free)
			return

	# New label.
	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", _ERR_COLOR)
	label.add_theme_font_size_override("font_size", 49)
	var font := UITheme.get_pixel_font()
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position  = Vector2(40.0, base_y + 40.0)
	label.modulate.a = 0.0
	add_child(label)

	var entry := {
		"label": label,
		"message": message,
		"base_y": base_y,
		"offset_y": 0.0,
		"tween": null,
		"fade_tween": null,
	}

	# Slide up + fade in.
	var appear := create_tween().set_parallel(true)
	appear.tween_property(label, "position:y", base_y, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	appear.tween_property(label, "modulate:a", 1.0, 0.35)

	# Push older entries up; retire the third.
	var spacing := 65.0
	var to_remove: Array = []
	for i in range(_active.size()):
		var e = _active[i]
		e.offset_y += spacing
		var target_y: float = e.base_y - e.offset_y
		if e.tween and e.tween.is_valid():
			e.tween.kill()
		if i >= 1:
			to_remove.append(e)
			if e.fade_tween and e.fade_tween.is_valid():
				continue
			var ft := create_tween().set_parallel(true)
			ft.tween_property(e.label, "position:y", target_y - 20.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			ft.tween_property(e.label, "modulate:a", 0.0, 0.4)
			ft.set_parallel(false)
			ft.tween_callback(e.label.queue_free)
		else:
			e.tween = create_tween()
			e.tween.tween_property(e.label, "position:y", target_y, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for e in to_remove:
		_active.erase(e)

	# Auto-fade after 2.5 s hold.
	var ft2 := create_tween()
	ft2.tween_interval(2.5)
	ft2.tween_property(label, "modulate:a", 0.0, 0.4)
	ft2.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
		_active.erase(entry)
	)
	entry.fade_tween = ft2

	_active.append(entry)
