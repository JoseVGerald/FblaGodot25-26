# My Little Buddy — System Architecture

High-level architecture for the four core subsystems, the finance data flow, and a
master integration diagram. Node labels reference the real scripts, scenes, signals,
and `GameState` fields in the codebase. The `GameState` autoload singleton
(`scripts/GameState.gd`) is the authoritative shared-state store; every subsystem
reads from and mutates it, and decoupled `signal` emissions act as the event bus.

---

## 1. Player Logic

The player is a `CharacterBody2D` sampled every physics tick. Input is read through
the `Input` singleton, normalized into a direction vector, scaled by a context speed,
and resolved against the collision world via `move_and_slide()`. Movement is gated by
the world's traversal flag and slowed indoors; the active pathway selects the
`AnimatedSprite2D` clip set.

```mermaid
graph TD
    InputSingleton["Input singleton<br/>get_axis(move_*)"] --> PP["player.gd · _physics_process(delta)"]
    PP --> Dir["input_dir = Vector2(...).normalized()"]
    PP --> Gate{"player_moveable()<br/>polls world.player_can_move"}
    Gate -- "blocked" --> Zero["velocity = Vector2.ZERO"]
    Zero --> Idle["_play_idle_anim()"]
    Gate -- "free" --> Speed["effective_speed = speed * 0.5<br/>if GameState.is_in_house"]
    Dir --> Speed
    Speed --> Vel["velocity = input_dir * effective_speed"]
    Vel --> Slide["move_and_slide()<br/>collision_layer/mask = 1"]
    Slide --> Last["cache last_dir"]
    Last --> MoveAnim["_play_move_anim()<br/>sprite_2d.speed_scale = 2.0"]
    GS["GameState.selected_pathway<br/>(kid/teen/adult)"] --> MoveAnim
    GS --> Idle
    Slide --> Cam["Camera2D · zoom = (5,5)"]
    Slide --> IA["interaction_area.gd (Area2D)<br/>building / NPC proximity"]
    IA --> SMgr["→ SceneManager (World §4)"]
    MoveAnim --> Sprite["AnimatedSprite2D playback"]
    Idle --> Sprite
```

---

## 2. Pet Logic & Pet Needs

`dog.gd` is an enum-driven finite state machine. It either path-follows the player
group or traverses a precomputed `action_path` toward fixed food/water/sleep targets,
firing an `action_callback` on arrival. Three need scalars decay by delta-time each
frame, replenish on actions, sync into `GameState.dog_health`, and drive both the
emotion bubble and the `needs_menu` overlay. House entry triggers a scripted evening
routine; nightly advance applies a random health roll.

```mermaid
graph TD
    subgraph FSM["DogState finite state machine (current_state)"]
        Follow["FOLLOWING_PLAYER"] --> GoFood["GOING_TO_FOOD"]
        Follow --> GoWater["GOING_TO_WATER"]
        Follow --> GoSleep["GOING_TO_SLEEP"]
        GoSleep --> Sleeping["SLEEPING"]
    end
    Keys["Keys 1/2/3 input"] --> FSM
    PlayerGrp["player_group follow target"] --> Follow
    GoFood & GoWater & GoSleep --> Action["action_path traversal<br/>action_speed → action_callback"]
    Action --> Replenish["replenish hunger/thirst/energy<br/>(+50 clamp 100)"]
    Decay["delta decay<br/>hunger/thirst/energy_decay (100/240)"] --> NeedVals["need scalars"]
    Replenish --> NeedVals
    Freeze["GameState.is_dog_sleeping<br/>freezes decay"] -.-> Decay
    NeedVals --> Emotion["emotion_label bubble<br/>(prev_emotion diff)"]
    NeedVals --> Sync["GameState.dog_health sync"]
    House["player enters house<br/>was_in_house"] --> Routine["is_in_evening_routine<br/>snap HOUSE_ENTRY_POS"]
    Routine --> FSM
    Night["advance_day → apply_random_night_health_roll"] --> Sync
    Sync --> NM["needs_menu.tscn (CanvasLayer)<br/>needs_menu.gd"]
    NeedVals --> NM
```

