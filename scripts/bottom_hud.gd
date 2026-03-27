# bottom_hud.gd
# Bottom screen HUD — shows money, current day/week, and action buttons.
# Includes week simulation: hovering the date label shows a tooltip,
# clicking it fast-forwards up to 7 days with interruption checks.
extends CanvasLayer

# ── Colour palette ─────────────────────────────────────────────────────────────
const CLR_SKY   := Color("#4A90D9")
const CLR_GREEN := Color("#4CAF50")
const CLR_RED   := Color("#EF5350")
const CLR_GOLD  := Color("#FFD700")
const CLR_WHITE := Color.WHITE

# ── Daily sim constants ────────────────────────────────────────────────────────
# Hunger, thirst, and energy stay at max during week simulation.
# Only health changes (random ±1-30 per day).
const DAILY_MED_COST         := 10     # Auto-medication cost when heal th < 50
const MED_HEAL_AMOUNT        := 30.0   # Health restored by daily medication when sick

# ── Scene node refs ────────────────────────────────────────────────────────────
@onready var money_label  = $Background/Margin/MainHBox/LeftSection/MoneyLabel
@onready var time_label   = $Background/Margin/MainHBox/TimeLabel
@onready var supplies_btn = $Background/Margin/MainHBox/RightSection/SuppliesBtn
@onready var needs_btn    = $Background/Margin/MainHBox/RightSection/NeedsBtn
@onready var finance_btn  = $TopRightHUD/FinanceBtn
@onready var notif_btn    = $TopRightHUD/NotifBtn
@onready var pause_btn    = $TopRightHUD/PauseBtn
@onready var home_btn     = $Background/Margin/MainHBox/RightSection/BuildBtn

# ── Scene preloads ─────────────────────────────────────────────────────────────
var pause_menu_scene        = preload("res://scenes/ui/PauseMenu.tscn")
var finance_menu_scene      = preload("res://scenes/ui/FinanceMenu.tscn")
var supplies_menu_scene     = preload("res://scenes/ui/supplies_menu.tscn")
var taxi_menu_scene         = preload("res://scenes/ui/taxi_menu.tscn")
var shop_menu_scene         = preload("res://scenes/ui/ShopMenu.tscn")
var notification_panel_scene = preload("res://scripts/notification_panel.gd")

var current_pause_menu     = null
var supplies_menu_instance = null
var taxi_menu_instance     = null
var shop_menu_instance     = null

var _notif_pulse_tween : Tween       = null   # Warning-state pulse animation
var _notif_icon        : TextureRect = null   # Icon child inside the button

# Notification icon textures (using load() for robustness)
var _tex_warning : Texture2D = load("res://assets/ui/notification_icons/urgent.png")
var _tex_badge   : Texture2D = load("res://assets/ui/notification_icons/Notification.png")
var _tex_normal  : Texture2D = load("res://assets/ui/notification_icons/Normal.png")

# ── Week simulation state ─────────────────────────────────────────────────────
var _is_simulating     : bool  = false   # True while week sim is running
var _sim_overlay       : Control = null  # "Simulating…" overlay
var _sim_day_label     : Label   = null  # "Day X / 7" counter
var _sim_tooltip       : Label   = null  # Hover tooltip for time_label
var _time_label_hovered: bool   = false  # RichTextLabel hover (no scale/font-size change)

# ── Signal for tutorial system ────────────────────────────────────────────────
signal supplies_menu_opened

