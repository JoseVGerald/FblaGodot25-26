@tool
class_name BBPlate
extends Control
## Burger Blitz — the serving plate: white dish, rounded underside, hard shadow.

const INK := Color("2a1408")


func _draw() -> void:
	var w := size.x
	var h := size.y
	# hard drop shadow
	_dish(Vector2(0, 6), w, h, Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.18))
	_dish(Vector2.ZERO, w, h, Color("dfe6ea"), INK)


func _dish(off: Vector2, w: float, h: float, fill: Color, border: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(off + Vector2(0, 0))
	pts.append(off + Vector2(w, 0))
	# elliptical underside
	for i in range(1, 24):
		var t := float(i) / 24.0
		var a := t * PI
		pts.append(off + Vector2(w / 2.0 + cos(a) * w / 2.0, sin(a) * h))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(fill)
	draw_polygon(pts, cols)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, border, 3.0)
