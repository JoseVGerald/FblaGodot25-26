# COMMIT: Achievements and Catch Minigame Update
class_name UITheme
## Shared UI styling utilities for the maroon pixel-art aesthetic.
##
## Two modes:
##   apply_theme(root)          – full-screen menus: adds checker bg + styles everything
##   apply_overlay_theme(root)  – in-game popups: styles fonts/buttons/panels, preserves label colors

const PIXEL_FONT_PATH := "res://assets/fonts/Minecraft.ttf"

# Legacy button colour palette (kept for backward compat)
const CLR_GREY   := Color(0.45, 0.48, 0.52)
const CLR_GREEN  := Color(0.30, 0.68, 0.38)
const CLR_ORANGE := Color(0.92, 0.62, 0.08)
const CLR_RED    := Color(0.72, 0.25, 0.25)

# ── New UI maroon pixel-art palette ──────────────────────────────────────────
const CLR_INK       := Color("#7a4a35")   # All borders, text, outlines
const CLR_MAROON    := Color("#b75b5f")   # Panel background (full-screen menus)
const CLR_MAROON_D  := Color("#9c4351")   # Darker sections, dividers, grid trays
const CLR_CREAM     := Color("#ffd7a8")   # Title plaque bg, overlay panel bg
const CLR_CREAM_LT  := Color("#ffe3c6")   # Highlight line inside plaque
const CLR_TAN       := Color("#e5b67f")   # Primary button fill
const CLR_TAN_HI    := Color("#f0cb97")   # Primary button hover highlight
const CLR_TAN_DRK   := Color("#c7895d")   # Primary button inner-bottom shade
const CLR_GRAY_NEW  := Color("#c6b09b")   # Secondary / disabled button
const CLR_GRAY_HI   := Color("#e8d0b9")   # Secondary button hover
const CLR_GRAY_DRK  := Color("#8a7868")   # Gray button inner-bottom shade
const CLR_ORANGE_PX := Color("#ffa34d")   # Corner brackets, accent bars, active tab
const CLR_GOLD      := Color("#ffd071")   # Corner highlight, selection outline
const CLR_PINK      := Color("#f29485")   # Display / chart background area


# ═══════════════════════════════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════════════════════════════

## Full-screen theme: replaces background with checker + styles every child.
static func apply_theme(root: Control) -> void:
	_replace_background(root)
	_style_children_recursive(root, true)


## Overlay theme: styles fonts, buttons, panels but preserves existing label colors.
## Works on CanvasLayer, Control, or any Node.
static func apply_overlay_theme(root: Node) -> void:
	_style_children_recursive(root, false)


