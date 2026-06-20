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
var daycare_menu_scene = preload("res://scripts/daycare_menu.gd")
var daycare_menu_instance = null
var daycare_btn: Button = null

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
signal finance_menu_opened

var status_lbl: Label = null
var work_btn: Button = null


# ══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready():
	add_to_group("hud")
	# Ensure HUD processes while paused so escape can unpause
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply_overlay_theme(self)
	_apply_redesign_styling()

	supplies_btn.pressed.connect(_on_supplies_btn_pressed)
	needs_btn.pressed.connect(_on_needs_btn_pressed)
	finance_btn.pressed.connect(_on_finance_btn_pressed)
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	home_btn.pressed.connect(_on_home_btn_pressed)

	# Create daycare menu instance (teens/adults only — button gated separately)
	daycare_menu_instance = daycare_menu_scene.new()
	add_child(daycare_menu_instance)

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

	# Wire GameState signals → NotificationCenter + transient HUD popups.
	# IMPORTANT: every connection uses a named method + is_connected() guard so
	# re-entering _ready (scene reload, re-instance) can't stack duplicates.
	# (We previously used anonymous lambdas here, which can't be deduped and
	# caused every notification to fire 4× after a few scene transitions.)
	if not GameState.event_triggered.is_connected(_on_event_to_center):
		GameState.event_triggered.connect(_on_event_to_center)
	if not GameState.achievement_unlocked.is_connected(_on_achievement_to_center):
		GameState.achievement_unlocked.connect(_on_achievement_to_center)
	if not GameState.emergency_fund_used.is_connected(_on_emergency_to_center):
		GameState.emergency_fund_used.connect(_on_emergency_to_center)
	if not GameState.budget_warning.is_connected(_on_budget_to_center):
		GameState.budget_warning.connect(_on_budget_to_center)

	# Transient HUD popup handlers (the toast messages).
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
	call_deferred("_float_time_label_center")

func _process(_delta):
	update_ui()

## Update the money and time labels every frame.
func update_ui():
	money_label.text = "$%.2f" % GameState.money
	_apply_time_label_text()
	_update_hud_status_label()
	if daycare_btn:
		daycare_btn.visible = (GameState.active_job != "none") and (not GameState.daycare_used_today) and (not GameState.worked_today)

# ══════════════════════════════════════════════════════════════════════════════
#  VISUAL REDESIGN (applied at _ready)
# ══════════════════════════════════════════════════════════════════════════════

