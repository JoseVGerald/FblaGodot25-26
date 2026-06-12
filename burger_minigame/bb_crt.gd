@tool
class_name BBCrt
extends Control
## Burger Blitz — CRT overlay: scanlines + corner vignette.


func _draw() -> void:
	var w := size.x
	var h := size.y
	var y := 0.0
	while y < h:
		draw_rect(Rect2(0, y, w, 1), Color(0, 0, 0, 0.16))
		y += 3.0
	# vignette: darken edges
	var steps := 10
	for i in range(steps):
		var t := float(i) / float(steps)
		var a := 0.45 * t * t * 0.5
		var inset := (1.0 - t) * 0.0
		var border := 60.0 * (1.0 - t)
		draw_rect(Rect2(0, 0, w, border * 0.5), Color(0, 0, 0, a * 0.22))
		draw_rect(Rect2(0, h - border * 0.5, w, border * 0.5), Color(0, 0, 0, a * 0.22))
		draw_rect(Rect2(0, 0, border * 0.5, h), Color(0, 0, 0, a * 0.22))
		draw_rect(Rect2(w - border * 0.5, 0, border * 0.5, h), Color(0, 0, 0, a * 0.22))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
