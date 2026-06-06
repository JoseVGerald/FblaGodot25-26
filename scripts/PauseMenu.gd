# PauseMenu.gd
# Pause menu — button wiring handled by bottom_hud.gd.
# This script applies the navy-blue panel theme and styles headers in cyan.
extends CanvasLayer

const CLR_NAVY := Color("#1a2a4a")
const CLR_SKY  := Color("#4A90D9")
const CLR_CYAN := Color("#53d8fb")

func _ready():
	visible = false
	
	var panel_node = get_node_or_null("Panel")
	if panel_node:
		var map = load("res://New Ui/FINAL PAUSE/Map.tscn").instantiate()
		map.scale = Vector2(7.5, 7.5)
		if map.has_node("Layer_1_1"):
			map.get_node("Layer_1_1").queue_free()
		
		var bg = Node2D.new()
		bg.name = "Backdrop"
		bg.add_child(map)
		panel_node.add_child(bg)
		panel_node.move_child(bg, 0)
		panel_node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	UITheme.apply_overlay_theme(self)
	_style_headers()
	_apply_redesign_styling()

## Colour-code the row buttons per the redesign spec.
func _apply_redesign_styling() -> void:
	var title := get_node_or_null("Panel/VBox/Header/Title")
	if title is Label:
		title.text = "Paused"
		title.add_theme_color_override("font_color", UITheme.CLR_INK)
	
	var close_btn := get_node_or_null("Panel/VBox/Header/CloseBtn")
	if close_btn is Button:
		close_btn.text = "X"
		close_btn.custom_minimum_size = Vector2(64, 64)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("#ef5350")
		sb.border_color = UITheme.CLR_INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		close_btn.add_theme_stylebox_override("normal", sb)
		close_btn.add_theme_stylebox_override("hover", sb)
		close_btn.add_theme_stylebox_override("pressed", sb)
		UITheme._do_juice_on(close_btn)

	var row_colors := {
		"SettingsBtn":     UIColors.BORDER_BLUE,
		"HelpBtn":         UIColors.ACCENT_CYAN,
		"AchievementsBtn": UIColors.GOLD,
		"ResumeBtn":       UIColors.BTN_GREEN,
		"QuitBtn":         UIColors.BTN_RED,
	}
	for node_name in row_colors.keys():
		var b := get_node_or_null("Panel/VBox/" + node_name)
		if b is Button:
			UITheme.style_pixel_button(b, true)
			b.add_theme_font_size_override("font_size", 36)

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
