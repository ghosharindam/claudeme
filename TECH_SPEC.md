# claudeme — Technical Specification

## Architecture

`claudeme` is a shell function in `~/.zshrc` backed by a standalone resolver script (`claudeme-resolve`) that handles endpoint resolution, session metadata, and auth. The shell function is a thin caller — it captures the resolver's output and execs `claude`.

```
~/.zshrc
  └── claudeme()
        ├── parse args (--isolated, profile name, -c, claude args)
        ├── claudeme-resolve        ← returns KEY=VALUE env block
        │     ├── endpoint resolution (profile / auto-detect)
        │     ├── auth resolution (none / api-key / gcp-adc / aws)
        │     ├── session metadata  (read/write ~/.claudeme/sessions.json)
        │     └── isolated dir      (compute path if --isolated)
        └── eval env block → exec claude [--isolated dir] [args]
```

---

## File Layout

```
my_workspace/
  claude_local/
    PRODUCT_SPEC.md
    TECH_SPEC.md
    claudeme-resolve          ← standalone resolver (installed to $PATH)
    install.sh                ← installs resolver, appends shell function

~/.claudeme/
  profiles.json               ← named endpoint configurations
  sessions.json               ← per-directory session metadata
  isolated/                   ← isolated session working directories
    <dir-hash>/               ← one per real project directory

~/.zshrc
  claudeme()                  ← shell function (written by install.sh)
```

---

## Argument Parsing

The shell function separates `claudeme`'s own flags from `claude`'s flags before calling the resolver.

### Colon syntax

If the first positional argument contains `:`, it is split into profile name and model ref:

```
claudeme gcp:g25pro   →  profile="gcp", model_ref="g25pro"
claudeme gcp:gemini-2.5-pro  →  profile="gcp", model_ref="gemini-2.5-pro"
```

`model_ref` is resolved against the profile's `models` alias map. If found, the full model name is used; if not found, `model_ref` is used verbatim as the model name. The resolved name is forwarded to `claude` as `--model <name>`.

### `<name> list` subcommand

If the second positional argument is `list` (and the first is a known profile name), the shell function routes to `claudeme-resolve <name> list` instead of the normal resolution flow. This queries `<profile.url>/v1/models`, merges with the configured `models` alias map, and prints a formatted table.

```bash
claudeme() {
  # Route management subcommands first
  case "$1" in
    add|remove|test|models) exec claudeme-resolve "$@" ;;
    list) exec claudeme-resolve list ;;
  esac

  # Check for <name> list
  if [[ -n "$1" && "$2" == "list" ]]; then
    exec claudeme-resolve profile-models "$1"
  fi

  local isolated=false
  local profile=""
  local model_ref=""
  local continue_flag=false
  local claude_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --isolated) isolated=true; shift ;;
      -c)         continue_flag=true; claude_args+=("$1"); shift ;;
      -*)         claude_args+=("$1"); shift ;;
      *)
        if [[ -z "$profile" ]]; then
          # Split colon syntax
          if [[ "$1" == *:* ]]; then
            profile="${1%%:*}"
            model_ref="${1#*:}"
          else
            profile="$1"
          fi
          shift
        else
          claude_args+=("$1"); shift
        fi
        ;;
    esac
  done

  local resolver_args=()
  [[ "$isolated" == true ]]      && resolver_args+=(--isolated)
  [[ "$continue_flag" == true ]] && resolver_args+=(--continue)
  [[ -n "$profile" ]]            && resolver_args+=(--profile "$profile")
  [[ -n "$model_ref" ]]          && resolver_args+=(--model-ref "$model_ref")

  local env_block
  env_block=$(claudeme-resolve "${resolver_args[@]}" 2>/dev/tty) || return 1

  eval "$env_block"
  # CLAUDEME_MODEL is set by resolver if a model was resolved
  [[ -n "$CLAUDEME_MODEL" ]] && claude_args=(--model "$CLAUDEME_MODEL" "${claude_args[@]}")
  exec claude "${claude_args[@]}"
}
```

`-c` is both captured (to inform session metadata lookup) and forwarded to `claude` (for actual session continuation).

---

## `claudeme-resolve` Output Format

The resolver prints only `KEY=VALUE` lines to stdout, suitable for `eval`. All user-facing output (prompts, warnings, backend list) goes to stderr.

