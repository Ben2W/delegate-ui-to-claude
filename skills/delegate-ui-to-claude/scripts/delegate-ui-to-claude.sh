#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  delegate-ui-to-claude.sh "UI task"
  delegate-ui-to-claude.sh < task.md

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
You are Claude Code running headlessly for a UI/frontend task delegated by Codex.

Apply the following embedded frontend-design skill instructions directly. Do not try to load a slash command or external skill; the complete design guidance is already included here.

<frontend-design>
$frontend_design_instructions
</frontend-design>

Repository: $repo

Task:
$task

Requirements:
- Make the requested UI/frontend changes directly in the repository.
- Preserve existing architecture, framework conventions, and design system patterns.
- Keep user-facing UI polished, responsive, accessible, and consistent with the product domain.
- Use visual verification when project tooling supports it.
- Run relevant checks when practical.
- Do not commit changes unless the user explicitly requested a commit.
- End with a concise summary: files changed, verification run, and any blockers.
PROMPT
)"