# ══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready():
	add_to_group("hud")
	UITheme.apply_overlay_theme(self)

	supplies_btn.pressed.connect(_on_supplies_btn_pressed)
	needs_btn.pressed.connect(_on_needs_btn_pressed)
	finance_btn.pressed.connect(_on_finance_btn_pressed)
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	home_btn.pressed.connect(_on_home_btn_pressed)

	# Create supplies menu instance
	supplies_menu_instance = supplies_menu_scene.instantiate()
	add_child(supplies_menu_instance)
	supplies_menu_instance.menu_opened.connect(func(): supplies_menu_opened.emit())

	# Create taxi menu instance
	taxi_menu_instance = taxi_menu_scene.instantiate()
	add_child(taxi_menu_instance)

	# Create shop menu instance
	shop_menu_instance = shop_menu_scene.instantiate()
	add_child(shop_menu_instance)
	GameState.open_shop_requested.connect(_on_open_shop_requested)

	# Set up time label hover / click for week simulation
	_setup_time_label_interaction()

	# ── Notification button setup ─────────────────────────────────────────────
	_setup_notif_button()

	# Wire GameState signals → NotificationCenter for permanent history log
	GameState.event_triggered.connect(func(msg: String):
		NotificationCenter.add_notification(
				NotificationCenter.NotifType.EVENT, msg))

	GameState.achievement_unlocked.connect(func(ach_name: String):
		NotificationCenter.add_notification(
				NotificationCenter.NotifType.ACHIEVEMENT,
				"Achievement Unlocked: " + ach_name))

	GameState.emergency_fund_used.connect(func(item: String):
		NotificationCenter.add_notification(
				NotificationCenter.NotifType.WARNING,
				"Emergency fund used for: " + item))

	GameState.budget_warning.connect(func(cat: String, msg: String):
		NotificationCenter.add_notification(
				NotificationCenter.NotifType.WARNING,
				cat + ": " + msg))

	# Also connect the transient HUD handlers — existing behavior is preserved
	if not GameState.emergency_fund_used.is_connected(_on_emergency_fund_used):
		GameState.emergency_fund_used.connect(_on_emergency_fund_used)
	if not GameState.budget_warning.is_connected(_on_budget_warning):
		GameState.budget_warning.connect(_on_budget_warning)
	if not GameState.event_triggered.is_connected(_on_event_triggered):
		GameState.event_triggered.connect(_on_event_triggered)
	if not GameState.achievement_unlocked.is_connected(_on_achievement_unlocked):
		GameState.achievement_unlocked.connect(_on_achievement_unlocked)

	# Startup warning: remind player that health will drop without attention
	NotificationCenter.add_notification(
			NotificationCenter.NotifType.WARNING,
			"Your dog needs care! Health will drop below 50 if ignored. Visit the vet.")

	update_ui()

func _process(_delta):
	update_ui()

## Update the money and time labels every frame.
func update_ui():
	money_label.text = "$ " + str(GameState.money)
	_apply_time_label_text()

# ══════════════════════════════════════════════════════════════════════════════
#  TIME LABEL — HOVER & CLICK (Week Simulation trigger)
# ══════════════════════════════════════════════════════════════════════════════

## Set up mouse interaction on the time label so it acts like a clickable link.
func _setup_time_label_interaction() -> void:
	# Make the label receive mouse events
	time_label.mouse_filter = Control.MOUSE_FILTER_STOP
	time_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if time_label is RichTextLabel:
		time_label.bbcode_enabled = true
		time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		time_label.custom_minimum_size.x = maxf(time_label.custom_minimum_size.x, 560.0)
		time_label.fit_content = true

	# Create hover tooltip (hidden by default)
	_sim_tooltip = Label.new()
	_sim_tooltip.text = "Click to simulate week"
	_sim_tooltip.add_theme_font_size_override("font_size", 22)
	_sim_tooltip.add_theme_color_override("font_color", CLR_GOLD)
	_sim_tooltip.visible = false
	_sim_tooltip.position = Vector2(0, -36)
	var font := UITheme.get_pixel_font()
	if font:
		_sim_tooltip.add_theme_font_override("font", font)
	time_label.add_child(_sim_tooltip)

	# Hover: cyan + underline only (no scale / font-size tween)
	time_label.mouse_entered.connect(_on_time_hover_enter)
	time_label.mouse_exited.connect(_on_time_hover_exit)

	# Connect click via gui_input
	time_label.gui_input.connect(_on_time_label_clicked)


func _apply_time_label_text() -> void:
	var s := GameState.get_time_string()
	if time_label is RichTextLabel:
		if _time_label_hovered:
			time_label.text = "[color=#53d8fb][u]%s[/u][/color]" % s
		else:
			time_label.text = "[color=#ffffff]%s[/color]" % s
	else:
		time_label.text = s