```
ANTHROPIC_BASE_URL=https://my-litellm.run.app
ANTHROPIC_API_KEY=ya29.c.c0ASRK0...
CLAUDEME_SESSION_DIR=/Users/arindamghosh/.claudeme/isolated/a3f9b2c1
```

`CLAUDEME_SESSION_DIR` is only emitted when `--isolated` is passed. The shell function uses it to `cd` before execing `claude`, establishing the isolated working directory.

---

## Management Subcommands

Subcommands are distinguished from profile names by being the first argument and matching a known keyword. The shell function routes them directly to `claudeme-resolve` without forwarding anything to `claude`.

```bash
claudeme() {
  case "$1" in
    add|remove|list|test|models) exec claudeme-resolve "$@" ;;
    *) ... # normal endpoint resolution flow
  esac
}
```

### `claudeme add <name> <url> [options]`

```
Options:
  --auth <type>     none (default) | api-key | gcp-adc | aws
  --desc <text>     Human-readable description
  --key <value>     Literal API key (auth=api-key only, not recommended)
  --key-env <var>   Env var name holding the API key (auth=api-key, preferred)
```

Algorithm:
1. Validate name is not `local` and not already in profiles.json → exit 1 if so
2. Probe URL with `curl --max-time 3` → warn to stderr if unreachable, do not block
3. Auth pre-check:
   - `gcp-adc`: verify `gcloud` installed + `gcloud auth print-access-token --quiet` returns non-empty
   - `api-key`: verify `--key` or `--key-env` provided; if `--key-env`, verify `$VAR` is non-empty
4. Read `~/.claudeme/profiles.json` (create if missing)
5. Insert new entry, write back atomically (write to `.tmp`, then `mv`)
6. Print confirmation to stdout

### `claudeme remove <name>`

1. Load `~/.claudeme/profiles.json` → exit 1 if name not found
2. Check `~/.claudeme/sessions.json` for any directory where `last_profile == name`
   - If found: print warning listing affected directories, ask `y/n` to confirm
3. Remove entry, write back atomically
4. Print confirmation

### `claudeme list`

Runs in parallel:
- Load `~/.claudeme/profiles.json`
- Probe all local backends (same as auto-detection step, 2s timeout)

Prints two sections to stdout: live local backends table, named profiles table.

### `claudeme test <name>`

1. Load profile from `~/.claudeme/profiles.json` → exit 1 if not found
2. Resolve auth (same as resolution algorithm step 2)
3. Probe `<url>/v1/models` with resolved token as bearer (3s timeout)
4. Print step-by-step result to stdout

### `claudeme <name> list` (alias: `claudeme models <name> list`)

1. Load profile → exit 1 if not found
2. Resolve auth
3. GET `<url>/v1/models` with resolved token (3s timeout) → exit 1 on failure
4. Load `profile.models` alias map
5. Print table: aliases with their full names first (marking the default), then remaining live models with no alias

```
Models on gcp (https://my-litellm.run.app):

  ALIAS    MODEL
  g25pro → gemini-2.5-pro          ← default
  opus   → claude-opus-5

  Also available (no alias):
           claude-sonnet-5
           mistral-large-latest
```

### `claudeme models <name> add <alias> <model>`

1. Load profile → exit 1 if not found
2. Validate alias does not already exist in `profile.models` → exit 1 if so
3. Insert `alias → model` into `profile.models`, write back atomically
4. Print confirmation

### `claudeme models <name> remove <alias>`

1. Load profile → exit 1 if alias not found
2. If alias is the current `profile.model` default, clear `profile.model` and warn
3. Remove alias, write back atomically

### `claudeme models <name> default <alias>`

1. Load profile → exit 1 if alias not found in `profile.models`
2. Set `profile.model` to the full model name the alias resolves to
3. Write back atomically
4. Print: `Default model for <name> set to <full-model-name> (via alias <alias>)`

---

## Endpoint Resolution Algorithm

