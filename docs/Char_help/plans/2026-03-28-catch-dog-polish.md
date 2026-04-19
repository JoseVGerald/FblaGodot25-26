# Catch & Dog Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix six issues in the catch minigame and dog system: swap the ball sprite, fix emotion bubble timing, add mute button, fix throw intervals, fix double aim-line + idle animation bugs, and add one dog AI idle behavior.

**Architecture:** All changes are isolated to `scripts/catch_game.gd`, `scripts/dog.gd`, and `scripts/SettingsMenu.gd`. No new scenes are needed. The ball sprite swap requires the user to manually place the image file first.

**Tech Stack:** Godot 4.x, GDScript 2.0, AudioServer API, Pillow (already used for sprite generation)

---

## File Map

| File | Changes |
|------|---------|
| `assets/sprites/red_ball_pixel.png` | New ball sprite (user provides file) |
| `scripts/catch_game.gd` | Ball texture path, throw timing, aim line, idle anim |
| `scripts/dog.gd` | Emotion bubble timer, prev_emotion tracking, dog idle twitch |
| `scripts/SettingsMenu.gd` | Mute button added programmatically |

---

## Task 1: Red Ball Sprite Swap

**Files:**
- Modify: `assets/sprites/` — place new PNG here
- Modify: `scripts/catch_game.gd:72`

### Prerequisite — User Action Required
The pixel-art cricket ball image the user shared needs to be saved as:
`assets/sprites/red_ball_pixel.png`

If the file isn't there yet, run this to generate a placeholder and then the user replaces it:
```bash
ls /Users/geralds/constanlyupdate/assets/sprites/
```

- [ ] **Step 1: Save the new ball image**

Copy or save the pixel-art cricket ball PNG (shown by user — red ball with white stitching seam) to:
```
/Users/geralds/constanlyupdate/assets/sprites/red_ball_pixel.png
```

- [ ] **Step 2: Update the texture path in catch_game.gd**

In `scripts/catch_game.gd`, find line ~72 in `_ready()`:
```gdscript
ball_texture = load("res://assets/sprites/red_ball_new.png") as Texture2D
```
Change to:
```gdscript
ball_texture = load("res://assets/sprites/red_ball_pixel.png") as Texture2D
```

- [ ] **Step 3: Verify texture size is right**

The ball draws at `BALL_RADIUS = 24.0` which is 48px diameter. The cricket ball PNG should be at least 64x64. If it's larger (e.g. 200x200), the `tex_size` calculation in `_draw()` already scales it to the right size since it reads `ball_texture.get_width()` — no extra changes needed.

- [ ] **Step 4: Run the game and enter catch minigame**

Confirm the cricket ball sprite appears instead of the plain red circle.

- [ ] **Step 5: Commit**
```bash
git add assets/sprites/red_ball_pixel.png scripts/catch_game.gd
git commit -m "feat: swap catch minigame ball to pixel-art cricket ball sprite"
```

---

## Task 2: Emotion Bubble Timing Fix

**Files:**
- Modify: `scripts/dog.gd`

Currently the bubble shows any time a need is critical OR on hover. New behavior:
- Show for **2 seconds** when the emotion state *changes*
- Show while *hovering* regardless of state
- Hide otherwise

- [ ] **Step 1: Add tracking variables to dog.gd**

Find the emotion bubble variable block (around line 33):
```gdscript
# Emotion bubble
var emotion_label: Label = null
var is_hovered: bool = false
```
Replace with:
```gdscript
# Emotion bubble
var emotion_label: Label = null
var is_hovered: bool = false
var prev_emotion: String = ""
var emotion_timer: float = 0.0
```

- [ ] **Step 2: Update `_update_emotion_bubble()` to use timer logic**

Find `_update_emotion_bubble()` in dog.gd and replace the entire function:
```gdscript
func _update_emotion_bubble(delta: float) -> void:
	if not emotion_label: return
	var emoji := _get_emotion_emoji()
	# State changed — restart 2-second display timer
	if emoji != prev_emotion:
		prev_emotion = emoji
		emotion_timer = 2.0
	# Tick down timer
	if emotion_timer > 0.0:
		emotion_timer = max(0.0, emotion_timer - delta)
	emotion_label.text = emoji
	emotion_label.visible = emotion_timer > 0.0 or is_hovered
```

- [ ] **Step 3: Pass delta into `_update_emotion_bubble` from `_apply_dynamic_appearance`**