## On hover: cyan + underline via BBCode; no size/scale changes.
func _on_time_hover_enter() -> void:
	if _is_simulating:
		return
	_time_label_hovered = true
	_apply_time_label_text()
	if _sim_tooltip:
		_sim_tooltip.visible = true


## On hover exit: white text, no underline.
func _on_time_hover_exit() -> void:
	_time_label_hovered = false
	_apply_time_label_text()
	if _sim_tooltip:
		_sim_tooltip.visible = false

## On click: start the week simulation.
func _on_time_label_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_simulating:
			_start_week_simulation()

# ══════════════════════════════════════════════════════════════════════════════
#  WEEK SIMULATION — Simulate up to 7 days with interruption checks
# ══════════════════════════════════════════════════════════════════════════════

## Main entry point: plays curtain transitions and ticks through days.
## Hunger, thirst, energy stay at 100. Only health changes (±1-30/day).
func _start_week_simulation() -> void:
	_is_simulating = true
	_create_sim_overlay()

	var dog = get_tree().get_first_node_in_group("dog")

	# Keep needs pegged at max for the entire simulation
	if dog:
		dog.hunger = 100.0
		dog.thirst = 100.0
		dog.energy = 100.0

	for day_offset in range(1, 8):
		if _sim_day_label:
			_sim_day_label.text = "Day %d / 7..." % day_offset

		# --- Food supply: just decrement the count ---
		if GameState.food > 0:
			GameState.food -= 1

		# --- Water supply: just decrement the count ---
		if GameState.water > 0:
			GameState.water -= 1

		# --- Random health change ±1-30 per day ---
		if dog:
			var health_delta = randi_range(1, 30)
			if randi() % 2 == 0:
				health_delta = -health_delta
			dog.health = clamp(dog.health + health_delta, 10.0, 100.0)
			GameState.dog_health = dog.health

		# --- Medication: pay + heal when on meds and health is low ---
		if dog and GameState.medication != "none" and dog.health < 50.0:
			if GameState.money >= DAILY_MED_COST:
				GameState.money -= DAILY_MED_COST
				GameState.record_transaction(
					"Daily medication",
					-DAILY_MED_COST,
					"Vet"
				)
				dog.health = min(dog.health + MED_HEAL_AMOUNT, 100.0)
				GameState.dog_health = dog.health

		# --- Interruption checks ---
		var fail_day := GameState.current_day + 1
		if GameState.food <= 0:
			_abort_week_simulation("out_of_food", fail_day)
			return
		if GameState.water <= 0:
			_abort_week_simulation("out_of_water", fail_day)
			return
		if dog and dog.health < 50.0:
			_abort_week_simulation("vet_needed", fail_day)
			return

		GameState.advance_day_after_simulation_supply()
		if dog:
			dog.health = GameState.dog_health

		# Play curtain close → open transition for each sim day
		_remove_sim_overlay()
		await SceneManager.fade_in_place({"pattern": "curtains"})
		_create_sim_overlay()

	_remove_sim_overlay()
	_is_simulating = false
	show_notification(
		"Week simulated! 7 days passed successfully.",
		CLR_GREEN
	)


## When simulation stops early: top up hunger/thirst/energy to 100; leave health unchanged.
func _reset_pet_needs_after_sim_interrupt() -> void:
	var d = get_tree().get_first_node_in_group("dog")
	if d:
		d.hunger = 100.0
		d.thirst = 100.0
		d.energy = 100.0
		GameState.dog_health = d.health


func _abort_week_simulation(reason: String, fail_day: int) -> void:
	_remove_sim_overlay()
	_is_simulating = false
	_reset_pet_needs_after_sim_interrupt()
	_trigger_simulation_warning(reason, fail_day)


