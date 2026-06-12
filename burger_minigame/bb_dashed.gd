@tool
class_name BBDashedRect
extends Control
## Burger Blitz — dashed rounded border (empty grill slot outline).

var line_color := Color("5a564f")
var line_width := 3.0
var dash := 8.0


func _draw() -> void:
	var r := Rect2(Vector2(line_width / 2.0, line_width / 2.0), size - Vector2(line_width, line_width))
	var tl := r.position
	var tr_ := r.position + Vector2(r.size.x, 0)
	var br := r.position + r.size
	var bl := r.position + Vector2(0, r.size.y)
	draw_dashed_line(tl, tr_, line_color, line_width, dash)
	draw_dashed_line(tr_, br, line_color, line_width, dash)
	draw_dashed_line(br, bl, line_color, line_width, dash)
	draw_dashed_line(bl, tl, line_color, line_width, dash)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
