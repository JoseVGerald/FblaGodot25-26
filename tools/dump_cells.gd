extends SceneTree

func _init():
	var root = (load("res://stuff/burgers/burgers.tscn") as PackedScene).instantiate()
	for c in root.get_children():
		if c.name == "Layer_4_4":
			var cells = c.get_used_cells()
			cells.sort()
			print("Layer_4_4 cells: ", cells)
	root.free()
	# also door gap rows: bottom wall cells of Layer_0_7
	var root2 = (load("res://stuff/burgers/burgers.tscn") as PackedScene).instantiate()
	for c in root2.get_children():
		if c.name == "Layer_0_7":
			var bottom: Array = []
			for cell in c.get_used_cells():
				if cell.y >= 10: bottom.append(cell)
			bottom.sort()
			print("Layer_0_7 bottom-wall cells: ", bottom)
	root2.free()
	quit()
