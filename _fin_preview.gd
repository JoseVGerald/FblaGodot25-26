extends Control
func _ready() -> void:
	GameState.selected_pathway = "adult"
	GameState.money = 1240.0
	GameState.savings_balance = 380.0
	GameState.loan_balance = 1125
	GameState.budget_data["Food"]["spent"] = 45.0
	GameState.budget_data["Vet"]["spent"] = 60.0
	GameState.budget_data["Travel"]["spent"] = 30.0
	var fm = load("res://scenes/ui/FinanceMenu.tscn").instantiate()
	add_child(fm)
	fm.show_menu()
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("res://_fin_overview.png")
	fm._switch_view("BudgetPlanner")
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("res://_fin_budget.png")
	get_tree().quit()
