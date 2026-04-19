# chore_menu.gd
# Chore quiz minigame — asks math multiplication questions and rewards cash.
# Redesigned to match the game's navy-blue / green pixel-art identity.
extends CanvasLayer

const CLR_NAVY  := Color("#1a2a4a")
const CLR_SKY   := Color("#4A90D9")
const CLR_GREEN := Color("#4CAF50")
const CLR_RED   := Color("#EF5350")
const CLR_WHITE := Color.WHITE

@onready var question_label = $Panel/VBoxContainer/QuestionLabel
@onready var answer_input   = $Panel/VBoxContainer/AnswerInput
@onready var result_label   = $Panel/VBoxContainer/ResultLabel

var num1   : int
var num2   : int
var answer : int

func _ready():
	# Apply navy panel style
	var panel_node = get_node_or_null("Panel")
	if panel_node:
		var sb := StyleBoxFlat.new()
		sb.bg_color     = CLR_NAVY
		sb.border_color = CLR_SKY
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(20)
		if panel_node is PanelContainer or panel_node is Panel:
			panel_node.add_theme_stylebox_override("panel", sb)
		panel_node.modulate.a = 1.0
	UITheme.apply_overlay_theme(self)
	$Panel/VBoxContainer/SubmitButton.pressed.connect(_on_submit)
	$Panel/VBoxContainer/CloseButton.pressed.connect(queue_free)
	get_tree().paused = true
	generate_question()

func _exit_tree():
	get_tree().paused = false

func generate_question():
	num1   = randi() % 12 + 1
	num2   = randi() % 12 + 1
	answer = num1 * num2
	question_label.text = "Solve: " + str(num1) + " x " + str(num2) + " ="
	question_label.add_theme_color_override("font_color", CLR_WHITE)
	answer_input.text = ""
	answer_input.grab_focus()

func _on_submit():
	var user_answer = answer_input.text.to_int()
	if user_answer == answer:
		var reward = int(15 * GameState.inflation_rate)
		GameState.money += reward
		result_label.text = "Correct! You earned $" + str(reward) + "!"
		result_label.add_theme_color_override("font_color", CLR_GREEN)
		GameState.event_triggered.emit("Completed chores, earned $" + str(reward))
		generate_question()
	else:
		result_label.text = "Wrong! Try again."
		result_label.add_theme_color_override("font_color", CLR_RED)

# Updated on 2026-04-19
