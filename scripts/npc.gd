# COMMIT: Achievements and Catch Minigame Update
extends CharacterBody2D

@export var dialogue_resource: DialogueResource
@export var dialugue_start: String = "start"

var finished: bool = false
var player_can_move: bool = true
var player_in_range: bool = false

@onready var label = get_node_or_null("CanvasLayer/Label")

func _ready():
	if label:
		label.hide()

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		# Only one conversation at a time — if a balloon is already open, the
		# player must close it (press E on the line) before starting another.
		if GameState.is_dialogue_active:
			return
		if not finished:
			GameState.npcs_talked += 1
			GameState.check_achievements()
		DialogueManager.show_example_dialogue_balloon(dialogue_resource, dialugue_start)
		finished = true

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		if label:
			label.show()

func _on_area_2d_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		if label:
			label.hide()

# Updated on 2026-04-19
