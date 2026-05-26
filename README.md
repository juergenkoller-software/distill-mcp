# Distill MCP Server

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![MCP](https://img.shields.io/badge/protocol-MCP-purple.svg)](https://modelcontextprotocol.io)
[![juergenkoller-software/distill-mcp MCP server](https://glama.ai/mcp/servers/juergenkoller-software/distill-mcp/badges/score.svg)](https://glama.ai/mcp/servers/juergenkoller-software/distill-mcp)

**Let Claude, Cursor, or any MCP client rename files for you — automatically, based on content.**

This is the official [Model Context Protocol](https://modelcontextprotocol.io) bridge for [**Distill**](https://store.juergenkoller.software/en/apps/distill) — a native macOS app that uses AI (Claude, OpenAI, Gemini, Ollama, or Apple Intelligence) to read your files and rename them with descriptive, consistent names. No more `IMG_4521.jpg` or `Scan_003.pdf` — get `250401 Invoice Telekom.pdf` instead.

> **You need the Distill app installed and running.** This MCP server is a stdio→HTTP bridge — the actual file analysis happens in the app. Get Distill at [store.juergenkoller.software/apps/distill](https://store.juergenkoller.software/en/apps/distill).

---

## What you can do

> "Claude, look at the 47 PDFs in ~/Downloads, rename them based on content, but show me the suggestions first."

The MCP server exposes **9 tools**:

| Tool | What it does |
|---|---|
| `rename_files` | Analyze file content with AI and rename with descriptive names |
| `suggest_names` | Suggest new names without renaming (preview mode) |
| `revert_rename` | Undo a previous rename |
| `get_rename_history` | Show the rename history (timestamps, before/after, AI provider used) |
| `watch_folder` | Add a folder to auto-monitoring (new files get renamed in the background) |
| `app_status` | Current state, AI provider, credits left, watched folders |
| `set_provider` | Switch AI provider — Claude, OpenAI GPT-4o, Gemini, Ollama (local), Apple Intelligence |
| `get_rules` | Show naming rules (date format, casing, categories, custom templates) |
| `set_rules` | Update naming rules |

Distill reads PDFs, images (via OCR), Office documents, emails, HTML, RTF, and media files. It extracts date, category, description, sender, and amounts — then builds filenames using your configurable rules.

---

## Installation

### Prerequisites

1. **macOS 14 (Sonoma) or later**
2. **Distill app installed and running** — [get it here](https://store.juergenkoller.software/en/apps/distill) (free, pay-per-use credits start at €1.99 / 100 renames)
3. **Swift 5.9+** (Xcode 15+) if building from source

### Build from source

```bash
git clone https://github.com/juergenkoller-software/distill-mcp.git
cd distill-mcp
swift build -c release
# Binary: .build/release/DistillMCP
```

### Pre-built binary

Grab the latest `DistillMCP` from [Releases](https://github.com/juergenkoller-software/distill-mcp/releases).

---

## Configuration

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "distill": {
      "command": "/path/to/DistillMCP",
      "env": {
        "DISTILL_PORT": "22200",
        "DISTILL_TOKEN": "your-token-here"
      }
    }
  }
}
```

Find `DISTILL_TOKEN` in **Distill → Settings → API & MCP**.

### Claude Code

```bash
claude mcp add distill /path/to/DistillMCP \
  --env DISTILL_PORT=22200 \
  --env DISTILL_TOKEN=your-token-here
```

### Cursor / other MCP clients

Same pattern — `DistillMCP` is a stdio MCP server, configured via the two env vars above.

---

## How it works

```
┌────────────────┐  JSON-RPC stdio   ┌────────────────┐  HTTP+Bearer   ┌────────────────┐
│  Claude/Cursor │ ───────────────►  │  DistillMCP    │ ─────────────► │  Distill.app   │
│  (MCP client)  │ ◄───────────────  │   (this repo)  │ ◄───────────── │  (port 22200)  │
└────────────────┘                   └────────────────┘                └────────────────┘
```

The bridge reads JSON-RPC 2.0 requests from `stdin`, forwards them to Distill's local HTTP server at `127.0.0.1:22200/mcp`, and writes responses back to `stdout`. All AI calls (Claude/OpenAI/Gemini/Ollama/Apple Intelligence), file reading (OCR, PDF extraction, Office parsing), credit tracking, and naming logic happen inside the Distill app.

This split lets the wire format stay open-source (audit it, sandbox it, run it through any MCP runtime) while the heavy lifting stays in the app.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `DISTILL_PORT` | `22200` | Port of Distill's local HTTP server |
| `DISTILL_TOKEN` | _(none)_ | Bearer token from Distill Settings (required) |

Errors and trace logs go to `stderr` so they don't pollute the JSON-RPC stdout channel.

---

## About Distill

Distill is an AI file manager for macOS that automatically renames files based on content analysis. Highlights:

- **No subscription** — free app, pay-per-use credits (100 free / 100 for €1.99 / 400 for €4.99 / 1,000 for €8.99)
- **Five AI providers** — Claude, OpenAI GPT-4o, Google Gemini, Ollama (local, no API needed), Apple Intelligence
- **Reads everything** — PDFs, images (OCR), Office docs, emails, HTML, RTF, media files
- **Local-only mode** with Ollama — nothing leaves your Mac
- **Configurable NameBuilder** — date formats, casing, categories, custom templates
- **Folder monitoring** — drop files in, get them renamed automatically
- **REST API + Swagger UI** — for non-MCP automation
- **MCP server** (this repo) — for Claude/AI agents
- **Available on Mac App Store + direct download**

→ **[Get Distill at store.juergenkoller.software](https://store.juergenkoller.software/en/apps/distill)**

---

## License

MIT — see [LICENSE](LICENSE). Bridge is open source; the Distill app is commercial (free-to-try with pay-per-use credits).

## Issues & support

- **Bridge bugs:** [open an issue](https://github.com/juergenkoller-software/distill-mcp/issues)
- **App support:** [support@juergenkoller.software](mailto:support@juergenkoller.software)

Built by [Juergen Koller Software GmbH](https://juergenkoller.software).
