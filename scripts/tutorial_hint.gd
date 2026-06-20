# COMMIT: Achievements and Catch Minigame Update
extends CanvasLayer

@onready var panel = $Panel
@onready var hint_label = $Panel/MarginContainer/HintLabel
@onready var anim_player = $AnimationPlayer

signal hint_shown
signal hint_hidden

var current_timer: Timer = null

# Spotlight properties
var highlight_target: Control = null
var dim_color: Color = Color(0.05, 0.06, 0.1, 0.6) # Premium navy-grey translucency

var _dim_top: ColorRect = null
var _dim_bottom: ColorRect = null
var _dim_left: ColorRect = null
var _dim_right: ColorRect = null

func _ready():
	UITheme.apply_overlay_theme(self)
	
	# Override panel stylebox to match the redesign spec (dark ink background, gold border, shadow)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = UITheme.CLR_INK
	panel_sb.border_color = UITheme.CLR_GOLD
	panel_sb.border_width_left = 3
	panel_sb.border_width_right = 3
	panel_sb.border_width_top = 3
	panel_sb.border_width_bottom = 3
	panel_sb.set_corner_radius_all(0)
	panel_sb.content_margin_left = 24
	panel_sb.content_margin_top = 16
	panel_sb.content_margin_right = 24
	panel_sb.content_margin_bottom = 16
	panel_sb.shadow_color = Color(0, 0, 0, 0.3)
	panel_sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", panel_sb)

	# Reset margin container margins so we only use the stylebox padding
	var margin_container = panel.get_node_or_null("MarginContainer")
	if margin_container is MarginContainer:
		margin_container.add_theme_constant_override("margin_left", 0)
		margin_container.add_theme_constant_override("margin_top", 0)
		margin_container.add_theme_constant_override("margin_right", 0)
		margin_container.add_theme_constant_override("margin_bottom", 0)

	# Override the HintLabel text color, font (weight 500), and font size to 24
	hint_label.add_theme_color_override("font_color", Color.WHITE)
	var font_medium := SystemFont.new()
	font_medium.font_weight = 500
	hint_label.add_theme_font_override("font", font_medium)
	hint_label.add_theme_font_size_override("font_size", 24)

	panel.modulate.a = 0
	anim_player.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	if highlight_target and is_instance_valid(highlight_target):
		_update_dim_rects()

func set_highlight_target(target: Control):
	highlight_target = target
	if highlight_target == null:
		_destroy_dim_rects()
	else:
		_create_dim_rects()
		_update_dim_rects()

func _create_dim_rects():
	if _dim_top == null:
		_dim_top = ColorRect.new()
		_dim_bottom = ColorRect.new()
		_dim_left = ColorRect.new()
		_dim_right = ColorRect.new()
		
		for rect in [_dim_top, _dim_bottom, _dim_left, _dim_right]:
			rect.color = dim_color
			rect.mouse_filter = Control.MOUSE_FILTER_STOP
			rect.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(rect)
			move_child(rect, 0) # Render behind Panel

func _destroy_dim_rects():
	for rect in [_dim_top, _dim_bottom, _dim_left, _dim_right]:
		if rect and is_instance_valid(rect):
			rect.queue_free()
	_dim_top = null
	_dim_bottom = null
	_dim_left = null
	_dim_right = null

func _update_dim_rects():
	if not highlight_target or not is_instance_valid(highlight_target) or not highlight_target.is_visible_in_tree():
		_destroy_dim_rects()
		return
		
	var viewport_size = get_viewport().get_visible_rect().size
	var target_rect = highlight_target.get_global_rect()
	
	var screen_w = viewport_size.x
	var screen_h = viewport_size.y
	
	var l = clampf(target_rect.position.x, 0.0, screen_w)
	var r = clampf(target_rect.position.x + target_rect.size.x, 0.0, screen_w)
	var t = clampf(target_rect.position.y, 0.0, screen_h)
	var b = clampf(target_rect.position.y + target_rect.size.y, 0.0, screen_h)
	
	# Create if not created
	_create_dim_rects()
	
	# Top rect
	_dim_top.position = Vector2(0, 0)
	_dim_top.size = Vector2(screen_w, t)
	
	# Bottom rect
	_dim_bottom.position = Vector2(0, b)
	_dim_bottom.size = Vector2(screen_w, screen_h - b)
	
	# Left rect
	_dim_left.position = Vector2(0, t)
	_dim_left.size = Vector2(l, b - t)
	
	# Right rect
	_dim_right.position = Vector2(r, t)
	_dim_right.size = Vector2(screen_w - r, b - t)


func show_hint(text: String, duration: float = 0.0):
	"""Show a hint with optional auto-hide after duration seconds. If duration is 0, waits for manual hide."""
	hint_label.text = text
	anim_player.play("fade_in")
	
	# Clear any existing timer
	if current_timer:
		current_timer.queue_free()
		current_timer = null
	
	# Set up auto-hide timer if duration specified
	if duration > 0:
		current_timer = Timer.new()
		current_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		current_timer.wait_time = duration
		current_timer.one_shot = true
		current_timer.timeout.connect(func():
			hide_hint()
			current_timer.queue_free()
			current_timer = null
		)
		add_child(current_timer)
		current_timer.start()
	
	hint_shown.emit()

func hide_hint():
	"""Fade out the current hint."""
	anim_player.play("fade_out")

func _on_animation_finished(anim_name: String):
	if anim_name == "fade_out":
		hint_hidden.emit()

func is_hint_visible() -> bool:
	return panel.modulate.a > 0.5

# Updated on 2026-04-19
