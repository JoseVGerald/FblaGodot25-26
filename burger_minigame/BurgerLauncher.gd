extends Node
## BurgerLauncher — autoload that toggles the Burger Blitz mini-game overlay
## when the player presses L (the "burger_menu" input action).

const BURGER_GAME_SCENE: PackedScene = preload("res://burger_minigame/BurgerBlitz.tscn")

var _layer: CanvasLayer = null


func _ready() -> void:
	# Must keep processing while the tree is paused, or L could never close it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("burger_menu"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _layer != null


func toggle() -> void:
	if _layer == null:
		open()
	else:
		close()


func open() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "BurgerGameLayer"
	_layer.layer = 100
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var game: Control = BURGER_GAME_SCENE.instantiate()
	_layer.add_child(game)
	get_tree().root.add_child(_layer)
	get_tree().paused = true


func close() -> void:
	if _layer == null:
		return
	_layer.queue_free()
	_layer = null
	get_tree().paused = false