```
claudeme-resolve [--isolated] [--continue] [--profile <name>]

─── STEP 1: Determine profile ──────────────────────────────────────

1a. If --profile local:
      profile = LOCAL (force local auto-detection, skip to step 3)

1b. If --profile <name> given:
      load ~/.claudeme/profiles.json
      if name not found → list available profiles to stderr, exit 1
      profile = <name>
      skip to step 2 (auth resolution)

1c. If --continue and session metadata exists for this directory:
      load ~/.claudeme/sessions.json
      profile = last_profile for pwd (may be null = local)
      skip to step 2 or 3 accordingly

1d. If CLAUDEME_PROFILE env var set (from settings.local.json):
      profile = CLAUDEME_PROFILE value
      skip to step 2

1e. If CLAUDE_LOCAL_URL env var set:
      print: ANTHROPIC_BASE_URL=$CLAUDE_LOCAL_URL
      print: ANTHROPIC_API_KEY=local
      update session metadata: last_profile = null (local)
      exit 0

1f. Otherwise:
      profile = LOCAL (auto-detect)

─── STEP 2: Auth resolution (named profile) ────────────────────────

2a. auth = none:
      print: ANTHROPIC_BASE_URL=<profile.url>
      print: ANTHROPIC_API_KEY=local

2b. auth = api-key:
      key = profile.key OR $profile.key_env
      if key empty → exit 1 with message
      print: ANTHROPIC_BASE_URL=<profile.url>
      print: ANTHROPIC_API_KEY=<key>

2c. auth = gcp-adc:
      check gcloud installed → exit 1 if not
      token=$(gcloud auth print-access-token --quiet 2>/dev/null)
      if token empty → print auth instructions, exit 1
      print: ANTHROPIC_BASE_URL=<profile.url>
      print: ANTHROPIC_API_KEY=<token>

2d. auth = aws:
      token=$AWS_SESSION_TOKEN
      if token empty → print auth instructions, exit 1
      print: ANTHROPIC_BASE_URL=<profile.url>
      print: ANTHROPIC_API_KEY=<token>

    → update session metadata, go to step 4

─── STEP 3: Local auto-detection ───────────────────────────────────

3a. Probe in parallel (2s timeout each):
      curl -sf --max-time 2 http://localhost:8080/health    → LLAMA_UP
      curl -sf --max-time 2 http://localhost:4000/v1/models → LITELLM_UP
      curl -sf --max-time 2 http://localhost:11434/api/tags  → OLLAMA_UP
      curl -sf --max-time 2 http://localhost:1234/v1/models  → EDGE_UP

3b. Build FOUND array from results

3c. Append named profiles from ~/.claudeme/profiles.json as additional options

3d. If FOUND empty and no profiles:
      print setup instructions to stderr, exit 1

3e. If one option: auto-select
    If multiple: numbered prompt to stderr, wait for input

3f. If selected is Ollama or Edge Gallery:
      if NOT LITELLM_UP:
        print warning + litellm start command to stderr, exit 1
      url = http://localhost:4000
    else:
      url = detected port URL

    print: ANTHROPIC_BASE_URL=<url>
    print: ANTHROPIC_API_KEY=local

─── STEP 3.5: Model resolution (named profile only) ────────────────

3.5a. If --model-ref provided:
        look up model_ref in profile.models alias map
        if found → resolved_model = alias value
        if not found → resolved_model = model_ref (used verbatim)
      Else if profile.model set:
        resolved_model = profile.model
      Else:
        resolved_model = "" (let the endpoint use its own default)

3.5b. If resolved_model non-empty:
        print: CLAUDEME_MODEL=<resolved_model>
      (shell function prepends --model <value> to claude_args)

─── STEP 4: Isolated directory ─────────────────────────────────────

4a. If --isolated:
      hash = sha256(pwd) | head -c 8
      dir = ~/.claudeme/isolated/<hash>
      mkdir -p "$dir"
      print: CLAUDEME_SESSION_DIR=<dir>

─── STEP 5: Update session metadata ────────────────────────────────

5a. Write to ~/.claudeme/sessions.json:
      key   = pwd (or isolated dir if --isolated)
      value = { last_profile, last_url, last_used (ISO8601) }

exit 0
```

---

## Session Metadata

`~/.claudeme/sessions.json` records the last endpoint used per directory.