## Create the maroon checker background (can also be used standalone).
static func create_checker_bg() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "CheckerBG"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 color1 : source_color = vec4(0.639, 0.302, 0.325, 1.0);
uniform vec4 color2 : source_color = vec4(0.600, 0.271, 0.298, 1.0);
uniform float tile_size = 48.0;
void fragment() {
	vec2 pos = FRAGCOORD.xy / tile_size;
	float checker = mod(floor(pos.x) + floor(pos.y), 2.0);
	COLOR = mix(color1, color2, checker);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	return rect


static func get_pixel_font() -> Font:
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		return load(PIXEL_FONT_PATH)
	return null


# ═══════════════════════════════════════════════════════════════════
#  INDIVIDUAL STYLE HELPERS  (can be called directly if needed)
# ═══════════════════════════════════════════════════════════════════

static func style_button(btn: Button, bg_color: Color = CLR_GREY) -> void:
	var font := get_pixel_font()
	if font and not _has_emoji(btn.text):
		btn.add_theme_font_override("font", font)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = bg_color.darkened(0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed: StyleBoxFlat = sb.duplicate()
	sb_pressed.bg_color = bg_color.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", sb_pressed)

	var sb_disabled: StyleBoxFlat = sb.duplicate()
	sb_disabled.bg_color = Color(0.5, 0.5, 0.5, 0.6)
	sb_disabled.border_color = Color(0.4, 0.4, 0.4)
	btn.add_theme_stylebox_override("disabled", sb_disabled)


## New-UI pixel button: thick bottom border = 3D depth, square corners.
## `secondary = true` → gray fill; `false` → tan/primary fill.
static func style_pixel_button(btn: Button, secondary: bool = false) -> void:
	var f := get_pixel_font()
	if f: btn.add_theme_font_override("font", f)
	btn.add_theme_color_override("font_color",         CLR_INK)
	btn.add_theme_color_override("font_hover_color",   CLR_INK)
	btn.add_theme_color_override("font_pressed_color", CLR_INK)

	var fill     := CLR_GRAY_NEW if secondary else CLR_TAN
	var fill_hi  := CLR_GRAY_HI  if secondary else CLR_TAN_HI
	var fill_drk := CLR_GRAY_DRK if secondary else CLR_TAN_DRK

	btn.add_theme_stylebox_override("normal",   _pxsb(fill,                fill_drk, 8))
	btn.add_theme_stylebox_override("hover",    _pxsb(fill_hi,             fill_drk, 8))
	btn.add_theme_stylebox_override("pressed",  _pxsb(fill.darkened(0.06), fill_drk, 2))
	btn.add_theme_stylebox_override("disabled", _pxsb(fill.darkened(0.30), fill_drk, 8))
	_do_juice_on(btn)


## Semantic colored pixel button — same 3-D pixel look as style_pixel_button but
## with an arbitrary fill colour and white text. Use for confirm / reset / danger
## actions (green / orange / red) so the colour cue survives the maroon rebrand.
static func style_pixel_button_colored(btn: Button, fill: Color) -> void:
	var f := get_pixel_font()
	if f and not _has_emoji(btn.text):
		btn.add_theme_font_override("font", f)
	btn.add_theme_color_override("font_color",         Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var shadow := fill.darkened(0.30)
	btn.add_theme_stylebox_override("normal",   _pxsb(fill,                 shadow, 8))
	btn.add_theme_stylebox_override("hover",    _pxsb(fill.lightened(0.10), shadow, 8))
	btn.add_theme_stylebox_override("pressed",  _pxsb(fill.darkened(0.08),  shadow, 2))
	btn.add_theme_stylebox_override("disabled", _pxsb(fill.darkened(0.30),  shadow, 8))
	_do_juice_on(btn)


## StyleBoxFlat factory for pixel buttons: `depth` = extra bottom border thickness.
static func _pxsb(fill: Color, shadow: Color, depth: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color            = fill
	sb.border_color        = CLR_INK
	sb.border_width_top    = 3
	sb.border_width_left   = 3
	sb.border_width_right  = 3
	sb.border_width_bottom = 3 + depth          # thick bottom = 3-D base
	sb.anti_aliasing       = false              # crisp pixel edges
	sb.set_corner_radius_all(0)                 # sharp = pixel art
	sb.content_margin_left   = 18
	sb.content_margin_right  = 18
	sb.content_margin_top    = 12
	sb.content_margin_bottom = 12 + (8 - depth) # shrinks on press = sinks
	return sb


## Wire hover/press/sound animation signals onto any Button.
## Safe to call multiple times — uses meta guard.
static func _do_juice_on(btn: Button) -> void:
	if btn.has_meta("juiced"): return
	btn.set_meta("juiced", true)
	# Deferred so size is known when pivot is calculated.
	# We use a one-shot ready connection: if already in tree, call next frame.
	if btn.is_inside_tree():
		(func(): apply_juice_now(btn)).call_deferred()
	else:
		btn.ready.connect(func(): apply_juice_now(btn), CONNECT_ONE_SHOT)


## Apply hover/press/sound signals to a Button. Call after layout so pivot is correct.
static func apply_juice_now(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	btn.mouse_entered.connect(func():
		if btn.disabled: return
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE * 1.05, 0.10))
	btn.mouse_exited.connect(func():
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08))
	btn.button_down.connect(func():
		Sfx.click()
		var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(btn, "scale", Vector2(1.03, 0.88), 0.06))
	btn.button_up.connect(func():
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10))


## Style the red ✕ close button used on all overlay panels.
static func style_close_button(btn: Button) -> void:
	var f := get_pixel_font()
	if f: btn.add_theme_font_override("font", f)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ef5350")
	sb.border_color = CLR_INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)

	var sb_h: StyleBoxFlat = sb.duplicate()
	sb_h.bg_color = Color("#ff6b6b")
	btn.add_theme_stylebox_override("hover", sb_h)

	var sb_p: StyleBoxFlat = sb.duplicate()
	sb_p.bg_color = Color("#d32f2f")
	btn.add_theme_stylebox_override("pressed", sb_p)
	_do_juice_on(btn)


## Style an overlay PanelContainer with cream bg + ink border (new UI).
static func style_cream_panel(panel: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_CREAM
	sb.border_color = CLR_INK
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(20)
	if panel is PanelContainer:
		panel.add_theme_stylebox_override("panel", sb)
	elif panel is Panel:
		panel.add_theme_stylebox_override("panel", sb)
	panel.modulate.a = 1.0


## Style a label that sits directly on the checker background:
## cream fill + thick ink outline so it stays readable on maroon.
static func style_checker_label(label: Label, outline_size: int = 10) -> void:
	var font := get_pixel_font()
	if font and not _has_emoji(label.text):
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", CLR_CREAM_LT)
	label.add_theme_color_override("font_outline_color", CLR_INK)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)


static func style_label(label: Label, force_white: bool = true) -> void:
	var font := get_pixel_font()
	if font and not _has_emoji(label.text):
		label.add_theme_font_override("font", font)
	if force_white:
		label.add_theme_color_override("font_color", CLR_INK)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func style_line_edit(input: LineEdit) -> void:
	var font := get_pixel_font()
	if font:
		input.add_theme_font_override("font", font)
	
	input.add_theme_color_override("font_color", CLR_INK)
	input.add_theme_color_override("font_placeholder_color", CLR_GRAY_DRK)

	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_CREAM_LT
	sb.border_color = CLR_INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	input.add_theme_stylebox_override("normal", sb)

	var sb_focus: StyleBoxFlat = sb.duplicate()
	sb_focus.border_color = CLR_ORANGE_PX
	sb_focus.border_width_bottom = 6
	input.add_theme_stylebox_override("focus", sb_focus)


static func style_panel(panel: Control) -> void:
	# Cream panel with ink border matching the maroon pixel-art identity.
	var sb := StyleBoxFlat.new()
	sb.bg_color     = CLR_CREAM
	sb.border_color = CLR_INK
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(20)
	if panel is PanelContainer:
		panel.add_theme_stylebox_override("panel", sb)
	elif panel is Panel:
		panel.add_theme_stylebox_override("panel", sb)
	# Force full opacity — prevents world from bleeding through
	panel.modulate.a = 1.0


static func style_rich_text(rtl: RichTextLabel) -> void:
	var font := get_pixel_font()
	if font:
		rtl.add_theme_font_override("normal_font", font)
		rtl.add_theme_font_override("bold_font", font)
		rtl.add_theme_font_override("italics_font", font)


static func style_check_box(cb: CheckBox) -> void:
	var font := get_pixel_font()
	if font and not _has_emoji(cb.text):
		cb.add_theme_font_override("font", font)
	cb.add_theme_color_override("font_color", Color.WHITE)
	cb.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 1.0))
	cb.add_theme_color_override("font_pressed_color", Color.WHITE)


