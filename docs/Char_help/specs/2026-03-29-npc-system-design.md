# NPC System Design
**Date:** 2026-03-29

## Overview

Six wandering NPCs placed across the world map, each with their own dog companion. NPCs roam randomly within a radius, have hitboxes matching the player's size, and can be talked to when the player walks close enough. Dialogue is handled via DialogueManager.

---

## Characters & Placement

| NPC   | Dog Breed ID      | Dog Breed Name  | Spawn Area          |
|-------|-------------------|-----------------|---------------------|
| Dude1 | `basic_Dog`       | Cane Corso      | Near top-left       |
| Dude2 | `Golden_Retriever`| Golden Retriever| Near top-right      |
| Dude3 | `dalmatian`       | Dalmatian       | Near center-left    |
| Dude4 | `rottie`          | Rottweiler      | Near center-right   |
| Girl1 | `Husky`           | Husky           | Near bottom-left    |
| Girl2 | `Pharoah_hound`   | Pharaoh Hound   | Near bottom-right   |

---

## Architecture

### `npc_wanderer.gd` (new script)

Single reusable `CharacterBody2D` script attached to all 6 NPC scenes.

**Exports:**
- `wander_radius: float` — max distance from spawn point to wander
- `wander_speed: float` — movement speed while wandering
- `dialogue_resource: DialogueResource` — the NPC's `.dialogue` file
- `interaction_radius: float` — distance at which player can interact

**Wander behavior:**
- On ready, record `spawn_position`
- Pick a random point within `wander_radius` of `spawn_position`
- Move toward it using `move_and_slide()` (collision with walls/borders handled automatically)
- On arrival (or after a stuck timeout), wait 1–3 seconds then pick a new target
- NPCs never leave their wander radius; wander targets are clamped to spawn + radius

**Interaction:**
- `Area2D` with `CircleShape2D` at `interaction_radius` detects player entering/exiting
- Shows a `Label` ("Press E") when player is in range
- On `interact` input press: calls `DialogueManager.show_example_dialogue_balloon(dialogue_resource, "start")`
- Resets after player leaves range so dialogue can trigger again on next approach

**Hitbox:**
- `CollisionShape2D` matching the player's capsule/rectangle dimensions exactly
- Same collision layer/mask as player (layer 1, mask 1)

---

### `npc_dog.gd` (new script)

Simplified follow-only dog script. No needs, no menus, no health, no emotion bubbles.

**Exports:**
- `breed: String` — breed ID (e.g. `"Husky"`, `"dalmatian"`)
- `follow_offset: Vector2` — fixed offset from NPC owner (default `Vector2(-40, 0)`)
- `follow_speed: float` — movement speed toward target position

**Follow behavior:**
- Each frame, compute target = NPC owner's `global_position + follow_offset`
- Move toward target using `move_and_slide()`
- Flip `AnimatedSprite2D` horizontally based on movement direction
- Play `breed + "_run"` when moving, `breed + "_idle"` when at rest
- Falls back to `"basic_Dog_idle"` / `"basic_Dog_run"` if breed animation missing

**Structure:**
- Dog is a child node of the NPC scene (moves with NPC's area automatically)
- Uses the existing `dog.tscn` as a base for sprite frames

---

## Scene Structure (per NPC)

```
NpcDude1 (CharacterBody2D)
  ├── AnimatedSprite2D
  ├── CollisionShape2D       ← matches player size
  ├── InteractionArea (Area2D)
  │     └── CollisionShape2D (CircleShape2D, interaction_radius)
  ├── InteractionLabel (Label) ← "Press E"
  └── NpcDog (CharacterBody2D)
        ├── AnimatedSprite2D
        └── CollisionShape2D
```

---

## Dialogue Files

Location: `res://dialogue/npcs/`

### dude1.dialogue
```
~ start
Dude1: Hey there! My Cane Corso looks tough but he's a big softie.
Dude1: He loves belly rubs more than anything.
Dude1: Don't let the size fool you — he's scared of butterflies.
```

### dude2.dialogue
```
~ start
Dude2: Golden Retrievers are the best dogs, no debate.
Dude2: My girl fetches everything — keys, socks, my TV remote...
Dude2: She once brought me a whole loaf of bread from the counter.
```

### dude3.dialogue
```
~ start
Dude3: 101 Dalmatians? More like 1 is more than enough.
Dude3: He has so much energy I can barely keep up.
Dude3: Spotted dogs, spotted personality — never know what he'll do next.
```

### dude4.dialogue
```
~ start
Dude4: People always cross the street when they see my Rottie.
Dude4: He just wants to say hi, I promise.
Dude4: Best guard dog I've ever had. Also best couch buddy.
```

### girl1.dialogue
```
~ start
Girl1: My Husky thinks she's a wolf. A very dramatic wolf.
Girl1: She howls at everything. The moon, the mailman, cartoons.
Girl1: I haven't slept a full night since I got her. Worth it.
```

### girl2.dialogue
```
~ start
Girl2: Pharaoh Hounds are ancient — like, actual Egyptian royalty.
Girl2: Mine acts like royalty too. Very picky about his food.
Girl2: He blushes when he's excited. His nose literally turns pink!
```

---

## World Placement (`world.tscn`)

All 6 NPC instances added to `world.tscn` with unique spawn positions spread across the map. Exact pixel coordinates to be set during implementation after visual placement testing.

---

## What This Does NOT Include

- NPC needs (hunger, thirst, energy) — purely cosmetic
- NPC dog menus or interaction — dog is visual only
- NPC pathfinding beyond random wander — no NavMesh
- Persistent dialogue state — dialogue resets each approach

<!-- Updated on 2026-04-19 -->
