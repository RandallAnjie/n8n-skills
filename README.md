# Official n8n Skills

<!-- TODO: add 15-second demo gif before the tagline -->

**n8n's MCP makes the connection. n8n Skills set the standard.**

Built by the n8n team to pair with n8n's instance-level MCP server. Your coding agent can now build and edit workflows through the MCP, organize them into folders and projects, and build n8n Agents. The skills enable it to get it right the first time.

**What's inside:**

- **The n8n MCP connection, set up for you** (Claude Code): the plugin bundles the `n8n-mcp` server and prompts for your instance URL at install, so there's no manual MCP config. Codex adds it with one `codex mcp add`.
- **13 official capability skills** covering best practices across the full workflow lifecycle: sub-workflow reuse, expressions, loops and pagination, AI agents, error handling, credentials, Data Tables, debugging, and more.
- **5 Feishu / 飞书 skills** (this fork) for `n8n-nodes-feishu-suite`: app setup, Bitable workflows, Trigger, AI Agent tools, and troubleshooting.
- **50+ reference docs and worked examples** loaded on demand: per-node gotchas, decision trees, and copy-pasteable workflow JSON / TypeScript SDK snippets.
- **A SessionStart hook** that loads the protocol on every session, including a compact reference for every n8n MCP tool.
- **PreToolUse hooks** that nudge your agent to consult the matching skill before high-impact MCP calls.
- **3 Suno Gateway skills** (this fork) for `n8n-nodes-suno-gateway` 0.4.0 (node v3): install/credentials/v1→v3, song recipes, troubleshooting.

## Prerequisite