## Restyle HUD nodes to match the April 2026 redesign spec.
## Runs once at _ready — all existing node paths are preserved.
func _apply_redesign_styling() -> void:
	# Background bar — dark charcoal with dark maroon top border
	var bg := get_node_or_null("Background")
	if bg is Panel:
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = UITheme.CLR_INK
		bg_sb.border_color = UITheme.CLR_MAROON_D
		bg_sb.border_width_top = 4
		bg_sb.set_corner_radius_all(0)
		bg.add_theme_stylebox_override("panel", bg_sb)
		bg.self_modulate.a = 1.0

	# Money label — pixel font, gold, big.
	money_label.text = "$%.2f" % GameState.money
	money_label.add_theme_color_override("font_color", UITheme.CLR_GOLD)
	money_label.add_theme_font_size_override("font_size", 58)
	var pf := UITheme.get_pixel_font()
	if pf: money_label.add_theme_font_override("font", pf)

	# Daycare button — teen/adult only, sits 20px right of the money label
	if GameState.selected_pathway in ["teenager", "adult"]:
		var left_sec = get_node_or_null("Background/Margin/MainHBox/LeftSection")
		if left_sec:
			# Convert LeftSection to HBoxContainer layout by adding a spacer + button
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(20, 0)
			spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			left_sec.add_child(spacer)

			daycare_btn = Button.new()
			daycare_btn.name = "DaycareBtn"
			daycare_btn.text = "🐾 Daycare"
			daycare_btn.custom_minimum_size = Vector2(140, 80) # Sized consistent with other nav buttons
			UITheme.style_pixel_button_colored(daycare_btn, UITheme.CLR_PINK)
			daycare_btn.add_theme_font_size_override("font_size", 22)
			left_sec.add_child(daycare_btn)
			daycare_btn.pressed.connect(_on_daycare_btn_pressed)

	# Status Indicator (created but kept off-screen — work_btn visibility still needs it)
	var	left_sec = get_node_or_null("Background/Margin/MainHBox/LeftSection")
	if left_sec:
		status_lbl = Label.new()
		status_lbl.name = "StatusLabel"
		status_lbl.add_theme_color_override("font_color", UITheme.CLR_GRAY_DRK)
		status_lbl.add_theme_font_size_override("font_size", 20)
		if pf: status_lbl.add_theme_font_override("font", pf)
		left_sec.add_child(status_lbl)
		status_lbl.visible = false  # job/shift info removed from HUD (visible in Work menu)

	# Color-code and size nav buttons
	supplies_btn.text = "Supplies"
	needs_btn.text    = "Needs"
	home_btn.text     = "Taxi"
	
	supplies_btn.custom_minimum_size = Vector2(160, 80)
	needs_btn.custom_minimum_size = Vector2(160, 80)
	home_btn.custom_minimum_size = Vector2(160, 80)
	
	UITheme.style_pixel_button_colored(supplies_btn, UITheme.CLR_ORANGE_PX)
	UITheme.style_pixel_button_colored(needs_btn, Color("#4A90D9"))
	UITheme.style_pixel_button_colored(home_btn, UITheme.CLR_RED)
	
	for b in [supplies_btn, needs_btn, home_btn]:
		b.add_theme_font_size_override("font_size", 26)

	# Create Work button for Teen/Adult pathways (green highlight)
	var right_sec = get_node_or_null("Background/Margin/MainHBox/RightSection")
	if right_sec:
		work_btn = Button.new()
		work_btn.name = "WorkBtn"
		work_btn.text = "Work"
		work_btn.custom_minimum_size = Vector2(140, 80)
		UITheme.style_pixel_button_colored(work_btn, UITheme.CLR_GREEN)
		work_btn.add_theme_font_size_override("font_size", 26)
		right_sec.add_child(work_btn)
		work_btn.pressed.connect(_on_work_btn_pressed)

	# Style top-right menu icon buttons
	var top_hud = get_node_or_null("TopRightHUD")
	if top_hud is HBoxContainer:
		top_hud.offset_left = -320.0
		top_hud.offset_bottom = 120.0
		top_hud.add_theme_constant_override("separation", 16)

	finance_btn.text = "📋"
	finance_btn.custom_minimum_size = Vector2(72, 72)
	UITheme.style_pixel_button_colored(finance_btn, UITheme.CLR_CREAM_LT)
	finance_btn.add_theme_color_override("font_color", UITheme.CLR_INK)
	finance_btn.add_theme_color_override("font_hover_color", UITheme.CLR_INK)
	finance_btn.add_theme_font_size_override("font_size", 36)

	pause_btn.text = "⚙️"
	pause_btn.custom_minimum_size = Vector2(72, 72)
	UITheme.style_pixel_button_colored(pause_btn, UITheme.CLR_CREAM_LT)
	pause_btn.add_theme_color_override("font_color", UITheme.CLR_INK)
	pause_btn.add_theme_color_override("font_hover_color", UITheme.CLR_INK)
	pause_btn.add_theme_font_size_override("font_size", 36)

