#!/usr/bin/env bash
# uninstall.sh — Uninstalls claudeme and utilities
#
# Usage:
#   ./uninstall.sh              # Interactive (asks about config)
#   ./uninstall.sh --all        # Remove everything including config
#   ./uninstall.sh --keep-config # Remove binaries only, keep config

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin/claudeme"
CONFIG_DIR="$HOME/.claudeme"
ZSHRC="$HOME/.zshrc"

# Markers to identify the claudeme block in .zshrc
MARKER_BEGIN="# ── claudeme ──────────────────────────────────────────────────────────────────"
MARKER_END="# ── end claudeme ──────────────────────────────────────────────────────────────"

# ── Utilities ──────────────────────────────────────────────────────────────────

msg() { echo "  $*"; }
check() { echo "  ✅ $*"; }
warn() { echo "  ⚠️  $*"; }

# ── Parse arguments ────────────────────────────────────────────────────────────

REMOVE_CONFIG="ask"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      REMOVE_CONFIG="yes"
      shift
      ;;
    --keep-config)
      REMOVE_CONFIG="no"
      shift
      ;;
    --help|-h)
      cat <<EOF
uninstall.sh - Uninstall claudeme and utilities

Usage:
  ./uninstall.sh              # Interactive (asks about config)
  ./uninstall.sh --all        # Remove everything including config
  ./uninstall.sh --keep-config # Remove binaries only, keep config

What gets removed:
  - ~/.local/bin/claudeme/    (installed binaries)
  - claudeme block in ~/.zshrc (shell function)
  - ~/.claudeme/              (config - optional)

To reinstall later:
  ./install.sh
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './uninstall.sh --help' for usage"
      exit 1
      ;;
  esac
done

# ── Main uninstall ─────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Uninstalling claudeme                         ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# 1. Remove installed binaries
if [[ -d "$INSTALL_DIR" ]]; then
  msg "Removing installed binaries..."
  rm -rf "$INSTALL_DIR"
  check "Removed $INSTALL_DIR"
else
  msg "No installed binaries found (already removed?)"
fi

# 2. Remove shell function from ~/.zshrc
if [[ -f "$ZSHRC" ]] && grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
  msg "Removing shell function from $ZSHRC..."

  # Use perl for portable in-place editing
  perl -i -ne "
    if (/$MARKER_BEGIN/../$MARKER_END/) {
      next;
    }
    print;
  " "$ZSHRC"

  check "Removed claudeme block from ~/.zshrc"
else
  msg "No shell function found in ~/.zshrc (already removed?)"
fi

# 3. Ask about config (if interactive)
if [[ "$REMOVE_CONFIG" == "ask" ]] && [[ -d "$CONFIG_DIR" ]]; then
  echo ""
  msg "Config directory exists: $CONFIG_DIR"
  msg "Contains: profiles, session history"
  echo ""
  read -p "  Remove config? (y/N): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    REMOVE_CONFIG="yes"
  else
    REMOVE_CONFIG="no"
  fi
fi

# Remove config if requested
if [[ "$REMOVE_CONFIG" == "yes" ]] && [[ -d "$CONFIG_DIR" ]]; then
  msg "Removing config directory..."
  rm -rf "$CONFIG_DIR"
  check "Removed $CONFIG_DIR"
elif [[ "$REMOVE_CONFIG" == "no" ]] && [[ -d "$CONFIG_DIR" ]]; then
  msg "Keeping config directory: $CONFIG_DIR"
fi

# 4. Success message
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Uninstall complete!                           ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

if [[ "$REMOVE_CONFIG" == "no" ]] && [[ -d "$CONFIG_DIR" ]]; then
  msg "✅ Binaries removed"
  msg "✅ Shell function removed"
  msg "⚠️  Config kept: $CONFIG_DIR"
  echo ""
  msg "To remove config later:"
  msg "  rm -rf ~/.claudeme/"
else
  msg "✅ Binaries removed"
  msg "✅ Shell function removed"
  msg "✅ Config removed"
fi

echo ""
msg "Reload your shell to complete:"
msg "  source ~/.zshrc"
echo ""
msg "To reinstall:"
msg "  ./install.sh"
echo ""
