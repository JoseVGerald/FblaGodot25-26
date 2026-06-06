# JuicyButton.gd
# Drop-in button feedback: hover scale-up + pixel press-down (squash) + click sound.
# Usage: set this as a Button's script, OR call UITheme._do_juice_on(btn) from code.
class_name JuicyButton
extends Button

@export var press_squash : float = 0.88   # Y scale on press
@export var hover_scale  : float = 1.05   # uniform scale on hover
@export var anim_secs    : float = 0.07
@export var play_sound   : bool  = true

var _tw : Tween

func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)
	mouse_entered.connect(_hover)
	mouse_exited.connect(_unhover)
	button_down.connect(_down)
	button_up.connect(_up)

func _centre_pivot() -> void:
	pivot_offset = size * 0.5

func _go(target : Vector2, trans := Tween.TRANS_BACK, ease_type := Tween.EASE_OUT) -> void:
	if _tw: _tw.kill()
	_tw = create_tween().set_trans(trans).set_ease(ease_type)
	_tw.tween_property(self, "scale", target, anim_secs)

func _hover() -> void:
	if not disabled: _go(Vector2.ONE * hover_scale)

func _unhover() -> void:
	_go(Vector2.ONE, Tween.TRANS_EXPO)

func _down() -> void:
	if play_sound: Sfx.click()
	_go(Vector2(1.03, press_squash), Tween.TRANS_QUAD, Tween.EASE_IN)

func _up() -> void:
	_go(Vector2.ONE * (hover_scale if is_hovered() else 1.0))
