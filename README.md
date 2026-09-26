# claudeme

`claudeme` is an endpoint resolver for Claude Code CLI. It routes requests to a local model server or a named cloud profile — and fails explicitly if neither is available, so you always know where your requests are going. For Anthropic's API, use `claude` directly.

```bash
claudeme          # if one endpoint found: use it; if multiple: pick from a menu
claudeme gcp      # use a named cloud endpoint
claudeme -c       # continue last session on the same endpoint you used last time
```

**Architecture:** `claudeme` is a shell function (in `~/.zshrc`) that calls `claudeme-resolve` (the resolver script) to determine which endpoint to use, then execs `claude` with the appropriate environment variables. The verb form `-resolve` follows Unix convention for commands that perform an action ("resolve this endpoint configuration").

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
./install.sh
```

The installer is **fully idempotent** — run it multiple times safely. It will:
- Install `claudeme-resolve` to `~/.local/bin`
- Auto-install `jq` (via Homebrew) if missing
- Auto-install `litellm[proxy]` (via pip) if missing
- Write the `claudeme` shell function to `~/.zshrc`
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

Run `./install.sh` again at any time — it's fully idempotent:
- Detects what's already installed
- Only installs or updates missing/outdated components
- Safe to run multiple times
- No sudo required (installs to `~/.local/bin`)

---

## Usage

### Local model (auto-detected)

Start any local model server, then just run:

```bash
claudeme
claudeme -c       # continue last session
```

Supported backends: **llama.cpp** (`:8080`), **LiteLLM proxy** (`:4000`), **Ollama** (`:11434`), **Edge Gallery** (`:1234`).

Ollama and Edge Gallery need a LiteLLM proxy running on `:4000` to translate to Anthropic format:
```bash
litellm --model ollama/llama3.2 --port 4000
```

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

`claudeme -c` continues the last session **and** reuses the last endpoint automatically — no need to name it again:

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

| Command | What it does |
|---|---|
| `claudeme` | Fresh session; auto-select if one endpoint, menu if multiple |
| `claudeme -c` | Continue last session on last used endpoint (prints which) |
| `claudeme gcp` | Fresh session, gcp profile, profile's default model |
| `claudeme gcp -c` | Continue last session, gcp profile |
| `claudeme gcp:g25pro` | Fresh session, gcp profile, alias resolved to full model name |
| `claudeme gcp:g25pro -c` | Continue last session, gcp profile, specific model |
| `claudeme local` | Fresh session, force local auto-detect |
| `claudeme local -c` | Continue last session, force local |
| `claudeme --isolated` | Fresh isolated session, auto-detect local |
| `claudeme --isolated -c` | Continue isolated session, last used endpoint |
| `claudeme --isolated gcp` | Fresh isolated session, gcp profile |
| `claudeme --isolated gcp -c` | Continue isolated session, gcp profile |
| `claudeme add <name> <url>` | Add a named profile |
| `claudeme remove <name>` | Remove a profile |
| `claudeme list` | List all endpoints: live local backends + named profiles |
| `claudeme test <name>` | Test a profile end-to-end |
| `claudeme <name> list` | List models on that profile's endpoint, with aliases |
| `claudeme models <name> add <alias> <model>` | Register a model alias |
| `claudeme models <name> remove <alias>` | Remove a model alias |
| `claudeme models <name> default <alias>` | Set the default model for a profile |
