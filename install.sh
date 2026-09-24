#!/usr/bin/env bash
# install.sh — installs claudeme
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER_SRC="$SCRIPT_DIR/claudeme-resolve"
RESOLVER_DEST="/usr/local/bin/claudeme-resolve"
ZSHRC="$HOME/.zshrc"
MARKER_BEGIN="# ── claudeme ──────────────────────────────────────────────────────────────────"
MARKER_END="# ── end claudeme ──────────────────────────────────────────────────────────────"

# ── The claudeme shell function ────────────────────────────────────────────────
# Written as a heredoc so install.sh can update it in-place without the user
# needing to re-source manually (they still need to run: source ~/.zshrc)

SHELL_FUNCTION='
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

# 1. Copy resolver to /usr/local/bin
echo "  Installing claudeme-resolve to $RESOLVER_DEST"
cp "$RESOLVER_SRC" "$RESOLVER_DEST"
chmod +x "$RESOLVER_DEST"
echo "  ✅ Done"

# 2. Check jq
echo ""
if command -v jq &>/dev/null; then
  echo "  ✅ jq found: $(jq --version)"
else
  echo "  ⚠️  jq not found — install it with: brew install jq"
fi

# 3. Write shell function to ~/.zshrc (idempotent: remove old block first)
echo ""
echo "  Updating $ZSHRC..."

# Remove existing claudeme block if present
if grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
  # Use python3 for portable in-place removal (macOS sed -i needs a suffix)
  python3 - "$ZSHRC" "$MARKER_BEGIN" "$MARKER_END" <<'PYEOF'
import sys
path, begin, end = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    lines = f.readlines()
out, skip = [], False
for line in lines:
    if line.rstrip() == begin:
        skip = True
    if not skip:
        out.append(line)
    if skip and line.rstrip() == end:
        skip = False
with open(path, 'w') as f:
    f.writelines(out)
PYEOF
  echo "  (removed previous claudeme block)"
fi

# Append fresh block
{
  echo ""
  echo "$MARKER_BEGIN"
  printf '%s' "$SHELL_FUNCTION"
  echo "$MARKER_END"
} >> "$ZSHRC"

echo "  ✅ Shell function written"

echo ""
echo "  Run this to activate now:"
echo "    source ~/.zshrc"
echo ""
echo "  Optional — alias 'claude' to 'claudeme' so all muscle memory works:"
echo "    echo 'alias claude=claudeme' >> ~/.zshrc && source ~/.zshrc"
echo ""
echo "  Escape hatch to reach Anthropic directly:"
echo "    command claude          # bypasses the alias"
echo ""
