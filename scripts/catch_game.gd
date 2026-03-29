# COMMIT: Achievements and Catch Minigame Update
extends Node2D

# ------- Catch Minigame (Frenzy Edition) -------
# The player's customized character auto-moves and auto-throws red balls
# into the field. The dog (WASD) catches them.
#
# - 40-second countdown timer
# - ONE ball at a time: aim line shows landing spot, throw fires every 2s
#   OR immediately when dog catches the current ball
# - At ≤10s: FRENZY MODE — throw interval drops to 0.2s, everything faster
# - On exit: dog health +10, hunger/thirst/energy -15 each

# ── Constants ─────────────────────────────────────────────────────────────────
const BALL_RADIUS           := 24.0
const DOG_SPEED             := 420.0   # Base; x2 in frenzy
const PLAYER_AUTO_SPEED     := 840.0   # x3 vs original 280
const BALL_FLIGHT_DURATION  := 0.225   # x2 faster vs original 0.45

const THROW_INTERVAL_NORMAL := 2.0
const THROW_INTERVAL_FRENZY := 0.2
const FRENZY_THRESHOLD      := 10.0
const GAME_DURATION         := 40.0

# ── Ball texture ──────────────────────────────────────────────────────────────
var ball_texture: Texture2D = null

# ── State ──────────────────────────────────────────────────────────────────────
var round_earnings: int  = 0
var game_active:    bool = false
var show_end_screen: bool = false

# 40-second countdown
var game_timer: float = GAME_DURATION

# Throw scheduling
var throw_timer:   float = 0.0   # counts up; fires when >= interval
var aim_target_y:  float = 0.0   # where the player is currently walking toward

# Multiple balls  — each dict: {pos, from, to, t, flying}
var balls: Array = []

# Popups
var popup_list: Array = []

# Frenzy
var frenzy_active:  bool  = false
var frenzy_flash_t: float = 0.0

# Arena
var arena_rect: Rect2

# ── Dog sprite ─────────────────────────────────────────────────────────────────
var dog_sprite:    AnimatedSprite2D = null
var dog_pos:       Vector2 = Vector2.ZERO
var current_breed: String  = "basic_dog"
var last_dog_dir:  String  = "idle"

# ── Player sprite (layered components) ────────────────────────────────────────
var player_sprites: Array[AnimatedSprite2D] = []
var player_pos:     Vector2 = Vector2.ZERO
const PLAYER_RENDER_SCALE := Vector2(1.5, 1.5)

# Track player throw animation state
var player_throw_t: float = 0.0   # counts down during throw anim; 0 = idle

# Stored next-throw landing spot (used for aim line drawing)
var next_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	ball_texture = load("res://assets/sprites/red_ball_new.png") as Texture2D
	var vp := get_viewport_rect().size
	var aw := vp.x * 0.5
	var ah := vp.y * 0.5
	arena_rect = Rect2((vp.x - aw) / 2.0, (vp.y - ah) / 2.0, aw, ah)

	current_breed = GameState.dog_breed

	# ── Load dog sprite ───────────────────────────────────────────────────────
	var dog_scene: PackedScene = load("res://scenes/People and dog/dog.tscn")
	if dog_scene:
		var inst: Node = dog_scene.instantiate()
		for child in inst.get_children():
			if child is AnimatedSprite2D:
				inst.remove_child(child)
				dog_sprite = child
				add_child(dog_sprite)
				break
		inst.queue_free()
	if not dog_sprite:
		dog_sprite = AnimatedSprite2D.new()
		add_child(dog_sprite)

	dog_sprite.scale = Vector2(2, 2)
	dog_pos = Vector2(arena_rect.position.x + arena_rect.size.x * 0.5,
					  arena_rect.position.y + arena_rect.size.y - 40.0)
	dog_sprite.position = dog_pos
	_play_dog_anim("idle")

	# ── Load player sprites ───────────────────────────────────────────────────
	_setup_player_sprites()

	player_pos = Vector2(arena_rect.position.x - 60.0,
						 arena_rect.position.y + arena_rect.size.y * 0.5)
	aim_target_y = player_pos.y
	_sync_player_positions()
	_play_player_anim("idle_right")

	# Pick first target so aim line is visible immediately; ball throws after 2s
	_pick_next_target()
	throw_timer = 0.0

	game_active = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Player sprite setup ────────────────────────────────────────────────────────
