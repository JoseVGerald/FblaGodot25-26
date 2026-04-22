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
	# Apply navy panel style via UITheme helper (spec rule)
	var panel_node = get_node_or_null("Panel")
	if panel_node:
		UITheme.style_panel(panel_node)
	UITheme.apply_overlay_theme(self)
	_apply_redesign_styling()
	$Panel/VBoxContainer/SubmitButton.pressed.connect(_on_submit)
	$Panel/VBoxContainer/CloseButton.pressed.connect(queue_free)
	get_tree().paused = true
	generate_question()

## Pixel-font headings, big green submit, red close, deeper answer input.
func _apply_redesign_styling() -> void:
	var title := get_node_or_null("Panel/VBoxContainer/Label")
	if title is Label:
		title.text = "MATH CHORES"
		title.add_theme_color_override("font_color", UIColors.GOLD)
		title.add_theme_font_size_override("font_size", 42)

	if question_label:
		question_label.add_theme_color_override("font_color", UIColors.TEXT_WHITE)
		question_label.add_theme_font_size_override("font_size", 54)

	var submit_btn := get_node_or_null("Panel/VBoxContainer/SubmitButton")
	if submit_btn is Button:
		UITheme.style_button(submit_btn, UITheme.CLR_GREEN)
	var close_btn := get_node_or_null("Panel/VBoxContainer/CloseButton")
	if close_btn is Button:
		UITheme.style_button(close_btn, UITheme.CLR_RED)

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
		_show_feedback(true, reward)
		GameState.event_triggered.emit("Completed chores, earned $" + str(reward))
		generate_question()
	else:
		_show_feedback(false, 0)

## Show feedback strip — green for correct (shows $ amount), red for wrong.
## Writes to result_label. If a FeedbackStrip panel exists (new layout),
## restyle it with the matching warning variant; otherwise no-op.
func _show_feedback(correct: bool, amount: int) -> void:
	if correct:
		result_label.text = "Correct! You earned $" + str(amount) + "!"
		result_label.add_theme_color_override("font_color", CLR_GREEN)
	else:
		result_label.text = "Wrong! Try again."
		result_label.add_theme_color_override("font_color", CLR_RED)
	var strip := get_node_or_null("Panel/VBoxContainer/FeedbackStrip")
	if strip is PanelContainer:
		UITheme.style_warning_strip(strip, "green" if correct else "red")
		strip.visible = true

# Updated on 2026-04-19
