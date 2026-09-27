# claudeme

`claudeme` is an endpoint resolver for Claude Code CLI. It routes requests to a local model server or a named cloud profile — and fails explicitly if neither is available, so you always know where your requests are going. For Anthropic's API, use `claude` directly.

```bash
claudeme          # if one endpoint found: use it; if multiple: pick from a menu
claudeme gcp      # use a named cloud endpoint
claudeme -c       # continue last session on the same endpoint you used last time
```

**Architecture:** `claudeme` is a shell function (in `~/.zshrc`) that calls `claudeme-resolve` (the resolver script) to determine which endpoint to use, then execs `claude` with the appropriate environment variables. The verb form `-resolve` follows Unix convention for commands that perform an action ("resolve this endpoint configuration").

**Typo-tolerant:** The installer also creates an alias `claudme` → `claudeme` for common typos.

---

## Quick Start (No Installation)

For one-time testing or quick usage without installation:

```bash
# Download and run
curl -O https://raw.githubusercontent.com/ghosharindam/claudeme/main/claudeme-quick
chmod +x claudeme-quick
./claudeme-quick --auto-start
```

Done! See [QUICK-START.md](QUICK-START.md) for details.

**When to use:**
- 🧪 Testing local models
- 🚀 CI/CD environments  
- ⚡ Quick one-off usage

**For daily use, install the full system below** ↓

---

## Install

### Prerequisites

