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
  CLAUDE_UI_OUTPUT_FORMAT    Claude output format. Defaults to stream-json.
  CLAUDE_UI_URL              Optional existing preview URL to give Claude.
  CLAUDE_UI_START_SERVER     auto, never, or always. Defaults to auto.
  CLAUDE_UI_DEV_CMD          Optional dev server command. Supports {host}, {port}, {url}.
  CLAUDE_UI_HOST             Preview host for auto-started servers. Defaults to 127.0.0.1.
  CLAUDE_UI_PORT             Preferred preview port. Defaults to first free port >= 4321.
  CLAUDE_UI_SERVER_READY_TIMEOUT
                              Seconds to wait for preview readiness. Defaults to 20.
  CLAUDE_UI_HEARTBEAT_SECONDS
                              Progress heartbeat interval. Defaults to 15. Use 0 to disable.
EOF
}

log() {
  printf '[delegate-ui] %s\n' "$*" >&2
}

is_url_reachable() {
  local url="$1"
  command -v curl >/dev/null 2>&1 && curl -fsS --max-time 2 "$url" >/dev/null 2>&1
}

find_free_port() {
  local preferred="${CLAUDE_UI_PORT:-}"
  local port

  for port in ${preferred:+"$preferred"} 4321 4322 4323 5173 5174 3000 3001 8080 8081; do
    if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      printf '%s\n' "$port"
      return 0
    fi
  done

  for port in $(seq 4300 4399); do
    if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      printf '%s\n' "$port"
      return 0
    fi
  done

  return 1
}

has_package_dev_script() {
  [[ -f package.json ]] || return 1

  if command -v node >/dev/null 2>&1; then
    node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts.dev ? 0 : 1)" >/dev/null 2>&1
    return $?
  fi

  grep -Eq '"dev"[[:space:]]*:' package.json
}

detect_package_manager() {
  if [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then
    printf 'pnpm\n'
  elif [[ -f yarn.lock ]] && command -v yarn >/dev/null 2>&1; then
    printf 'yarn\n'
  elif [[ -f bun.lockb || -f bun.lock ]] && command -v bun >/dev/null 2>&1; then
    printf 'bun\n'
  elif command -v npm >/dev/null 2>&1; then
    printf 'npm\n'
  else
    return 1
  fi
}

infer_dev_cmd() {
  local host="$1"
  local port="$2"
  local package_manager

  has_package_dev_script || return 1
  package_manager="$(detect_package_manager)" || return 1

  case "$package_manager" in
    npm)
      printf 'npm run dev -- --host %q --port %q\n' "$host" "$port"
      ;;
    pnpm)
      printf 'pnpm dev --host %q --port %q\n' "$host" "$port"
      ;;
    yarn)
      printf 'yarn dev --host %q --port %q\n' "$host" "$port"
      ;;
    bun)
      printf 'bun run dev --host %q --port %q\n' "$host" "$port"
      ;;
  esac
}

print_new_log_lines() {
  local log_file="$1"
  local line_count

  line_count="$(wc -l < "$log_file" | tr -d ' ')"
  if (( line_count >= next_line )); then
    sed -n "${next_line},${line_count}p" "$log_file"
    next_line=$((line_count + 1))
  fi
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
output_format="${CLAUDE_UI_OUTPUT_FORMAT:-stream-json}"
start_server="${CLAUDE_UI_START_SERVER:-auto}"
dev_cmd="${CLAUDE_UI_DEV_CMD:-}"
preview_url="${CLAUDE_UI_URL:-}"
host="${CLAUDE_UI_HOST:-127.0.0.1}"
server_ready_timeout="${CLAUDE_UI_SERVER_READY_TIMEOUT:-20}"
heartbeat_seconds="${CLAUDE_UI_HEARTBEAT_SECONDS:-15}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
frontend_design_file="$script_dir/../references/frontend-design.md"
server_pid=""
server_log=""

cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" >/dev/null 2>&1; then
    log "stopping preview server pid $server_pid"
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

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

case "$start_server" in
  auto | never | always)
    ;;
  *)
    echo "error: CLAUDE_UI_START_SERVER must be auto, never, or always" >&2
    exit 64
    ;;
esac

if [[ -n "$preview_url" ]]; then
  if is_url_reachable "$preview_url"; then
    log "using provided preview URL: $preview_url"
  else
    log "provided preview URL is not reachable, continuing without it: $preview_url"
    preview_url=""
  fi