func _setup_player_sprites() -> void:
	var layer_order := ["body", "eyes", "outfit", "hairstyle", "accessory"]
	var components  := GameState.get_character_components()

	for category in layer_order:
		var option: int = components.get(category, 1)
		var sf: SpriteFrames = GameState.get_component_sprite_frames(category, option)
		if sf:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = sf
			sprite.scale = PLAYER_RENDER_SCALE
			sprite.speed_scale = 1.0   # idle plays at normal speed
			if sf.has_animation("idle_right"):
				sprite.play("idle_right")
			add_child(sprite)
			player_sprites.append(sprite)


func _sync_player_positions() -> void:
	for sprite in player_sprites:
		sprite.position = player_pos


func _play_player_anim(anim: String) -> void:
	# Idle animations play at 1.0; move/throw animations play at x3 (x6 in frenzy)
	var is_idle := anim.begins_with("idle")
	var move_speed := 6.0 if frenzy_active else 3.0
	for sprite in player_sprites:
		if sprite and sprite.sprite_frames:
			if sprite.sprite_frames.has_animation(anim):
				sprite.speed_scale = 1.0 if is_idle else move_speed
				sprite.play(anim)


func _play_dog_anim(anim_name: String) -> void:
	if not dog_sprite or not dog_sprite.sprite_frames:
		return
	var possible := [
		current_breed + "_" + anim_name,
		current_breed.capitalize() + "_" + anim_name,
		anim_name,
		"basic_dog_" + anim_name,
		"basic_Dog_" + anim_name,
	]
	for name_check in possible:
		if dog_sprite.sprite_frames.has_animation(name_check):
			if dog_sprite.animation != name_check:
				dog_sprite.play(name_check)
			return


# ── Main process ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if show_end_screen:
		queue_redraw()
		return
	if not game_active:
		return

	# ── Global countdown ──────────────────────────────────────────────────────
	game_timer -= delta
	if game_timer <= 0.0:
		game_timer = 0.0
		_end_game()
		return

	# ── Check / activate FRENZY ───────────────────────────────────────────────
	if not frenzy_active and game_timer <= FRENZY_THRESHOLD:
		_activate_frenzy()
	if frenzy_active:
		frenzy_flash_t += delta

	# ── Player auto-move + throw scheduling ───────────────────────────────────
	_process_player(delta)

	# ── Dog movement (always active) ──────────────────────────────────────────
	_process_dog(delta)

	# ── Update all balls ──────────────────────────────────────────────────────
	_process_balls(delta)

	# ── Update popups ─────────────────────────────────────────────────────────
	var to_remove: Array = []
	for popup in popup_list:
		popup["time"] -= delta
		popup["pos"].y -= 30.0 * delta
		if popup["time"] <= 0:
			to_remove.append(popup)
	for p in to_remove:
		popup_list.erase(p)

	queue_redraw()


# ── FRENZY activation ──────────────────────────────────────────────────────────
func _activate_frenzy() -> void:
	frenzy_active = true
	GameState._unlock("Into the Frenzy")
	# Player anim speed_scale is handled per-call in _play_player_anim (idle=1.0, move=6.0)
	# Double dog anim speed
	if dog_sprite:
		dog_sprite.speed_scale = 2.0


# ── Player: auto-move toward aim_target_y, auto-throw on interval ─────────────
func _process_player(delta: float) -> void:
	var speed := PLAYER_AUTO_SPEED * (2.0 if frenzy_active else 1.0)
	var diff  := aim_target_y - player_pos.y

	if absf(diff) > 3.0:
		player_pos.y += signf(diff) * speed * delta
		player_pos.y = clamp(player_pos.y,
			arena_rect.position.y + 20.0,
			arena_rect.position.y + arena_rect.size.y - 20.0)
		_sync_player_positions()
		_play_player_anim("move_right")
	else:
		player_pos.y = aim_target_y
		_sync_player_positions()
		if player_throw_t <= 0.0:
			_play_player_anim("idle_right")

	# Throw animation timer (drives move_right during throw)
	if player_throw_t > 0.0:
		player_throw_t -= delta
		if player_throw_t <= 0.0:
			player_throw_t = 0.0
			_play_player_anim("idle_right")

	# Throw interval scheduler — only fire when no ball is currently active
	var interval := THROW_INTERVAL_FRENZY if frenzy_active else THROW_INTERVAL_NORMAL
	throw_timer += delta
	if throw_timer >= interval and balls.is_empty():
		throw_timer = 0.0
		_launch_ball()


