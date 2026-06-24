extends Control
func _ready():
	GameState.money = 150.0
	var sm = load("res://scenes/ui/ShopMenu.tscn").instantiate()
	add_child(sm)
	if sm.has_method("show_shop"):
		sm.show_shop()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("res://_shop.png")
	get_tree().quit()
