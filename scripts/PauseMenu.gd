# PauseMenu.gd
# Pause menu — button wiring handled by bottom_hud.gd.
# This script applies the cream/maroon pixel-art panel theme.
extends CanvasLayer

func _ready():
	visible = false
	# Apply cream panel style via UITheme helper
	var panel_node = get_node_or_null("Panel")
	if panel_node:
		UITheme.style_panel(panel_node)
	UITheme.apply_overlay_theme(self)
	_style_headers()
	_apply_redesign_styling()

## Colour-code the row buttons per the new pixel-art spec.
func _apply_redesign_styling() -> void:
	var title := get_node_or_null("Panel/VBox/Header/Title")
	if title is Label:
		title.text = "Paused"
		title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	var close_btn := get_node_or_null("Panel/VBox/Header/CloseBtn")
	if close_btn is Button:
		close_btn.text = "✕"
		close_btn.custom_minimum_size = Vector2(64, 64)
		UITheme.style_close_button(close_btn)

	# Balance the close button so the title is truly centered
	var header := get_node_or_null("Panel/VBox/Header")
	if header is HBoxContainer:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(64, 0)
		header.add_child(spacer)
		header.move_child(spacer, 0)

	# Style row buttons with semantic color-coding to avoid flat gray colors
	for node_name in ["SettingsBtn", "HelpBtn", "AchievementsBtn", "ResumeBtn", "QuitBtn"]:
		var b := get_node_or_null("Panel/VBox/" + node_name)
		if b is Button:
			b.add_theme_font_size_override("font_size", 36)
			if node_name == "ResumeBtn":
				UITheme.style_pixel_button_colored(b, UITheme.CLR_GREEN)
			elif node_name == "QuitBtn":
				UITheme.style_pixel_button_colored(b, UITheme.CLR_RED)
			elif node_name == "AchievementsBtn":
				UITheme.style_pixel_button_colored(b, UITheme.CLR_GOLD)
				b.add_theme_color_override("font_color", UITheme.CLR_INK)
				b.add_theme_color_override("font_hover_color", UITheme.CLR_INK)
				b.add_theme_color_override("font_pressed_color", UITheme.CLR_INK)
			else:
				UITheme.style_pixel_button(b, false) # Primary Tan button

## Find labels that look like section headers and colour them maroon-deep.
func _style_headers() -> void:
	var panel_node = get_node_or_null("Panel")
	if not panel_node:
		return
	var vbox = panel_node.get_node_or_null("VBox")
	if not vbox:
		return
	for child in vbox.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					sub.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)

# Updated on 2026-04-19