## Style a PanelContainer as a "card" — navy card bg with colored accent border.
## `accent_side`: "all" | "left" applies accent as the full border or just the left edge.
static func style_card(panel: PanelContainer, accent_color: Color = Color("#4A90D9"), accent_side: String = "all") -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color("#162240")
	var dim_accent := Color(accent_color.r, accent_color.g, accent_color.b, 0.3)
	if accent_side == "left":
		# Godot 4 StyleBoxFlat has one border color; use it for the left stripe.
		sb.border_color = accent_color
		sb.border_width_left = 6
		sb.border_width_top = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0
	else:
		sb.border_color = dim_accent
		sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)


## Style a translucent inline warning strip. `variant` ∈ {"orange","green","red","cyan"}.
static func style_warning_strip(panel: PanelContainer, variant: String = "orange") -> void:
	var palette := {
		"orange": [Color("#FFA726", 0.12), Color("#FFA726", 0.45)],
		"green":  [Color("#4CAF50", 0.12), Color("#4CAF50", 0.45)],
		"red":    [Color("#EF5350", 0.12), Color("#EF5350", 0.45)],
		"cyan":   [Color("#53d8fb", 0.12), Color("#53d8fb", 0.45)],
	}
	var c: Array = palette.get(variant, palette["orange"])
	var sb := StyleBoxFlat.new()
	sb.bg_color     = c[0]
	sb.border_color = c[1]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)


## Build a small category pill (PanelContainer + Label) matching the finance palette.
static func make_cat_pill(category: String, font_size: int = 20) -> PanelContainer:
	var colors := {
		"Food":   Color("#4CAF50"),
		"Vet":    Color("#4A90D9"),
		"Travel": Color("#FFA726"),
		"Income": Color("#53d8fb"),
		"Loan":   Color("#EF5350"),
	}
	var cat_color: Color = colors.get(category, Color.WHITE)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(cat_color.r, cat_color.g, cat_color.b, 0.18)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(20)
	sb.content_margin_left   = 14
	sb.content_margin_right  = 14
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = category
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", cat_color)
	var font := get_pixel_font()
	if font: lbl.add_theme_font_override("font", font)
	pill.add_child(lbl)
	return pill


