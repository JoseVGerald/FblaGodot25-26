# Day-2 Job Tutorial — Design

**Date:** 2026-06-13 (revised 2026-06-16)
**Status:** Approved design, ready for implementation plan

## Summary

A second "day-one"-style onboarding script that runs **after** the player has
taken a job (teen or adult pathway), gone home, and slept at least once. On the
first morning of any new job the player has not yet been briefed on, it:

1. **Auto-plays an opening dialogue** the moment the day starts — the **Mother**
   greets the teen (she is already standing in the house), or the **adult** has a
   brief inner monologue — telling them it's time to head to their job, named by
   its building (e.g. "Burger Barn").
2. **Reveals a visual path** to the correct building and shows a "follow the path
   to your job" hint.
3. The moment they enter the building, **pops up a prompt** telling them to talk
   to their manager. The existing manager NPC then handles the actual job
   briefing.

This re-runs on the first morning of **every** new job — including a re-hire to a
job the player previously held — because taking a job clears the briefed flag
(see Trigger gate). It stops permanently once that job's manager has briefed them.

This is the day-2 counterpart to the existing Day-1 tutorial
(`scripts/day1_tutorial.gd`), which taught the vet, the shop, and finances.

## Goals

- Guide a newly-employed player to their workplace the first time they wake up
  with a job they have not yet been briefed on.
- Reuse the existing path-reveal style, building enter/exit doors, and manager
  NPC briefing flow. No new gameplay systems.
- Touch **no** existing gameplay logic: signals, method names, GameState economy
  calls, `manager_npc.gd`, and `interaction_area.gd` behavior all stay identical.
  The only `GameState.gd` changes are two **additive, read-only** computed
  properties (`active_job_location_name`, `player_display_name`); they alter no
  existing behavior.

## Non-goals

- No movement blocking once the path is shown — the player must be free to walk
  to the building. (The opening balloon holds them in place only while it is
  open, then releases, which is the existing balloon behavior.)
- No changes to job pay, promotion, firing, or shift logic.
- No tutorial for the kid pathway (kids have no job, so the gate excludes them
  automatically).

## Existing system (verified)

- **Sleeping** (`interaction_area.gd → trigger_sleep`) calls
  `SceneManager.fade_in_place` (which sets `skip_scene_change = true`, so the
  scene is **not** reloaded) then `GameState.advance_day()`, which increments
  `current_day`, sets `is_day_one = false`, and emits `day_started(current_day)`.
  → MainGame stays loaded; we can react on the `day_started` signal.
- **MainGame** (`scripts/MainGame.gd`) already connects
  `GameState.day_started.connect(_on_day_started)` in `_ready()`.
- **Buildings + doors** already exist in `scenes/ui/MainGame.tscn`. Each job
  building has working enter/exit `interaction_area` doors that already show
  "Press E to enter the …".
- **Manager NPCs** (`scripts/manager_npc.gd`) are spawned at each building and
  already give a first-day briefing via the dialogue balloon, gated on
  `GameState.has_manager_briefed(job)` (a persisted flag in
  `manager_briefed_jobs`, saved/loaded and reset in `reset_all`).
- **Path reveal** in Day-1 (`MainGame._make_paths_visible`) draws a
  semi-transparent yellow `Line2D` (width `4.0`, `default_color = Color(1, 1, 0, 0.5)`)
  whose `points` are the `Path2D` curve's baked points
  (`path.curve.get_baked_points()`). The day-2 controller replicates this for a
  single path.
- **`interaction_area.post_teleport_hint`** is an existing exported field: when a
  door teleports the player, it shows this hint for ~4s afterward (already used
  for the house→shop flow). We set it at runtime to deliver the "talk to your
  manager" popup — no change to `interaction_area.gd` required.

## Job → scene-node mapping (exact, casing matters)

Node names in `MainGame.tscn` are inconsistently cased, so the controller MUST
use an explicit lookup table rather than deriving names from the location key.

| `active_job`      | location key | Path2D node (parent `.`) | Enter door (parent `Interaction areas`) | Location name (`active_job_location_name`) |
|-------------------|--------------|--------------------------|-----------------------------------------|--------------------------------------------|
| `burger_cashier`  | `burger`     | `Burger path`            | `Burger enter`                          | `Burger Barn`                              |
| `bank_accountant` | `bank`       | `bank path`              | `bank enter`                            | `First City Bank`                          |
| `news_boy`        | `post`       | `post path`              | `post enter`                            | `Post Office`                              |