func _pick_next_target() -> void:
	next_target = Vector2(
		randf_range(arena_rect.position.x + arena_rect.size.x * 0.3,
					arena_rect.position.x + arena_rect.size.x - 30.0),
		randf_range(arena_rect.position.y + 40.0,
					arena_rect.position.y + arena_rect.size.y - 40.0)
	)
	aim_target_y = next_target.y


func _launch_ball() -> void:
	# Throw toward the pre-chosen target (aim line was already showing it)
	var ball_from := player_pos + Vector2(30.0, -20.0)
	balls.append({
		"pos":    ball_from,
		"from":   ball_from,
		"to":     next_target,
		"t":      0.0,
		"flying": true
	})
	# Brief throw animation
	player_throw_t = 0.35
	_play_player_anim("move_right")
	# Pre-pick the next target so the aim line updates immediately after throw
	_pick_next_target()


# ── Dog: WASD movement, always active ─────────────────────────────────────────
func _process_dog(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_left")  or Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_action_pressed("move_up")    or Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_action_pressed("move_down")  or Input.is_key_pressed(KEY_S): input_dir.y += 1

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()

	var speed := DOG_SPEED * (2.0 if frenzy_active else 1.0)
	dog_pos += input_dir * speed * delta
	dog_pos.x = clamp(dog_pos.x, arena_rect.position.x + 20.0,
								  arena_rect.position.x + arena_rect.size.x - 20.0)
	dog_pos.y = clamp(dog_pos.y, arena_rect.position.y + 20.0,
								  arena_rect.position.y + arena_rect.size.y - 20.0)
	if dog_sprite:
		dog_sprite.position = dog_pos

	if input_dir == Vector2.ZERO:
		if last_dog_dir != "idle":
			last_dog_dir = "idle"
			_play_dog_anim("idle")
	else:
		if dog_sprite:
			dog_sprite.flip_h = input_dir.x < 0
		if last_dog_dir != "run":
			last_dog_dir = "run"
			_play_dog_anim("run")


# ── Balls: advance flight, check catches ──────────────────────────────────────
func _process_balls(delta: float) -> void:
	var to_catch: Array = []

	for ball in balls:
		if ball["flying"]:
			ball["t"] += delta / BALL_FLIGHT_DURATION
			if ball["t"] >= 1.0:
				ball["t"] = 1.0
				ball["pos"] = ball["to"]
				ball["flying"] = false
			else:
				var t: float = ball["t"]
				ball["pos"] = (ball["from"] as Vector2).lerp(ball["to"], t)
				ball["pos"].y -= 80.0 * sin(t * PI)
		else:
			# Landed — check dog collision
			if dog_pos.distance_to(ball["pos"]) < BALL_RADIUS + 36.0:
				to_catch.append(ball)

	for ball in to_catch:
		_catch_ball(ball)


func _catch_ball(ball: Dictionary) -> void:
	round_earnings += 2
	popup_list.append({"text": "+$2", "pos": Vector2(ball["pos"]), "time": 1.0})
	balls.erase(ball)
	# Ball Machine: check if 15+ caught this session
	var session_catches: int = roundi(round_earnings * 0.5)
	if session_catches > GameState.max_balls_one_session:
		GameState.max_balls_one_session = session_catches
	if session_catches >= 15:
		GameState._unlock("Ball Machine")
	# Do NOT reset throw_timer — interval clock fires naturally


# ── End game ───────────────────────────────────────────────────────────────────
func _end_game() -> void:
	game_active    = false
	show_end_screen = true

	if dog_sprite:
		var c := get_viewport_rect().size * 0.5
		dog_sprite.position = Vector2(c.x, c.y - 140.0)
		_play_dog_anim("idle")

	GameState.money                += round_earnings
	GameState.catch_total_earnings += round_earnings
	GameState.record_transaction("Catch game earnings", round_earnings, "Income")

	# Tracking
	GameState.catch_games_played += 1
	if not GameState.catch_days_played.has(GameState.current_day):
		GameState.catch_days_played.append(GameState.current_day)

	GameState._unlock("First Fetch")
	GameState.check_achievements()

	if round_earnings >= 40 and not GameState.achievements["Catch Pro"]:
		GameState.achievements["Catch Pro"] = true
		GameState.achievement_unlocked.emit("Catch Pro")
	if GameState.catch_total_earnings >= 200 and not GameState.achievements["Catch Master"]:
		GameState.achievements["Catch Master"] = true
		GameState.achievement_unlocked.emit("Catch Master")


# ── Drawing ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var vp := get_viewport_rect().size

	if show_end_screen:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.12, 0.22, 0.12))
		_draw_end_screen()
		return

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.12, 0.22, 0.12))
	# Arena grass
	draw_rect(arena_rect, Color(0.25, 0.55, 0.22))
	# Arena border
	draw_rect(arena_rect, Color(1.0, 1.0, 1.0, 0.3), false, 3.0)

	if not game_active:
		return

	# Player zone
	var pzone := Rect2(arena_rect.position.x - 110.0, arena_rect.position.y,
					   110.0, arena_rect.size.y)
	draw_rect(pzone, Color(0.18, 0.38, 0.16))
	draw_rect(pzone, Color(1.0, 1.0, 1.0, 0.2), false, 2.0)

	# ── Yellow aim line (next throw target) — hidden in FRENZY MODE ──────────
	if not frenzy_active and next_target != Vector2.ZERO and balls.is_empty():
		var line_from := player_pos + Vector2(20.0, 0.0)
		var line_to   := next_target
		var total_len := line_from.distance_to(line_to)
		var segments  := int(total_len / 20.0)
		for i in range(segments):
			if i % 2 == 0:
				var s := line_from.lerp(line_to, float(i) / float(segments))
				var e := line_from.lerp(line_to, float(i + 1) / float(segments))
				draw_line(s, e, Color(1.0, 0.9, 0.0, 0.5), 2.0)
		# Target landing circle
		draw_circle(next_target, BALL_RADIUS + 4.0, Color(1.0, 0.9, 0.0, 0.22))
		draw_circle(next_target, BALL_RADIUS + 4.0, Color(1.0, 0.9, 0.0, 0.8), false, 2.0)

	# ── Draw all balls ────────────────────────────────────────────────────────
	for ball in balls:
		var bp: Vector2 = ball["pos"]
		if ball_texture:
			var ball_scale := 0.85 if ball["flying"] else 1.0
			var tex_size := Vector2(ball_texture.get_width(), ball_texture.get_height()) * ball_scale
			var ball_color := Color(1.0, 1.0, 1.0, 0.85) if ball["flying"] else Color.WHITE
			draw_texture_rect(ball_texture,
				Rect2(bp - tex_size * 0.5, tex_size),
				false, ball_color)
		else:
			# Fallback if texture didn't load
			if ball["flying"]:
				draw_circle(bp, BALL_RADIUS * 0.85, Color(0.9, 0.15, 0.15, 0.85))
			else:
				draw_circle(bp, BALL_RADIUS, Color(0.9, 0.15, 0.15))

	# ── 40-second countdown bar ───────────────────────────────────────────────
	var bar_w := arena_rect.size.x
	var bar_x := arena_rect.position.x
	var bar_y := arena_rect.position.y - 64.0
	var pct: float = clamp(game_timer / GAME_DURATION, 0.0, 1.0)
	draw_rect(Rect2(bar_x, bar_y, bar_w, 56.0), Color(0.2, 0.2, 0.2))
	var bar_col := Color(0.9, 0.2, 0.2) if frenzy_active else \
				  (Color(0.2, 0.8, 0.2) if pct > 0.3 else Color(0.9, 0.5, 0.1))
	draw_rect(Rect2(bar_x, bar_y, bar_w * pct, 56.0), bar_col)
	draw_string(ThemeDB.fallback_font,
		Vector2(bar_x + bar_w * 0.5 - 40.0, bar_y + 42.0),
		"%.1fs" % game_timer,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color.WHITE)

	# ── Control hint ──────────────────────────────────────────────────────────
	draw_string(ThemeDB.fallback_font,
		Vector2(arena_rect.position.x, arena_rect.position.y + arena_rect.size.y + 34.0),
		"WASD — move the dog and catch the balls!",
		HORIZONTAL_ALIGNMENT_CENTER, int(arena_rect.size.x), 28,
		Color(1.0, 1.0, 0.8, 0.9))

	# ── Earnings ──────────────────────────────────────────────────────────────
	draw_string(ThemeDB.fallback_font,
		Vector2(arena_rect.position.x, arena_rect.position.y + arena_rect.size.y + 64.0),
		"Earned: $%d" % round_earnings,
		HORIZONTAL_ALIGNMENT_CENTER, int(arena_rect.size.x), 40, Color(0.2, 1.0, 0.2))

	# ── Popups ────────────────────────────────────────────────────────────────
	for popup in popup_list:
		var alpha: float = clamp(popup["time"], 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, popup["pos"], "+$2",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 48, Color(0.1, 1.0, 0.1, alpha))

	# ── FRENZY MODE overlay ───────────────────────────────────────────────────
	if frenzy_active:
		_draw_frenzy_overlay(vp)


