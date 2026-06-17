# Dog Daycare System — Design Spec
**Date:** 2026-06-17
**Project:** My Little Buddy (Godot 4)

---

## Goal

Add a dog daycare system so players with jobs (teens and adults) can send their dog to daycare before going to work. Bringing the dog to work without using daycare triggers a punishment. Daycare pricing is configurable in the Cost Customization menu.

---

## Files Touched

| File | Change |
|---|---|
| `scripts/GameState.gd` | 4 new vars, `apply_dog_at_work_penalty()`, day reset |
| `scripts/bottom_hud.gd` | Spawn daycare HUD button (teen/adult only), visibility logic |
| `scripts/daycare_menu.gd` | **New** — popup with cheap/premium tiers, confirm/cancel |
| `scripts/manager_npc.gd` | Dog-at-work check before shift launch |
| `scripts/CostCustomization.gd` | Two daycare price sliders (teen/adult only) |

---

## Section 1: GameState Data Model

```gdscript
var dog_at_daycare: bool = false
var daycare_used_today: bool = false
var daycare_cheap_price: float = 15.0
var daycare_premium_price: float = 30.0

enum DaycareTier { NONE, CHEAP, PREMIUM }
var daycare_tier_today: DaycareTier = DaycareTier.NONE
```

**Day reset** — in `advance_day()`, reset `dog_at_daycare`, `daycare_used_today`, and `daycare_tier_today` to defaults.

**Dog stat effects** applied at `advance_day()` before health tick:
- Both tiers: hunger, thirst, energy top off to max
- `CHEAP`: `dog.health += randf_range(-8.0, 3.0)` — slight health risk
- `PREMIUM`: health untouched, dog mood +10 (skip if no mood stat)

**`apply_dog_at_work_penalty() -> String`:**
1. Deduct `$25.0` fine from `GameState.money`
2. Reduce `promotion_standing` for the active job (same magnitude as a bad shift event)
3. Return `"$25 fine. Your standing took a hit."` for dialogue display

---

## Section 2: HUD Button

Added in `bottom_hud.gd` → `_apply_redesign_styling()`:
- Only spawned when `GameState.player_age_group in ["teen", "adult"]`
- Placed in `LeftSection` (converted to `HBoxContainer`), 20px spacer between money label and daycare button
- Size: `Vector2(130, 60)`, font size 22, styled with `UITheme.style_pixel_button()`
- Text: `"🐾 Daycare"`

**Visibility** (checked in `update_ui()` every frame):
```gdscript
if daycare_btn:
    daycare_btn.visible = not GameState.daycare_used_today and not GameState.has_worked_today
```
Button disappears once dog is sent to daycare OR player works their first shift.

---

## Section 3: Daycare Popup (`daycare_menu.gd`)

Built in code as a `CanvasLayer` on layer 60 — no `.tscn` needed. Style matches `work_action_menu.gd` (cream panel, ink border, maroon title, pixel font).

**Layout:**
```
┌─────────────────────────────┐
│       DOG DAYCARE           │
│  Send your pup while you    │
│  work. Pick a plan:         │
├─────────────────────────────┤
│  [Cheap Daycare  — $15.00]  │
│  Basic care. Health at risk.│
│                             │
│  [Premium Daycare — $30.00] │
│  Safe + mood boost.         │
├─────────────────────────────┤
│        [Cancel]             │
└─────────────────────────────┘
```

- Prices shown dynamically from `GameState.daycare_cheap_price` / `GameState.daycare_premium_price`
- If player can't afford a tier, that button is disabled with red tint
- On confirm: deduct price, set `dog_at_daycare = true`, `daycare_used_today = true`, set tier, close popup

---

## Section 4: Punishment Flow (`manager_npc.gd`)

New check in `_interact()` before the minigame launcher, after the briefing/block checks:

```gdscript
if not GameState.dog_at_daycare and get_tree().get_nodes_in_group("dog").size() > 0:
    _show_dialogue([
        "Hey — is that your dog?",
        "Don't bring your dog to work. You're getting a fine.",
        GameState.apply_dog_at_work_penalty()
    ])
    return
```

- Uses `get_nodes_in_group("dog")` to detect live dog in scene
- Penalty cascades into fire risk naturally via existing promotion standing system
- Shift does NOT proceed after the warning — player is turned away

---

## Section 5: Cost Customization (`CostCustomization.gd`)

Two sliders added, visible only for `player_age_group in ["teen", "adult"]`:

- **Cheap Daycare Price**: range `$5 – $50`, default `$15`, writes to `GameState.daycare_cheap_price`
- **Premium Daycare Price**: range `$10 – $80`, default `$30`, writes to `GameState.daycare_premium_price`
- Premium slider minimum is always `cheap_price + 5` — enforced live to prevent inversion
- Children never see this section

---

## Edge Cases

- Player is a child: daycare button never spawns, no penalty check in manager NPC
- Player has no job: daycare button hidden (same `has_worked_today` / age check)
- Dog sent to daycare but player doesn't work: `dog_at_daycare` resets at `advance_day()` — no leftover state
- Player can't afford either tier: both buttons disabled, must cancel and earn more money first
- Dog group empty (dog despawned): penalty check safely skips via `size() > 0`