## Trigger the game's existing notification/warning system with context.
## Also routes each warning to NotificationCenter for the persistent history log.
func _trigger_simulation_warning(reason: String, stopped_day: int) -> void:
	match reason:
		"out_of_food":
			show_notification(
				"Simulation stopped: Ran out of food on Day %d! Go to the shop." % stopped_day,
				CLR_RED
			)
			GameState.event_triggered.emit(
				"Pet ran out of food on Day %d during simulation!" % stopped_day
			)
			# Route directly to NotificationCenter so it stores as WARNING (clickable)
			NotificationCenter.add_notification(
					NotificationCenter.NotifType.WARNING,
					"Simulation: Ran out of food on Day %d! Go to the shop." % stopped_day)
		"out_of_water":
			show_notification(
				"Simulation stopped: Ran out of water on Day %d! Go to the shop." % stopped_day,
				CLR_RED
			)
			GameState.event_triggered.emit(
				"Pet ran out of water on Day %d during simulation!" % stopped_day
			)
			# Route directly to NotificationCenter so it stores as WARNING (clickable)
			NotificationCenter.add_notification(
					NotificationCenter.NotifType.WARNING,
					"Simulation: Ran out of water on Day %d! Go to the shop." % stopped_day)
		"vet_needed":
			show_notification(
				"Simulation stopped: Pet is sick on Day %d! Visit the vet." % stopped_day,
				CLR_RED
			)
			GameState.event_triggered.emit(
				"Pet health dropped on Day %d during simulation! Visit the vet." % stopped_day
			)
			# Route directly to NotificationCenter so it stores as WARNING (clickable)
			NotificationCenter.add_notification(
					NotificationCenter.NotifType.WARNING,
					"Simulation: Pet is sick on Day %d! Visit the vet." % stopped_day)

# ── Simulation overlay (visual feedback) ──────────────────────────────────────

## Create a dark overlay with a "Simulating…" message and day counter.
func _create_sim_overlay() -> void:
	_remove_sim_overlay()

	# Semi-transparent dark background
	_sim_overlay = ColorRect.new()
	_sim_overlay.color = Color(0, 0, 0, 0.5)
	_sim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sim_overlay.anchor_right  = 1.0
	_sim_overlay.anchor_bottom = 1.0
	_sim_overlay.mouse_filter  = Control.MOUSE_FILTER_STOP  # Block input
	add_child(_sim_overlay)

	# "Simulating…" title
	var title := Label.new()
	title.text = "Simulating Week..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", CLR_GOLD)
	var font = UITheme.get_pixel_font()
	if font:
		title.add_theme_font_override("font", font)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-200, -60)
	_sim_overlay.add_child(title)

	# Day counter "Day X / 7"
	_sim_day_label = Label.new()
	_sim_day_label.text = "Day 1 / 7..."
	_sim_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sim_day_label.add_theme_font_size_override("font_size", 42)
	_sim_day_label.add_theme_color_override("font_color", CLR_WHITE)
	if font:
		_sim_day_label.add_theme_font_override("font", font)
	_sim_day_label.set_anchors_preset(Control.PRESET_CENTER)
	_sim_day_label.position = Vector2(-100, 20)
	_sim_overlay.add_child(_sim_day_label)

## Remove the simulation overlay.
func _remove_sim_overlay() -> void:
	if _sim_overlay and is_instance_valid(_sim_overlay):
		_sim_overlay.queue_free()
		_sim_overlay = null
		_sim_day_label = null

# ══════════════════════════════════════════════════════════════════════════════
#  MENU MANAGEMENT (unchanged logic, reformatted for consistency)
# ══════════════════════════════════════════════════════════════════════════════

## Close all bottom menus so only one can be open at a time.
func _close_all_bottom_menus():
	if supplies_menu_instance and supplies_menu_instance.get_menu_visible():
		supplies_menu_instance.hide_menu()
	if taxi_menu_instance and taxi_menu_instance.get_menu_visible():
		taxi_menu_instance.hide_menu()
	var dog = get_tree().get_first_node_in_group("dog")
	if dog and dog.has_method("get_menu_visible") and dog.get_menu_visible():
		dog.toggle_menu()

func _on_supplies_btn_pressed():
	if supplies_menu_instance:
		if supplies_menu_instance.get_menu_visible():
			supplies_menu_instance.hide_menu()
		else:
			_close_all_bottom_menus()
			supplies_menu_instance.show_menu()

