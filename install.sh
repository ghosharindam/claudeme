#!/usr/bin/env bash
# install.sh — installs claudeme and dependencies
#
# WHAT THIS DOES:
#   1. Installs claudeme-resolve binary to ~/.local/bin (no sudo needed)
#   2. Installs utilities to ~/.local/bin:
#      - cleanup-advisor: System resource cleanup
#      - benchmark-run: Performance benchmarking
#   3. Adds claudeme shell function to ~/.zshrc
#   4. Auto-installs dependencies: jq, litellm[proxy]
#
# IDEMPOTENCY:
#   Safe to run multiple times. It will:
#   - Skip already-installed components
#   - Update outdated components
#   - Never break existing setup
#
# DEPENDENCIES:
#   - jq:              JSON parser (auto-installed via Homebrew)
#   - litellm[proxy]:  API translator for Ollama/Edge Gallery (auto-installed via pip)
#   - claude CLI:      Required but user must install separately (link shown)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin/claudeme"                          # Install subdirectory
RESOLVER_SRC="$SCRIPT_DIR/bin/claudeme-resolve"                  # Source script in repo
RESOLVER_DEST="$INSTALL_DIR/claudeme-resolve"                    # Destination
CLEANUP_SRC="$SCRIPT_DIR/utils/cleanup-advisor/cleanup-advisor"  # Cleanup utility
CLEANUP_DEST="$INSTALL_DIR/cleanup-advisor"                      # Destination
BENCHMARK_SRC="$SCRIPT_DIR/utils/benchmark/benchmark-run"        # Benchmark utility
BENCHMARK_DEST="$INSTALL_DIR/benchmark-run"                      # Destination
ZSHRC="$HOME/.zshrc"                                             # Shell config file

# Markers to identify the claudeme block in .zshrc (for safe updates)
MARKER_BEGIN="# ── claudeme ──────────────────────────────────────────────────────────────────"
MARKER_END="# ── end claudeme ──────────────────────────────────────────────────────────────"

# ── Utilities ──────────────────────────────────────────────────────────────────

msg() { echo "  $*"; }      # Regular message
check() { echo "  ✅ $*"; }  # Success
warn() { echo "  ⚠️  $*"; }  # Warning
err() { echo "  ❌ $*"; }   # Error

# ── The claudeme shell function ────────────────────────────────────────────────
# This function is written to ~/.zshrc and provides the `claudeme` command.
#
# FLOW:
#   1. Route management commands (add/remove/list) to claudeme-resolve binary
#   2. For session commands: call claudeme-resolve to determine endpoint
#   3. Eval the returned env vars (ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY, etc.)
#   4. Exec the real `claude` CLI with those env vars set
#
# WHY A SHELL FUNCTION?
#   - Must eval env vars in the current shell (can't do this from a binary)
#   - Can exec to replace the shell process (clean process tree)

SHELL_FUNCTION='# Ensure ~/.local/bin/claudeme is in PATH (where claudeme binaries live)
export PATH="$HOME/.local/bin/claudeme:$PATH"

# Typo-tolerant alias (claudme → claudeme)
alias claudme=claudeme

claudeme() {
  # Route management subcommands directly to the resolver
  case "${1:-}" in
    add|remove|test|models)
      command claudeme-resolve "$@"
      return
      ;;
    list)
      command claudeme-resolve list
      return
      ;;
  esac

  # claudeme <name> list — model listing for a named profile
  if [[ -n "${1:-}" && "${2:-}" == "list" && "${1:-}" != -* ]]; then
    command claudeme-resolve profile-models "$1"
    return
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
          # Split colon syntax: gcp:g25pro → profile=gcp, model_ref=g25pro
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
  env_block=$(command claudeme-resolve "${resolver_args[@]+"${resolver_args[@]}"}" 2>/dev/tty) || return 1
  eval "$env_block"

  # Prepend --model if the resolver resolved one
  if [[ -n "${CLAUDEME_MODEL:-}" ]]; then
    claude_args=(--model "$CLAUDEME_MODEL" "${claude_args[@]+"${claude_args[@]}"}")
    unset CLAUDEME_MODEL
  fi

  # For isolated sessions: cd into the session dir before execing claude
  if [[ -n "${CLAUDEME_SESSION_DIR:-}" ]]; then
    local session_dir="$CLAUDEME_SESSION_DIR"
    unset CLAUDEME_SESSION_DIR
    cd "$session_dir" || return 1
  fi

  exec command claude "${claude_args[@]+"${claude_args[@]}"}"
}
'

# ── Install ────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   claudeme installer                            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Installation Steps ────────────────────────────────────────────────────────

