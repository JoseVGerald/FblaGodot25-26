# COMMIT: Achievements and Catch Minigame Update
extends CanvasLayer

signal settings_closed

@onready var volume_slider = $Panel/VBox/VolumeContainer/VolumeSlider
@onready var volume_value_label = $Panel/VBox/VolumeContainer/VolumeValue
@onready var close_btn = $Panel/VBox/CloseBtn
var mute_btn: Button = null
var is_muted: bool = false

func _ready():
	UITheme.apply_overlay_theme(self)

	# Initial value from GameState if exists, else default to 70
	var initial_volume = GameState.get("master_volume") if "master_volume" in GameState else 70
	volume_slider.value = initial_volume
	volume_value_label.text = str(initial_volume)

	volume_slider.value_changed.connect(_on_volume_changed)
	close_btn.pressed.connect(_on_close_pressed)
	# Create mute button below the slider
	mute_btn = Button.new()
	mute_btn.text = "🔇 Mute"
	mute_btn.toggle_mode = true
	is_muted = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	mute_btn.button_pressed = is_muted
	_update_mute_label()
	mute_btn.toggled.connect(_on_mute_toggled)
	# Insert after VolumeContainer in the VBox
	var vbox = $Panel/VBox
	vbox.add_child(mute_btn)
	vbox.move_child(mute_btn, vbox.get_child_count() - 2) # Before close button

func _input(event):
	# ESC closes settings without toggling pause menu
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_volume_changed(value):
	volume_value_label.text = str(int(value))
	if "master_volume" in GameState:
		GameState.master_volume = int(value)

	# Apply volume to master bus
	var db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	# Handle mute if volume is 0
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value == 0)

func _on_close_pressed():
	settings_closed.emit()
	queue_free()

func _on_mute_toggled(pressed: bool) -> void:
	is_muted = pressed
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted)
	_update_mute_label()

func _update_mute_label() -> void:
	if not mute_btn: return
	mute_btn.text = "🔇 Unmute" if is_muted else "🔇 Mute"
