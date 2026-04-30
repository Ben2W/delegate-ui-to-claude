---
name: delegate-ui-to-claude
description: Use Claude Code as a headless frontend design refinement pass after Codex scaffolds or implements UI code. Use whenever Codex is asked to create, modify, polish, redesign, review, or verify user-facing frontend code, visual design, layout, styling, responsive behavior, accessibility, components, pages, or interactions; Codex may write the functional frontend implementation, but must ask Claude Code to rewrite/refine the design with embedded frontend-design instructions before finalizing user-facing UI work.
---

# Delegate UI To Claude

## Overview

Let Codex build the frontend functionality, structure, data wiring, and initial UI code. Then route the result through Claude Code using a non-interactive `claude --print` invocation so Claude performs a design rewrite/refinement pass with this skill's bundled `references/frontend-design.md`.

## Required Behavior

- Codex may scaffold, implement, and modify frontend code directly, including components, routes, state, data fetching, accessibility semantics, tests, and build wiring.
- Before finalizing user-facing UI work, delegate a design refinement pass to Claude Code headlessly. Use `scripts/delegate-ui-to-claude.sh` or an equivalent `claude --print` command.
- Treat Claude Code as the design specialist. Ask it to improve visual hierarchy, typography, spacing, color, motion, layout, responsiveness, and interaction polish while preserving the behavior Codex implemented.
- Do not ask Claude Code to load `$frontend-design`, `$web-design-guidelines`, or any other external design skill. The frontend design instructions are bundled with this skill and must be included directly in Claude's prompt.
- If Claude Code is unavailable, stop and report the blocker unless the user explicitly authorizes Codex to do the UI implementation directly.
- After Claude finishes, inspect the diff yourself. Codex may make functional fixes, integration fixes, and small cleanup edits. If the result still needs meaningful visual/design changes, delegate another design pass to Claude Code.

## Workflow

1. Clarify the frontend task: target pages/components, expected behavior, design constraints, and relevant verification commands.
2. Codex implements the functional frontend first. For a new UI, scaffold the working page/component/app before calling Claude. For existing UI, make required functional or structural changes before calling Claude.
3. Confirm the repository path and working tree state. Preserve user changes and do not ask Claude to revert unrelated files.
4. Run the wrapper from the repository root for the design pass. Resolve the script relative to this skill directory; for common Codex installs, use one of these paths:

```bash
script_path="${CODEX_HOME:-$HOME/.codex}/skills/delegate-ui-to-claude/scripts/delegate-ui-to-claude.sh"
[ -x "$script_path" ] || script_path="$HOME/.agents/skills/delegate-ui-to-claude/scripts/delegate-ui-to-claude.sh"
[ -x "$script_path" ] || script_path=".agents/skills/delegate-ui-to-claude/scripts/delegate-ui-to-claude.sh"

"$script_path" <<'TASK'
Describe the frontend work Codex already implemented and the design goals for Claude's refinement pass.
Include target files or routes when known.
Include expected verification commands when known.
TASK
```

5. Review Claude's output and the local diff with `git diff --stat` and targeted file reads.
6. Run the relevant checks yourself when practical: lint, typecheck, tests, build, and visual verification for significant UI work.
7. If the UI needs design revision, delegate the follow-up back to Claude Code with the same wrapper and a precise diff-aware prompt. If it needs functional revision, Codex may make that fix directly.
8. Final response: summarize what Codex implemented, what Claude refined, and list verification run or skipped.

## Direct Claude Command

If the wrapper is unavailable, use this command shape and paste the full contents of `references/frontend-design.md` where indicated:

```bash
claude --print \
  --permission-mode acceptEdits \
  --output-format text \
  --add-dir "$PWD" \
  -- \
  'You are Claude Code running headlessly as a frontend design refinement pass after Codex has implemented the functional UI.

Apply these frontend-design instructions directly:

<paste references/frontend-design.md here>

Rewrite/refine the existing frontend design directly in this repository. Preserve existing behavior, data flow, framework conventions, and public APIs. Improve visual hierarchy, typography, spacing, color, motion, layout, responsiveness, and interaction polish. Run relevant checks when practical, and do not commit changes unless explicitly requested.'
```

The `--` separator is required. In current Claude Code CLI versions, `--add-dir` accepts multiple directory values and can otherwise consume the prompt as another directory.

Use `CLAUDE_UI_PERMISSION_MODE=bypassPermissions` only when the user explicitly requests fully autonomous execution in a trusted workspace. Default to `acceptEdits`.

## Bundled Design Instructions

The wrapper reads `references/frontend-design.md` and includes it directly in the prompt to Claude Code. Keep that reference file aligned with the desired frontend design behavior.