# 1. Ensure install directory exists
# WHY: Groups all claudeme binaries together in ~/.local/bin/claudeme/
msg "Checking $INSTALL_DIR..."
if [[ ! -d "$INSTALL_DIR" ]]; then
  mkdir -p "$INSTALL_DIR"
  check "Created $INSTALL_DIR"
else
  check "$INSTALL_DIR exists"
fi

# Ensure ~/.local/bin is in PATH (parent directory)
if [[ ! -d "$HOME/.local/bin" ]]; then
  mkdir -p "$HOME/.local/bin"
fi

# Ensure ~/.claudeme config directory exists
CONFIG_DIR="$HOME/.claudeme"
if [[ ! -d "$CONFIG_DIR" ]]; then
  mkdir -p "$CONFIG_DIR"
  check "Created $CONFIG_DIR"
fi

# 2. Copy scripts to ~/.local/bin
# IDEMPOTENCY: Only copy if missing or different (uses diff to check)
echo ""
msg "Installing scripts..."

# claudeme-resolve
if [[ -f "$RESOLVER_DEST" ]]; then
  # Check if it's different
  if ! diff -q "$RESOLVER_SRC" "$RESOLVER_DEST" &>/dev/null; then
    cp "$RESOLVER_SRC" "$RESOLVER_DEST"
    chmod +x "$RESOLVER_DEST"
    check "Updated claudeme-resolve"
  else
    check "claudeme-resolve already up to date"
  fi
else
  cp "$RESOLVER_SRC" "$RESOLVER_DEST"
  chmod +x "$RESOLVER_DEST"
  check "Installed claudeme-resolve"
fi

# cleanup-advisor utility
if [[ -f "$CLEANUP_SRC" ]]; then
  if [[ -f "$CLEANUP_DEST" ]]; then
    if ! diff -q "$CLEANUP_SRC" "$CLEANUP_DEST" &>/dev/null; then
      cp "$CLEANUP_SRC" "$CLEANUP_DEST"
      chmod +x "$CLEANUP_DEST"
      check "Updated cleanup-advisor"
    else
      check "cleanup-advisor already up to date"
    fi
  else
    cp "$CLEANUP_SRC" "$CLEANUP_DEST"
    chmod +x "$CLEANUP_DEST"
    check "Installed cleanup-advisor"
  fi
else
  warn "cleanup-advisor source not found (skipping)"
fi

# benchmark-run utility
if [[ -f "$BENCHMARK_SRC" ]]; then
  if [[ -f "$BENCHMARK_DEST" ]]; then
    if ! diff -q "$BENCHMARK_SRC" "$BENCHMARK_DEST" &>/dev/null; then
      cp "$BENCHMARK_SRC" "$BENCHMARK_DEST"
      chmod +x "$BENCHMARK_DEST"
      check "Updated benchmark-run"
    else
      check "benchmark-run already up to date"
    fi
  else
    cp "$BENCHMARK_SRC" "$BENCHMARK_DEST"
    chmod +x "$BENCHMARK_DEST"
    check "Installed benchmark-run"
  fi
else
  warn "benchmark-run source not found (skipping)"
fi

# 3. Install config files
# Copy default configs to ~/.claudeme/ if they don't exist
echo ""
msg "Installing config files..."

# model-catalog.yaml
CATALOG_SRC="$SCRIPT_DIR/examples/model-catalog.yaml"
CATALOG_DEST="$CONFIG_DIR/model-catalog.yaml"

if [[ -f "$CATALOG_SRC" ]]; then
  if [[ ! -f "$CATALOG_DEST" ]]; then
    cp "$CATALOG_SRC" "$CATALOG_DEST"
    check "Installed model-catalog.yaml"
  else
    # Config exists - check if update needed
    if ! diff -q "$CATALOG_SRC" "$CATALOG_DEST" &>/dev/null; then
      msg "model-catalog.yaml exists (keeping your version)"
      msg "  New version available at: examples/model-catalog.yaml"
    else
      check "model-catalog.yaml up to date"
    fi
  fi
else
  warn "model-catalog.yaml source not found (skipping)"
fi

# preferences.yaml
PREFS_SRC="$SCRIPT_DIR/examples/preferences.yaml"
PREFS_DEST="$CONFIG_DIR/preferences.yaml"

if [[ -f "$PREFS_SRC" ]]; then
  if [[ ! -f "$PREFS_DEST" ]]; then
    cp "$PREFS_SRC" "$PREFS_DEST"
    check "Installed preferences.yaml"
  else
    # Preferences exist - never overwrite (user customized)
    check "preferences.yaml exists (keeping your settings)"
  fi
else
  warn "preferences.yaml source not found (skipping)"
fi

# sessions.json
SESSIONS_FILE="$CONFIG_DIR/sessions.json"
if [[ ! -f "$SESSIONS_FILE" ]]; then
  echo '{}' > "$SESSIONS_FILE"
  check "Created sessions.json"