---

## 3. UI & Overlay

`bottom_hud.gd` is a persistent `CanvasLayer` that processes while paused. Its
`@onready` buttons lazily instantiate preloaded menu `PackedScene`s as stacked
`CanvasLayer` overlays, and emit decoupled signals (`supplies_menu_opened`,
`finance_menu_opened`) consumed by the tutorial controllers. All menus pull styling
from `UITheme.gd` helpers (`StyleBoxFlat`, `get_pixel_font`). The `NotificationCenter`
autoload broadcasts toasts; `achievements_popup` raises unlock events.

```mermaid
graph TD
    GS["GameState (money / time / day)"] --> HUD["bottom_hud.gd · CanvasLayer<br/>process_mode = ALWAYS"]
    HUD --> Labels["MoneyLabel / TimeLabel refresh"]
    HUD --> Btns{"@onready HUD buttons"}
    Btns --> Sup["supplies_menu.tscn"]
    Btns --> Needs["needs_menu.tscn"]
    Btns --> Fin["FinanceMenu.tscn"]
    Btns --> Shop["ShopMenu.tscn"]
    Btns --> Pause["PauseMenu.tscn → SettingsMenu"]
    Sup --> Sig["signals: supplies_menu_opened<br/>finance_menu_opened"]
    Fin --> Sig
    Sig --> Tut["day1/2_tutorial · tutorial_hint.gd"]
    Theme["UITheme.gd<br/>StyleBoxFlat · get_pixel_font"] --> Sup & Needs & Fin & Shop & Pause
    NC["NotificationCenter (autoload)"] --> Toast["notification_panel.gd toasts"]
    Ach["achievements_popup.gd<br/>_unlock events"] --> NC
    GS --> NC
    Tut --> HUD
```

---

## 4. World & Tile Map

`MainGame.gd` is the world bootstrap: it spawns the player, dog, HUD, and NPC actors
onto the `Map.tscn` `TileMapLayer`, branching spawn points by pathway. Buildings are
`y-sort` scenes whose `interaction_area` (`Area2D`) zones detect `body_entered`,
toggle the `GameState.is_in_house` flag, and request a `SceneManager` cross-fade into
interior maps (Vet, Bank, Job, House). Tutorial path guides overlay the tilemap on
Day 1.

```mermaid
graph TD
    Boot["MainGame.gd · _ready()"] --> Spawn["spawn_player / spawn_dog<br/>setup_hud"]
    Boot --> NPCSpawn["spawn_mother_npc<br/>spawn_manager_npcs"]
    Spawn --> Map["Map.tscn · TileMapLayer"]
    NPCSpawn --> NPCs["manager_npc / mother<br/>shop_npc / vet_npc"]
    Map --> YSort["y-sort building_*.tscn<br/>(depth-sorted sprites)"]
    YSort --> IA["interaction_area.gd (Area2D)<br/>body_entered"]
    NPCs --> IA
    IA --> Flag["GameState.is_in_house = true"]
    IA --> SMgr["SceneManager.fade_in_place<br/>(autoload, change scene)"]
    SMgr --> Interiors["Vet / Bank / Job / House maps"]
    Flag --> Player["→ player.gd half-speed (§1)"]
    Flag --> Dog["→ dog.gd evening routine (§2)"]
    PathBranch{"GameState.selected_pathway"} --> Spawn
    Paths["ShopPath / VetPath guides"] --> Map
    Day1["is_day_one && !tutorial_complete"] --> Paths
```

---

## 5. Finance Flow

