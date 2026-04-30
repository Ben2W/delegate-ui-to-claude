# delegate-ui-to-claude

Agent skill that makes Codex delegate UI/frontend changes to Claude Code in headless mode.

Install with:

```bash
npx skills add Ben2W/delegate-ui-to-claude --skill delegate-ui-to-claude --agent codex --global --yes
```

The skill expects the `claude` CLI to be available. It embeds the `frontend-design` instructions directly into the prompt sent to Claude Code, so Claude does not need a separate design skill installed.
