extends Node
## Captures the rebranded Help popup + Keybinds overlays to PNG for visual review.
## Run (windowed): godot --path . res://tools/MenuShots.tscn

const OUT_DIR := "/tmp/menu_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# Cream checker backdrop so the overlays render over the real game vibe.
	var bg := UITheme.create_checker_bg()
	add_child(bg)

	# ── Keybinds ────────────────────────────────────────────────────────────
	var kb_scene: PackedScene = load("res://scenes/ui/KeybindsMenu.tscn")
	var kb := kb_scene.instantiate()
	add_child(kb)
	await _settle()
	await _snap("keybinds")
	kb.queue_free()
	await _settle()

	# ── Help popup (welcome state) ──────────────────────────────────────────
	var help_scene: PackedScene = load("res://scenes/ui/HelpPopup.tscn")
	var help := help_scene.instantiate()
	add_child(help)
	await _settle()
	await _snap("help_welcome")

	# ── Help popup (with a chat exchange) to verify bubble colours ──────────
	help.add_chat_message("How do I feed my dog?", true)
	help.add_chat_message("Press 1 while your dog is following you — it'll run to the food bowl. Buy food from the shop first.", false)
	await _settle()
	await _snap("help_chat")

	get_tree().quit(0)


func _settle() -> void:
	for i in range(8):
		await get_tree().process_frame


func _snap(tag: String) -> void:
	for i in range(4):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, tag])
	print("SAVED %s/%s.png" % [OUT_DIR, tag])
