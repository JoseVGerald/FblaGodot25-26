@tool
class_name BBSlab
extends Control
## Burger Blitz — one ingredient "slab" sprite, drawn procedurally.
## Port of the reference CSS slab shapes (gradients, zigzag clip-paths, domes).

const SIZES := {
	"bunBottom": Vector2(210, 32), "bunTop": Vector2(218, 64),
	"cheese": Vector2(222, 20), "lettuce": Vector2(230, 24),
	"tomato": Vector2(200, 22), "onion": Vector2(198, 15),
	"pickle": Vector2(184, 15), "ketchup": Vector2(200, 11),
	"mustard": Vector2(200, 11), "patty": Vector2(208, 28),
}
const EDGE := Color("160b05")

var slab_type: String = "bunBottom"
var doneness: String = "Medium"
var patty_seed: int = 7
var _patty_tex: ImageTexture = null


static func make(type: String, opts: Dictionary = {}) -> BBSlab:
	var s := BBSlab.new()
	s.slab_type = type
	s.doneness = opts.get("doneness", "Medium")
	s.patty_seed = opts.get("seed", 7)
	var sz: Vector2 = SIZES.get(type, Vector2(200, 20))
	s.custom_minimum_size = sz
	s.size = sz
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _draw() -> void:
	match slab_type:
		"patty":
			if _patty_tex == null:
				_patty_tex = BBPix.patty_texture(doneness, 52, 7, patty_seed)
			draw_texture_rect(_patty_tex, Rect2(Vector2.ZERO, size), false)
		"bunBottom":
			_draw_banded(_bun_bottom_bounds, [
				[0.0, Color("f2c887")], [0.35, Color("e8b465")], [0.8, Color("cf9341")], [1.0, Color("b67c33")],
			], EDGE)
			_band_overlay(_bun_bottom_bounds, 3, 7, Color(1.0, 0.957, 0.839, 0.55))
			_band_overlay(_bun_bottom_bounds, int(size.y) - 11, int(size.y) - 3, Color(0.573, 0.353, 0.125, 0.45))
		"bunTop":
			_draw_banded(_bun_top_bounds, [
				[0.0, Color("f8d99c")], [0.32, Color("f1c277")], [0.62, Color("e8b465")],
				[0.88, Color("cf9341")], [1.0, Color("b67c33")],
			], EDGE)
			# glossy shine streak
			draw_set_transform(Vector2(size.x * 0.14 + size.x * 0.17, 12.0), deg_to_rad(-7.0), Vector2.ONE)
			_fill_ellipse(Vector2.ZERO, Vector2(size.x * 0.17, 5.5), Color(1.0, 0.98, 0.902, 0.55))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# sesame seeds
			for s in [[40, 18, -20], [95, 28, 15], [150, 16, 30], [70, 40, 5], [125, 42, -15], [178, 32, 12]]:
				draw_set_transform(Vector2(s[0] + 4, s[1] + 2.5), deg_to_rad(float(s[2])), Vector2.ONE)
				_fill_ellipse(Vector2.ZERO, Vector2(4, 2.5), Color("fff2cf"))
				_fill_ellipse(Vector2(0, 1.0), Vector2(3.2, 1.2), Color(0.698, 0.51, 0.235, 0.5))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cheese":
			_draw_poly_grad(_cheese_points(), Color("ffd75e"), Color("d99a23"), Color("a9791a"))
		"lettuce":
			_draw_poly_grad(_lettuce_points(), Color("9ed06e"), Color("4d8a32"), Color("33621f"))
		"tomato":
			_draw_banded(_pill_bounds.bind(80.0, 8.8), [[0.0, Color("e76a60")], [1.0, Color("c93a30")]], Color("922c25"))
			_band_overlay(_pill_bounds.bind(80.0, 8.8), int(size.y) - 8, int(size.y) - 3, Color("a73129"))
			_fill_ellipse(Vector2(size.x * 0.1 + size.x * 0.12, 6.0), Vector2(size.x * 0.12, 2.5), Color(1.0, 0.824, 0.784, 0.7))
		"onion":
			_draw_banded(_pill_bounds.bind(79.0, 6.0), [[0.0, Color("efe0f3")], [1.0, Color("cda7d6")]], Color("7c5a86"))
			_band_overlay(_pill_bounds.bind(79.0, 6.0), int(size.y) - 7, int(size.y) - 3, Color("b48cbe"))
		"pickle":
			for i in range(5):
				var cx := size.x * (float(i) + 0.5) / 5.0
				_fill_ellipse(Vector2(cx, size.y * 0.5), Vector2(12.5, 7.5), Color("4d6e20"))
				_fill_ellipse(Vector2(cx, size.y * 0.5), Vector2(9.5, 4.5), Color("7ba23a"))
				_fill_ellipse(Vector2(cx, size.y * 0.44), Vector2(5.5, 2.6), Color("b8d97a"))
		"ketchup":
			_draw_sauce(Color("ef6a5e"), Color("b22f27"))
		"mustard":
			_draw_sauce(Color("ffd75e"), Color("d99a23"))


# ---- silhouette bound functions: y -> Vector2(left, right) ----

