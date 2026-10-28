# Distill MCP Server

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![MCP](https://img.shields.io/badge/protocol-MCP-purple.svg)](https://modelcontextprotocol.io)
[![juergenkoller-software/distill-mcp MCP server](https://glama.ai/mcp/servers/juergenkoller-software/distill-mcp/badges/score.svg)](https://glama.ai/mcp/servers/juergenkoller-software/distill-mcp)

**Let Claude, Cursor, or any MCP client rename files for you — automatically, based on content.**

This is the official [Model Context Protocol](https://modelcontextprotocol.io) bridge for [**Distill**](https://store.juergenkoller.software/en/apps/distill?mtm_source=mcp&mtm_medium=agent&mtm_campaign=distill-mcp&mtm_content=github-readme) — a native macOS app that uses AI (Distill Cloud, or your own Claude, OpenAI or Gemini access, or a local Ollama model) to read your files and rename them with descriptive, consistent names. No more `IMG_4521.jpg` or `Scan_003.pdf` — get `250401 Invoice Telekom.pdf` instead.

> **You need the Distill app installed and running.** This MCP server is a stdio→HTTP bridge — the actual file analysis happens in the app. Get Distill at [store.juergenkoller.software/apps/distill](https://store.juergenkoller.software/en/apps/distill?mtm_source=mcp&mtm_medium=agent&mtm_campaign=distill-mcp&mtm_content=github-readme).
>
> The Distill version from the website already contains this bridge as `distill-mcp-server`, together with its offline manual. Build from this repository only if you want to audit or modify the bridge. The Mac App Store version has neither the REST API nor the MCP server.

---

## What you can do

> "Claude, look at the 47 PDFs in ~/Downloads, rename them based on content, but show me the suggestions first."

The MCP server exposes **13 tools**:

| Tool | What it does |
|---|---|
| `rename_files` | Analyze file content with AI and rename with descriptive names |
| `suggest_names` | Suggest new names without renaming (preview mode) |
| `revert_rename` | Undo a previous rename |
| `get_rename_history` | Show the rename history (timestamps, before/after, AI provider used) |
| `watch_folder` | Add a folder to auto-monitoring (new files get renamed in the background) |
| `process_existing_files` | Process the files already lying in a watched folder |
| `queue_status` | Progress of automatic processing: detected, done, open, renamed, failed |
| `app_status` | Current state, AI provider, credits left, watched folders |
| `set_provider` | Switch AI provider — Distill Cloud (default, uses credits), or in the website version your own Claude, OpenAI or Gemini access, or Ollama (local) |
| `get_rules` | Show naming rules (date format, casing, categories, custom templates) |
| `set_rules` | Update naming rules |
| `search_manual` | Search the Distill user manual (works offline, even without the app running) |
| `get_manual_section` | Read one chapter of the manual as Markdown |

Distill reads PDFs, images (via OCR), Office documents, emails, HTML, RTF, and media files. It extracts date, category, description, sender, and amounts — then builds filenames using your configurable rules.

---

## Installation

### Prerequisites

1. **macOS 15 (Sequoia) or later** — Distill's own requirement
2. **Distill app installed and running** — [get it here](https://store.juergenkoller.software/en/apps/distill?mtm_source=mcp&mtm_medium=agent&mtm_campaign=distill-mcp&mtm_content=github-readme) (website version; free, 100 starter credits, then pay-per-use from €1.99 per 100 name suggestions)
3. **Terms of Use and Privacy Policy accepted** once in the Distill window — until then the API answers only status requests
4. **Swift 5.9+** (Xcode 15+) only if building from source

### Use the bridge inside the app (recommended)

```
/Applications/Distill.app/Contents/MacOS/distill-mcp-server
```

It always matches the installed app version and finds the offline manual on its own.

### Build from source

```bash
git clone https://github.com/juergenkoller-software/distill-mcp.git
cd distill-mcp
swift build -c release
# Binary: .build/release/DistillMCP
```

### Pre-built binary

Not needed on a Mac: the website version of Distill ships the bridge (see above). The binary attached to [Releases](https://github.com/juergenkoller-software/distill-mcp/releases) is a static Linux x86_64 build for container-based MCP registries such as Glama; it does not run on macOS.

---

## Configuration

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "distill": {
      "command": "/Applications/Distill.app/Contents/MacOS/distill-mcp-server",
      "env": {
        "DISTILL_API_PORT": "43821",
        "DISTILL_API_TOKEN": "only-if-set-in-distill"
      }
    }
  }
}
```

`DISTILL_API_TOKEN` is needed only if you set a token in **Distill → Settings → API**. Without a token, Distill accepts connections from your own Mac only.

### Claude Code

```bash
claude mcp add distill /Applications/Distill.app/Contents/MacOS/distill-mcp-server \
  --env DISTILL_API_PORT=43821
```

### Cursor / other MCP clients

Same pattern — `DistillMCP` is a stdio MCP server, configured via the two env vars above.

---

## How it works

```
┌────────────────┐  JSON-RPC stdio   ┌────────────────┐  HTTP+Bearer   ┌────────────────┐
│  Claude/Cursor │ ───────────────►  │  DistillMCP    │ ─────────────► │  Distill.app   │
│  (MCP client)  │ ◄───────────────  │   (this repo)  │ ◄───────────── │  (port 43821)  │
└────────────────┘                   └────────────────┘                └────────────────┘
```

The bridge reads JSON-RPC 2.0 requests from `stdin`, translates each tool call into a request to Distill's local REST API (`http://localhost:43821/v1/…`), and writes responses back to `stdout`. All AI calls (Distill Cloud, Claude, OpenAI, Gemini, Ollama), file reading (OCR, PDF extraction, Office parsing), credit tracking, and naming logic happen inside the Distill app.

This split lets the wire format stay open-source (audit it, sandbox it, run it through any MCP runtime) while the heavy lifting stays in the app.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `DISTILL_API_PORT` | `43821` | Port of Distill's local HTTP server (Distill → Settings → API) |
| `DISTILL_API_TOKEN` | _(none)_ | Bearer token — only if set in Distill → Settings → API |
| `DISTILL_MANUAL_JSON` | _(next to the binary)_ | Path to `distill-manual.json` for a bridge built from source: `/Applications/Distill.app/Contents/Resources/distill-manual.json` |

Errors and trace logs go to `stderr` so they don't pollute the JSON-RPC stdout channel.

---

## Errors

Every refusal comes back as an MCP error (`isError: true`) with a sentence the agent can act on:

| Situation | What the bridge reports |
|---|---|
| Distill not running, API off, or Mac App Store version | Distill is not reachable at `http://localhost:<port>`; open Distill and check Settings → API |
| Token wrong or missing (HTTP 401) | Set `DISTILL_API_TOKEN` to the token in Distill → Settings → API |
| Legal texts not accepted (HTTP 403 `legal_not_accepted`) | The user opens the Distill window and accepts in the “Legal Notice” sheet; an agent cannot do this |
| Any other HTTP error | Status code and Distill's error text, e.g. `engine not ready` while the app starts |

Before version 1.1.0 the bridge ignored the HTTP status, so these refusals looked like successful calls.

---

## About Distill

Distill is an AI file manager for macOS that automatically renames files based on content analysis. Highlights:

- **No subscription** — free app, pay-per-use credits (100 free / 100 for €1.99 / 400 for €4.99 / 1,000 for €8.99)
- **Distill Cloud by default** — credits, no sign-up; in the website version also your own Claude, OpenAI or Google Gemini access (no credits used) or Ollama (local, no API key)
- **Reads everything** — PDFs, images (OCR), Office docs, emails, HTML, RTF, media files
- **Local-only mode** with Ollama — nothing leaves your Mac
- **Configurable NameBuilder** — date formats, casing, categories, custom templates
- **Folder monitoring** — drop files in, get them renamed automatically
- **REST API + Swagger UI** — for non-MCP automation
- **MCP server** (this repo) — for Claude/AI agents, in the website version
- **24 languages**
- **Available on the Mac App Store and as a direct download** — the REST API and MCP server ship with the direct download

→ **[Get Distill at store.juergenkoller.software](https://store.juergenkoller.software/en/apps/distill?mtm_source=mcp&mtm_medium=agent&mtm_campaign=distill-mcp&mtm_content=github-readme)**

---

## License

MIT — see [LICENSE](LICENSE). Bridge is open source; the Distill app is commercial (free-to-try with pay-per-use credits).

## Issues & support

- **Bridge bugs:** [open an issue](https://github.com/juergenkoller-software/distill-mcp/issues)
- **App support:** [support@juergenkoller.software](mailto:support@juergenkoller.software)

Built by [Juergen Koller Software GmbH](https://juergenkoller.software).