- `location key` is the reverse of `GameState.JOB_FOR_LOCATION`.
- Location name comes from the new `GameState.active_job_location_name` property,
  which returns `JOB_PROGRESSION[active_job]["location"]`. (Distinct from
  `active_job_display_name`, which returns the job *title* like "Burger Cashier".)
- Path nodes are direct children of the MainGame root (`$"Burger path"`).
- Enter doors live under `$"Interaction areas/Burger enter"` etc.

## Opening dialogue (day-2 delta)

Two new sections are added to `dialogues/tutorial.dialogue`, played via the same
`balloon.tscn` flow `day1_tutorial.gd` already uses. The controller chooses the
section by `GameState.selected_pathway`:

- **`adult`** → `day2_adult` — inner monologue, speaker label `You`:
  > You: Alright… time to head to my job at {{GameState.active_job_location_name}}.
- **anything else** (teen; also kid-with-a-job, which the gate makes impossible)
  → `day2_teen` — speaker `Mother` (she is already spawned in the house at
  `(565,-640)`):
  > Mother: Good morning, {{name}}! It's time to head to your job at {{GameState.active_job_location_name}}.

Interpolation details:

- **`{{name}}`** resolves to the player's name with a **warm fallback**
  (`"sweetie"`) when `player_name` is empty, so the line never reads
  "Good morning, !". In normal play `CharacterCustomize` sets the real name before
  `MainGame` loads; `""` only occurs for name-less/old saves, and the literal
  `"Player"` only via the secret backslash skip. **Primary approach:** the teen
  dialogue references a new read-only helper `GameState.player_display_name`
  (returns `player_name` if non-empty, else `"sweetie"`) — consistent with how we
  add `active_job_location_name`, and avoids relying on inline-ternary support in
  the DialogueManager `{{ }}` parser. (If during implementation an inline
  expression proves clean, that is an acceptable equivalent.)
- **`{{GameState.active_job_location_name}}`** is a **new read-only computed
  property** on `GameState.gd`, mirroring the existing `active_job_display_name`
  but returning `JOB_PROGRESSION[active_job]["location"]` ("Burger Barn",
  "First City Bank", "Post Office"; `_` → `"work"`).
- The adult speaker is a static `You` label because `.dialogue` speaker names are
  static text — no per-name interpolation needed there.

**Timing / race:** `day_started` fires mid-sleep behind
`SceneManager.fade_in_place`. The controller MUST `await` the fade/settle (a short
timer, as `day1_tutorial` does) before adding the balloon, so it doesn't appear
during the fade. The balloon blocks movement while open and releases on close.

## Architecture — Approach A: dedicated controller

New file `scripts/day2_job_tutorial.gd` (extends `Node`), mirroring
`day1_tutorial.gd`'s shape. `MainGame.gd` owns the trigger and instantiates it.

### Trigger gate (in `MainGame.gd`)

A single helper, e.g. `maybe_start_day2_job_tutorial()`, is called from BOTH:
1. `_on_day_started(day)` — the morning after sleeping (scene stays loaded), and
2. `_ready()` — after spawns, to cover a save loaded directly on day 2+.

It starts the tutorial only when **all** are true:
- `not GameState.is_day_one`
- `GameState.active_job != "none"`  (excludes kid pathway)
- `not GameState.has_manager_briefed(GameState.active_job)`
- no day-2 controller instance already active (guard against double-spawn / the
  `_ready` + `day_started` both firing).

Because the gate keys on `has_manager_briefed`, the guide naturally:
- re-appears each morning until the player actually goes and meets the manager,
- stops permanently once briefed,
- re-runs on the first morning of **every** new job the player takes — including
  a re-hire to a job they previously held and were briefed on. This works with
  **no extra code** because `GameState.start_job()` (called from
  `job_selection_menu.gd:236` whenever a job is taken) already does
  `manager_briefed_jobs.erase(job)`, so any freshly-taken job is un-briefed again.

No new GameState save field is required, and no firing/job-loss hook is needed.

### Controller responsibilities (`day2_job_tutorial.gd`)

`start(active_job: String, main_game: Node2D)` does:

1. Resolve path node, enter door, and location name from the mapping table.
2. **Await the fade/settle** (short timer, as day1 does) so the balloon does not
   appear during `fade_in_place`. Guard `tutorial_blocks_movement` is left to the
   balloon's own open/close behavior — no manual movement lock.
3. **Play the opening dialogue:** load `dialogues/tutorial.dialogue` and start the
   balloon on `day2_adult` (if `selected_pathway == "adult"`) or `day2_teen`
   (otherwise). `await balloon.tree_exited` before continuing — mirrors
   `day1_tutorial.run_dialogue`. (The `{{name}}` empty fallback and
   `active_job_location_name` interpolation are described in *Opening dialogue*.)
