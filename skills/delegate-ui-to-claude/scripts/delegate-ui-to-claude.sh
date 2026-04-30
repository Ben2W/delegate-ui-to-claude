#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  delegate-ui-to-claude.sh "Design refinement task"
  delegate-ui-to-claude.sh < design-task.md

Environment:
  CLAUDE_UI_REPO             Repository path. Defaults to current directory.
  CLAUDE_UI_PERMISSION_MODE  Claude permission mode. Defaults to acceptEdits.
  CLAUDE_UI_OUTPUT_FORMAT    Claude output format. Defaults to text.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "error: claude CLI was not found on PATH" >&2
  exit 127
fi

repo="${CLAUDE_UI_REPO:-$PWD}"
permission_mode="${CLAUDE_UI_PERMISSION_MODE:-acceptEdits}"
output_format="${CLAUDE_UI_OUTPUT_FORMAT:-text}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
frontend_design_file="$script_dir/../references/frontend-design.md"

if [[ ! -f "$frontend_design_file" ]]; then
  echo "error: bundled frontend design instructions not found: $frontend_design_file" >&2
  exit 66
fi

if [[ $# -gt 0 ]]; then
  task="$*"
else
  task="$(cat)"
fi

if [[ -z "${task//[[:space:]]/}" ]]; then
  echo "error: provide a UI task as arguments or stdin" >&2
  usage >&2
  exit 64
fi

cd "$repo"
frontend_design_instructions="$(cat "$frontend_design_file")"

claude --print \
  --permission-mode "$permission_mode" \
  --output-format "$output_format" \
  --add-dir "$repo" \
  -- \
  "$(cat <<PROMPT
You are Claude Code running headlessly as a frontend design refinement pass after Codex has implemented or scaffolded the functional UI.

Apply the following embedded frontend-design skill instructions directly. Do not try to load a slash command or external skill; the complete design guidance is already included here.

<frontend-design>
$frontend_design_instructions
</frontend-design>

Repository: $repo

Task:
$task

Requirements:
- Rewrite/refine the existing frontend design directly in the repository.
- Preserve existing behavior, data flow, framework conventions, public APIs, routes, and accessibility semantics unless a design change requires a clearly beneficial accessibility improvement.
- Improve visual hierarchy, typography, spacing, color, motion, layout, responsiveness, and interaction polish.
- Keep user-facing UI polished, responsive, accessible, and consistent with the product domain.
- Do not take over unrelated functional implementation. If required UI files or a functional baseline are missing, report that Codex should scaffold/implement them first instead of building a full app from scratch.
- Use visual verification when project tooling supports it.
- Run relevant checks when practical.
- Do not commit changes unless the user explicitly requested a commit.
- End with a concise summary: files changed, verification run, and any blockers.
PROMPT
)"
