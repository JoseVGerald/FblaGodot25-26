# NPC System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 wandering NPCs (Dude1–4, Girl1, Girl2) to the MainGame, each with their own dog companion, hitbox, proximity interaction, and DialogueManager dialogue.

**Architecture:** NPCs are spawned programmatically in `MainGame.gd` using the existing character scenes with `npc_wanderer.gd` set as an overriding script. Each NPC gets an NPC dog child (dog.tscn instance with `npc_dog.gd` overriding its script). All interaction area setup and label creation happens in `npc_wanderer.gd`'s `_ready()` so no .tscn edits are needed for the character scenes.

**Tech Stack:** Godot 4.x / GDScript 2.0, DialogueManager plugin, existing character + dog scenes.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/npc_wanderer.gd` | **Create** | Wander logic, interaction area, dialogue trigger, hitbox |
| `scripts/npc_dog.gd` | **Create** | Simplified dog follow (offset behind NPC, no needs) |
| `dialogues/npc_dude1.dialogue` | **Create** | Dude1 dialogue lines |
| `dialogues/npc_dude2.dialogue` | **Create** | Dude2 dialogue lines |
| `dialogues/npc_dude3.dialogue` | **Create** | Dude3 dialogue lines |
| `dialogues/npc_dude4.dialogue` | **Create** | Dude4 dialogue lines |
| `dialogues/npc_girl1.dialogue` | **Create** | Girl1 dialogue lines |
| `dialogues/npc_girl2.dialogue` | **Create** | Girl2 dialogue lines |
| `scripts/MainGame.gd` | **Modify** | Add `spawn_npcs()` call and NPC config array |

---

## Task 1: Create `npc_wanderer.gd`

**Files:**
- Create: `scripts/npc_wanderer.gd`

- [ ] **Step 1: Create the script**

```gdscript
# scripts/npc_wanderer.gd
extends CharacterBody2D

@export var wander_radius: float = 150.0
@export var wander_speed: float = 80.0
@export var dialogue_resource: DialogueResource
@export var interaction_radius: float = 60.0

var spawn_position: Vector2
var wander_target: Vector2
var wait_timer: float = 0.0
var is_waiting: bool = true
var player_in_range: bool = false
var stuck_timer: float = 0.0

var _sprite: AnimatedSprite2D
var _interaction_area: Area2D
var _interaction_label: Label

func _ready() -> void:
	remove_from_group("player")
	# Match player collision layers so NPC blocks and is blocked by the same things
	collision_layer = 1
	collision_mask = 1

	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.enabled = false

	_sprite = get_node_or_null("Sprite2D")

	spawn_position = global_position
	wander_target = global_position
	wait_timer = randf_range(0.5, 2.0)

	_setup_interaction()

func _setup_interaction() -> void:
	_interaction_label = Label.new()
	_interaction_label.text = "Press E"
	_interaction_label.position = Vector2(-20, -50)
	_interaction_label.visible = false
	add_child(_interaction_label)

	_interaction_area = Area2D.new()
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interaction_radius
	shape_node.shape = circle
	_interaction_area.add_child(shape_node)
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)
	add_child(_interaction_area)

func _physics_process(delta: float) -> void:
	if is_waiting:
		wait_timer -= delta
		if wait_timer <= 0.0:
			is_waiting = false
			_pick_new_target()
		_play_animation("idle")
		return

	var direction := wander_target - global_position
	var distance := direction.length()

	if distance < 8.0:
		_arrive()
		return

	stuck_timer += delta
	if stuck_timer > 3.0:
		_arrive()
		return

	var old_pos := global_position
	velocity = direction.normalized() * wander_speed
	move_and_slide()

	if global_position.distance_to(old_pos) > 0.5:
		stuck_timer = 0.0

	if _sprite:
		_sprite.flip_h = velocity.x < 0
	_play_animation("move_right" if velocity.x >= 0 else "move_left")

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		if dialogue_resource:
			DialogueManager.show_example_dialogue_balloon(dialogue_resource, "start")

