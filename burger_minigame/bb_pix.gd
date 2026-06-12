@tool
class_name BBPix
extends RefCounted
## Burger Blitz — procedural pixel-art textures (patties + customer avatars).
## Port of the reference canvas painters (paintPatty / makeAvatar).

const PATTY_PAL := {
	"Raw": {"base": Color("c0584a"), "dark": Color("94392f"), "light": Color("d98270"), "edge": Color("160b05")},
	"Rare": {"base": Color("a8503a"), "dark": Color("7a3122"), "light": Color("c47a5e"), "edge": Color("160b05")},
	"Medium": {"base": Color("8a4a28"), "dark": Color("5c2d14"), "light": Color("aa6b3c"), "edge": Color("160b05")},
	"Well": {"base": Color("5e3219"), "dark": Color("3a1d0b"), "light": Color("7c4c26"), "edge": Color("160b05")},
	"Burnt": {"base": Color("291a10"), "dark": Color("120a05"), "light": Color("3d2a18"), "edge": Color("0a0503")},
}

const SKIN := [Color("f2c79b"), Color("e0a875"), Color("c98a55"), Color("a3683c"), Color("7a4a28")]
const HAIR := [Color("2a1a0e"), Color("4a2c14"), Color("6b3e1c"), Color("8a5a2a"), Color("b07636"),
	Color("d9a441"), Color("999999"), Color("3a2a4a"), Color("7a2a2a"), Color("2a4a3a")]
const SHIRT := [Color("e0463b"), Color("4f8ccc"), Color("6fb24a"), Color("f4c13d"), Color("b76fc4"),
	Color("e07ba0"), Color("46c0c0"), Color("e88a3c")]
const AV_BG := [Color("cfe3a0"), Color("a0d4e3"), Color("e3c2a0"), Color("e3a0c2"), Color("bfb0e3")]


static func patty_texture(doneness: String, w: int, h: int, seed_val: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var pal: Dictionary = PATTY_PAL.get(doneness, PATTY_PAL["Medium"])
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var inset := 0
		if y == 0 or y == h - 1:
			inset = 2
		elif y == 1 or y == h - 2:
			inset = 1
		for x in range(inset, w - inset):
			var c: Color = pal["base"]
			if y == 0 or y == h - 1 or x == inset or x == w - 1 - inset:
				c = pal["edge"]
			elif y == 1:
				c = pal["light"]
			elif y >= h - 2:
				c = pal["dark"]
			else:
				var rv := rng.randf()
				if rv < 0.11:
					c = pal["dark"]
				elif rv > 0.93:
					c = pal["light"]
			img.set_pixel(x, y, c)
	# char / grill marks on cooked patties
	if doneness != "Raw":
		var marks: int = 2 + (rng.randi() % 3)
		for i in range(marks):
			var mx: int = 3 + (rng.randi() % maxi(w - 9, 1))
			var my: int = 2 + (rng.randi() % maxi(h - 4, 1))
			var length: int = 2 + (rng.randi() % 3)
			for dx in range(length):
				if mx + dx < w:
					img.set_pixel(mx + dx, my, pal["dark"])
	return ImageTexture.create_from_image(img)


## 16x16 pixel customer face. mood: "neutral" | "happy" | "angry"
static func avatar_texture(seed_val: int, mood: String) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var sz := 16
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var skin: Color = SKIN[rng.randi() % SKIN.size()]
	var hair: Color = HAIR[rng.randi() % HAIR.size()]
	var shirt: Color = SHIRT[rng.randi() % SHIRT.size()]
	var bg: Color = AV_BG[rng.randi() % AV_BG.size()]
	img.fill(bg)
	_rect(img, 2, 13, 12, 3, shirt)            # shirt
	_rect(img, 4, 4, 8, 9, skin)               # head
	_rect(img, 3, 3, 10, 3, hair)              # hair
	_rect(img, 3, 4, 2, 5, hair)
	_rect(img, 11, 4, 2, 5, hair)
	var ink := Color("1a120b")
	if mood == "angry":
		_rect(img, 5, 7, 2, 1, ink)
		_rect(img, 9, 7, 2, 1, ink)
		_rect(img, 5, 6, 1, 1, ink)
		_rect(img, 10, 6, 1, 1, ink)
	else:
		_rect(img, 5, 7, 2, 2, ink)
		_rect(img, 9, 7, 2, 2, ink)
	if mood == "happy":
		_rect(img, 6, 10, 4, 1, ink)
		_rect(img, 5, 9, 1, 1, ink)
		_rect(img, 10, 9, 1, 1, ink)
	elif mood == "angry":
		_rect(img, 6, 11, 4, 1, ink)
		_rect(img, 5, 10, 1, 1, ink)
		_rect(img, 10, 10, 1, 1, ink)
		_rect(img, 13, 5, 2, 3, Color("cc4b3a"))  # steam mark
	else:
		_rect(img, 6, 10, 4, 1, ink)
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, mini(y + h, img.get_height())):
		for xx in range(x, mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, c)


## TextureRect wrapper that keeps pixels crisp at any scale.
static func tex_rect(tex: Texture2D, display_size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = display_size
	tr.size = display_size
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