func _on_needs_btn_pressed():
	var dog = get_tree().get_first_node_in_group("dog")
	if dog and dog.has_method("toggle_menu"):
		var menu_is_visible = dog.has_method("get_menu_visible") and dog.get_menu_visible()
		if menu_is_visible:
			dog.toggle_menu()
		else:
			_close_all_bottom_menus()
			dog.toggle_menu()

func _on_finance_btn_pressed():
	get_tree().paused = true
	var finance_menu = finance_menu_scene.instantiate()
	add_child(finance_menu)
	finance_menu.show_menu()
	finance_menu.menu_closed.connect(func():
		finance_menu.queue_free()
		get_tree().paused = false
	)

func _on_pause_btn_pressed():
	if current_pause_menu:
		current_pause_menu.queue_free()
		current_pause_menu = null
		get_tree().paused = false
		return

	get_tree().paused = true
	current_pause_menu = pause_menu_scene.instantiate()
	add_child(current_pause_menu)
	current_pause_menu.visible = true

	current_pause_menu.get_node("Panel/VBox/ResumeBtn").pressed.connect(func():
		current_pause_menu.queue_free()
		current_pause_menu = null
		get_tree().paused = false
	)

	current_pause_menu.get_node("Panel/VBox/Header/CloseBtn").pressed.connect(func():
		current_pause_menu.queue_free()
		current_pause_menu = null
		get_tree().paused = false
	)

	current_pause_menu.get_node("Panel/VBox/QuitBtn").pressed.connect(func():
		get_tree().paused = false
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn", {"pattern": "curtains"})
	)

	current_pause_menu.get_node("Panel/VBox/HelpBtn").pressed.connect(func():
		var help_popup = load("res://scenes/ui/HelpPopup.tscn").instantiate()
		get_tree().root.add_child(help_popup)
	)

	current_pause_menu.get_node("Panel/VBox/AchievementsBtn").pressed.connect(func():
		var ach_popup = load("res://scripts/achievements_popup.gd").new()
		get_tree().root.add_child(ach_popup)
	)

	current_pause_menu.get_node("Panel/VBox/SettingsBtn").pressed.connect(func():
		var settings_menu = load("res://scenes/ui/SettingsMenu.tscn").instantiate()
		get_tree().root.add_child(settings_menu)
	)

	# Signals are now connected in _ready() so this block is no longer needed here,
	# but we guard against any duplicate connections just in case.
	if not GameState.emergency_fund_used.is_connected(_on_emergency_fund_used):
		GameState.emergency_fund_used.connect(_on_emergency_fund_used)
	if not GameState.budget_warning.is_connected(_on_budget_warning):
		GameState.budget_warning.connect(_on_budget_warning)
	if not GameState.event_triggered.is_connected(_on_event_triggered):
		GameState.event_triggered.connect(_on_event_triggered)
	if not GameState.achievement_unlocked.is_connected(_on_achievement_unlocked):
		GameState.achievement_unlocked.connect(_on_achievement_unlocked)

# ── Event / notification handlers ────────────────────────────────────────────

func _on_event_triggered(msg: String):
	show_notification("Event: " + msg, Color(0.8, 0.8, 1))

func _on_achievement_unlocked(_achievement_name: String):
	show_notification("🏆 Achievement Unlocked: Check the achievements tab to see it!", Color(1, 0.8, 0.2))

## Returns true if any overlay/submenu is currently visible.
func _is_any_overlay_open() -> bool:
	if supplies_menu_instance and supplies_menu_instance.get_menu_visible():
		return true
	if taxi_menu_instance and taxi_menu_instance.get_menu_visible():
		return true
	if shop_menu_instance and shop_menu_instance.visible:
		return true
	var dog = get_tree().get_first_node_in_group("dog")
	if dog and dog.has_method("get_menu_visible") and dog.get_menu_visible():
		return true
	return false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if not _is_any_overlay_open():
			_on_pause_btn_pressed()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
		var chore_instance = get_node_or_null("ChoreMenu")
		if chore_instance:
			chore_instance.queue_free()
		else:
			var chore_scene = load("res://scenes/ui/ChoreMenu.tscn")
			if chore_scene:
				var minigame = chore_scene.instantiate()
				minigame.name = "ChoreMenu"
				add_child(minigame)

