# Source Binaries

This directory contains source scripts that are **installed** by `install.sh`, not run directly.

## Files

- **`claudeme-resolve`** - Main endpoint resolver
  - Detects local backends (llama-server, Ollama, LiteLLM)
  - Manages named cloud profiles
  - Called by the `claudeme` shell function

## Installation

**Do NOT run these scripts directly.** They are installed by:

```bash
cd ..
./install.sh
```

This copies scripts to `~/.local/bin/` and sets up shell integration.

## After Installation

Once installed, use the `claudeme` command (from the shell function):

```bash
claudeme                 # Auto-detect endpoint
claudeme list            # List available endpoints
claudeme <profile>       # Use named profile
claudeme -c              # Continue last session

# Add a profile:
claudeme add gcp https://my-litellm.run.app --auth gcp-adc
```

## Updates

To update installed scripts:

```bash
git pull
./install.sh    # Re-run installer (safe, idempotent)
```

The installer uses smart diff detection - only updates changed files.

## Architecture

**Source (this directory):**
```
bin/claudeme-resolve     ← Source script
```

**Installed:**
```
~/.local/bin/claudeme-resolve   ← Installed binary
~/.zshrc                        ← Shell function added
```

**How it works:**
1. User runs: `claudeme`
2. Shell function calls: `~/.local/bin/claudeme-resolve`
3. Resolver detects endpoint and returns env vars
4. Shell function evals vars and execs `claude` CLI

See `../README.md` for full documentation.
