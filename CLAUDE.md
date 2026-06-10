# My Little Buddy — UI Redesign Implementation

You are implementing a complete UI redesign for a Godot 4 game called **My Little Buddy**.
All reference designs are in `Finance Menu.html` and `All Menus Mockup.html` in this folder.
Open them in a browser to see the exact target appearance before writing any code.

## Your task
Rebuild the following Godot scenes and scripts to match the reference HTML designs exactly.
Work through them **in the order listed** — each builds on shared helpers established earlier.

1. `scripts/UITheme.gd` — add new helper methods
2. `scripts/ui_colors.gd` — update color constants
3. `scenes/ui/bottom_hud.tscn` + `scripts/bottom_hud.gd`
4. `scenes/ui/needs_menu.tscn` + `scripts/needs_menu.gd`
5. `scenes/ui/supplies_menu.tscn` + `scripts/supplies_menu.gd`
6. `scenes/ui/ShopMenu.tscn` + `scripts/shop_menu.gd`
7. `scenes/ui/PauseMenu.tscn` + `scripts/PauseMenu.gd`
8. `scenes/ui/SettingsMenu.tscn` + `scripts/SettingsMenu.gd`
9. `scenes/ui/ChoreMenu.tscn` + `scripts/chore_menu.gd`
10. `scenes/ui/FinanceMenu.tscn` + `scripts/finance_menu.gd`

## Critical rules
- **Never break existing gameplay logic.** Only change visual structure and styling.
  Signals, method names, and GameState calls must remain identical.
- **Read every existing script fully** before editing it.
- **Test each scene** by running the game and opening that menu before moving to the next.
- Use `UITheme.gd` helpers everywhere — do not inline StyleBoxFlat creation in individual scripts.
- All pixel-font text uses `UITheme.get_pixel_font()` (loads `assets/fonts/Minecraft.ttf`).
- Labels containing emoji skip the pixel font — UITheme already handles this.

## Slider design
When creating or modifying **any slider** (`HSlider`, range inputs, progress bars), invoke the **Emil Kowalski skill** first (`npx skills add emilkowalski/skill`).
Key rules for Godot sliders: grabber_highlight slightly larger than grabber (press feedback), track uses a strong contrast fill color, linear easing for the fill as value changes, no bounce.

## Motion design skill
For any UI animation, transitions, or loading screens, invoke the **Emil Kowalski skill** first:
- Skill is installed at `.agents/skills/emil-design-eng/`
- To reinstall: `npx skills add emilkowalski/skill`
- Key rules in Godot: ease-out for entering elements, linear for constant motion (progress bars), stagger groups 150–200ms apart, exit animations faster than entrances (200ms ease-in).

## Model recommendation
Use **claude-opus-4-5** with **extended thinking (budget ≥ 8000 tokens)** for each step.
The extra reasoning budget prevents shortcuts on the StyleBoxFlat wiring and scene tree structure.
