@tool
class_name BBStyle
extends RefCounted
## Burger Blitz — palette, fonts, stylebox + widget factories.
## Faithful port of the reference styles.css design tokens.

const BG := Color("1c130c")
const BG2 := Color("2a1d12")
const PANEL := Color("f6e6c4")
const PANEL2 := Color("ead2a0")
const INK := Color("2a1408")
const LINE := Color("43230f")
const RED := Color("e0463b")
const RED_D := Color("b22f27")
const YELLOW := Color("f4c13d")
const YELLOW_D := Color("d99a23")
const GREEN := Color("6fb24a")
const GREEN_D := Color("4d8a32")
const BUN := Color("e8b465")
const BUN_D := Color("cf9341")
const BLUE := Color("4f8ccc")
const BLUE_D := Color("356199")
const CREAM := Color("fff7e6")
const SHADOW := Color(20.0 / 255.0, 8.0 / 255.0, 2.0 / 255.0, 0.35)
const EDGE := Color("0a0705")

static var _font: Font = null


static func font() -> Font:
	if _font == null:
		var base: FontFile = load("res://assets/fonts/Minecraft.ttf")
		var f: FontVariation = FontVariation.new()
		f.base_font = base
		var emoji := SystemFont.new()
		emoji.font_names = PackedStringArray(["Apple Color Emoji", "Noto Color Emoji"])
		f.fallbacks = [emoji]
		_font = f
	return _font


## Pixel sizes: the reference uses Press Start 2P (very wide). Minecraft.ttf is
## narrower, so headline-ish sizes get a small bump to fill similar space.
static func px(n: int) -> int:
	return n + 2


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func flat(bg: Color, border: int = 0, border_color: Color = INK, radius: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = false
	return sb


static func empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## Solid offset "retro" drop shadow panel placed behind an element.
static func shadow_panel(target_size: Vector2, drop: int, radius: int = 0, color: Color = SHADOW) -> Panel:
	var p := Panel.new()
	p.name = "Shadow"
	p.position = Vector2(0, drop)
	p.size = target_size
	p.add_theme_stylebox_override("panel", flat(color, 0, color, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A chunky button with a hard 2D shadow that presses down 3px on click.
## Returns wrapper Control; the actual Button is meta "btn".
static func big_btn(text: String, bg: Color, fg: Color, size: Vector2, font_size: int = 14, drop: int = 5) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = size + Vector2(0, drop)
	wrap.size = size + Vector2(0, drop)
	wrap.add_child(shadow_panel(size, drop))
	var b := Button.new()
	b.text = text
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_hover_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_disabled_color", fg)
	var sb := flat(bg, 3, INK)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", empty_box())
	var pressed_sb := flat(bg.darkened(0.04), 3, INK)
	b.add_theme_stylebox_override("pressed", pressed_sb)
	b.add_theme_stylebox_override("hover_pressed", pressed_sb)
	var dis := flat(bg.lerp(Color(0.55, 0.52, 0.47), 0.55), 3, INK)
	b.add_theme_stylebox_override("disabled", dis)
	wrap.add_child(b)
	wrap.set_meta("btn", b)
	# press feedback: button sinks into its shadow (100-160ms felt-response rule)
	b.button_down.connect(func() -> void: b.position.y = 3)
	b.button_up.connect(func() -> void: b.position.y = 0)
	return wrap


static func mini_btn(text: String, bg: Color, size: Vector2) -> Control:
	return big_btn(text, bg, Color.WHITE, size, 10, 3)


## HUD chip: dark slab, small yellow label + cream value.
## Returns wrapper; value Label is meta "val".
static func chip(lbl: String, val: String, val_color: Color = CREAM) -> Control:
	var p := PanelContainer.new()
	var sb := flat(Color("3a2414"), 3, EDGE)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 10.0
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := label(lbl, px(10), YELLOW)
	var v := label(val, px(13), val_color)
	h.add_child(l)
	h.add_child(v)
	p.add_child(h)
	# inset bottom shadow line
	var ins := ColorRect.new()
	ins.color = Color(0, 0, 0, 0.35)
	ins.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ins.offset_top = -6.0
	ins.offset_left = 3.0
	ins.offset_right = -3.0
	ins.offset_bottom = -3.0
	ins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ins)
	p.set_meta("val", v)
	return p


## Cream framed panel with hard shadow + inner panel2 ring and dark header bar.
## Returns the panel; header content area is meta "head_box", body meta "body".
static func framed_panel(rect: Rect2, title: String, tag: String) -> Control:
	var root := Control.new()
	root.position = rect.position
	root.size = rect.size
	root.add_child(shadow_panel(rect.size, 6, 4))
	var p := Panel.new()
	p.name = "Frame"
	p.size = rect.size
	p.add_theme_stylebox_override("panel", flat(PANEL, 4, INK, 4))
	root.add_child(p)
	var ring := Panel.new()
	ring.name = "Ring"
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 4.0
	ring.offset_top = 4.0
	ring.offset_right = -4.0
	ring.offset_bottom = -4.0
	var rsb := flat(Color.TRANSPARENT, 3, PANEL2)
	rsb.draw_center = false
	ring.add_theme_stylebox_override("panel", rsb)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ring)

	var body_top := 4.0
	if title != "":
		var head := Panel.new()
		head.name = "Head"
		head.position = Vector2(4, 4)
		head.size = Vector2(rect.size.x - 8, 36)
		var hsb := flat(LINE, 0)
		hsb.border_width_bottom = 4
		hsb.border_color = INK
		head.add_theme_stylebox_override("panel", hsb)
		root.add_child(head)
		var hl := label(title, px(13), CREAM)
		hl.position = Vector2(12, 0)
		hl.size = Vector2(rect.size.x - 24, 32)
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(hl)
		if tag != "":
			var tl := label(tag, px(9), YELLOW)
			tl.position = Vector2(12, 0)
			tl.size = Vector2(head.size.x - 24, 32)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			head.add_child(tl)
		root.set_meta("head", head)
		body_top = 40.0

	var body := Control.new()
	body.name = "Body"
	body.position = Vector2(4, body_top)
	body.size = Vector2(rect.size.x - 8, rect.size.y - body_top - 4)
	root.add_child(body)
	root.set_meta("body", body)
	return root
