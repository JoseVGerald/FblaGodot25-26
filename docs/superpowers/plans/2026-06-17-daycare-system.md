# Dog Daycare System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dog daycare system so teens/adults can send their dog to daycare before a work shift; bringing the dog to work without daycare triggers a fine + career penalty.

**Architecture:** GameState holds all daycare state (flags, prices, tier). A new `daycare_menu.gd` popup is opened from a HUD button spawned in `bottom_hud.gd`. The penalty fires in `manager_npc.gd` before any shift is launched. Price configuration lives in `CostCustomization.gd`.

**Tech Stack:** Godot 4, GDScript, DialogueManager (for manager punishment dialogue), MCP Godot server for in-editor testing.

## Global Constraints

- `selected_pathway` values are exactly `"kid"`, `"teenager"`, `"adult"` — never `"teen"`
- Dog daycare button and pricing visible only when `selected_pathway in ["teenager", "adult"]`
- All popup UI must match `work_action_menu.gd` style: `UITheme.CLR_CREAM` bg, `UITheme.CLR_INK` border 5px, maroon title, pixel font via `UITheme.get_pixel_font()`
- Use `UITheme.style_pixel_button()` for all buttons — no inline StyleBoxFlat on buttons
- Never break existing signals, method names, or GameState calls
- Test each task using the MCP Godot server (`mcp__godot__run_project` / `mcp__godot__get_debug_output`)

---

### Task 1: GameState — Daycare State, Penalty Method, Day Reset

**Files:**
- Modify: `scripts/GameState.gd`

**Interfaces:**
- Produces:
  - `GameState.dog_at_daycare: bool` — true after drop-off
  - `GameState.daycare_used_today: bool` — gate: can only send once per morning
  - `GameState.daycare_cheap_price: float` — default 15.0
  - `GameState.daycare_premium_price: float` — default 30.0
  - `GameState.DaycareTier` enum with values `NONE`, `CHEAP`, `PREMIUM`
  - `GameState.daycare_tier_today: DaycareTier` — which tier was used today
  - `GameState.worked_today: bool` — true after any shift is initiated today
  - `GameState.apply_dog_at_work_penalty() -> String`

- [ ] **Step 1: Add daycare vars after the existing `catch_played_today` var (line ~269)**

  Open `scripts/GameState.gd`. Find:
  ```gdscript
  var catch_played_today: bool = false
  ```
  Add directly after it:
  ```gdscript
  enum DaycareTier { NONE, CHEAP, PREMIUM }
  var dog_at_daycare: bool = false
  var daycare_used_today: bool = false
  var daycare_tier_today: DaycareTier = DaycareTier.NONE
  var daycare_cheap_price: float = 15.0
  var daycare_premium_price: float = 30.0
  var worked_today: bool = false
  ```

- [ ] **Step 2: Add `apply_dog_at_work_penalty()` method**

  Find the `shift_block_reason()` function (line ~915). Add this new method directly before it:
  ```gdscript
  ## Called when player arrives at work with dog (no daycare). Docks $25 and
  ## reduces promotion standing — lower standing already raises fire risk.
  func apply_dog_at_work_penalty() -> String:
      money -= 25.0
      if active_job != "none" and active_job in job_promo_chance:
          job_promo_chance[active_job] = maxf(0.0, job_promo_chance[active_job] - 0.15)
      return "$25 fine. Your standing took a hit."
  ```

- [ ] **Step 3: Reset daycare flags and worked_today in `_advance_day_after_supply_decrement()`**

  Find the line:
  ```gdscript
  catch_played_today = false
  ```
  Add directly after it:
  ```gdscript
  dog_at_daycare = false
  daycare_used_today = false
  daycare_tier_today = DaycareTier.NONE
  worked_today = false
  ```