fi

# 4. Check and install dependencies
# Each dependency is checked before installing (idempotent)
echo ""
msg "Checking dependencies..."

# ── jq: JSON parser ──
# Required by claudeme-resolve to read/write profile JSON files
if command -v jq &>/dev/null; then
  check "jq found: $(jq --version)"
else
  warn "jq not found"
  if command -v brew &>/dev/null; then
    msg "Installing jq via Homebrew..."
    brew install jq
    check "jq installed"
  else
    err "Please install jq manually: brew install jq"
    exit 1
  fi
fi

# ── claude CLI ──
# The actual Claude Code CLI that we're wrapping
# Must be installed separately by the user
if command -v claude &>/dev/null; then
  check "claude CLI found"
else
  warn "claude CLI not found"
  msg "Install from: https://docs.anthropic.com/claude-code"
fi

# ── Python 3 ──
# Required for litellm
if command -v python3 &>/dev/null; then
  check "python3 found: $(python3 --version)"
else
  warn "python3 not found — required for litellm"
fi

# ── litellm[proxy]: API translator ──
# WHY NEEDED: Ollama and Edge Gallery don't speak Anthropic API format
# The [proxy] extras include all dependencies for running as an HTTP proxy
if command -v litellm &>/dev/null; then
  # Check if litellm[proxy] is properly installed (test by running --version)
  if litellm --version &>/dev/null; then
    check "litellm found: $(litellm --version 2>&1 | head -1 || echo 'installed')"
  else
    warn "litellm found but proxy dependencies missing"
    msg "Reinstalling with proxy support..."
    if command -v pip3 &>/dev/null; then
      pip3 install --upgrade 'litellm[proxy]' --quiet
    else
      pip install --upgrade 'litellm[proxy]' --quiet
    fi
    check "litellm proxy dependencies installed"
  fi
else
  warn "litellm not found"
  if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
    msg "Installing litellm with proxy support..."
    if command -v pip3 &>/dev/null; then
      pip3 install 'litellm[proxy]' --quiet
    else
      pip install 'litellm[proxy]' --quiet
    fi
    if command -v litellm &>/dev/null && litellm --version &>/dev/null; then
      check "litellm installed successfully"
    else
      warn "litellm installation may require adding Python bin to PATH"
      msg "Try: export PATH=\"\$HOME/Library/Python/3.*/bin:\$PATH\""
    fi
  else
    err "pip not found — cannot install litellm"
    msg "Install manually: pip3 install 'litellm[proxy]'"
  fi
fi

# 4. Write shell function to ~/.zshrc
# IDEMPOTENCY: Remove old claudeme block before adding new one
# This lets you re-run the installer to update the function
echo ""
msg "Updating $ZSHRC..."

# Create .zshrc if it doesn't exist
touch "$ZSHRC"

# Remove existing claudeme block if present (identified by markers)
if grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
  # Use perl for portable in-place editing (works on macOS and Linux)
  # Delete all lines between MARKER_BEGIN and MARKER_END (inclusive)
  perl -i -ne "
    if (/$MARKER_BEGIN/../$MARKER_END/) {
      next;
    }
    print;
  " "$ZSHRC"
  msg "(removed previous claudeme block)"
fi

# Append fresh block with markers
{
  echo ""
  echo "$MARKER_BEGIN"
  printf '%s' "$SHELL_FUNCTION"
  echo "$MARKER_END"
} >> "$ZSHRC"

check "Shell function written to ~/.zshrc"

# 5. Ensure ~/.local/bin is in current PATH for verification
# This only affects the installer process — the shell function also adds it
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Installation complete!                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
msg "✅ claudeme installed and added to ~/.zshrc"
msg "✅ Utilities installed:"
[[ -f "$CLEANUP_DEST" ]] && msg "   - cleanup-advisor (system resource cleanup)"
[[ -f "$BENCHMARK_DEST" ]] && msg "   - benchmark-run (performance benchmarking)"
echo ""
msg "To use in THIS terminal (current session):"
msg "  source ~/.zshrc"
msg "  claudeme list"
echo ""
msg "To use in NEW terminals:"
msg "  Just open a new terminal — claudeme works automatically!"
echo ""
msg "Optional — alias 'claude' to 'claudeme':"
msg "  echo 'alias claude=claudeme' >> ~/.zshrc && source ~/.zshrc"
echo ""
msg "Try the utilities:"
[[ -f "$CLEANUP_DEST" ]] && msg "  cleanup-advisor         # See what's using RAM/CPU"
[[ -f "$BENCHMARK_DEST" ]] && msg "  benchmark-run           # Run performance benchmarks"
echo ""
msg "Escape hatch to reach Anthropic directly (even with alias):"
msg "  command claude"
echo ""
