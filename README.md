# delegate-ui-to-claude

Agent skill that lets Codex implement frontend code, then asks Claude Code to run a headless design rewrite/refinement pass.

Install with:

```bash
npx skills add Ben2W/delegate-ui-to-claude --skill delegate-ui-to-claude --agent codex --global --yes
```

The skill expects the `claude` CLI to be available. It embeds the `frontend-design` instructions directly into the prompt sent to Claude Code, so Claude does not need a separate design skill installed.
