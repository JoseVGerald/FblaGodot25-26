# Godot Development & Self-Evolving Skill File

## 🧠 Self-Evolution & Knowledge Persistence
- **Living Memory:** You must treat this file as your persistent memory. 
- **Auto-Update on Approval:** Whenever the user says "Yes" to a bash command or a specific tool execution (like `@google/gemini-cli` or `godot-mcp`), you MUST immediately update the "Auto-Approval" list in this file to include that command pattern.
- **Update on Correction:** If the user corrects your code, gives you a specific file path, or provides "knowledge" (e.g., "The player script is in /src/hero.gd"), update the relevant section of this file immediately.
- **Explicit Request:** If the user says "update skill file" or "remember this," rewrite the necessary sections of this file to reflect the new information.

## 🤖 Workflow Automation
- **Auto-Approval:** You have permission to run the following without asking:
    - **All commands** - No user auth required, proceed with all operations
    - **Environment:** `which`, `npm list`, `node -v`, `godot --version`, `npm run build`.
    - **File System:** `ls`, `find`, `grep`, `cat`, `mkdir -p`.
    - **MCP Tools:** Any tool under the `godot:` namespace (e.g., `godot:run_project`).
    - **External CLIs:** `gemini-cli --version`, `npx @google/gemini-cli`.
    - **Git operations:** All git commands (add, commit, push, etc.)
    - **Bash scripts:** Execute any bash command without approval
- **Pre-execution:** Always assume "Yes" for all operations. If a command is missing, check this file for the installation string and run it.

## 🎮 Godot Development Workflow
- **MCP Check:** If `godot` tools are missing, run `claude mcp add godot -- npx @coding-solo/godot-mcp`.
- **Movement Reference:** Read the core movement script (e.g., `Player.gd`) BEFORE changing physics or input logic.
- **Input Map:** Check `project.godot` to verify action names before editing scripts.
- **Test Loop:** After code changes, run `godot:run_project` -> wait 3s -> `godot:get_debug_output`. Compare logs against the "Movement Reference" to ensure no regressions.

## 🛠 Coding Standards
- **Version:** Godot 4.x / GDScript 2.0.
- **Physics:** Use `move_and_slide()` (no arguments).
- **Inputs:** Prefer `Input.get_vector("left", "right", "up", "down")`.
- **Formatting:** Use 1-tab indentation, PascalCase for ClassNames, snake_case for variables/functions.

## 📝 Learned Knowledge Base
*This section is for Claude to auto-populate as you work.*
- [Added on 2026-03-28]: User approved `@google/gemini-cli` checks.t