| Tool | Required for | Install |
|---|---|---|
| `jq` | Everything | Auto-installed by installer (via Homebrew) |
| `claude` CLI | Running sessions | [Claude Code docs](https://docs.anthropic.com/claude-code) |
| `litellm` | Ollama/Edge Gallery bridge | Auto-installed by installer (via pip) |
| `gcloud` CLI | GCP profiles (`--auth gcp-adc`) | `brew install --cask google-cloud-sdk` |
| `aws` CLI | AWS profiles (`--auth aws`) | `brew install awscli` |

### Steps

**1. Run the installer:**

```bash
cd ~/Documents/my_workspace/claudeme
./install.sh                              # Default: installs to ~/.local/bin (no sudo)
```

**Custom install location:**
```bash
./install.sh --prefix /usr/local/bin      # System-wide (needs sudo)
INSTALL_DIR=/opt/bin ./install.sh         # Via environment variable
```

The installer is **fully idempotent** — run it multiple times safely. It will:
- Install `claudeme-resolve` to chosen directory (default: `~/.local/bin`)
- Auto-detect your shell (bash/zsh/fish) and update the appropriate config file
- Auto-install `jq` (via Homebrew) if missing
- Auto-install `litellm[proxy]` (via pip) if missing
- Only update what's missing or outdated

**2. Activate in your current shell:**

```bash
source ~/.zshrc
```

**3. Verify:**

```bash
claudeme list
```

You should see a list of local backends (currently running) and named profiles (initially empty).

**4. Add your first profile** (skip if you only use local models):

```bash
claudeme add <name> <url> --auth <type>

# Examples:
claudeme add gcp    https://my-litellm.run.app  --auth gcp-adc   # GCP via Application Default Credentials
claudeme add kimi   https://api.moonshot.cn/v1  --auth api-key --key-env KIMI_API_KEY
claudeme add gpu    http://192.168.1.50:4000                      # LAN server, no auth needed
```

### Optional: alias `claude` to `claudeme`

So existing muscle memory (`claude`, `claude -c`) routes through claudeme instead of going straight to Anthropic:

```bash
echo 'alias claude=claudeme' >> ~/.zshrc
source ~/.zshrc
```

Escape hatch to reach Anthropic directly even with the alias set:

```bash
command claude        # bypasses the alias
command claude -c
```

### Re-installing / updating

**To get updates:**
```bash
git pull               # Get latest changes
./install.sh          # Update installed scripts
```

The installer is **fully idempotent** — run it multiple times safely:
- ✅ Detects what's already installed
- ✅ Only updates files that changed (smart diff check)
- ✅ Skips unchanged files
- ✅ Safe to run 100 times
- ✅ No sudo required

**Example output:**
```
✅ claudeme-resolve already up to date
✅ Updated cleanup-advisor
```

**Can I delete the repo after install?**  
Yes! All scripts are **copied** to `~/.local/bin/claudeme/`, so they work even after deleting the source repo. To get updates later, just re-download the repo and re-run `./install.sh`.

---

### Uninstalling

```bash
./utils/uninstall.sh              # Interactive (asks about config)
./utils/uninstall.sh --all        # Remove everything including config
./utils/uninstall.sh --keep-config # Keep profiles and session history
```

**What gets removed:**
- `~/.local/bin/claudeme/` — Installed binaries
- `~/.zshrc` — Shell function
- `~/.claudeme/` — Config (optional)

To reinstall: `./install.sh`

---

## Utilities

Installed automatically by `./install.sh`:

### cleanup-advisor - System Resource Cleanup

Find processes hogging RAM/CPU before resource-intensive tasks.

```bash
cleanup-advisor           # Show all recommendations
cleanup-advisor --ram     # RAM hogs only
cleanup-advisor --cpu     # CPU hogs only
```

**Catches multi-process apps** like VSCode (5GB across 10 helpers) and Chrome!

See [`utils/cleanup-advisor/README.md`](utils/cleanup-advisor/README.md)

### benchmark-run - Performance Benchmarking

Benchmark claudeme with fair comparisons and bias detection.

```bash
benchmark-run             # Run all benchmarks
benchmark-run baseline    # Baseline only
benchmark-run cleanup     # Free up resources first
```

**Detects bias** (memory pressure, running servers) and provides cleanup suggestions.

See [`utils/benchmark/README.md`](utils/benchmark/README.md)

---

## Usage

### Local model (auto-detected)

Start any local model server, then just run:

```bash
claudeme
claudeme -c       # continue last session (smart resume!)
```

Supported backends: **llama.cpp** (`:8080`), **LiteLLM proxy** (`:4000`), **Ollama** (`:11434`), **Edge Gallery** (`:1234`).

#### Automatic LiteLLM startup

If Ollama is running but LiteLLM proxy isn't, `claudeme` will offer to start it automatically:

```
$ claudeme

→ Ollama detected on :11434
  Available models: qwen2.5-coder:7b (4.3GB)

→ LiteLLM proxy not running on :4000
  Start LiteLLM with qwen2.5-coder:7b? [Y/n/never]: y

→ Starting LiteLLM proxy...
✅ LiteLLM proxy started on :4000
```

**How it works:**
- ✅ Detects Ollama running without LiteLLM
- ✅ Recommends best coding model for your available RAM
- ✅ Checks memory before starting (prevents OOM)
- ✅ Remembers your choice (won't ask again if you said "never")
- ✅ Starts LiteLLM in background
- ✅ Waits for port to be ready before connecting

**Manual start** (if you prefer):
```bash
# Start with default model
litellm --model ollama/qwen2.5-coder:7b --port 4000

# Or use any model you have loaded
litellm --model ollama/deepseek-coder:6.7b --port 4000
```

#### Auto-configures Claude Code settings

When you run `claudeme` for the first time in a project, it automatically detects available local models and creates `.claude/settings.json` so **both `claude` and `claudeme` use the local model**:

**Single model (auto-select):**
```
$ claudeme

→ Detecting local models...
✓ Local model detected
  Model: ollama/qwen2.5-coder:7b

✓ Created: .claude/settings.json
  Model: ollama/qwen2.5-coder:7b

✓ Both `claude` and `claudeme` will use this model in this project
```

**Multiple models (choose):**
```
✓ Multiple local models available

  1) ollama/qwen2.5-coder:7b (4.3GB)
  2) deepseek-coder:6.7b (4.5GB)

Choose model [1-2]: 1
✓ Saved to .claude/settings.json
```

Now both commands work seamlessly:
- `claudeme` → Uses local model ✅
- `claude` → Uses local model ✅ (not Anthropic!)

#### Smart session resume

`claudeme -c` now does **instant resume** if your model is still loaded in memory:

```
$ claudeme -c

→ Resuming previous session
  Tool: ollama
  Model: qwen2.5-coder:7b

✓ ollama running
✓ Model already loaded in memory
→ Resuming instantly (no overhead)

(Claude Code connects immediately)
```

If the model was unloaded, it automatically reloads it:

```
→ Resuming previous session
  Tool: ollama
  Model: qwen2.5-coder:7b

✓ ollama running
⚠️  Model not loaded anymore

→ Loading qwen2.5-coder:7b into memory...
✅ Ready
```

**Benefits:**
- 🚀 Instant return to your project (no waiting if model still loaded)
- 🧠 Smart model selection based on available RAM
- 💾 Remembers which model you were using per directory
- 🔄 Automatic reload if model was unloaded
- 🛡️ Memory checks before loading (prevents OOM)

### Endpoint selection menu

When you run `claudeme` with no arguments and more than one option is available (local backends + named profiles), it shows a numbered menu and waits for your choice:

```
$ claudeme

  Select endpoint:
    1) local   llama.cpp at http://localhost:8080
    2) gcp     https://my-litellm.run.app
    3) office  http://192.168.1.50:4000

  Choice:
```

If only one endpoint is available it is selected automatically — no prompt.

### Continuing a previous session

`claudeme -c` continues the last session and reuses the last endpoint — no need to name it again.

**For local sessions** (Ollama/llama-server):
- Detects if your previous model is still loaded in memory
- **Resumes instantly** if loaded (0 overhead)
- **Auto-reloads** if needed (with memory checks)

**For cloud profiles** (GCP, AWS, etc.):
```
$ claudeme -c
→ Continuing on gcp (https://my-litellm.run.app)
```

You only need to name a profile once (`claudeme gcp`); after that, `claudeme -c` picks it up.

### Cloud endpoint

Add a named profile once:

```bash
claudeme add gcp https://my-litellm.run.app --auth gcp-adc --desc "LiteLLM on Cloud Run"
```

Then use it by name:

```bash
claudeme gcp
claudeme gcp -c
```

#### Selecting a model

Pass a model after the profile name with a colon:

```bash
claudeme gcp:gemini-2.5-pro
claudeme gcp:claude-opus-5 -c
```

You can also register short aliases for long model names (once, in the profile):

```bash
claudeme models gcp add g25pro gemini-2.5-pro
claudeme models gcp add opus  claude-opus-5
```

Then:

```bash
claudeme gcp:g25pro           # resolves to gemini-2.5-pro
claudeme gcp:opus -c
```

Set a default model for a profile so bare `claudeme gcp` uses it:

```bash
claudeme models gcp default g25pro
```

List all models available on a profile's endpoint, with your aliases shown:

```bash
claudeme gcp list
```

```
Models on gcp (https://my-litellm.run.app):

  ALIAS    MODEL NAME
  g25pro → gemini-2.5-pro          ← default
  opus   → claude-opus-5

  Also available (no alias):
           claude-sonnet-5
           mistral-large
```

### Isolated sessions

Run with `--isolated` to keep the session separate from your shared session store:

```bash
claudeme --isolated gcp
claudeme --isolated gcp -c    # continue the isolated session
```

---

## Profile Management

```bash
claudeme add <name> <url> [--auth <type>] [--desc <text>]
claudeme remove <name>
claudeme list
claudeme test <name>
claudeme <name> list
```

Auth types: `none` (default), `api-key`, `gcp-adc`, `aws`.

```bash
claudeme add <name> <url> [--auth <type>] [--key-env <VAR>] [--desc <text>]

# GCP via Application Default Credentials
claudeme add gcp    https://my-litellm.run.app  --auth gcp-adc

# API key read from an env var
claudeme add kimi   https://api.moonshot.cn/v1  --auth api-key --key-env KIMI_API_KEY

# LAN model server — no auth needed on a trusted network
claudeme add gpu    http://192.168.1.50:4000

# Verify a profile works end-to-end
claudeme test gcp

# See all endpoints (local backends + named profiles)
claudeme list

# See all models on a specific profile's endpoint
claudeme gcp list
```

### Model aliases

```bash
claudeme models <name> add <alias> <full-model-name>   # add alias
claudeme models <name> remove <alias>                  # remove alias
claudeme models <name> default <alias>                 # set default model
claudeme models <name> list                            # same as claudeme <name> list
```

---

## Configuration

All settings are stored in `~/.claudeme/` with sensible defaults — **zero configuration needed** to get started.

### Auto-start preferences

Control when and how LiteLLM auto-starts:

```bash
# View/edit preferences
cat ~/.claudeme/preferences.yaml

# Key settings:
auto_start:
  enabled: true                      # Enable auto-start
  remember_choice: true              # Remember yes/no decision
  last_decision: null                # "yes", "no", or "never"

preferred_models:
  - qwen2.5-coder:7b                # First choice (balanced quality/speed)
  - deepseek-coder-v2:6.7b          # Second choice (good alternative)
  - qwen2.5-coder:3b                # Fallback (low memory)

litellm:
  port: 4000                         # Port to run LiteLLM on
  host: "0.0.0.0"                    # Listen address
  keep_running: true                 # Keep proxy running after exit
```

### Model catalog

Available coding models and their memory requirements:

```bash
cat ~/.claudeme/model-catalog.yaml
```

Contains:
- **Model versions** with RAM requirements
- **Quality/speed scores** for each version
- **Memory thresholds** (high/medium/low/very_low)
- **Safety margins** (min free RAM, max usage %)

**How it's used:**
- Auto-start recommends the best model for your available RAM
- Won't start a model if insufficient memory
- Falls back to smaller models on low-memory systems

### Session history

Tracks which tool and model you were using per directory:

```bash
cat ~/.claudeme/sessions.json

# Output:
{
  "/path/to/project": {
    "tool": "ollama",
    "model": "qwen2.5-coder:7b",
    "endpoint": "http://localhost:4000",
    "model_was_loaded": true,
    "last_used": "2026-09-27T11:30:00Z"
  }
}
```

This enables instant resume when you return to a project.

---

## Shared with `claude`

`claudeme` is a wrapper around `claude` — it sets the endpoint and execs the real Claude Code binary. This means everything is shared:

- **Session history** — `claudeme -c` and `claude -c` continue the same conversation
- **Skills, MCP servers, tools** — all your Claude Code configuration applies unchanged
- **Project context, CLAUDE.md, settings** — read identically
- **Permissions** — same trust model as plain `claude`

The only thing `claudeme` changes is where the request goes. Use `--isolated` if you want a session that stays separate from your shared `claude` history.

---

## Per-project default

To make a project always use a specific endpoint, add to `.claude/settings.local.json` (gitignored):

```json
{
  "env": {
    "CLAUDEME_PROFILE": "gcp"
  }
}
```

Then `claudeme` and `claudeme -c` in that project automatically use the `gcp` profile.

---

## All commands

### Main commands

| Command | What it does |
|---|---|
| `claudeme` | Fresh session; auto-select if one endpoint, menu if multiple; auto-starts LiteLLM if needed |
| `claudeme -c` | Continue last session on last used endpoint; **smart resume** (instant if model loaded) |
| `claudeme gcp` | Fresh session, gcp profile, profile's default model |
| `claudeme gcp -c` | Continue last session, gcp profile |
| `claudeme gcp:g25pro` | Fresh session, gcp profile, alias resolved to full model name |
| `claudeme gcp:g25pro -c` | Continue last session, gcp profile, specific model |
| `claudeme local` | Fresh session, force local auto-detect |
| `claudeme local -c` | Continue last session, force local |

### Isolated sessions

| Command | What it does |
|---|---|
| `claudeme --isolated` | Fresh isolated session, auto-detect local |
| `claudeme --isolated -c` | Continue isolated session, last used endpoint |
| `claudeme --isolated gcp` | Fresh isolated session, gcp profile |
| `claudeme --isolated gcp -c` | Continue isolated session, gcp profile |

### Profile management

| Command | What it does |
|---|---|
| `claudeme add <name> <url>` | Add a named profile |
| `claudeme remove <name>` | Remove a profile |
| `claudeme list` | List all endpoints: live local backends + named profiles |
| `claudeme test <name>` | Test a profile end-to-end |

### Model aliases

| Command | What it does |
|---|---|
| `claudeme <name> list` | List models on that profile's endpoint, with aliases |
| `claudeme models <name> add <alias> <model>` | Register a model alias |
| `claudeme models <name> remove <alias>` | Remove a model alias |
| `claudeme models <name> default <alias>` | Set the default model for a profile |