- [ ] **Step 4: Apply daycare dog stat effects in `_advance_day_after_supply_decrement()`**

  Find the line `catch_played_today = false` again (now has daycare resets after it). Add the dog stat effects **before** the daycare flag resets (so they read the tier before it clears):
  ```gdscript
  # Apply daycare stat effects before resetting flags
  if daycare_tier_today != DaycareTier.NONE:
      dog_health = min(100.0, dog_hunger + 0.0)  # hunger topped off via dog instance at day end
      if daycare_tier_today == DaycareTier.CHEAP:
          dog_health = clampf(dog_health + randf_range(-8.0, 3.0), 0.0, 100.0)
      # PREMIUM: health untouched, no mood stat exists yet so skip mood buff
  ```

  Wait — `dog_hunger` is not in GameState. GameState tracks `dog_health` directly. Replace the above with:
  ```gdscript
  if daycare_tier_today != DaycareTier.NONE:
      if daycare_tier_today == DaycareTier.CHEAP:
          dog_health = clampf(dog_health + randf_range(-8.0, 3.0), 0.0, 100.0)
      # PREMIUM: health untouched (dog is safe at premium daycare)
  ```

- [ ] **Step 5: Reset daycare vars in `reset_all()`**

  Find `catch_played_today = false; catch_last_played_day = -1` (line ~1149). Add after it:
  ```gdscript
  dog_at_daycare = false
  daycare_used_today = false
  daycare_tier_today = DaycareTier.NONE
  worked_today = false
  ```

- [ ] **Step 6: Test via MCP**

  ```
  mcp__godot__run_project  (launch the game)
  mcp__godot__get_debug_output  (verify no parse errors)
  ```
  Expected: game launches, no GDScript errors in output. `GameState.dog_at_daycare` accessible.

- [ ] **Step 7: Commit**
  ```bash
  git add scripts/GameState.gd
  git commit -m "feat(daycare): add daycare state vars, penalty method, and day reset to GameState"
  ```

---

### Task 2: `daycare_menu.gd` — Daycare Popup

**Files:**
- Create: `scripts/daycare_menu.gd`

**Interfaces:**
- Consumes:
  - `GameState.daycare_cheap_price: float`
  - `GameState.daycare_premium_price: float`
  - `GameState.money: float`
  - `GameState.dog_at_daycare: bool`
  - `GameState.daycare_used_today: bool`
  - `GameState.daycare_tier_today: GameState.DaycareTier`
  - `UITheme.CLR_CREAM`, `UITheme.CLR_INK`, `UITheme.CLR_MAROON_D`, `UITheme.CLR_GRAY_DRK`
  - `UITheme.get_pixel_font() -> Font`
  - `UITheme.style_pixel_button(btn, secondary=false)`
- Produces: `DaycareMenu` node (CanvasLayer) — call `open()` to show it