func _on_emergency_fund_used(item_name: String):
	show_notification("Emergency Fund used for %s!" % item_name, Color(1, 0.3, 0.3))

func _on_budget_warning(category: String, message: String):
	show_notification("%s: %s" % [category, message], Color(1, 0.5, 0.2))

## Display a tween-animated notification at bottom of screen.
func show_notification(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 49)
	var font := UITheme.get_pixel_font()
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = Vector2(40, get_viewport().get_visible_rect().size.y - 215)
	label.modulate.a = 0.0
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _on_open_shop_requested():
	if shop_menu_instance:
		shop_menu_instance.show_shop()

# ══════════════════════════════════════════════════════════════════════════════
#  NOTIFICATION BUTTON
# ══════════════════════════════════════════════════════════════════════════════

## Set up the notification bell button with badge overlay.
## Called once in _ready() after all @onready refs are available.
func _setup_notif_button() -> void:
	UITheme.style_button(notif_btn, UITheme.CLR_GREY)
	notif_btn.text = ""   # No emoji — we use a TextureRect child instead

	# TextureRect icon inside the button
	_notif_icon = TextureRect.new()
	_notif_icon.texture = _tex_normal
	_notif_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_notif_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Manual scaling (scaling factor of 12 as requested)
	_notif_icon.set_anchors_preset(Control.PRESET_CENTER)
	_notif_icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notif_icon.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_notif_icon.custom_minimum_size = Vector2(100, 100)
	
	_notif_icon.pivot_offset = Vector2(50, 50)
	_notif_icon.scale = Vector2(3.0, 3.0)
	
	_notif_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notif_btn.add_child(_notif_icon)

	notif_btn.pressed.connect(_on_notif_btn_pressed)
	NotificationCenter.badge_state_changed.connect(_update_notif_badge)
	_update_notif_badge()

## Update the notification button icon to reflect current state.
## Called every time NotificationCenter.badge_state_changed fires.
func _update_notif_badge() -> void:
	# Kill any running pulse tween first
	if _notif_pulse_tween and _notif_pulse_tween.is_valid():
		_notif_pulse_tween.kill()

	if NotificationCenter.has_unread_warning:
		# WARNING state: exclamation envelope icon + red pulse animation
		_notif_icon.texture = _tex_warning
		_notif_icon.position = Vector2(0, -2)
		_notif_pulse_tween = create_tween().set_loops()
		_notif_pulse_tween.tween_callback(
				func(): UITheme.style_button(notif_btn, Color("#5a1010")))
		_notif_pulse_tween.tween_interval(0.6)
		_notif_pulse_tween.tween_callback(
				func(): UITheme.style_button(notif_btn, UITheme.CLR_GREY))
		_notif_pulse_tween.tween_interval(0.6)
	elif NotificationCenter.has_unread:
		# UNREAD state: red-badge envelope icon, no pulse
		_notif_icon.texture = _tex_badge
		_notif_icon.position = Vector2(0, -2)
		UITheme.style_button(notif_btn, UITheme.CLR_GREY)
	else:
		# CLEAR state: plain envelope icon
		_notif_icon.texture = _tex_normal
		_notif_icon.position = Vector2(-4, -4)
		UITheme.style_button(notif_btn, UITheme.CLR_GREY)

## Open the notification panel as a child of this CanvasLayer.
func _on_notif_btn_pressed() -> void:
	var panel: CanvasLayer = notification_panel_scene.new()
	add_child(panel)

## Public helper called by notification_panel.gd's taxi dialog "Yes" handler.
## Delegates to the pre-instantiated taxi_menu_instance so travel animations
## work exactly the same as the player pressing a taxi button normally.
func _travel_via_taxi(dest: String) -> void:
	if taxi_menu_instance and taxi_menu_instance.has_method("_travel_to"):
		taxi_menu_instance._travel_to(dest)

func _on_home_btn_pressed():
	if taxi_menu_instance:
		if taxi_menu_instance.get_menu_visible():
			taxi_menu_instance.hide_menu()
		else:
			_close_all_bottom_menus()
			taxi_menu_instance.show_menu()
