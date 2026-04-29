# delegate-ui-to-claude

Agent skill that makes Codex delegate UI/frontend changes to Claude Code in headless mode.

Install with:

```bash
npx skills add Ben2W/mcpForClaudeCodeFrontend --skill delegate-ui-to-claude --agent codex --global --yes
```

The skill expects the `claude` CLI to be available and asks Claude Code to use `$frontend-design` when available, falling back to `$web-design-guidelines`.