elif [[ "$start_server" != "never" ]]; then
  port="$(find_free_port || true)"

  if [[ -n "$port" ]]; then
    if [[ -z "$dev_cmd" ]]; then
      dev_cmd="$(infer_dev_cmd "$host" "$port" || true)"
    else
      url="http://$host:$port/"
      dev_cmd="${dev_cmd//\{host\}/$host}"
      dev_cmd="${dev_cmd//\{port\}/$port}"
      dev_cmd="${dev_cmd//\{url\}/$url}"
    fi
  fi

  if [[ -n "$dev_cmd" && -n "${port:-}" ]]; then
    preview_url="http://$host:$port/"
    server_log="$(mktemp -t delegate-ui-server.XXXXXX.log)"
    log "starting preview server: $dev_cmd"
    bash -lc "$dev_cmd" >"$server_log" 2>&1 &
    server_pid=$!

    for _ in $(seq 1 "$server_ready_timeout"); do
      if is_url_reachable "$preview_url"; then
        log "preview URL available: $preview_url"
        break
      fi

      if ! kill -0 "$server_pid" >/dev/null 2>&1; then
        log "preview server exited before becoming ready"
        break
      fi

      sleep 1
    done

    if ! is_url_reachable "$preview_url"; then
      log "preview URL unavailable, continuing without browser context"
      log "preview server log: $server_log"
      cleanup
      server_pid=""
      preview_url=""
    fi
  elif [[ "$start_server" == "always" ]]; then
    echo "error: no dev server command could be inferred; set CLAUDE_UI_DEV_CMD or CLAUDE_UI_URL" >&2
    exit 65
  else
    log "no obvious dev server command found; continuing without preview URL"
  fi
fi

if [[ -n "$preview_url" ]]; then
  preview_context="$(cat <<PREVIEW
Preview URL: $preview_url

Use this local preview when practical to inspect user-facing routes after meaningful visual edit batches. Do not assume every project route is linked from the home page; inspect the files and visit the relevant route paths.
PREVIEW
)"
else
  preview_context="$(cat <<PREVIEW
Preview URL: unavailable

No local preview URL was detected. Refine the UI from source files and run available code/build checks. Do not block on browser verification.
PREVIEW
)"
fi

prompt="$(cat <<PROMPT
You are Claude Code running headlessly as a frontend design refinement pass after Codex has implemented or scaffolded the functional UI.

Apply the following embedded frontend-design skill instructions directly. Do not try to load a slash command or external skill; the complete design guidance is already included here.

<frontend-design>
$frontend_design_instructions
</frontend-design>

Repository: $repo

$preview_context

Task:
$task

Requirements:
- Rewrite/refine the existing frontend design directly in the repository.
- Preserve existing behavior, data flow, framework conventions, public APIs, routes, and accessibility semantics unless a design change requires a clearly beneficial accessibility improvement.
- Improve visual hierarchy, typography, spacing, color, motion, layout, responsiveness, and interaction polish.
- Keep user-facing UI polished, responsive, accessible, and consistent with the product domain.
- Do not take over unrelated functional implementation. If required UI files or a functional baseline are missing, report that Codex should scaffold/implement them first instead of building a full app from scratch.
- Use visual verification when a preview URL or project tooling supports it, but continue without one when unavailable.
- Run relevant checks when practical.
- Do not commit changes unless the user explicitly requested a commit.
- End with a concise summary: files changed, verification run, and any blockers.
PROMPT
)"

claude_args=(
  --print
  --permission-mode "$permission_mode"
  --output-format "$output_format"
  --add-dir "$repo"
)

if [[ "$output_format" == "stream-json" && "${CLAUDE_UI_INCLUDE_PARTIAL_MESSAGES:-1}" != "0" ]]; then
  claude_args+=(--include-partial-messages)
fi

if [[ "$heartbeat_seconds" == "0" ]]; then
  claude "${claude_args[@]}" -- "$prompt"
  exit $?
fi

claude_log="$(mktemp -t delegate-ui-claude.XXXXXX.log)"
claude "${claude_args[@]}" -- "$prompt" >"$claude_log" 2>&1 &
claude_pid=$!
next_line=1
last_heartbeat="$(date +%s)"

set +e
while kill -0 "$claude_pid" >/dev/null 2>&1; do
  print_new_log_lines "$claude_log"

  now="$(date +%s)"
  if (( now - last_heartbeat >= heartbeat_seconds )); then
    log "Claude still running; current working tree:"
    if [[ -n "$(git status --short)" ]]; then
      git status --short | sed 's/^/[delegate-ui]   /' >&2
    else
      log "  no file changes yet"
    fi
    last_heartbeat="$now"
  fi

  sleep 2
done

wait "$claude_pid"
claude_status=$?
print_new_log_lines "$claude_log"

exit "$claude_status"
