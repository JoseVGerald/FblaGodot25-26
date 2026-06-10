extends SceneTree

const CONFIG = {
	"bank":    { "path": "res://stuff/bank/bank.tscn",          "skip": ["Layer_0_10", "NPC_LAYER_HERE_7"], "exclude": [] },
	"burgers": { "path": "res://stuff/burgers/burgers.tscn",    "skip": ["Layer_3_8"],                       "exclude": [Vector2i(5, 11), Vector2i(6, 11)] },
	"house":   { "path": "res://stuff/house/NewHouse.tscn",     "skip": ["Layer_8_9", "Wall_Art_3", "Dogs_Stuff_0"], "exclude": [] },
	"post":    { "path": "res://stuff/post office/post.tscn",   "skip": ["Floor_9"],                         "exclude": [] },
	"shop":    { "path": "res://stuff/shop/NewShop.tscn",       "skip": ["Layer_7_5"],                       "exclude": [] },
}
const TILE := 16

func _init():
	for key in CONFIG:
		var cfg = CONFIG[key]
		var root = (load(cfg.path) as PackedScene).instantiate()
		var cells := {}
		for c in root.get_children():
			if c is TileMapLayer and not cfg.skip.has(String(c.name)):
				for cell in c.get_used_cells():
					cells[cell] = true
		for ex in cfg.exclude:
			cells.erase(ex)
		root.free()
		var rects := _merge(cells)
		_emit(key, rects)
		print(key, ": ", cells.size(), " solid cells -> ", rects.size(), " rects")
	quit()

# Greedy: horizontal runs per row, then merge identical runs on consecutive rows.
func _merge(cells: Dictionary) -> Array:
	var ymin := 99999; var ymax := -99999
	for c in cells:
		ymin = mini(ymin, c.y); ymax = maxi(ymax, c.y)
	var rects: Array = []
	var prev := {}  # "x0:x1" -> rect index
	for y in range(ymin, ymax + 1):
		var xs: Array = []
		for c in cells:
			if c.y == y: xs.append(c.x)
		xs.sort()
		var runs: Array = []
		var i := 0
		while i < xs.size():
			var x0: int = xs[i]
			var x1: int = x0
			while i + 1 < xs.size() and xs[i + 1] == x1 + 1:
				i += 1; x1 = xs[i]
			runs.append([x0, x1])
			i += 1
		var cur := {}
		for run in runs:
			var rkey := "%d:%d" % [run[0], run[1]]
			if prev.has(rkey):
				var idx: int = prev[rkey]
				rects[idx].h += 1
				cur[rkey] = idx
			else:
				rects.append({ "x": run[0], "y": y, "w": run[1] - run[0] + 1, "h": 1 })
				cur[rkey] = rects.size() - 1
		prev = cur
	return rects

func _emit(key: String, rects: Array):
	# dedupe shapes by size
	var sizes := {}   # "WxH" -> shape id
	var subs := ""
	var nodes := "\n[node name=\"MapCollisions\" type=\"StaticBody2D\" parent=\".\"]\n"
	var n := 0
	for r in rects:
		var skey := "%dx%d" % [r.w, r.h]
		if not sizes.has(skey):
			sizes[skey] = "RectangleShape2D_col%s" % skey
			subs += "\n[sub_resource type=\"RectangleShape2D\" id=\"%s\"]\nsize = Vector2(%d, %d)\n" % [sizes[skey], r.w * TILE, r.h * TILE]
		var cx: float = (r.x + r.w / 2.0) * TILE
		var cy: float = (r.y + r.h / 2.0) * TILE
		nodes += "\n[node name=\"C%d\" type=\"CollisionShape2D\" parent=\"MapCollisions\"]\nposition = Vector2(%s, %s)\nshape = SubResource(\"%s\")\n" % [n, cx, cy, sizes[skey]]
		n += 1
	var f := FileAccess.open("res://tools/gen/%s.subs.txt" % key, FileAccess.WRITE)
	f.store_string(subs); f.close()
	f = FileAccess.open("res://tools/gen/%s.nodes.txt" % key, FileAccess.WRITE)
	f.store_string(nodes); f.close()
