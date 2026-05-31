extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var file_label: Label = $FileBox/FileLabel
@onready var percent_label: Label = $PercentLabel
@onready var tip_label: Label = $TipLabel
@onready var title_label: Label = $TitleLabel
@onready var bar_card: Panel = $BarCard
@onready var file_box: ColorRect = $FileBox

const TIPS = [
	"Teaching tricks to your pup...",
	"Filling up the water bowl...",
	"Preparing the vet clinic...",
	"Counting your allowance...",
	"Fluffing the dog bed...",
	"Stocking the pet store shelves...",
	"Setting up the neighborhood...",
	"Wagging tails incoming...",
]

var map_loaded: bool = false
var real_files: Array = []
var tween_finished: bool = false

func _ready():
	_build_file_library("res://scenes")
	_build_file_library("res://scripts")
	_build_file_library("res://assets")

	if real_files.size() > 0:
		real_files.shuffle()
	else:
		real_files = ["res://project.godot", "res://icon.svg"]

	ResourceLoader.load_threaded_request("res://scenes/ui/MainGame.tscn", "PackedScene")

	var pixel_font = load("res://assets/fonts/Minecraft.ttf")
	if pixel_font:
		title_label.add_theme_font_override("font", pixel_font)
		percent_label.add_theme_font_override("font", pixel_font)

	_run_entrance_animations()
	_start_progress_tween()
	set_process(true)
	_cycle_file()
	_cycle_tip()

func _run_entrance_animations():
	title_label.modulate.a = 0.0
	$TaglineLabel.modulate.a = 0.0
	bar_card.modulate.a = 0.0
	progress_bar.modulate.a = 0.0
	percent_label.modulate.a = 0.0
	tip_label.modulate.a = 0.0
	file_box.modulate.a = 0.0

	# Capture original positions for slide-in effect
	var title_orig_y = title_label.position.y
	var bar_orig_y = bar_card.position.y
	var pb_orig_y = progress_bar.position.y
	title_label.position.y = title_orig_y + 18.0
	bar_card.position.y = bar_orig_y + 12.0
	progress_bar.position.y = pb_orig_y + 12.0

	# Emil: ease-out for entering elements — stagger groups 150-180ms apart
	var t = get_tree().create_tween()

	# Group 1: Title — fade + slide up
	t.tween_property(title_label, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(title_label, "position:y", title_orig_y, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Group 2: Tagline — fade in
	t.tween_interval(0.18)
	t.tween_property($TaglineLabel, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Group 3: Bar card + progress bar — fade + slide up together
	t.tween_interval(0.18)
	t.tween_property(bar_card, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(bar_card, "position:y", bar_orig_y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(progress_bar, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(progress_bar, "position:y", pb_orig_y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Group 4: Percent + tip + file box — fades only
	t.tween_interval(0.15)
	t.tween_property(percent_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(tip_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(file_box, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _start_progress_tween():
	var tween = get_tree().create_tween()
	# Multi-phase psychological loading: burst → steady → heavy → crawl
	tween.tween_property(progress_bar, "value", 22.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(progress_bar, "value", 58.0, 16.0).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(progress_bar, "value", 85.0, 12.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Emil: linear for constant motion — the final crawl feels deliberate
	tween.tween_property(progress_bar, "value", 99.9, 18.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_tween_finished)

func _build_file_library(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					_build_file_library(path + "/" + file_name)
			else:
				if file_name.ends_with(".tscn") or file_name.ends_with(".gd") or file_name.ends_with(".png") or file_name.ends_with(".tres"):
					real_files.append(path + "/" + file_name)
			file_name = dir.get_next()

func _cycle_file():
	if real_files.size() > 0:
		var file = real_files.pop_back()
		file_label.text = "Loading: " + file.get_file()

	if not tween_finished:
		var delay = 0.5 if progress_bar.value < 65.0 else (1.5 if progress_bar.value < 85.0 else 3.5)
		await get_tree().create_timer(delay + randf_range(-0.2, 0.5)).timeout
		if is_inside_tree():
			_cycle_file()

func _cycle_tip():
	if tween_finished:
		return

	var next_tip = TIPS[randi() % TIPS.size()]

	# Emil: asymmetric timing — fast exit (180ms), responsive enter (300ms ease-out)
	var t = get_tree().create_tween()
	t.tween_property(tip_label, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func(): tip_label.text = next_tip)
	t.tween_property(tip_label, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished

	await get_tree().create_timer(randf_range(3.0, 4.5)).timeout
	if is_inside_tree() and not tween_finished:
		_cycle_tip()

func _on_tween_finished():
	tween_finished = true

func _process(_delta):
	if not map_loaded:
		var status = ResourceLoader.load_threaded_get_status("res://scenes/ui/MainGame.tscn")
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			map_loaded = true
			GameState.preloaded_map = ResourceLoader.load_threaded_get("res://scenes/ui/MainGame.tscn")

	percent_label.text = "%d%%" % int(progress_bar.value)

	if tween_finished and map_loaded:
		set_process(false)
		_play_completion()

func _play_completion():
	progress_bar.value = 100.0
	percent_label.text = "100%"
	file_label.text = "Ready!"

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return

	# Emil: exit fast — 220ms ease-in (user already anticipates next screen)
	var out = get_tree().create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await out.finished

	if is_inside_tree():
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn", {"pattern": "fade", "skip_fade_out": true})