func _bun_bottom_bounds(y: float) -> Vector2:
	var w := size.x
	var h := size.y
	var r_top := 7.0
	var r_bot := 16.0
	var inset := 0.0
	if y < r_top:
		inset = r_top - sqrt(maxf(0.0, r_top * r_top - (r_top - y) * (r_top - y)))
	elif y > h - r_bot:
		var dy := y - (h - r_bot)
		inset = r_bot - sqrt(maxf(0.0, r_bot * r_bot - dy * dy))
	return Vector2(inset, w - inset)


func _bun_top_bounds(y: float) -> Vector2:
	var w := size.x
	var h := size.y
	var rx := w / 2.0
	var ry := h * 0.71  # browser-normalized dome radii (60%/85% capped)
	var inset := 0.0
	if y < ry:
		var t := (ry - y) / ry
		inset = rx * (1.0 - sqrt(maxf(0.0, 1.0 - t * t)))
	elif y > h - 10.0:
		var dy := y - (h - 10.0)
		inset = 10.0 - sqrt(maxf(0.0, 100.0 - dy * dy))
	return Vector2(inset, w - inset)


func _pill_bounds(y: float, rx: float, ry: float) -> Vector2:
	var w := size.x
	var h := size.y
	rx = minf(rx, w / 2.0)
	ry = minf(ry, h / 2.0)
	var inset := 0.0
	if y < ry:
		var t := (ry - y) / ry
		inset = rx * (1.0 - sqrt(maxf(0.0, 1.0 - t * t)))
	elif y > h - ry:
		var t2 := (y - (h - ry)) / ry
		inset = rx * (1.0 - sqrt(maxf(0.0, 1.0 - t2 * t2)))
	return Vector2(inset, w - inset)


# ---- painters ----

## Fill a y-monotone silhouette with a multi-stop vertical gradient + 3px edge.
func _draw_banded(bounds: Callable, stops: Array, edge_color: Color) -> void:
	var h := int(size.y)
	for y in range(h):
		var b: Vector2 = bounds.call(float(y) + 0.5)
		if b.y - b.x <= 0.0:
			continue
		var t := float(y) / maxf(float(h - 1), 1.0)
		var col := _grad(stops, t)
		# edge: top/bottom rows and 3px sides
		if y < 3 or y >= h - 3:
			draw_rect(Rect2(b.x, y, b.y - b.x, 1), edge_color)
		else:
			draw_rect(Rect2(b.x, y, 3, 1), edge_color)
			draw_rect(Rect2(b.y - 3, y, 3, 1), edge_color)
			draw_rect(Rect2(b.x + 3, y, (b.y - b.x) - 6, 1), col)


## Tint rows from_y..to_y inside the silhouette (inner highlights/shadows).
func _band_overlay(bounds: Callable, from_y: int, to_y: int, col: Color) -> void:
	for y in range(maxi(from_y, 3), mini(to_y, int(size.y) - 3)):
		var b: Vector2 = bounds.call(float(y) + 0.5)
		if b.y - b.x > 6.0:
			draw_rect(Rect2(b.x + 3, y, (b.y - b.x) - 6, 1), col)


func _grad(stops: Array, t: float) -> Color:
	for i in range(stops.size() - 1):
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		if t <= b[0] or i == stops.size() - 2:
			var span: float = maxf(b[0] - a[0], 0.0001)
			return (a[1] as Color).lerp(b[1], clampf((t - a[0]) / span, 0.0, 1.0))
	return stops[-1][1]


func _draw_poly_grad(points: PackedVector2Array, top: Color, bottom: Color, border: Color) -> void:
	var cols := PackedColorArray()
	for p in points:
		cols.append(top.lerp(bottom, clampf(p.y / size.y, 0.0, 1.0)))
	draw_polygon(points, cols)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, border, 3.0)


func _draw_sauce(top: Color, bottom: Color) -> void:
	# zigzag drips along the top edge, flat bottom
	var pts := PackedVector2Array()
	var w := size.x
	var h := size.y
	for i in range(11):
		var x := w * float(i) / 10.0
		var y := h * 0.4 if i % 2 == 0 else 0.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(w, h))
	pts.append(Vector2(0, h))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf(p.y / h, 0.0, 1.0)))
	draw_polygon(pts, cols)


func _cheese_points() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var norm := [[0, 0], [100, 0], [100, 60], [90, 100], [78, 60], [64, 100], [52, 60],
		[40, 100], [28, 60], [15, 100], [5, 60], [0, 70]]
	var pts := PackedVector2Array()
	for p in norm:
		pts.append(Vector2(w * p[0] / 100.0, h * p[1] / 100.0))
	return pts


func _lettuce_points() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var norm := [[0, 35], [8, 0], [18, 40], [28, 0], [38, 40], [48, 0], [58, 40], [68, 0],
		[78, 40], [88, 0], [96, 35], [100, 60], [100, 100], [0, 100]]
	var pts := PackedVector2Array()
	for p in norm:
		pts.append(Vector2(w * p[0] / 100.0, h * p[1] / 100.0))
	return pts


func _fill_ellipse(center: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
