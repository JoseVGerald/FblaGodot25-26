extends Node

var _player : AudioStreamPlayer
var _click  : AudioStream = null

func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.bus = "Master"
    add_child(_player)
    var p := "res://assets/sfx/click.wav"
    if ResourceLoader.exists(p):
        _click = load(p)

func click(pitch : float = 1.0) -> void:
    if _click == null: return
    _player.stream = _click
    _player.pitch_scale = randf_range(0.94, 1.08) * pitch
    _player.volume_db = -6.0
    _player.play()
