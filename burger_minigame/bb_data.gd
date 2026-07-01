@tool
class_name BBData
extends RefCounted
## Burger Blitz — ingredient tables, cook model and order generation.
## Direct port of the reference data.js.

const INGREDIENTS := {
	"bunBottom": {"name": "Bottom Bun", "key": "Q"},
	"cheese": {"name": "Cheese", "key": "1"},
	"lettuce": {"name": "Lettuce", "key": "2"},
	"tomato": {"name": "Tomato", "key": "3"},
	"onion": {"name": "Onion", "key": "4"},
	"pickle": {"name": "Pickle", "key": "5"},
	"ketchup": {"name": "Ketchup", "key": "6"},
	"mustard": {"name": "Mustard", "key": "7"},
	"bunTop": {"name": "Top Bun", "key": "E"},
}
const BIN_ORDER := ["bunBottom", "cheese", "lettuce", "tomato", "onion", "pickle", "ketchup", "mustard", "bunTop"]
const TOPPING_POOL := ["cheese", "lettuce", "tomato", "onion", "pickle", "ketchup", "mustard"]

const COOK_MAX := 124.0
const COOK_RATE := 16.0  # cook units per second

# [label, from, to, bar color]
const COOK_ZONES := [
	["Raw", 0.0, 28.0, Color("c9b6a0")],
	["Rare", 28.0, 52.0, Color("d8736a")],
	["Medium", 52.0, 78.0, Color("9c5a31")],
	["Well", 78.0, 104.0, Color("5e3219")],
	["Burnt", 104.0, 124.0, Color("241712")],
]

const DONE_TAG_COLOR := {
	"Rare": Color("c25b50"), "Medium": Color("b07a2e"),
	"Well": Color("4d8a32"), "Burnt": Color("444444"),
}

# ticket dot swatches
const SWATCH := {
	"bunBottom": Color("e8b465"), "bunTop": Color("e8b465"), "patty": Color("7a3f22"),
	"cheese": Color("f4c13d"), "lettuce": Color("6fb24a"), "tomato": Color("d8453b"),
	"onion": Color("cda7d6"), "pickle": Color("7ba23a"), "ketchup": Color("e0463b"),
	"mustard": Color("f4c13d"),
}

const CRUMB_COLORS := {
	"bunBottom": [Color("e8b465"), Color("cf9341"), Color("fff2cf")],
	"bunTop": [Color("e8b465"), Color("cf9341"), Color("fff2cf")],
	"patty": [Color("7a3f22"), Color("5c2d14"), Color("3a1d0b")],
	"cheese": [Color("f4c13d"), Color("ffd75e")],
	"lettuce": [Color("6fb24a"), Color("9ed06e")],
	"tomato": [Color("d8453b"), Color("ef837a")],
	"onion": [Color("cda7d6"), Color("efe0f3")],
	"pickle": [Color("7ba23a"), Color("b8d97a")],
	"ketchup": [Color("e0463b"), Color("ef6a5e")],
	"mustard": [Color("f4c13d"), Color("ffd75e")],
}

const NAMES := ["Rex", "Gabby", "Mort", "Olive", "Buzz", "Penny", "Hank", "Lulu", "Dwight", "Coco",
	"Sven", "Mabel", "Tito", "Bex", "Cliff", "Dot", "Gus", "Vera", "Roscoe", "Mimi",
	"Wade", "Pip", "Nash", "Trudy"]


static func doneness_from_cook(c: float) -> String:
	if c < 28.0:
		return "Raw"
	if c < 52.0:
		return "Rare"
	if c < 78.0:
		return "Medium"
	if c < 104.0:
		return "Well"
	return "Burnt"


static func label_of(type: String) -> String:
	if type == "patty":
		return "Patty"
	if INGREDIENTS.has(type):
		return INGREDIENTS[type]["name"]
	return type