func _arrive() -> void:
	velocity = Vector2.ZERO
	is_waiting = true
	wait_timer = randf_range(1.0, 3.0)
	stuck_timer = 0.0

func _pick_new_target() -> void:
	var angle := randf() * TAU
	var radius := randf() * wander_radius
	wander_target = spawn_position + Vector2(cos(angle), sin(angle)) * radius

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if _interaction_label:
			_interaction_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if _interaction_label:
			_interaction_label.visible = false

func _play_animation(anim_name: String) -> void:
	if not _sprite: return
	if _sprite.sprite_frames.has_animation(anim_name):
		_sprite.play(anim_name)
```

- [ ] **Step 2: Verify file exists**

```bash
ls /Users/geralds/constanlyupdate/scripts/npc_wanderer.gd
```
Expected: file listed

- [ ] **Step 3: Commit**

```bash
git add scripts/npc_wanderer.gd
git commit -m "feat: add npc_wanderer.gd — wander, interaction, dialogue trigger"
```

---

## Task 2: Create `npc_dog.gd`

**Files:**
- Create: `scripts/npc_dog.gd`

- [ ] **Step 1: Create the script**

```gdscript
# scripts/npc_dog.gd
extends CharacterBody2D

@export var breed: String = "basic_Dog"
@export var follow_offset: Vector2 = Vector2(-40, 0)
@export var follow_speed: float = 120.0

var _sprite: AnimatedSprite2D

func _ready() -> void:
	# Disconnect any signals wired up by dog.gd before script override
	# and skip dog.gd _ready entirely — this script replaces it fully.
	_sprite = get_node_or_null("AnimatedSprite2D")
	# Disable the needs menu that dog.tscn may have queued
	# (needs_menu_instance was not set since _ready ran fresh here)

func _physics_process(_delta: float) -> void:
	var owner_node := get_parent()
	if not owner_node:
		return

	var target := owner_node.global_position + follow_offset
	var direction := target - global_position
	var distance := direction.length()

	if distance < 5.0:
		velocity = Vector2.ZERO
		move_and_slide()
		_play_animation("idle")
		return

	velocity = direction.normalized() * follow_speed
	move_and_slide()

	if _sprite:
		_sprite.flip_h = velocity.x < 0
	_play_animation("run")

func _play_animation(anim_name: String) -> void:
	if not _sprite: return
	var names_to_try := [
		breed + "_" + anim_name,
		"basic_Dog_" + anim_name,
		anim_name,
	]
	for name in names_to_try:
		if _sprite.sprite_frames.has_animation(name):
			if _sprite.animation != name:
				_sprite.play(name)
			return
```

- [ ] **Step 2: Verify file exists**

```bash
ls /Users/geralds/constanlyupdate/scripts/npc_dog.gd
```
Expected: file listed

- [ ] **Step 3: Commit**

```bash
git add scripts/npc_dog.gd
git commit -m "feat: add npc_dog.gd — simplified offset-follow dog for NPCs"
```

---

## Task 3: Create all 6 dialogue files

**Files:**
- Create: `dialogues/npc_dude1.dialogue`
- Create: `dialogues/npc_dude2.dialogue`
- Create: `dialogues/npc_dude3.dialogue`
- Create: `dialogues/npc_dude4.dialogue`
- Create: `dialogues/npc_girl1.dialogue`
- Create: `dialogues/npc_girl2.dialogue`

- [ ] **Step 1: Create npc_dude1.dialogue**

```
~ start
Dude1: Hey there! My Cane Corso looks tough but he's a big softie.
Dude1: He loves belly rubs more than anything.
Dude1: Don't let the size fool you — he's scared of butterflies.
=> END
```
Save to `res://dialogues/npc_dude1.dialogue`

- [ ] **Step 2: Create npc_dude2.dialogue**

```
~ start
Dude2: Golden Retrievers are the best dogs, no debate.
Dude2: My girl fetches everything — keys, socks, my TV remote...
Dude2: She once brought me a whole loaf of bread from the counter.
=> END
```
Save to `res://dialogues/npc_dude2.dialogue`

