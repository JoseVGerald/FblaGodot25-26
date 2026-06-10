extends SceneTree

const MAPS = {
	"bank": "res://stuff/bank/bank.tscn",
	"burgers": "res://stuff/burgers/burgers.tscn",
	"house": "res://stuff/house/NewHouse.tscn",
	"post": "res://stuff/post office/post.tscn",
	"shop": "res://stuff/shop/NewShop.tscn",
}

func _init():
	for key in MAPS:
		var ps: PackedScene = load(MAPS[key])
		if ps == null:
			print("FAILED to load ", MAPS[key]); continue
		var root = ps.instantiate()
		print("\n=== ", key, " ===")
		_walk(root, "")
		root.free()
	quit()

func _walk(n: Node, indent: String):
	var info = indent + n.name + " (" + n.get_class() + ")"
	if n is TileMapLayer:
		var r: Rect2i = n.get_used_rect()
		var ts = n.tile_set.tile_size if n.tile_set else Vector2i.ZERO
		info += "  rect=%s cells=%d tile=%s pos=%s" % [str(r), n.get_used_cells().size(), str(ts), str(n.position)]
	print(info)
	for c in n.get_children():
		_walk(c, indent + "  ")