## order: { name, items:[{type[,doneness]}], avatar_seed, base_pay, patience_max, patience, mood }
static func generate_order(day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# First shift: fixed tutorial order every time
	if day == 1:
		return {
			"name": NAMES[rng.randi() % NAMES.size()],
			"items": [
				{"type": "bunBottom"},
				{"type": "patty", "doneness": "Rare"},
				{"type": "tomato"},
				{"type": "lettuce"},
				{"type": "cheese"},
				{"type": "bunTop"},
			],
			"avatar_seed": rng.randi(),
			"base_pay": 8.4,
			"patience_max": 39.5,
			"patience": 39.5,
			"mood": "neutral",
			"resolved": false,
		}

	var items: Array = [{"type": "bunBottom"}]

	var doneness_opts: Array = ["Rare", "Medium", "Well"] if day >= 2 else ["Medium", "Well"]
	var num_patties: int = 2 if (day >= 2 and rng.randf() < 0.35 + day * 0.03) else 1

	var max_top: int = mini(2 + day, 5)
	var num_top: int = 1 + (rng.randi() % max_top)
	var pool := TOPPING_POOL.duplicate()
	var tops: Array = []
	for i in range(num_top):
		if pool.is_empty():
			break
		tops.append(pool.pop_at(rng.randi() % pool.size()))

	var middle: Array = []
	for i in range(num_patties):
		middle.append({"type": "patty", "doneness": doneness_opts[rng.randi() % doneness_opts.size()]})
	for t in tops:
		middle.append({"type": t})
	middle.shuffle()
	# keep one patty near the bottom for realism
	var fp := -1
	for i in range(middle.size()):
		if middle[i]["type"] == "patty":
			fp = i
			break
	if fp > 0:
		var p: Dictionary = middle.pop_at(fp)
		middle.push_front(p)

	items.append_array(middle)
	items.append({"type": "bunTop"})

	var base_pay: float = 3.0 + items.size() * 0.6 + num_patties * 0.8
	var patience: float = maxf(20.0, 42.0 - day * 2.5)

	return {
		"name": NAMES[rng.randi() % NAMES.size()],
		"items": items,
		"avatar_seed": rng.randi(),
		"base_pay": snappedf(base_pay, 0.01),
		"patience_max": patience,
		"patience": patience,
		"mood": "neutral",
		"resolved": false,
	}


## Returns { overall, stars, label, mood, points }
static func score_build(build: Array, order: Dictionary) -> Dictionary:
	var want: Array = order["items"]
	var got: Array = build
	var l: int = maxi(want.size(), got.size())
	var correct := 0
	for i in range(l):
		if i < want.size() and i < got.size() and want[i]["type"] == got[i]["type"]:
			correct += 1
	var item_score: float = (float(correct) / float(l)) if want.size() > 0 else 0.0

	var p_want := 0
	var p_right := 0
	for i in range(want.size()):
		if want[i]["type"] == "patty":
			p_want += 1
			if i < got.size() and got[i]["type"] == "patty" and got[i].get("doneness", "") == want[i]["doneness"]:
				p_right += 1
	var done_score: float = (float(p_right) / float(p_want)) if p_want > 0 else 1.0
	var overall := item_score * 0.72 + done_score * 0.28

	var stars: int
	var lbl: String
	var mood: String
	if overall >= 0.965:
		stars = 3; lbl = "PERFECT!"; mood = "happy"
	elif overall >= 0.8:
		stars = 2; lbl = "GREAT"; mood = "happy"
	elif overall >= 0.55:
		stars = 1; lbl = "OKAY"; mood = "neutral"
	else:
		stars = 0; lbl = "WRONG ORDER"; mood = "angry"
	var points := roundi(overall * 100.0) + stars * 25
	return {"overall": overall, "stars": stars, "label": lbl, "mood": mood, "points": points}


static func fmt_money(n: float) -> String:
	return "$%.2f" % snappedf(n, 0.01)
