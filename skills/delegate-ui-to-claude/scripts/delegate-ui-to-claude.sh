#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  delegate-ui-to-claude.sh "UI task"
  delegate-ui-to-claude.sh < task.md

Environment:
  CLAUDE_UI_REPO             Repository path. Defaults to current directory.
  CLAUDE_UI_SKILL            Preferred Claude design skill. Defaults to frontend-design.
  CLAUDE_UI_FALLBACK_SKILL   Fallback skill. Defaults to web-design-guidelines.
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
skill="${CLAUDE_UI_SKILL:-frontend-design}"
fallback_skill="${CLAUDE_UI_FALLBACK_SKILL:-web-design-guidelines}"
permission_mode="${CLAUDE_UI_PERMISSION_MODE:-acceptEdits}"
output_format="${CLAUDE_UI_OUTPUT_FORMAT:-text}"

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

claude --print \
  --permission-mode "$permission_mode" \
  --output-format "$output_format" \
  --add-dir "$repo" \
  "$(cat <<PROMPT
You are Claude Code running headlessly for a UI/frontend task delegated by Codex.

Use \$$skill if it exists. If that skill is unavailable, use \$$fallback_skill. If neither skill is available, continue by applying equivalent high-quality frontend design standards directly and mention that the named skill was unavailable.

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