- [ ] **Step 1: Create `scripts/daycare_menu.gd`**

  ```gdscript
  extends CanvasLayer
  ## Popup that lets teens/adults choose cheap or premium daycare before a shift.

  var _cheap_btn: Button
  var _premium_btn: Button
  var _pf: Font


  func _ready() -> void:
      layer = 60
      _pf = UITheme.get_pixel_font()
      visible = false
      _build_ui()


  func open() -> void:
      _refresh()
      visible = true


  func _build_ui() -> void:
      var overlay := ColorRect.new()
      overlay.color = Color(0, 0, 0, 0.7)
      overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
      overlay.mouse_filter = Control.MOUSE_FILTER_STOP
      add_child(overlay)

      var center := CenterContainer.new()
      center.set_anchors_preset(Control.PRESET_FULL_RECT)
      add_child(center)

      var panel := PanelContainer.new()
      panel.custom_minimum_size = Vector2(520, 0)
      var sb := StyleBoxFlat.new()
      sb.bg_color = UITheme.CLR_CREAM
      sb.border_color = UITheme.CLR_INK
      sb.set_border_width_all(5)
      sb.set_corner_radius_all(0)
      sb.set_content_margin_all(28)
      panel.add_theme_stylebox_override("panel", sb)
      center.add_child(panel)

      var col := VBoxContainer.new()
      col.add_theme_constant_override("separation", 14)
      panel.add_child(col)

      var title := Label.new()
      title.text = "DOG DAYCARE"
      title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
      title.add_theme_font_size_override("font_size", 38)
      title.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
      if _pf: title.add_theme_font_override("font", _pf)
      col.add_child(title)

      var sub := Label.new()
      sub.text = "Send your pup while you work. Pick a plan:"
      sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
      sub.autowrap_mode = TextServer.AUTOWRAP_WORD
      sub.custom_minimum_size = Vector2(460, 0)
      sub.add_theme_font_size_override("font_size", 20)
      sub.add_theme_color_override("font_color", UITheme.CLR_GRAY_DRK)
      if _pf: sub.add_theme_font_override("font", _pf)
      col.add_child(sub)

      col.add_child(HSeparator.new())

      _cheap_btn = _make_tier_button("Cheap Daycare", "Basic care. Health at risk.")
      _cheap_btn.pressed.connect(func(): _pick(GameState.DaycareTier.CHEAP, GameState.daycare_cheap_price))
      col.add_child(_cheap_btn)

      _premium_btn = _make_tier_button("Premium Daycare", "Safe + health protected.")
      _premium_btn.pressed.connect(func(): _pick(GameState.DaycareTier.PREMIUM, GameState.daycare_premium_price))
      col.add_child(_premium_btn)

      col.add_child(HSeparator.new())

      var cancel_btn := Button.new()
      cancel_btn.text = "Cancel"
      cancel_btn.custom_minimum_size = Vector2(0, 56)
      cancel_btn.add_theme_font_size_override("font_size", 22)
      if _pf: cancel_btn.add_theme_font_override("font", _pf)
      UITheme.style_pixel_button(cancel_btn, true)
      cancel_btn.pressed.connect(func(): visible = false)
      col.add_child(cancel_btn)


  func _make_tier_button(tier_name: String, desc: String) -> Button:
      var b := Button.new()
      b.custom_minimum_size = Vector2(0, 72)
      b.add_theme_font_size_override("font_size", 22)
      if _pf: b.add_theme_font_override("font", _pf)
      UITheme.style_pixel_button(b)
      return b


  func _refresh() -> void:
      var cheap := GameState.daycare_cheap_price
      var premium := GameState.daycare_premium_price
      var money := GameState.money

      _cheap_btn.text = "Cheap Daycare — $%.2f\nBasic care. Health at risk." % cheap
      _premium_btn.text = "Premium Daycare — $%.2f\nSafe + health protected." % premium

      _cheap_btn.disabled = money < cheap
      _premium_btn.disabled = money < premium

      # Red tint on disabled buttons
      var red_mod := Color(1.0, 0.5, 0.5, 1.0)
      var normal_mod := Color.WHITE
      _cheap_btn.self_modulate = red_mod if _cheap_btn.disabled else normal_mod
      _premium_btn.self_modulate = red_mod if _premium_btn.disabled else normal_mod


  func _pick(tier: GameState.DaycareTier, price: float) -> void:
      GameState.money -= price
      GameState.dog_at_daycare = true
      GameState.daycare_used_today = true
      GameState.daycare_tier_today = tier
      visible = false
  ```

- [ ] **Step 2: Test via MCP**

  Run the project and open the game. In the Godot editor console verify no parse errors for the new script.
  ```
  mcp__godot__run_project
  mcp__godot__get_debug_output
  ```
  Expected: no errors mentioning `daycare_menu.gd`.

- [ ] **Step 3: Commit**
  ```bash
  git add scripts/daycare_menu.gd
  git commit -m "feat(daycare): add DaycareMenu popup (cheap/premium tiers, confirm/cancel)"
  ```

---

### Task 3: `bottom_hud.gd` — Daycare HUD Button

**Files:**
- Modify: `scripts/bottom_hud.gd`

**Interfaces:**
- Consumes:
  - `GameState.selected_pathway: String` (values: `"kid"`, `"teenager"`, `"adult"`)
  - `GameState.daycare_used_today: bool`
  - `GameState.worked_today: bool`
  - `DaycareMenu` (the new script from Task 2) — loaded via `preload`
- Produces: `daycare_btn` (Button) visible in HUD for teenager/adult, 20px right of money label

- [ ] **Step 1: Add daycare preload and instance var at the top of `bottom_hud.gd`**

  Find the existing preloads block (around line 31–36). After:
  ```gdscript
  var notification_panel_scene = preload("res://scripts/notification_panel.gd")
  ```
  Add:
  ```gdscript
  var daycare_menu_scene = preload("res://scripts/daycare_menu.gd")
  var daycare_menu_instance = null
  var daycare_btn: Button = null
  ```