func _update_hud_status_label():
	if not is_instance_valid(status_lbl):
		return
	
	if GameState.selected_pathway == "kid":
		status_lbl.text = "Kid Pathway"
	elif GameState.selected_pathway == "teenager":
		var job_str = "No Job"
		if GameState.active_job == "news_boy": job_str = "Mail Boy"
		elif GameState.active_job == "burger_cashier": job_str = "The Cook"
		elif GameState.active_job == "bank_accountant": job_str = "Bank Accountant"
		if GameState.active_job != "none": job_str += " (" + GameState.get_job_title(GameState.active_job) + ")"
		status_lbl.text = "Job: %s | Work: %d/3 days" % [job_str, GameState.days_worked_this_week]
	elif GameState.selected_pathway == "adult":
		var job_str = "No Job"
		if GameState.active_job == "news_boy": job_str = "Mail Boy"
		elif GameState.active_job == "burger_cashier": job_str = "The Cook"
		elif GameState.active_job == "bank_accountant": job_str = "Bank Accountant"
		if GameState.active_job != "none": job_str += " (" + GameState.get_job_title(GameState.active_job) + ")"

		var rent_str = "Rent Due: %d days" % GameState.rent_timer if not GameState.house_owned else "Home Owned!"
		status_lbl.text = "Job: %s\nWork: %d/%d days | %s" % [
			job_str, 
			GameState.days_worked_this_week, 
			GameState.work_days_scheduled,
			rent_str
		]
	
	if is_instance_valid(work_btn):
		# Visible whenever the player holds a job. It stays enabled even after
		# the weekly shift quota is hit so they can still ask for a raise or
		# promotion — the popup gates the "Work a Shift" option itself.
		var show_work = GameState.selected_pathway != "kid" and GameState.active_job != "none"
		work_btn.visible = show_work
		work_btn.disabled = false

## Reparent time_label out of the HBox so it floats centered over the full HUD width.
## A spacer replaces it in the HBox so the flanking sections keep their layout.
func _float_time_label_center() -> void:
	var bg := get_node_or_null("Background")
	if not bg or not is_instance_valid(time_label):
		return
	var hbox := time_label.get_parent()
	if hbox:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(spacer)
		hbox.move_child(spacer, time_label.get_index())
	# Re-parent to Background so it spans the full HUD width
	time_label.reparent(bg)
	time_label.set_anchor(SIDE_LEFT,   0.0)
	time_label.set_anchor(SIDE_RIGHT,  1.0)
	time_label.set_anchor(SIDE_TOP,    0.0)
	time_label.set_anchor(SIDE_BOTTOM, 1.0)
	time_label.offset_left   = 0.0
	time_label.offset_right  = 0.0
	time_label.offset_top    = 0.0
	time_label.offset_bottom = 0.0
	time_label.z_index       = 2
	# IGNORE so the full-width overlay doesn't steal clicks from HUD buttons
	time_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE

func _on_work_btn_pressed():
	if GameState.active_job == "none":
		show_notification("You do not have a job yet! Talk to Mother or choose a job first.", CLR_RED)
		return

	# Open the work-action popup: work a shift, or gamble on a raise/promotion.
	if get_tree().root.has_node("WorkActionMenu"):
		return
	var menu = load("res://scripts/work_action_menu.gd").new()
	menu.name = "WorkActionMenu"
	get_tree().root.add_child(menu)


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
		time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
			time_label.text = "[center][color=#%s][u]%s[/u][/color][/center]" % [UITheme.CLR_ORANGE_PX.to_html(false), s]
		else:
			time_label.text = "[center][color=#%s]%s[/color][/center]" % [UITheme.CLR_CREAM_LT.to_html(false), s]
	else:
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.text = s
		time_label.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)


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

## Main entry point: plays ONE curtain transition, ticks through days behind it,
## then fades back in. Hunger, thirst, energy stay at 100. Only health changes.
## On interruption (out of food/water, vet needed), we stop at that day and
## the single transition still wraps only that shortened span.
func _start_week_simulation() -> void:
	_is_simulating = true

	# Close the curtain once for the whole simulation.
	await SceneManager.fade_out({"pattern": "curtains"})

	var dog = get_tree().get_first_node_in_group("dog")

	# Keep needs pegged at max for the entire simulation
	if dog:
		dog.hunger = 100.0
		dog.thirst = 100.0
		dog.energy = 100.0

	var aborted := false
	var abort_reason := ""
	var abort_day := 0

	for day_offset in range(1, 8):
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
			abort_reason = "out_of_food"; abort_day = fail_day; aborted = true
			break
		if GameState.water <= 0:
			abort_reason = "out_of_water"; abort_day = fail_day; aborted = true
			break
		if dog and dog.health < 50.0:
			abort_reason = "vet_needed"; abort_day = fail_day; aborted = true
			break

		GameState.advance_day_after_simulation_supply()
		if dog:
			dog.health = GameState.dog_health

	if aborted:
		_reset_pet_needs_after_sim_interrupt()

	# Single fade-in at the end — one transition for the whole span.
	await SceneManager.fade_in({"pattern": "curtains"})

	_is_simulating = false
	if aborted:
		_trigger_simulation_warning(abort_reason, abort_day)
	else:
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
	title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
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
	finance_menu_opened.emit()
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