func _draw_frenzy_overlay(vp: Vector2) -> void:
	var font     := ThemeDB.fallback_font
	var fsize    := 88
	var pulse: float = 0.65 + 0.35 * abs(sin(frenzy_flash_t * 8.0))
	var cx       := vp.x * 0.5

	# Two lines: "FRENZY" and "MODE"
	for i in range(2):
		var word    := "FRENZY" if i == 0 else "MODE"
		var wy: float = arena_rect.position.y - 64.0 - float(fsize) * (1.0 - float(i)) - 8.0
		var ww: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var wx: float = cx - ww * 0.5

		# Black outline (4 offsets)
		for ox in [-4, 4]:
			for oy in [-4, 4]:
				draw_string(font, Vector2(wx + ox, wy + oy), word,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
					Color(0.0, 0.0, 0.0, pulse))

		# Orange-red fill
		draw_string(font, Vector2(wx, wy), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
			Color(1.0, 0.35, 0.0, pulse))


func _draw_end_screen() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.55))

	var center  := vp * 0.5
	var pw      := minf(920.0, vp.x - 48.0)
	var ph      := minf(520.0, vp.y - 48.0)
	var pr      := Rect2(center.x - pw * 0.5, center.y - ph * 0.5, pw, ph)
	draw_rect(pr, Color(0.15, 0.15, 0.2, 0.97))
	draw_rect(pr, Color(0.5, 0.8, 0.5), false, 4.0)

	var font       := ThemeDB.fallback_font
	var ttxt       := "You earned $%d" % round_earnings
	var tsz        := 72
	var tw: float  = font.get_string_size(ttxt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
	draw_string(font, Vector2(center.x - tw * 0.5, center.y - 40.0),
		ttxt, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.2, 1.0, 0.2))

	var bw   := 400.0
	var bh   := 120.0
	var br   := Rect2(center.x - bw * 0.5, center.y + 80.0, bw, bh)
	draw_rect(br, Color(0.3, 0.6, 0.3))
	draw_rect(br, Color(0.5, 0.9, 0.5), false, 3.0)
	var etxt       := "Exit"
	var esz        := 60
	var ew: float  = font.get_string_size(etxt, HORIZONTAL_ALIGNMENT_LEFT, -1, esz).x
	draw_string(font, Vector2(center.x - ew * 0.5, center.y + 80.0 + bh * 0.5 + esz * 0.35),
		etxt, HORIZONTAL_ALIGNMENT_LEFT, -1, esz, Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if show_end_screen:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var center := get_viewport_rect().size * 0.5
			if Rect2(center.x - 200.0, center.y + 80.0, 400.0, 120.0).has_point(event.position):
				_exit_game()
		if event is InputEventKey and event.pressed:
			if event.keycode in [KEY_E, KEY_ENTER, KEY_ESCAPE]:
				_exit_game()


func _exit_game() -> void:
	# Apply dog needs changes: health +10, hunger/thirst/energy -15
	var dog := get_tree().get_first_node_in_group("dog")
	if dog:
		dog.health = min(100.0, dog.health + 10.0)
		dog.hunger = max(0.0,   dog.hunger  - 15.0)
		dog.thirst = max(0.0,   dog.thirst  - 15.0)
		dog.energy = max(0.0,   dog.energy  - 15.0)
		GameState.dog_health = dog.health

	GameState.catch_played_today    = true
	GameState.catch_last_played_day = GameState.current_day
	get_tree().paused = false
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()