## Colored left-accent card (used in budget, shop, supplies rows).
## Tighter padding than style_card — 12px vs 16px — and a bold 3px left stripe.
static func style_accent_card(panel: PanelContainer, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color("#162240")
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.22)
	sb.set_border_width_all(2)
	sb.border_width_left = 3
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)


## Small colored icon tile — 32×32 by default — used behind drawn icons / labels.
static func make_icon_tile(color: Color, size: float = 32.0) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(size, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.18)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(6)
	tile.add_theme_stylebox_override("panel", sb)
	return tile


## HUD action button (icon + label, colored tint bg + border).
## Use for the bottom-HUD nav buttons and top-right HUD buttons.
static func style_hud_btn(btn: Button, accent: Color) -> void:
	var font := get_pixel_font()
	if font and not _has_emoji(btn.text):
		btn.add_theme_font_override("font", font)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(accent.r, accent.g, accent.b, 0.12)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_h: StyleBoxFlat = sb.duplicate()
	sb_h.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	btn.add_theme_stylebox_override("hover", sb_h)

	var sb_p: StyleBoxFlat = sb.duplicate()
	sb_p.bg_color = Color(accent.r, accent.g, accent.b, 0.06)
	btn.add_theme_stylebox_override("pressed", sb_p)


## Toggle switch (replaces CheckBox in settings rows).
## Returns a Button with toggle_mode — connect its `toggled` signal externally.
static func make_toggle(initial_on: bool = false) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial_on
	btn.custom_minimum_size = Vector2(44, 24)
	btn.focus_mode = Control.FOCUS_NONE
	_apply_toggle_style(btn)
	btn.toggled.connect(func(_v): _apply_toggle_style(btn))
	return btn


static func _apply_toggle_style(btn: Button) -> void:
	var on := btn.button_pressed
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color("#4CAF50") if on else Color("#1e3a6e")
	sb.border_color = Color("#4CAF50") if on else Color("#2d6aad")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.text = ""
	# The thumb is drawn as a child ColorRect; create it once.
	if btn.get_child_count() == 0:
		var thumb := ColorRect.new()
		thumb.color = Color.WHITE
		thumb.custom_minimum_size = Vector2(14, 14)
		thumb.name = "Thumb"
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(thumb)
	var thumb_node := btn.get_node_or_null("Thumb")
	if thumb_node:
		thumb_node.position = Vector2(22.0 if on else 4.0, 3.0)


# ═══════════════════════════════════════════════════════════════════
#  INTERNALS
# ═══════════════════════════════════════════════════════════════════

## Remove any existing full-screen ColorRect backgrounds, then add checker.
static func _replace_background(root: Control) -> void:
	for child in root.get_children():
		if child is ColorRect and child.anchor_right >= 1.0 and child.anchor_bottom >= 1.0:
			child.queue_free()
	var checker := create_checker_bg()
	root.add_child(checker)
	root.move_child(checker, 0)


## Auto-detect a good colour based on button text.
static func _auto_button_color(btn: Button) -> Color:
	var t := btn.text.to_lower().strip_edges()
	if t in ["continue", "continue game", "yes", "start new game", "start", "resume",
			"got it!", "transfer", "submit", "ask", "send", "purchace", "purchase"]:
		return CLR_GREEN
	elif t in ["randomize"]:
		return CLR_ORANGE
	elif t in ["no", "back", "close", "x", "quit game", " x "]:
		return CLR_RED
	return CLR_GREY


## Walk the tree and style every relevant node.
## preserve_colors=false → full styling (for full-screen menus)
## preserve_colors=true  → skip label color overrides (for overlays)
static func _style_children_recursive(node: Node, force_label_colors: bool = true) -> void:
	if node is CheckBox:
		style_check_box(node)
	elif node is OptionButton:
		pass  # OptionButtons are custom-styled by their own scripts
	elif node is Button:
		style_button(node, _auto_button_color(node))
		_do_juice_on(node)
	elif node is Label:
		if force_label_colors:
			style_label(node, true)
		else:
			# Overlay mode: set font + shadow but keep existing color
			style_label(node, not node.has_theme_color_override("font_color"))
	elif node is LineEdit:
		style_line_edit(node)
	elif node is RichTextLabel:
		style_rich_text(node)
	elif node is PanelContainer or node is Panel:
		style_panel(node)
	for child in node.get_children():
		_style_children_recursive(child, force_label_colors)


## Returns true if the text contains emoji (high-unicode) characters.
## We skip setting the pixel font on these since Minecraft.ttf lacks emoji glyphs.
static func _has_emoji(text: String) -> bool:
	for i in range(text.length()):
		if text.unicode_at(i) > 0x2000:
			return true
	return false

# Updated on 2026-04-19
