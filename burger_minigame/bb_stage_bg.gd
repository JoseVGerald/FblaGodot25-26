@tool
class_name BBStageBG
extends Control
## Burger Blitz — diner backdrop: warm radial glow + faint 45° checker tiles.


func _draw() -> void:
	var w := size.x
	var h := size.y
	# radial-ish glow from top center: #3a281a -> #2a1d12 -> #1c130c
	var bands := 36
	var focus := Vector2(w * 0.5, -h * 0.1)
	var max_d := (Vector2(0, h) - focus).length()
	for i in range(bands, 0, -1):
		var t := float(i) / float(bands)
		var col: Color
		if t < 0.45:
			col = Color("3a281a").lerp(Color("2a1d12"), t / 0.45)
		else:
			col = Color("2a1d12").lerp(Color("1c130c"), (t - 0.45) / 0.55)
		_ring(focus, max_d * t, col)
	# checker texture (45° diamonds), barely visible
	var cell := 28.3  # 40px checker rotated 45°
	var diamond := Color(1, 1, 1, 0.03)
	var y := 0.0
	var row := 0
	while y < h + cell:
		var x := (cell if row % 2 == 1 else 0.0)
		while x < w + cell:
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - cell), Vector2(x + cell, y), Vector2(x, y + cell), Vector2(x - cell, y),
			]), diamond)
			x += cell * 2.0
		y += cell
		row += 1


func _ring(center: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(40):
		var a := TAU * float(i) / 40.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, col)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
