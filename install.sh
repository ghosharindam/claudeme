#!/usr/bin/env bash
# install.sh — installs claudeme and dependencies
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER_SRC="$SCRIPT_DIR/claudeme-resolve"
RESOLVER_DEST="$HOME/.local/bin/claudeme-resolve"
ZSHRC="$HOME/.zshrc"
MARKER_BEGIN="# ── claudeme ──────────────────────────────────────────────────────────────────"
MARKER_END="# ── end claudeme ──────────────────────────────────────────────────────────────"

# ── Utilities ──────────────────────────────────────────────────────────────────

msg() { echo "  $*"; }
check() { echo "  ✅ $*"; }
warn() { echo "  ⚠️  $*"; }
err() { echo "  ❌ $*"; }

# ── The claudeme shell function ────────────────────────────────────────────────

SHELL_FUNCTION='# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

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

# 1. Ensure ~/.local/bin exists
msg "Checking ~/.local/bin..."
if [[ ! -d "$HOME/.local/bin" ]]; then
  mkdir -p "$HOME/.local/bin"
  check "Created ~/.local/bin"
else
  check "~/.local/bin exists"
fi

# 2. Copy resolver to ~/.local/bin
echo ""
msg "Installing claudeme-resolve..."
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

# 3. Check and install dependencies
echo ""
msg "Checking dependencies..."

# Check jq
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

# Check claude CLI
if command -v claude &>/dev/null; then
  check "claude CLI found"
else
  warn "claude CLI not found"
  msg "Install from: https://docs.anthropic.com/claude-code"
fi

# Check Python (for litellm)
if command -v python3 &>/dev/null; then
  check "python3 found: $(python3 --version)"
else
  warn "python3 not found — required for litellm"
fi

# Check/install litellm
if command -v litellm &>/dev/null; then
  # Check if litellm[proxy] is properly installed
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

# 4. Write shell function to ~/.zshrc (idempotent: remove old block first)
echo ""
msg "Updating $ZSHRC..."

# Create .zshrc if it doesn't exist
touch "$ZSHRC"

# Remove existing claudeme block if present
if grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
  # Use perl for portable in-place editing
  perl -i -ne "
    if (/$MARKER_BEGIN/../$MARKER_END/) {
      next;
    }
    print;
  " "$ZSHRC"
  msg "(removed previous claudeme block)"
fi

# Append fresh block
{
  echo ""
  echo "$MARKER_BEGIN"
  printf '%s' "$SHELL_FUNCTION"
  echo "$MARKER_END"
} >> "$ZSHRC"

check "Shell function written to ~/.zshrc"

# 5. Ensure ~/.local/bin is in current PATH for verification
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Installation complete!                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
msg "Run this to activate now:"
msg "  source ~/.zshrc"
echo ""
msg "Then verify:"
msg "  claudeme list"
echo ""
msg "Optional — alias 'claude' to 'claudeme':"
msg "  echo 'alias claude=claudeme' >> ~/.zshrc && source ~/.zshrc"
echo ""
msg "Escape hatch to reach Anthropic directly:"
msg "  command claude"
echo ""
