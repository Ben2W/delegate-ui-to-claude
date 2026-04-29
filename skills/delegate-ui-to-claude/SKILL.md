---
name: delegate-ui-to-claude
description: Delegate frontend and UI changes from Codex to Claude Code in headless mode. Use whenever Codex is asked to create, modify, polish, redesign, review, or verify user-facing frontend code, visual design, layout, styling, responsive behavior, accessibility, components, pages, or interactions; Codex must ask Claude Code to perform the UI work with the frontend design/web design skill instead of editing UI directly.
---

# Delegate UI To Claude

## Overview

Route UI/frontend work through Claude Code using a non-interactive `claude --print` invocation. Codex remains responsible for framing the task, reviewing the resulting diff, and reporting verification, but Claude Code performs the user-facing UI edits.

## Required Behavior

- Do not directly edit user-facing UI files when this skill is triggered. This includes component markup, styling, layout, design tokens, animation, responsive behavior, copy placement, and interaction details.
- Delegate the UI work to Claude Code headlessly before making any UI change. Use `scripts/delegate-ui-to-claude.sh` or an equivalent `claude --print` command.
- Ask Claude Code to use `$frontend-design` if available. If that named skill is unavailable, ask it to use `$web-design-guidelines`; that is the current Vercel skills collection name for frontend/web design guidance.
- If Claude Code or the required design skill is unavailable, stop and report the blocker unless the user explicitly authorizes Codex to do the UI implementation directly.
- After Claude finishes, inspect the diff yourself. Codex may make small non-UI integration fixes, but any further visual, layout, or styling changes must be delegated back to Claude Code.

## Workflow

1. Clarify the UI task enough to delegate it: target pages/components, expected behavior, design constraints, and relevant verification commands.
2. Confirm the repository path and working tree state. Preserve user changes and do not ask Claude to revert unrelated files.
3. Run the wrapper from the repository root. Resolve the script relative to this skill directory; for common Codex installs, use one of these paths:

```bash
script_path="${CODEX_HOME:-$HOME/.codex}/skills/delegate-ui-to-claude/scripts/delegate-ui-to-claude.sh"
[ -x "$script_path" ] || script_path="$HOME/.agents/skills/delegate-ui-to-claude/scripts/delegate-ui-to-claude.sh"
[ -x "$script_path" ] || script_path=".agents/skills/delegate-ui-to-claude/scripts/delegate-ui-to-claude.sh"

"$script_path" <<'TASK'
Describe the exact UI/frontend change to make.
Include target files or routes when known.
Include expected verification commands when known.
TASK
```

4. Review Claude's output and the local diff with `git diff --stat` and targeted file reads.
5. Run the relevant checks yourself when practical: lint, typecheck, tests, build, and visual verification for significant UI work.
6. If the UI needs revision, delegate the follow-up back to Claude Code with the same wrapper and a precise diff-aware prompt.
7. Final response: state that Claude Code performed the UI edits, summarize the files changed, and list verification run or skipped.

## Direct Claude Command

If the wrapper is unavailable, use this command shape:

```bash
claude --print \
  --permission-mode acceptEdits \
  --output-format text \
  --add-dir "$PWD" \
  'Use $frontend-design if available; otherwise use $web-design-guidelines. Make the requested UI/frontend changes directly in this repository. Preserve existing framework and design-system conventions, keep the result responsive and accessible, run relevant checks when practical, and do not commit changes unless explicitly requested.'
```

Use `CLAUDE_UI_PERMISSION_MODE=bypassPermissions` only when the user explicitly requests fully autonomous execution in a trusted workspace. Default to `acceptEdits`.

## Installing The Design Skill For Claude Code

If Claude Code reports that neither `$frontend-design` nor `$web-design-guidelines` is available, install the current public design skill for Claude Code and rerun the delegation:

```bash
npx skills add vercel-labs/agent-skills \
  --skill web-design-guidelines \
  --agent claude-code \
  --global \
  --yes \
  --copy
```