Find the call site in `_apply_dynamic_appearance()`. It currently says:
```gdscript
_update_emotion_bubble()
```

`_apply_dynamic_appearance()` is called from `_physics_process(delta)` but doesn't receive delta itself. Change the call chain:

In `_physics_process(delta)`, find:
```gdscript
_apply_dynamic_appearance()
```
Change to:
```gdscript
_apply_dynamic_appearance(delta)
```

Then update the function signature:
```gdscript
func _apply_dynamic_appearance(delta: float) -> void:
```

And inside it, change:
```gdscript
_update_emotion_bubble()
```
To:
```gdscript
_update_emotion_bubble(delta)
```

- [ ] **Step 4: Test**

Run the game. Pet the dog's needs drop — the bubble should appear for 2 seconds when it first switches from ❤️ to 😢, then disappear. Hover over the dog — bubble reappears immediately. Move away — it disappears.

- [ ] **Step 5: Commit**
```bash
git add scripts/dog.gd
git commit -m "fix: emotion bubble now shows on state change (2s) and hover only"
```

---

## Task 3: Mute Button in Settings Menu

**Files:**
- Modify: `scripts/SettingsMenu.gd`

The settings menu has a volume slider. Add a mute toggle button programmatically (no scene edit needed).

- [ ] **Step 1: Add mute state tracking and button ref to SettingsMenu.gd**

At the top of `SettingsMenu.gd`, add after the existing `@onready` lines:
```gdscript
var mute_btn: Button = null
var is_muted: bool = false
```

- [ ] **Step 2: Create the mute button in `_ready()`**

In `_ready()`, after `volume_slider.value_changed.connect(_on_volume_changed)`, add:
```gdscript
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
```

- [ ] **Step 3: Add mute handler and label update**

Add these two functions at the bottom of `SettingsMenu.gd`, before the closing:
```gdscript
func _on_mute_toggled(pressed: bool) -> void:
	is_muted = pressed
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted)
	_update_mute_label()

func _update_mute_label() -> void:
	if not mute_btn: return
	mute_btn.text = "🔇 Unmute" if is_muted else "🔇 Mute"
```

- [ ] **Step 4: Test**

Open settings in-game. A Mute button should appear. Click it — audio goes silent, button text changes to "Unmute". Click again — audio returns.

- [ ] **Step 5: Commit**
```bash
git add scripts/SettingsMenu.gd
git commit -m "feat: add mute toggle button to settings menu"
```

---

## Task 4: Fix Throw Timing in Catch Minigame

**Files:**
- Modify: `scripts/catch_game.gd`

**Current behavior:**
- `_catch_ball()` calls `_launch_ball()` immediately on catch AND resets `throw_timer = 0.0`
- Interval scheduler in `_process_player()` also fires every 2s if `balls.is_empty()`
- This causes balls to fire immediately on catch AND again 2s later → effectively double-firing

**Desired behavior:**
- Normal mode: throw every 2s on a fixed clock. Dog catching does NOT reset the clock.
- Frenzy mode: throw every 0.2s on a fixed clock. Same rule.
- `balls.is_empty()` check stays — ensures one ball at a time.

- [ ] **Step 1: Remove immediate-throw from `_catch_ball()`**

Find `_catch_ball()` in catch_game.gd:
```gdscript
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
	# Dog caught it — throw the next ball immediately, reset timer
	throw_timer = 0.0
	_launch_ball()
```

Replace with:
```gdscript
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
```

- [ ] **Step 2: Verify interval scheduler in `_process_player()` is the sole firing mechanism**

Confirm these lines exist unchanged in `_process_player()`:
```gdscript
var interval := THROW_INTERVAL_FRENZY if frenzy_active else THROW_INTERVAL_NORMAL
throw_timer += delta
if throw_timer >= interval and balls.is_empty():
	throw_timer = 0.0
	_launch_ball()
```
This is already correct — `balls.is_empty()` gates it so only one ball flies at a time, and the timer is the single source of truth.

- [ ] **Step 3: Test normal mode**

Play the catch minigame. Balls should throw every ~2 seconds. Catching the ball should NOT cause an immediate re-throw.

- [ ] **Step 4: Test frenzy mode**

Wait for the 10-second frenzy threshold. Balls should throw every ~0.2 seconds. Catching should not change the rhythm.

- [ ] **Step 5: Commit**
```bash
git add scripts/catch_game.gd
git commit -m "fix: catch minigame throw interval is clock-based only, catching no longer resets timer"
```

---