# ── Event / notification handlers ────────────────────────────────────────────

func _on_event_triggered(msg: String):
	show_notification("Event: " + msg, Color(0.8, 0.8, 1))

func _on_achievement_unlocked(_achievement_name: String):
	show_notification("🏆 Achievement Unlocked: Check the achievements tab to see it!", Color(1, 0.8, 0.2))

# ── NotificationCenter mirror handlers (named so they can be deduped) ─────────

func _on_event_to_center(msg: String) -> void:
	NotificationCenter.add_notification(NotificationCenter.NotifType.EVENT, msg)

func _on_achievement_to_center(ach_name: String) -> void:
	NotificationCenter.add_notification(
		NotificationCenter.NotifType.ACHIEVEMENT,
		"Achievement Unlocked: " + ach_name,
	)

func _on_emergency_to_center(item: String) -> void:
	NotificationCenter.add_notification(
		NotificationCenter.NotifType.WARNING,
		"Emergency fund used for: " + item,
	)

func _on_budget_to_center(cat: String, msg: String) -> void:
	NotificationCenter.add_notification(
		NotificationCenter.NotifType.WARNING,
		cat + ": " + msg,
	)

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

func _input(event):
	# B triggers a week sim from anywhere (same behavior as clicking the
	# date label). Only guard against stacking a second sim on top of one
	# that's already running.
	if event.is_action_pressed("sim_day"):
		if not _is_simulating:
			_start_week_simulation()
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if _is_any_overlay_open():
			_close_all_bottom_menus()
			if shop_menu_instance and shop_menu_instance.visible:
				shop_menu_instance.hide_shop()
		else:
			_on_pause_btn_pressed()
	elif event.is_action_pressed("chore_menu"):
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
	notif_btn.custom_minimum_size = Vector2(72, 72)
	UITheme.style_pixel_button_colored(notif_btn, UITheme.CLR_CREAM_LT)
	notif_btn.text = ""   # No emoji — we use a TextureRect child instead

	# TextureRect icon inside the button
	_notif_icon = TextureRect.new()
	_notif_icon.texture = _tex_normal
	_notif_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_notif_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_notif_icon.custom_minimum_size = Vector2(40, 40)
	_notif_icon.size = Vector2(40, 40)
	_notif_icon.position = Vector2(16, 16)
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
		_notif_icon.position = Vector2(16, 16)
		_notif_pulse_tween = create_tween().set_loops()
		_notif_pulse_tween.tween_callback(
				func(): notif_btn.modulate = UITheme.CLR_RED)
		_notif_pulse_tween.tween_interval(0.6)
		_notif_pulse_tween.tween_callback(
				func(): notif_btn.modulate = Color.WHITE)
		_notif_pulse_tween.tween_interval(0.6)
	elif NotificationCenter.has_unread:
		# UNREAD state: red-badge envelope icon, no pulse
		_notif_icon.texture = _tex_badge
		_notif_icon.position = Vector2(16, 16)
		notif_btn.modulate = Color.WHITE
	else:
		# CLEAR state: plain envelope icon
		_notif_icon.texture = _tex_normal
		_notif_icon.position = Vector2(16, 16)
		notif_btn.modulate = Color.WHITE

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

func _on_daycare_btn_pressed() -> void:
	if daycare_menu_instance:
		daycare_menu_instance.open()

# Updated on 2026-04-19
