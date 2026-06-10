extends SceneTree

const MAPS = {
	"bank": "res://stuff/bank/bank.tscn",
	"burgers": "res://stuff/burgers/burgers.tscn",
	"house": "res://stuff/house/NewHouse.tscn",
	"post": "res://stuff/post office/post.tscn",
	"shop": "res://stuff/shop/NewShop.tscn",
}

func _init():
	call_deferred("_run")

func _run():
	await process_frame
	for key in MAPS:
		await _capture(key, MAPS[key])
	quit()

func _capture(key: String, path: String):
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.13, 0.18)
	bg.position = Vector2(-100, -100); bg.size = Vector2(8000, 8000)
	vp.add_child(bg)
	var holder := Node2D.new()
	holder.scale = Vector2(3, 3)   # 3x zoom for inspection
	holder.position = Vector2(12, 12)
	vp.add_child(holder)
	var inst = (load(path) as PackedScene).instantiate()
	holder.add_child(inst)
	var w := 0.0; var h := 0.0
	var body: Node = inst.get_node_or_null("MapCollisions")
	if body:
		for cs in body.get_children():
			if cs is CollisionShape2D and cs.shape is RectangleShape2D:
				var r := ColorRect.new()
				r.color = Color(1, 0.1, 0.1, 0.45)
				r.size = cs.shape.size
				r.position = cs.position - cs.shape.size / 2.0
				inst.add_child(r)
				w = maxf(w, cs.position.x + cs.shape.size.x); h = maxf(h, cs.position.y + cs.shape.size.y)
	vp.size = Vector2i(int(w * 3) + 80, int(h * 3) + 80)
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("res://tools/shots/verify_%s.png" % key)
	print("verified ", key)
	vp.queue_free()