## Task 5: Fix Double Aim Line + Idle Animation Bug

**Files:**
- Modify: `scripts/catch_game.gd`

**Bug A — Double aim line:** The aim line draws from `player_pos` to `next_target`. When a ball is in flight, `next_target` has already been updated to the NEXT throw location. Meanwhile the ball flies to the PREVIOUS target. This creates an apparent second visual line (the ball's arc + the aim line to a different spot). Fix: only show aim line when no ball is currently flying.

**Bug B — Player runs in place:** When player reaches `aim_target_y` (the `else` branch), no animation is set. The last `move_right` animation keeps playing. Fix: explicitly play `idle_right` when player is stationary and not throwing.

- [ ] **Step 1: Fix the aim line to only show when no ball is in flight**

Find the aim line block in `_draw()`:
```gdscript
# ── Yellow aim line (next throw target) — hidden in FRENZY MODE ──────────
if not frenzy_active and next_target != Vector2.ZERO:
```
Replace the condition:
```gdscript
# ── Yellow aim line — hidden in FRENZY MODE and while ball is in flight ──
if not frenzy_active and next_target != Vector2.ZERO and balls.is_empty():
```

- [ ] **Step 2: Fix idle animation when player is stationary**

Find `_process_player()`, the `else` branch (player has reached target):
```gdscript
else:
	player_pos.y = aim_target_y
	_sync_player_positions()
```
Replace with:
```gdscript
else:
	player_pos.y = aim_target_y
	_sync_player_positions()
	if player_throw_t <= 0.0:
		_play_player_anim("idle_right")
```

- [ ] **Step 3: Test**

Enter catch minigame. Player should stand idle between throws. When a ball is flying, the aim line should disappear and reappear only when the field is clear.

- [ ] **Step 4: Commit**
```bash
git add scripts/catch_game.gd
git commit -m "fix: aim line hides during ball flight, player plays idle when stationary"
```

---

## Task 6: Dog AI — Add Idle Twitch Behavior

**Files:**
- Modify: `scripts/dog.gd`

**Current AI assessment:** The dog already has solid following logic (path-based trailing at 67px, teleport recovery, color moods, jitter when sick, run/idle animation switching). For FBLA judges this is already strong. One addition that would make it feel alive: an **occasional idle twitch** — when the dog has been stationary for 3+ seconds, it briefly plays the run animation for 0.3s then returns to idle, simulating a fidget/shake.

- [ ] **Step 1: Add idle twitch variables to dog.gd**

After the emotion bubble variables block, add:
```gdscript
# Idle twitch
var idle_time: float = 0.0
var twitch_timer: float = 0.0
```

- [ ] **Step 2: Add twitch logic to `_process_following_player()`**

At the very end of `_process_following_player()`, after the existing idle/run animation block, add:
```gdscript
# Idle twitch — fidget after 3s of standing still
if old_pos.distance_to(global_position) <= 0.1:
	idle_time += delta
	if twitch_timer > 0.0:
		twitch_timer -= delta
		_play_animation("run")
		if twitch_timer <= 0.0:
			_play_animation("idle")
	elif idle_time >= 3.0:
		idle_time = 0.0
		twitch_timer = 0.3
else:
	idle_time = 0.0
	twitch_timer = 0.0
```

- [ ] **Step 3: Test**

Run the game and stand still near the dog for 3+ seconds. The dog should briefly twitch/shake then return to idle — like a real dog shaking off.

- [ ] **Step 4: Commit**
```bash
git add scripts/dog.gd
git commit -m "feat: dog plays idle twitch animation after 3s of standing still"
```

---

## Self-Review

**Spec coverage:**
- ✅ Task 1 — ball sprite swap
- ✅ Task 2 — emotion bubble 2s timer + hover only
- ✅ Task 3 — mute button in settings
- ✅ Task 4 — throw interval clock-only (normal 2s, frenzy 0.2s)
- ✅ Task 5 — aim line double-draw fix, idle animation fix
- ✅ Task 6 — dog AI idle twitch

**Placeholder scan:** None found. All steps have concrete code.

**Type consistency:**
- `_apply_dynamic_appearance(delta: float)` signature change propagates correctly through Task 2 steps
- `_update_emotion_bubble(delta: float)` matches its call site
- `prev_emotion: String` and `emotion_timer: float` are consistent throughout Task 2

**Dependency note:** Task 2 Step 3 (delta plumbing) must be done before Step 2 compiles correctly.

<!-- Updated on 2026-04-19 -->
