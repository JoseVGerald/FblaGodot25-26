# shop_menu.gd
# Shop / purchase screen — buy food, water, and prescriptions.
# Redesigned to match the game's navy-blue / sky-blue pixel-art identity.
extends CanvasLayer
signal shop_closed

# ── Colour palette ─────────────────────────────────────────────────────────────
const CLR_NAVY  := Color("#1a2a4a")
const CLR_SKY   := Color("#4A90D9")
const CLR_GREEN := Color("#4CAF50")
const CLR_RED   := Color("#EF5350")

@onready var food_count_label   = $Panel/VBox/Items/FoodItem/Controls/Count
@onready var water_count_label  = $Panel/VBox/Items/WaterItem/Controls/Count
@onready var total_label        = $Panel/VBox/Footer/TotalLabel
@onready var prescription_item  = $Panel/VBox/Items/PrescriptionItem
@onready var prescription_check = $Panel/VBox/Items/PrescriptionItem/CheckBox
@onready var food_label         = $Panel/VBox/Items/FoodItem/Label
@onready var water_label        = $Panel/VBox/Items/WaterItem/Label

var FOOD_PRICE: int:
	get: return GameState.food_cost
var WATER_PRICE: int:
	get: return GameState.water_cost
var PRESCRIPTION_PRICE: int:
	get: return GameState.medicine_cost

var food_cart_count      := 0
var water_cart_count     := 0
var prescription_selected := false

func _ready():
	# Apply navy-blue opaque panel style
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
	visible = false
	update_ui()

func show_shop():
	GameState.store_visit_count += 1
	GameState.check_achievements()
	food_cart_count  = 0
	water_cart_count = 0
	food_label.text  = "Dog food (Lasts for 5 days)    $" + str(GameState.food_cost)
	water_label.text = "Water (Lasts for 5 days)    $" + str(GameState.water_cost)
	prescription_check.text = "Prescription: $" + str(GameState.medicine_cost)
	prescription_item.visible = GameState.has_prescription and GameState.medication != "Antibiotics (5 days)"
	if prescription_item.visible:
		prescription_selected = true
		prescription_check.button_pressed = true
	else:
		prescription_selected = false
		prescription_check.button_pressed = false
	update_ui()
	visible = true
	get_tree().paused = true

func update_ui():
	food_count_label.text  = str(food_cart_count)
	water_count_label.text = str(water_cart_count)
	var total = (food_cart_count * GameState.food_cost) + (water_cart_count * GameState.water_cost)
	if prescription_selected:
		total += GameState.medicine_cost
	total_label.text = "Total: $" + str(total)
	# Green if affordable, red if too expensive
	if total <= GameState.money:
		total_label.add_theme_color_override("font_color", CLR_GREEN)
	else:
		total_label.add_theme_color_override("font_color", CLR_RED)

func _on_close_btn_pressed():
	visible = false
	get_tree().paused = false
	shop_closed.emit()

func _on_food_plus_pressed():
	food_cart_count += 1
	update_ui()

func _on_food_minus_pressed():
	if food_cart_count > 0:
		food_cart_count -= 1
		update_ui()

func _on_water_plus_pressed():
	water_cart_count += 1
	update_ui()

func _on_water_minus_pressed():
	if water_cart_count > 0:
		water_cart_count -= 1
		update_ui()

func _on_prescription_toggled(toggled_on):
	prescription_selected = toggled_on
	update_ui()

func _on_purchase_pressed():
	var total = (food_cart_count * FOOD_PRICE) + (water_cart_count * WATER_PRICE)
	if prescription_selected:
		total += PRESCRIPTION_PRICE
	if total == 0:
		return
	if GameState.money >= total:
		var success = true
		if food_cart_count > 0:
			success = GameState.spend_money(food_cart_count * GameState.food_cost, "Food")
		if success and water_cart_count > 0:
			success = GameState.spend_money(water_cart_count * GameState.water_cost, "Food")
		if success and prescription_selected:
			success = GameState.spend_money(GameState.medicine_cost, "Vet")
			if success:
				GameState.times_medicated += 1
				GameState.medication = "Antibiotics (5 days)"
				GameState.has_prescription = false
				var dog = get_tree().get_first_node_in_group("dog")
				if dog:
					dog.health = min(100, dog.health + 40)
		if success:
			GameState.food  += (food_cart_count * 5)
			GameState.water += (water_cart_count * 5)
			print("Purchase successful!")
			visible = false
			get_tree().paused = false
			shop_closed.emit()
	else:
		print("Not enough money!")