- [ ] **Step 2: Instantiate daycare menu in `_ready()`**

  Find (around line 83):
  ```gdscript
  # Create supplies menu instance
  supplies_menu_instance = supplies_menu_scene.instantiate()
  ```
  Add before that block:
  ```gdscript
  # Create daycare menu instance (teens/adults only — button gated separately)
  daycare_menu_instance = daycare_menu_scene.new()
  add_child(daycare_menu_instance)
  ```

- [ ] **Step 3: Spawn the daycare button in `_apply_redesign_styling()`**

  Find the money label styling block (around line 161):
  ```gdscript
  # Money label — pixel font, maroon, big.
  money_label.text = "$%.2f" % GameState.money
  ```
  After the money label block ends (after `if pf: money_label.add_theme_font_override("font", pf)`), add:
  ```gdscript
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
          daycare_btn.custom_minimum_size = Vector2(130, 60)
          daycare_btn.add_theme_font_size_override("font_size", 22)
          if pf: daycare_btn.add_theme_font_override("font", pf)
          UITheme.style_pixel_button(daycare_btn)
          left_sec.add_child(daycare_btn)
          daycare_btn.pressed.connect(_on_daycare_btn_pressed)
  ```

- [ ] **Step 4: Add `_on_daycare_btn_pressed()` handler**

  At the bottom of the file (before the last function or at end), add:
  ```gdscript
  func _on_daycare_btn_pressed() -> void:
      if daycare_menu_instance:
          daycare_menu_instance.open()
  ```

- [ ] **Step 5: Update `update_ui()` to hide button after use or after first shift**

  Find `update_ui()`:
  ```gdscript
  func update_ui():
      money_label.text = "$%.2f" % GameState.money
      _apply_time_label_text()
      _update_hud_status_label()
  ```
  Add at the end of the function:
  ```gdscript
      if daycare_btn:
          daycare_btn.visible = (not GameState.daycare_used_today) and (not GameState.worked_today)
  ```

- [ ] **Step 6: Set `GameState.worked_today = true` after a shift is initiated in `manager_npc.gd`**

  Open `scripts/manager_npc.gd`. Find the burger launch block:
  ```gdscript
  if location_key == "burger":
      var launcher = get_node_or_null("/root/BurgerLauncher")
      if launcher and launcher.has_method("open_for_work"):
          if hint_instance:
              hint_instance.hide_hint()
          launcher.open_for_work()
  ```
  Add `GameState.worked_today = true` after `launcher.open_for_work()`:
  ```gdscript
  if location_key == "burger":
      var launcher = get_node_or_null("/root/BurgerLauncher")
      if launcher and launcher.has_method("open_for_work"):
          if hint_instance:
              hint_instance.hide_hint()
          launcher.open_for_work()
          GameState.worked_today = true
      else:
          _show_dialogue([GameState.complete_work_shift()])
          GameState.worked_today = true
  elif location_key == "bank":
      var loan_launcher = get_node_or_null("/root/LoanLauncher")
      if loan_launcher and loan_launcher.has_method("open_for_work"):
          if hint_instance:
              hint_instance.hide_hint()
          loan_launcher.open_for_work()
          GameState.worked_today = true
      else:
          _show_dialogue([GameState.complete_work_shift()])
          GameState.worked_today = true
  else:
      _show_dialogue([GameState.complete_work_shift()])
      GameState.worked_today = true
  ```

- [ ] **Step 7: Test via MCP**

  ```
  mcp__godot__run_project
  mcp__godot__get_debug_output
  ```
  Start a teenager or adult game. Verify:
  - "🐾 Daycare" button appears near money label
  - Clicking it opens the daycare popup
  - Choosing cheap/premium deducts money and hides the button
  - Button is hidden for kid pathway

- [ ] **Step 8: Commit**
  ```bash
  git add scripts/bottom_hud.gd scripts/manager_npc.gd
  git commit -m "feat(daycare): add daycare HUD button and worked_today flag wiring"
  ```

---

### Task 4: `manager_npc.gd` — Dog-at-Work Punishment Check

**Files:**
- Modify: `scripts/manager_npc.gd`