```json
{
  "/Users/arindamghosh/my-gcp-project": {
    "last_profile": "gcp",
    "last_url": "https://my-litellm.run.app",
    "last_used": "2026-09-16T11:00:00Z"
  },
  "/Users/arindamghosh/my-local-project": {
    "last_profile": null,
    "last_url": "http://localhost:8080",
    "last_used": "2026-09-16T10:00:00Z"
  },
  "/Users/arindamghosh/.claudeme/isolated/a3f9b2c1": {
    "last_profile": "gcp",
    "last_url": "https://my-litellm.run.app",
    "last_used": "2026-09-16T09:00:00Z"
  }
}
```

`last_profile: null` means the last session used local auto-detection.

Isolated sessions are keyed by their isolated directory path, not the real project path — so shared and isolated histories for the same project directory are independent.

---

## Isolated Sessions

`--isolated` and `-c` are orthogonal. `--isolated` determines which session directory is used; `-c` determines whether to continue. `claudeme --isolated` always starts fresh. `claudeme --isolated -c` continues the isolated session if one exists, otherwise starts fresh — identical to how `claude -c` behaves in a new directory.

The isolated directory is a stable path derived from the real project directory:

```bash
hash=$(echo "$PWD" | shasum -a 256 | head -c 8)
dir="$HOME/.claudeme/isolated/$hash"
```

The shell function `cd`s into this directory before execing `claude`, so `claude` scopes its session to the isolated directory. The real project files are still accessible via the original paths — `claudeme` does not symlink or mount anything.

### `--isolated -c` behaviour

- Isolated session exists (`sessions.json` has an entry for the isolated dir) → `-c` is passed to `claude`, which continues from that directory's session
- No isolated session yet → `-c` is still passed to `claude` but `claude` finds no session and starts fresh (same as `claude -c` in a new directory)

---

## Environment Variables

| Variable | Set by | Purpose |
|---|---|---|
| `ANTHROPIC_BASE_URL` | resolver | Overrides Claude Code's default endpoint |
| `ANTHROPIC_API_KEY` | resolver | Key or token for the selected endpoint |
| `CLAUDEME_MODEL` | resolver | Resolved model name; shell function forwards as `--model` |
| `CLAUDEME_PROFILE` | `settings.local.json` | Project-level profile name, read by resolver |
| `CLAUDE_LOCAL_URL` | User | Direct URL override, skips all resolution |
| `CLAUDEME_SESSION_DIR` | resolver (isolated only) | Path the shell function cds into before exec |

---

## Profiles File

`~/.claudeme/profiles.json` — written by management subcommands, never hand-edited by `claudeme` core.

```json
{
  "<name>": {
    "url": "https://...",
    "auth": "none|api-key|gcp-adc|aws",
    "description": "...",
    "key": "...",         // auth=api-key, literal (not recommended)
    "key_env": "...",     // auth=api-key, read from this env var name
    "model": "gemini-2.5-pro",   // default model (optional)
    "models": {           // short aliases → full model names (optional)
      "g25pro": "gemini-2.5-pro",
      "opus":   "claude-opus-5"
    }
  }
}
```

`local` is reserved and cannot appear as a key in this file.

---

## Probe Timing

Local probes run in parallel via background `curl` processes, capped at 2 seconds. Non-running backends fail instantly (connection refused). In the common case (one backend running, rest not) detection completes in under 200ms.

GCP token resolution (`gcloud auth print-access-token`) runs only when a `gcp-adc` profile is selected. It does not run during local probing.

---

## Dependencies

| Tool | Required for | Notes |
|---|---|---|
| `curl` | Local detection | All probing |
| `bash` 4+ | All | Arrays, process substitution |
| `shasum` | Isolated sessions | Hashing project path |
| `jq` | Profile/metadata JSON | Optional; falls back to `python3 -m json.tool` + grep |
| `gcloud` | `gcp-adc` profiles | Must be authenticated via `gcloud auth login` |
| `aws` CLI | `aws` profiles | Must have credentials in environment |

---

## Out of Scope

- Starting/stopping local servers or cloud proxies
- Managing GCP projects, Cloud Run deployments, or IAM
- LiteLLM configuration or model routing within the proxy
- Token refresh within a running session (token fetched fresh per invocation)
- `.claude/settings.local.json` management (reads `CLAUDEME_PROFILE` from it, never writes)
- Claude Desktop gateway configuration
- Model listing or selection within a backend