- [ ] **Step 3: Create npc_dude3.dialogue**

```
~ start
Dude3: 101 Dalmatians? More like 1 is more than enough.
Dude3: He has so much energy I can barely keep up.
Dude3: Spotted dogs, spotted personality — never know what he'll do next.
=> END
```
Save to `res://dialogues/npc_dude3.dialogue`

- [ ] **Step 4: Create npc_dude4.dialogue**

```
~ start
Dude4: People always cross the street when they see my Rottie.
Dude4: He just wants to say hi, I promise.
Dude4: Best guard dog I've ever had. Also best couch buddy.
=> END
```
Save to `res://dialogues/npc_dude4.dialogue`

- [ ] **Step 5: Create npc_girl1.dialogue**

```
~ start
Girl1: My Husky thinks she's a wolf. A very dramatic wolf.
Girl1: She howls at everything. The moon, the mailman, cartoons.
Girl1: I haven't slept a full night since I got her. Worth it.
=> END
```
Save to `res://dialogues/npc_girl1.dialogue`

- [ ] **Step 6: Create npc_girl2.dialogue**

```
~ start
Girl2: Pharaoh Hounds are ancient — like, actual Egyptian royalty.
Girl2: Mine acts like royalty too. Very picky about his food.
Girl2: He blushes when he's excited. His nose literally turns pink!
=> END
```
Save to `res://dialogues/npc_girl2.dialogue`

- [ ] **Step 7: Verify all dialogue files exist**

```bash
ls /Users/geralds/constanlyupdate/dialogues/npc_*.dialogue
```
Expected: 6 files listed

- [ ] **Step 8: Commit**

```bash
git add dialogues/npc_dude1.dialogue dialogues/npc_dude2.dialogue dialogues/npc_dude3.dialogue dialogues/npc_dude4.dialogue dialogues/npc_girl1.dialogue dialogues/npc_girl2.dialogue
git commit -m "feat: add dialogue files for 6 NPCs"
```

---

## Task 4: Add `spawn_npcs()` to `MainGame.gd`

**Files:**
- Modify: `scripts/MainGame.gd`

The player spawns at `Vector2(716, 323)`. NPC spawn positions are spread across the map. These may need minor visual adjustment after first run.

- [ ] **Step 1: Add preloads and NPC config at the top of MainGame.gd**

Find this line at the top of `scripts/MainGame.gd`:
```gdscript
var Day1Tutorial = preload("res://scripts/day1_tutorial.gd")
```

Add these lines immediately before it:
```gdscript
const NpcWandererScript = preload("res://scripts/npc_wanderer.gd")
const NpcDogScript = preload("res://scripts/npc_dog.gd")
const DogScene = preload("res://scenes/People and dog/dog.tscn")

const NPC_CONFIGS = [
	{
		"scene": "res://scenes/People and dog/Dude1.tscn",
		"dialogue": "res://dialogues/npc_dude1.dialogue",
		"dog_breed": "basic_Dog",
		"position": Vector2(316, 123),
		"wander_radius": 150.0
	},
	{
		"scene": "res://scenes/People and dog/Dude2.tscn",
		"dialogue": "res://dialogues/npc_dude2.dialogue",
		"dog_breed": "Golden_Retriever",
		"position": Vector2(1116, 123),
		"wander_radius": 150.0
	},
	{
		"scene": "res://scenes/People and dog/Dude3.tscn",
		"dialogue": "res://dialogues/npc_dude3.dialogue",
		"dog_breed": "dalmatian",
		"position": Vector2(316, 423),
		"wander_radius": 130.0
	},
	{
		"scene": "res://scenes/People and dog/Dude4.tscn",
		"dialogue": "res://dialogues/npc_dude4.dialogue",
		"dog_breed": "rottie",
		"position": Vector2(1116, 423),
		"wander_radius": 130.0
	},
	{
		"scene": "res://scenes/People and dog/girl1.tscn",
		"dialogue": "res://dialogues/npc_girl1.dialogue",
		"dog_breed": "Husky",
		"position": Vector2(316, 623),
		"wander_radius": 120.0
	},
	{
		"scene": "res://scenes/People and dog/girl2.tscn",
		"dialogue": "res://dialogues/npc_girl2.dialogue",
		"dog_breed": "Pharoah_hound",
		"position": Vector2(1116, 623),
		"wander_radius": 120.0
	},
]
```