**Interfaces:**
- Consumes:
  - `GameState.dog_at_daycare: bool`
  - `GameState.apply_dog_at_work_penalty() -> String`
  - `get_tree().get_nodes_in_group("dog")` — detects live dog in scene
  - `_show_dialogue(lines: Array)` — existing method on manager_npc

- [ ] **Step 1: Add dog-at-work check in `_interact()`**

  Find in `manager_npc.gd` the section after the briefing/block checks but before the minigame launch:
  ```gdscript
  if location_key == "burger":
  ```
  Insert directly before that line (after the `if block != "": ... return` block):
  ```gdscript
  # Dog-at-work check: if dog is in the scene and wasn't sent to daycare, punish.
  if not GameState.dog_at_daycare and get_tree().get_nodes_in_group("dog").size() > 0:
      _show_dialogue([
          "Hey — is that your dog?",
          "Don't bring your dog to work. You're getting a fine.",
          GameState.apply_dog_at_work_penalty()
      ])
      return
  ```

- [ ] **Step 2: Test via MCP**

  ```
  mcp__godot__run_project
  mcp__godot__get_debug_output
  ```
  Walk a teenager/adult character to their manager NPC with the dog following (don't use daycare). Press E. Verify:
  - Manager says three lines: dog spotted → fine warning → penalty confirmation
  - Shift does NOT start
  - `GameState.money` decreased by $25
  - `GameState.job_promo_chance` for the active job decreased

  Then test with daycare used (send dog to daycare first, then press E). Verify:
  - Punishment dialogue does NOT appear
  - Shift launches normally

- [ ] **Step 3: Commit**
  ```bash
  git add scripts/manager_npc.gd
  git commit -m "feat(daycare): add dog-at-work punishment check in manager_npc before shift launch"
  ```

---

### Task 5: `CostCustomization.gd` — Daycare Price Inputs

**Files:**
- Modify: `scripts/CostCustomization.gd`

**Interfaces:**
- Consumes:
  - `GameState.daycare_cheap_price: float`
  - `GameState.daycare_premium_price: float`
  - Existing `setup_new_variables()` pattern (GridContainer with label + LineEdit rows)
  - `_update_field_visibilities(pathway)` — existing visibility toggle method
- Produces: Two new `LineEdit` inputs writing to `GameState.daycare_cheap_price` and `GameState.daycare_premium_price` on Continue

- [ ] **Step 1: Add daycare input refs at the top of `CostCustomization.gd`**

  Find the career input var declarations (around line 38–42):
  ```gdscript
  var promotion_boost_input: LineEdit = null
  ```
  Add after it:
  ```gdscript
  var daycare_section_header: Label = null
  var daycare_grid: GridContainer = null
  var daycare_cheap_input: LineEdit = null
  var daycare_premium_input: LineEdit = null
  ```

- [ ] **Step 2: Build the daycare section in `setup_new_variables()`**

  Find the end of `setup_new_variables()` — the last lines adding `boost_spacer`. After:
  ```gdscript
  var boost_spacer := Control.new()
  career_grid.add_child(boost_spacer)
  ```
  Add:
  ```gdscript
  # HSeparator
  var sep3 := HSeparator.new()
  sections.add_child(sep3)

  # Section header: Daycare Settings
  daycare_section_header = Label.new()
  daycare_section_header.text = "Daycare Settings"
  daycare_section_header.add_theme_font_size_override("font_size", 28)
  daycare_section_header.add_theme_color_override("font_color", Color("#53d8fb"))
  if pf: daycare_section_header.add_theme_font_override("font", pf)
  sections.add_child(daycare_section_header)

  daycare_grid = GridContainer.new()
  daycare_grid.columns = 3
  daycare_grid.add_theme_constant_override("h_separation", 20)
  daycare_grid.add_theme_constant_override("v_separation", 12)
  sections.add_child(daycare_grid)

  var dc_cheap_lbl := Label.new()
  dc_cheap_lbl.text = "Cheap Daycare Price"
  dc_cheap_lbl.add_theme_font_size_override("font_size", 22)
  dc_cheap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  daycare_grid.add_child(dc_cheap_lbl)

  var dc_premium_lbl := Label.new()
  dc_premium_lbl.text = "Premium Daycare Price"
  dc_premium_lbl.add_theme_font_size_override("font_size", 22)
  dc_premium_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  daycare_grid.add_child(dc_premium_lbl)

  var dc_spacer := Control.new()
  daycare_grid.add_child(dc_spacer)

  daycare_cheap_input = LineEdit.new()
  daycare_cheap_input.custom_minimum_size = Vector2(220, 56)
  daycare_cheap_input.add_theme_font_size_override("font_size", 28)
  daycare_cheap_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
  daycare_grid.add_child(daycare_cheap_input)

  daycare_premium_input = LineEdit.new()
  daycare_premium_input.custom_minimum_size = Vector2(220, 56)
  daycare_premium_input.add_theme_font_size_override("font_size", 28)
  daycare_premium_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
  daycare_grid.add_child(daycare_premium_input)

  var dc_spacer2 := Control.new()
  daycare_grid.add_child(dc_spacer2)
  ```

- [ ] **Step 3: Prefill daycare inputs in `populate_from_state()`**

  Find the end of `populate_from_state()`:
  ```gdscript
  if promotion_boost_input:
      promotion_boost_input.text = str(int(round(GameState.promotion_boost_percent)))
  ```
  Add after it:
  ```gdscript
  if daycare_cheap_input:
      daycare_cheap_input.text = "%.2f" % GameState.daycare_cheap_price
  if daycare_premium_input:
      daycare_premium_input.text = "%.2f" % GameState.daycare_premium_price
  ```

- [ ] **Step 4: Show/hide daycare section in `_update_field_visibilities()`**

  Find in `_update_field_visibilities()`:
  ```gdscript
  if career_section_header: career_section_header.visible = show_career
  if career_grid: career_grid.visible = show_career
  ```
  Add after it:
  ```gdscript
  if daycare_section_header: daycare_section_header.visible = show_career
  if daycare_grid: daycare_grid.visible = show_career
  ```
  (`show_career` is already `pathway == "teenager" or pathway == "adult"` — correct for daycare too.)

- [ ] **Step 5: Apply preset values for daycare in `apply_preset()`**

  Find the `elif pathway == "teenager":` block. After `promotion_boost_input.text = "40"`, add:
  ```gdscript
  if daycare_cheap_input: daycare_cheap_input.text = "15.00"
  if daycare_premium_input: daycare_premium_input.text = "30.00"
  ```
  Find the `elif pathway == "adult":` block. After `promotion_boost_input.text = "40"`, add:
  ```gdscript
  if daycare_cheap_input: daycare_cheap_input.text = "15.00"
  if daycare_premium_input: daycare_premium_input.text = "30.00"
  ```

- [ ] **Step 6: Read and validate daycare prices in `_on_continue_pressed()`**

  Find at the bottom of `_on_continue_pressed()`, before the final `SceneManager.change_scene(...)` call:
  ```gdscript
  GameState.promotion_boost_percent = promo_boost
  ```
  Add after it:
  ```gdscript
  # Daycare prices — only for teenager/adult, premium must exceed cheap by at least $5
  if _selected_pathway in ["teenager", "adult"]:
      var cheap_price := GameState.daycare_cheap_price
      var premium_price := GameState.daycare_premium_price
      if daycare_cheap_input and not daycare_cheap_input.text.is_empty():
          cheap_price = clampf(float(daycare_cheap_input.text), 5.0, 50.0)
      if daycare_premium_input and not daycare_premium_input.text.is_empty():
          premium_price = clampf(float(daycare_premium_input.text), cheap_price + 5.0, 80.0)
      GameState.daycare_cheap_price = cheap_price
      GameState.daycare_premium_price = premium_price
  ```

- [ ] **Step 7: Test via MCP**

  ```
  mcp__godot__run_project
  mcp__godot__get_debug_output
  ```
  On the cost customization screen:
  - Select Kid pathway → daycare section hidden
  - Select Teenager → daycare section visible, defaults $15/$30
  - Change cheap to $20, premium to $24 → after Continue, verify premium is clamped to $25 (cheap + 5)
  - Select Adult preset → fields reset to $15/$30

- [ ] **Step 8: Commit**
  ```bash
  git add scripts/CostCustomization.gd
  git commit -m "feat(daycare): add cheap/premium daycare price inputs to CostCustomization (teen/adult only)"
  ```
