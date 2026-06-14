extends Node
## LoanLauncher — autoload that toggles the Bank Blitz "Loan Decision Desk"
## mini-game overlay. Mirrors BurgerLauncher: press K (the "loan_menu" action)
## for a no-pay practice run, or call open_for_work() from the bank manager NPC
## to run a paid shift that credits GameState on completion.

const LOAN_GAME_SCENE: PackedScene = preload("res://loan_minigame/LoanDesk.tscn")

var _layer: CanvasLayer = null

## When true the open game is a real work shift: LDGame credits GameState with
## the shift's commission on completion. The K-key practice mode leaves this
## false so practicing never pays out.
var work_mode: bool = false


func _ready() -> void:
	# Must keep processing while the tree is paused, or K could never close it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("loan_menu"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _layer != null


func toggle() -> void:
	if _layer == null:
		open()
	else:
		close()


## Open the game as a paid work shift (called by the bank manager NPC).
func open_for_work() -> void:
	if _layer != null:
		return
	work_mode = true
	open()


func open() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "LoanGameLayer"
	_layer.layer = 100
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var game: Control = LOAN_GAME_SCENE.instantiate()
	# In a real shift the desk's difficulty climbs with the player's bank-day
	# count, so each in-game work day plays a harder day at the desk.
	if work_mode:
		var gs := get_node_or_null("/root/GameState")
		if gs and "bank_days_completed" in gs:
			game.day = int(gs.bank_days_completed) + 1
	_layer.add_child(game)
	get_tree().root.add_child(_layer)
	get_tree().paused = true


func close() -> void:
	if _layer == null:
		return
	_layer.queue_free()
	_layer = null
	work_mode = false
	get_tree().paused = false
