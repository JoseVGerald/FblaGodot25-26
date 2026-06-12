@tool
class_name BBGrillSurface
extends Control
## Burger Blitz — grill plate: vertical metal stripes, ink frame, inner top shadow.


func _draw() -> void:
	var w := size.x
	var h := size.y
	# stripes: 8px #23211f / 8px #171615
	var x := 0.0
	var i := 0
	while x < w:
		draw_rect(Rect2(x, 0, minf(8.0, w - x), h), Color("23211f") if i % 2 == 0 else Color("171615"))
		x += 8.0
		i += 1
	# inner top shadow
	for s in range(10):
		draw_rect(Rect2(0, s, w, 1), Color(0, 0, 0, 0.45 * (1.0 - float(s) / 10.0)))
	# frame (4px ink, rounded 6)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(4)
	sb.border_color = Color("2a1408")
	sb.set_corner_radius_all(6)
	sb.anti_aliasing = false
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
