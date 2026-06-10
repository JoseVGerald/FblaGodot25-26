extends SceneTree

const MAPS = {
	"bank": "res://stuff/bank/bank.tscn",
	"burgers": "res://stuff/burgers/burgers.tscn",
	"house": "res://stuff/house/NewHouse.tscn",
	"post": "res://stuff/post office/post.tscn",
	"shop": "res://stuff/shop/NewShop.tscn",
}
const COLS = 4
const CELLW = 380
const CELLH = 270

func _init():
	call_deferred("_run")

func _run():
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/shots"))
	for key in MAPS:
		await _capture(key, MAPS[key])
	quit()

func _capture(key: String, path: String):
	var ps: PackedScene = load(path)
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.13, 0.18)
	bg.position = Vector2(-100, -100)
	bg.size = Vector2(8000, 8000)
	vp.add_child(bg)
	var container := Node2D.new()
	vp.add_child(container)

	var slots: Array = [ps.instantiate()]  # slot 0 = full map
	var tmp = ps.instantiate()
	for c in tmp.get_children():
		if c is TileMapLayer and c.get_used_cells().size() > 0:
			slots.append(c.duplicate())
	tmp.free()

	for i in slots.size():
		var holder := Node2D.new()
		holder.position = Vector2((i % COLS) * CELLW + 14, float(i / COLS) * CELLH + 14)
		container.add_child(holder)
		holder.add_child(slots[i])

	var rows := ceili(float(slots.size()) / COLS)
	vp.size = Vector2i(COLS * CELLW, rows * CELLH)
	await process_frame
	await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png("res://tools/shots/%s.png" % key)
	print("saved ", key, " slots=", slots.size())
	vp.queue_free()