- [ ] **Step 2: Add `spawn_npcs()` function**

Find this function in `scripts/MainGame.gd`:
```gdscript
func spawn_player():
```

Add the following new function immediately before `spawn_player()`:
```gdscript
func spawn_npcs() -> void:
	for config in NPC_CONFIGS:
		var npc: CharacterBody2D = load(config["scene"]).instantiate()
		npc.set_script(NpcWandererScript)
		npc.position = config["position"]
		npc.wander_radius = config["wander_radius"]
		npc.dialogue_resource = load(config["dialogue"])
		add_child(npc)

		var dog: CharacterBody2D = DogScene.instantiate()
		dog.set_script(NpcDogScript)
		dog.breed = config["dog_breed"]
		dog.position = Vector2(0, 0)
		npc.add_child(dog)

```

- [ ] **Step 3: Call `spawn_npcs()` in `_ready()`**

Find this line in `_ready()`:
```gdscript
	spawn_player()
```

Change it to:
```gdscript
	spawn_player()
	spawn_npcs()
```

- [ ] **Step 4: Verify the diff looks correct**

```bash
git diff scripts/MainGame.gd
```
Expected: shows `spawn_npcs()` call added in `_ready()`, new function defined, constants and config array at top.

- [ ] **Step 5: Commit**

```bash
git add scripts/MainGame.gd
git commit -m "feat: spawn 6 wandering NPCs with dogs in MainGame"
```

---

## Task 5: Verify in Godot

- [ ] **Step 1: Run the project**

Use `mcp__godot__run_project` to launch the game.

- [ ] **Step 2: Wait 3 seconds and get debug output**

Use `mcp__godot__get_debug_output` after 3 seconds.

Check for:
- No script errors about `NpcWandererScript`, `NpcDogScript`, or dialogue resources
- No `Invalid get index 'wander_radius'` errors (means set_script is working)
- No Camera2D takeover (only one camera should be active — the player's)

- [ ] **Step 3: Walk player near an NPC**

Verify in game:
- "Press E" label appears when close
- Dialogue balloon opens on E press
- NPC is wandering and not entering walls
- NPC dog follows its NPC with offset

- [ ] **Step 4: If Camera2D takeover occurs (multiple cameras fighting)**

In `scripts/npc_wanderer.gd`, `_ready()` already disables the camera:
```gdscript
var cam = get_node_or_null("Camera2D")
if cam:
    cam.enabled = false
```
If the issue persists, also add `cam.queue_free()` on the next line to fully remove it.

- [ ] **Step 5: Adjust NPC spawn positions if any NPCs are inside walls**

Edit the `NPC_CONFIGS` positions in `scripts/MainGame.gd`. The player spawns at `Vector2(716, 323)`. Adjust any NPC position that visually lands inside a collision boundary.

- [ ] **Step 6: Commit final position adjustments if any were needed**

```bash
git add scripts/MainGame.gd
git commit -m "fix: adjust NPC spawn positions to avoid collision boundaries"
```

---

## Spawn Position Reference

| NPC | Spawn Position | Notes |
|-----|---------------|-------|
| Dude1 | `Vector2(316, 123)` | Top-left of map |
| Dude2 | `Vector2(1116, 123)` | Top-right of map |
| Dude3 | `Vector2(316, 423)` | Center-left |
| Dude4 | `Vector2(1116, 423)` | Center-right |
| Girl1 | `Vector2(316, 623)` | Bottom-left |
| Girl2 | `Vector2(1116, 623)` | Bottom-right |

Player spawns at `Vector2(716, 323)` for reference. All positions may need adjustment after visual testing.