4. **Reveal the path:** add a yellow `Line2D` child to the job's `Path2D` (same
   width/color as `_make_paths_visible`). Keep a reference so it can be removed.
   The path line stays visible until the tutorial ends.
5. **Show the hint** via a `tutorial_hint` instance:
   `"Follow the path to your job at <location name>."` with a ~6s auto-hide
   duration (text fades; path line remains). Confirmed timing choice.
6. **Arm the entry popup:** set the enter door's
   `post_teleport_hint = "Talk to your manager to see how to work the job and what it's about."`
   Remember the door's previous value (normally `""`) to restore on cleanup.
7. **Watch for completion:** poll (per-frame `await`, like day1) until
   `GameState.has_manager_briefed(active_job)` becomes true.
8. **Cleanup:** remove the `Line2D`, restore the enter door's
   `post_teleport_hint`, free the `tutorial_hint`, and `queue_free()` self.

The existing "Press E to enter…" door prompt (between steps 6 and 7) needs no
work — it already fires on approach. The manager NPC's own "Press E to meet …"
prompt and briefing dialogue are likewise untouched.

### Why not the alternatives

- **B (inline in MainGame.gd):** MainGame is already large and mixes spawn/HUD/
  save concerns; isolation is cleaner and testable.
- **C (extend day1_tutorial.gd):** day-1 is hard-wired to `_ready`/`is_day_one`;
  merging two different lifecycles adds branchy complexity for no gain.

## Edge cases

- **Both triggers fire same morning:** `_ready` (on a fresh boot the player is
  already day-2) and `day_started` (if they then sleep) are both guarded by the
  "no controller already active" + `has_manager_briefed` checks, so only one runs
  and the opening dialogue plays exactly once.
- **Player ignores the job and sleeps again:** still un-briefed → guide re-shows
  (dialogue included) next morning (acceptable / helpful).
- **Player switches jobs after being fired (incl. re-hire to the same job):** the
  newly-taken job is un-briefed (`start_job` cleared the flag) → guide + dialogue
  run for that job's building on the next qualifying morning.
- **Kid pathway / no job:** `active_job == "none"` → never triggers.
- **Manager hint vs entry popup overlap:** the `post_teleport_hint` shows at the
  teleport landing spot and auto-hides in ~4s; the manager's prompt only appears
  once the player walks into the manager's interaction area. Different spots/times.

## Files touched

- **New:** `scripts/day2_job_tutorial.gd` (+ its `.uid` generated by Godot).
- **Edit:** `scripts/MainGame.gd` — add `maybe_start_day2_job_tutorial()` and
  call it from `_ready()` and `_on_day_started()`; add a member to hold the
  controller instance. No other behavior changes.
- **Edit:** `scripts/GameState.gd` — add two **read-only computed properties**:
  `active_job_location_name` (mirrors `active_job_display_name`, returns
  `JOB_PROGRESSION[active_job]["location"]`) and `player_display_name`
  (`player_name` if non-empty, else `"sweetie"`). No existing behavior changes;
  no new save field.
- **Edit:** `dialogues/tutorial.dialogue` — add `day2_teen` (speaker `Mother`)
  and `day2_adult` (speaker `You`) sections, each interpolating
  `active_job_location_name` and (teen only) the player name with empty fallback.
- **No edits** to `manager_npc.gd`, `interaction_area.gd`, or `MainGame.tscn`
  (the three `Path2D` nodes and enter doors already exist).

## Testing

- New game → teenager → pick a job in the Day-1 tutorial → finish Day-1 →
  sleep → confirm on waking: Mother's "Good morning, <name>! …Burger Barn"
  dialogue auto-plays, then correct path line appears, correct hint text, walk
  to building, "Press E to enter" works, enter → "talk to your manager" popup,
  talk to manager → briefing plays → path line + popup gone and do not return.
- Repeat for adult pathway and confirm the `day2_adult` inner-monologue plays
  with the `You` speaker label and correct location name.
- Cover each of the three jobs (burger/bank/post) — confirm the right path,
  enter door, and location name.
- **Re-hire replay:** get briefed at a job, get fired, take the **same** job
  again → next qualifying morning the tutorial replays (because `start_job`
  cleared the briefed flag).
- **Empty name:** with `player_name == ""`, confirm the teen line falls back to
  the warm default rather than rendering "Good morning, !".
- Kid pathway → sleep → confirm no job guide and no dialogue appears.
- Load a save created on day 2+ with an un-briefed job → guide appears on
  `_ready`.
- `tools/JobSystemTest.tscn` may be extended as a fast harness if useful.
