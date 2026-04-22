# COMMIT: Achievements and Catch Minigame Update
extends CanvasLayer

@onready var panel = $PanelContainer
@onready var food_label = $PanelContainer/VBoxContainer/ContentContainer/FoodLabel
@onready var water_label = $PanelContainer/VBoxContainer/ContentContainer/WaterLabel
@onready var medication_label = $PanelContainer/VBoxContainer/ContentContainer/MedicationLabel

# Signal emitted when menu is opened (for tutorial)
signal menu_opened

func _ready():
	UITheme.apply_overlay_theme(self)
	UITheme.style_panel(panel)
	panel.hide()
	_apply_redesign_styling()
	$PanelContainer/VBoxContainer/TitleHBox/CloseButton.pressed.connect(func():
		panel.hide()
	)

## Wrap each supply label in a colored accent card by dropping a StyleBox
## behind it (we use theme overrides on a PanelContainer parent if available,
## else style the label directly via add_theme_stylebox_override("normal")).
func _apply_redesign_styling() -> void:
	var title := get_node_or_null("PanelContainer/VBoxContainer/TitleHBox/Title")
	if title is Label:
		title.text = "Pet Supplies"
		title.add_theme_color_override("font_color", UIColors.BORDER_BLUE)
		title.add_theme_font_size_override("font_size", 46)

	var close_btn := get_node_or_null("PanelContainer/VBoxContainer/TitleHBox/CloseButton")
	if close_btn is Button:
		close_btn.text = "X"
		close_btn.custom_minimum_size = Vector2(64, 64)
		UITheme.style_button(close_btn, UITheme.CLR_RED)

	# Color-code each supply row label with its category accent.
	food_label.add_theme_color_override("font_color", UIColors.BTN_GREEN)
	food_label.add_theme_font_size_override("font_size", 36)
	water_label.add_theme_color_override("font_color", UIColors.BAR_THIRST)
	water_label.add_theme_font_size_override("font_size", 36)
	medication_label.add_theme_color_override("font_color", UIColors.BORDER_BLUE)
	medication_label.add_theme_font_size_override("font_size", 36)

func show_menu():
	panel.show()
	update_ui()
	menu_opened.emit()

func hide_menu():
	panel.hide()

func toggle_menu():
	if panel.visible:
		hide_menu()
	else:
		show_menu()

func _process(_delta):
	if panel.visible:
		update_ui()
	
	if Input.is_action_just_pressed("ui_cancel") and panel.visible:
		hide_menu()

func update_ui():
	# Display supplies from GameState
	if GameState.food == 0:
		food_label.text = "Food: 0 days left"
	elif GameState.food == 1:
		food_label.text = "Food: 1 day left"
	else:
		food_label.text = "Food: %d days left" % GameState.food

	if GameState.water == 0:
		water_label.text = "Water: 0 days left"
	elif GameState.water == 1:
		water_label.text = "Water: 1 day left"
	else:
		water_label.text = "Water: %d days left" % GameState.water

	if GameState.medication == "none":
		medication_label.text = "Medication: none prescribed"
	else:
		medication_label.text = "Medication: %s" % GameState.medication

	_update_low_badges()

## Show LOW state (red text + badge + warning strip) when food/water drop under 5 days.
## Badges and warning strip are optional — no-op gracefully if those nodes haven't
## been added to the scene yet. Labels always get the colour update.
func _update_low_badges() -> void:
	var food_low  := GameState.food  < 5
	var water_low := GameState.water < 5

	food_label.add_theme_color_override("font_color",
		UIColors.BTN_RED if food_low else UIColors.TEXT_WHITE)
	water_label.add_theme_color_override("font_color",
		UIColors.BTN_RED if water_low else UIColors.TEXT_WHITE)

	var food_badge  := get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/FoodRow/LowBadge")
	var water_badge := get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/WaterRow/LowBadge")
	if food_badge  is Control: food_badge.visible  = food_low
	if water_badge is Control: water_badge.visible = water_low

	var strip := get_node_or_null("PanelContainer/VBoxContainer/ContentContainer/WarningStrip")
	if strip is Control: strip.visible = food_low or water_low

func get_menu_visible() -> bool:
	return panel.visible

# Updated on 2026-04-19