Income sources mutate `GameState.money`; spending sinks draw it down. The setter logs
each event into `transaction_history` with a category, which aggregates into the
`weekly_report.category_breakdown`. `advance_day` ticks `current_day`; every 7th day
finalizes the report. Savings accrue daily interest and loans accrue weekly interest.
`finance_menu.gd` renders the aggregated state across its six views, and balance events
fan out through signals.

```mermaid
graph LR
    subgraph Income
        Allow["weekly_allowance"]
        Pay["job pay + tips<br/>JOB_PROGRESSION ladder"]
        Chores["chore_menu.gd"]
        Catch["catch_game.gd payout"]
    end
    subgraph Spending
        Rent["monthly_rent · rent_timer"]
        Supplies["supplies_menu.gd"]
        ShopBuy["ShopMenu / daycare_menu"]
        Costs["CostCustomization / taxi / vet meds"]
    end
    Income --> Money["GameState.money (mutation point)"]
    Money --> Spending
    Money <--> Bank["savings_balance (daily interest)<br/>loan_balance (weekly interest)"]
    Income --> Log["transaction_history<br/>{day, desc, amount, category}"]
    Spending --> Log
    Log --> Breakdown["weekly_report.category_breakdown"]
    Tick["advance_day · current_day % 7 == 0"] --> Report["weekly_report finalize"]
    Breakdown --> Report
    Money --> Report
    Bank --> Report
    Report --> FM["finance_menu.gd views<br/>Overview · Spending · BudgetPlanner<br/>WeeklyReport · Loans · History"]
    Money --> FM
    Spending --> Sig["signals: event_triggered<br/>emergency_fund_used"]
    Sig --> NC["→ NotificationCenter (§3)"]
```

---

## 6. Master Integration — Everything Connected

`GameState` is the central hub and `NotificationCenter` the event bus. Player traversal
drives world interaction; the world toggles flags the player and pet react to; gameplay
actions mutate the finance ledger; and the UI overlay projects every subsystem's state
back to the screen. No subsystem is isolated — all converge on shared state.

```mermaid
graph TD
    GS["⭐ GameState (autoload singleton)<br/>money · needs · day · flags · ledger"]
    NC["NotificationCenter (event bus)"]
    Player["§1 Player Logic<br/>player.gd"]
    World["§4 World & Tilemap<br/>MainGame + SceneManager"]
    Pet["§2 Pet Logic & Needs<br/>dog.gd FSM"]
    Finance["§5 Finance System<br/>money · weekly_report · ledger"]
    UI["§3 UI & Overlay<br/>bottom_hud + menus"]

    Player -->|enters interaction_area| World
    World -->|is_in_house flag| Player
    World -->|is_in_house · routine| Pet
    Pet -->|dog_health sync| GS
    Player -->|jobs / chores / catch payout| Finance
    World -->|enter shop / bank / vet| Finance
    GS <-->|read & write| Player
    GS <-->|read & write| Pet
    GS <-->|read & write| Finance
    GS <-->|read & write| World
    GS -->|projected state| UI
    UI -->|button actions spend| Finance
    UI -->|open needs panel| Pet
    UI -->|pause / settings| World
    Finance -->|event_triggered| NC
    Pet -->|low-need alerts| NC
    World -->|scene events| NC
    NC -->|toasts / popups| UI
```

---

### Subsystem reference

| Subsystem | Entry point | Authoritative shared state |
| --- | --- | --- |
| Player | `scripts/player.gd` | `is_in_house`, `selected_pathway` |
| Pet | `scripts/dog.gd` | `dog_health`, `is_dog_sleeping` |
| UI | `scripts/bottom_hud.gd` | reads the full `GameState` surface |
| World | `scripts/MainGame.gd` + `SceneManager` | `is_in_house`, spawn / day flags |
| Finance | `scripts/GameState.gd` + `scripts/finance_menu.gd` | `money`, `weekly_report`, `transaction_history` |
| Event bus | `scripts/NotificationCenter.gd` | `event_triggered`, `emergency_fund_used` |
