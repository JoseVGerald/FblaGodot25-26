# PauseMenu.gd
# Pause menu — button wiring handled by bottom_hud.gd.
# This script applies the navy-blue panel theme and styles headers in cyan.
extends CanvasLayer

const CLR_NAVY := Color("#1a2a4a")
const CLR_SKY  := Color("#4A90D9")
const CLR_CYAN := Color("#53d8fb")

func _ready():
	visible = false
	# Apply navy panel style
	var panel_node = get_node_or_null("Panel")
	if panel_node:
		var sb := StyleBoxFlat.new()
		sb.bg_color     = CLR_NAVY
		sb.border_color = CLR_SKY
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(20)
		if panel_node is PanelContainer or panel_node is Panel:
			panel_node.add_theme_stylebox_override("panel", sb)
		panel_node.modulate.a = 1.0
	UITheme.apply_overlay_theme(self)
	_style_headers()

## Find labels that look like section headers and colour them cyan.
func _style_headers() -> void:
	var panel_node = get_node_or_null("Panel")
	if not panel_node:
		return
	var vbox = panel_node.get_node_or_null("VBox")
	if not vbox:
		return
	for child in vbox.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", CLR_CYAN)
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					sub.add_theme_color_override("font_color", CLR_CYAN)

# Updated on 2026-04-19