An n8n instance (any plan, Cloud or self-hosted) with the instance-level MCP server enabled (**Settings → Instance-level MCP**). Minimum **n8n 2.2.0**; for best results, run the latest stable. See [n8n's MCP setup guide](https://docs.n8n.io/build/ways-of-building-workflows/connect-to-n8n-mcp-server/?utm_source=github&utm_medium=readme&utm_campaign=official-skills-repo).

## Install

Pick your platform:

- [Claude Code (CLI)](#claude-code-cli)
- [Claude Code (Desktop app)](#claude-code-desktop-app)
- [Codex](#codex)
- [OpenCode (CLI)](#opencode-cli)
- [OpenCode (Desktop app)](#opencode-desktop-app)
- [Other platforms](#other-platforms)

### Claude Code (CLI)

Inside a `claude` session:

1. **Add the marketplace.** Run `/plugin marketplace add n8n-io/skills`.
2. **Install the plugin.** Run `/plugin install n8n-skills@n8n-io`, enter your **n8n instance URL** when prompted, then run `/reload-plugins`.
   - Just the base URL, e.g. `https://acme.app.n8n.cloud` (no path) — the plugin adds `/mcp-server/http`.
3. **Authorize the MCP.** Run `/mcp`, select **n8n-mcp**, and choose **Authenticate** to sign in via your browser.

> Already run the n8n MCP elsewhere? This adds its own `n8n-mcp` connection. Disable it from `/mcp` to avoid a duplicate toolset.

### Claude Code (Desktop app)

1. **Add the marketplace.** In the prompt box, run `/plugin marketplace add n8n-io/skills`.
2. **Install.** Click **+** next to the prompt box → **Plugins** → **Add plugin**, select **n8n-skills** in the plugin browser, and pick a scope. Enter your **n8n instance URL** when prompted (just the base URL, e.g. `https://acme.app.n8n.cloud` — the plugin adds `/mcp-server/http`).
   - No prompt? Set it with `/plugin configure n8n-skills@n8n-io`, then reload.
3. **Authorize the MCP.** Open **Settings → Connectors**, find **n8n-mcp**, and connect (browser sign-in).

### Codex

> Requires **Codex ≥ 0.142.0** (root-plugin marketplace support). Works in the Codex CLI and the Codex mode of the ChatGPT desktop app.

In a terminal:

1. **Add the marketplace.** Run `codex plugin marketplace add n8n-io/skills`.
2. **Install the plugin.** Run `codex plugin add n8n-skills@n8n-io`, then restart Codex and approve the hook-trust prompt (enables the SessionStart, PreToolUse, and PostToolUse reminders).
3. **Add the MCP server.** Codex can't auto-configure it, so add it once (Codex has no config prompt like Claude Code):
   ```bash
   codex mcp add n8n-mcp --url https://<your-n8n-domain>/mcp-server/http
   ```
   - No terminal (desktop app only)? Add it in the GUI: **Settings → MCP servers → Add server → Streamable HTTP**, paste the URL, save, then **Restart**.
4. **Authorize the MCP.** Codex signs in via OAuth on first use, or click **Authenticate** in the MCP servers list.

### OpenCode (CLI)

Add one line to your `opencode.jsonc` (global `~/.config/opencode/`, or a project `.opencode/`) and restart:

```jsonc
{
  "plugin": ["n8n-skills@git+https://github.com/n8n-io/skills.git"]
}
```

OpenCode fetches and installs the plugin, which registers the n8n skills and fires the bash hooks after n8n MCP tool calls. No clone, symlink, or `skills.paths`. Pin a version with `...skills.git#v1.2.0`.

### OpenCode (Desktop app)

The desktop app loads plugins from `~/.config/opencode/plugins/`. Get the repo (clone, or download and unzip [the ZIP](https://github.com/n8n-io/skills/archive/refs/heads/main.zip)), then symlink the plugin file into that folder:

```bash
git clone https://github.com/n8n-io/skills.git ~/.local/share/opencode/n8n-skills
mkdir -p ~/.config/opencode/plugins/
ln -s ~/.local/share/opencode/n8n-skills/opencode/plugin.ts \
      ~/.config/opencode/plugins/n8n-skills-hooks.ts
```

Fully quit and reopen the app. The plugin self-registers its skills, so no `skills.paths` is needed. Update later with `git pull` in the clone (or re-download the ZIP).

See [`opencode/README.md`](./opencode/README.md) for prerequisites and the experimental-API caveat.

### Other platforms

> *Each coding agent has its own skill format. Follow your platform's docs for installing skills*

[skills.sh](https://skills.sh) handles a few popular platforms via `npx`. From your project folder:

```bash
npx skills add n8n-io/skills
```

Compatibility varies by agent. Check skills.sh for support on your specific platform.

#### Then add a snippet to your `AGENTS.md`

```markdown
This project uses n8n. When working with workflows, nodes, expressions, or
the n8n MCP tools, always start by loading the `using-n8n-skills-official` meta-skill
and follow its routing into the matching capability skill before acting.
```

> *The plugins ship a SessionStart hook that loads the entry-point skill for you. Plain skill installs don't have that hook, so the snippet is what cues your agent to start every n8n task by loading `using-n8n-skills-official`.*

## 如何安装/更新/卸载

给 Cursor / Claude Code 的一键安装。从本仓库 `main` 下载 tarball，按技能扁平安装（一技能一文件夹）。再跑同一条命令即更新。

不要用上游 `n8n-io/skills` 的 marketplace 装飞书 / Suno Gateway 技能，那里没有这些 fork 技能。

### macOS / Linux

用户级（Cursor）：

```bash
curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor
```

Claude Code：

```bash
curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool claude
```

装到当前仓库（项目级）：

```bash
curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --project
```

只装飞书技能：

```bash
curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --only feishu
```

只装 Suno Gateway 技能：

```bash
curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --only suno
```

卸载（可与 `--tool` / `--project` / `--only feishu` / `--only suno` 组合）：

```bash
curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --uninstall
```

`--tool both` 同时写 Cursor 和 Claude 路径。`--project /path` 指定仓库目录。

### Windows（PowerShell）

```powershell
irm https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.ps1 -OutFile install.ps1; .\install.ps1 -Tool cursor
```

其它组合：`.\install.ps1 -Tool claude`、`.\install.ps1 -Tool cursor -Project .`、`.\install.ps1 -Tool cursor -Only feishu`、`.\install.ps1 -Tool cursor -Only suno`、`.\install.ps1 -Tool cursor -Uninstall`、`.\install.ps1 -Tool cursor -Only suno -Uninstall`。

### 路径

| 工具 | 用户级 | 项目级 |
|---|---|---|
| Claude Code | `~/.claude/skills/<name>` | `<仓库>/.claude/skills/<name>` |
| Cursor | `~/.cursor/skills/<name>` | `<仓库>/.cursor/skills/<name>` |

## Skills inside

| Skill | When it activates |
|---|---|
| `n8n-workflow-lifecycle-official` | Starting, designing, organizing, or finishing a workflow |
| `n8n-subworkflows-official` | Anything reusable, multi-step builds |
| `n8n-extending-mcp-official` | Need capabilities the MCP doesn't have |
| `n8n-expressions-official` | Writing `{{}}`, `$json`, `$node` |
| `n8n-node-configuration-official` | Configuring any node |
| `n8n-code-nodes-official` | Custom logic, Code node consideration |
| `n8n-loops-official` | Loops, batching, paginated APIs |
| `n8n-agents-official` | LangChain Agent node, tools, system prompts, structured output |
| `n8n-error-handling-official` | Webhook APIs, production workflows |
| `n8n-credentials-and-security-official` | Auth, API keys, tokens |
| `n8n-binary-and-data-official` | Files, images, attachments, vision |
| `n8n-data-tables-official` | Data Tables: schemas, dedup, persistent state |
| `n8n-debugging-official` | Things break |
| `feishu-n8n-setup` | First Feishu / 飞书 app, scopes, version publish, Feishu Suite API Test |
| `feishu-bitable-workflows` | Bitable / 多维表格: webhook, schedule, upsert, batch, field formats |
| `feishu-bitable-trigger` | Bitable record/field change starts a workflow |
| `feishu-bitable-ai-agent` | Feishu Suite / Base as an n8n AI Agent tool |
| `feishu-n8n-troubleshooting` | Feishu node errors: 99991672, 40004, rate limits, timezone |
| `suno-gateway-setup` | Install n8n-nodes-suno-gateway 0.4.0, Suno Gateway API credential, v1→v3 |
| `suno-gateway-workflows` | Generate, persona+cover, async poll, download audio, n8n binary source |
| `suno-gateway-troubleshooting` | ECONNRESET, 节点未安装, 401/403, timeout, 409, 0.4.0 source pitfalls |

A 19th meta-skill, `using-n8n-skills-official`, is loaded by the SessionStart hook in plugins and routes your agent to the right capability skill on every n8n task.

## How it works

Each skill is a markdown file. Frontmatter tells the agent when to load it. The SessionStart hook routes to the right one on every n8n task; PreToolUse hooks pull the matching skill back into context before high-impact MCP calls. It's all just markdown. Disagree with a call? Fork it.

## Related

- [Connect to the n8n MCP server](https://docs.n8n.io/build/ways-of-building-workflows/connect-to-n8n-mcp-server/?utm_source=github&utm_medium=readme&utm_campaign=official-skills-repo)
- [n8n](https://n8n.io?utm_source=github&utm_medium=readme&utm_campaign=official-skills-repo)

## Contributing

See [CLAUDE.md](./CLAUDE.md), the contributing guide for humans and AI agents alike. **Open an issue first.** We don't accept PRs that haven't been discussed in an issue.

**Looking for contributors:** feature parity plugins for other coding agents (Cursor, OpenCode, etc.). The skills are just markdown, the work is wrapping them so they activate in those harnesses the way they do in Claude Code.

## License

Apache 2.0. See [LICENSE](./LICENSE).
