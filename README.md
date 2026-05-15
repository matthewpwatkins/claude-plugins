# claude-plugins

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace.

## Plugins

- **[session-wall](./session-wall/)** — Coordinate parallel Claude Code sessions via per-session bulletin files.
- **[auto-pause](./auto-pause/)** — Proactively pause a session before it hits the 5-hour subscription window so long autonomous runs survive the reset.

## Install

In any Claude Code session:

```
/plugin marketplace add https://github.com/matthewpwatkins/claude-plugins
/plugin install auto-pause@matthewpwatkins-plugins
/plugin install session-wall@matthewpwatkins-plugins
```

For local development, point at the working copy instead:

```
/plugin marketplace add ~/dev-personal/claude-plugins
```

## Layout

```
.claude-plugin/marketplace.json    # the marketplace manifest
session-wall/                       # plugin 1
auto-pause/                         # plugin 2
```

Each plugin is a self-contained directory with its own `.claude-plugin/plugin.json`, `hooks/`, `scripts/`, `commands/`, and `skills/`. See each plugin's own README for details.

## License

MIT — see [LICENSE](./LICENSE).
