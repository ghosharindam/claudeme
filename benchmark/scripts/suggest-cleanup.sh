#!/usr/bin/env bash
# suggest-cleanup.sh - Recommend processes to kill before benchmarking
#
# Lists killable processes sorted by RAM/CPU usage with kill commands

# ── System Processes (Don't Kill) ──────────────────────────────────────────────

is_system_process() {
  local proc="$1"

  # System processes that should NOT be killed
  local system_procs=(
    "kernel" "launchd" "systemd" "WindowServer" "loginwindow"
    "Finder" "Dock" "SystemUIServer" "coreaudiod" "corestoraged"
    "cloudd" "bird" "cfprefsd" "diskarbitrationd"
  )

  for sys_proc in "${system_procs[@]}"; do
    if [[ "$proc" == *"$sys_proc"* ]]; then
      return 0  # Is system process
    fi
  done

  return 1  # Not system process
}

# ── Top RAM Consumers ──────────────────────────────────────────────────────────

suggest_ram_cleanup() {
  echo "# Top RAM Consumers (killable):"
  echo "#"

  local total_freeable=0
  local count=0

  # Get top processes by RAM, excluding system ones
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS
    ps aux | awk '$6 > 102400 {printf "%s|%s|%s|%s\n", $2, $11, int($6/1024), $3}' | \
    while IFS='|' read -r pid cmd ram_mb cpu_pct; do
      # Skip system processes
      if is_system_process "$cmd"; then
        continue
      fi

      # Get just the command name (not full path)
      local cmd_name=$(basename "$cmd")

      printf "# - %-30s PID %-7s RAM %5dMB  CPU %5.1f%%\n" \
        "$cmd_name" "$pid" "$ram_mb" "$cpu_pct"
      printf "#   Kill: kill %s\n" "$pid"

      total_freeable=$((total_freeable + ram_mb))
      ((count++)) || true

      [[ $count -ge 5 ]] && break
    done | sort -t ' ' -k7 -rn  # Sort by RAM descending
  else
    # Linux
    ps aux --sort=-rss | awk '$6 > 102400 {printf "%s|%s|%s|%s\n", $2, $11, int($6/1024), $3}' | \
    head -10 | \
    while IFS='|' read -r pid cmd ram_mb cpu_pct; do
      if is_system_process "$cmd"; then
        continue
      fi

      local cmd_name=$(basename "$cmd")
      printf "# - %-30s PID %-7s RAM %5dMB  CPU %5.1f%%\n" \
        "$cmd_name" "$pid" "$ram_mb" "$cpu_pct"
      printf "#   Kill: kill %s\n" "$pid"

      total_freeable=$((total_freeable + ram_mb))
      ((count++)) || true

      [[ $count -ge 5 ]] && break
    done
  fi

  if [[ $count -eq 0 ]]; then
    echo "# - (no heavy killable processes found)"
  else
    local total_gb=$((total_freeable / 1024))
    echo "#"
    echo "# Potential RAM freed: ~${total_gb}GB"
  fi

  echo "#"
}

# ── Top CPU Consumers ──────────────────────────────────────────────────────────

suggest_cpu_cleanup() {
  echo "# Top CPU Consumers (>10% usage):"
  echo "#"

  local count=0

  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS
    ps aux | awk '$3 > 10 {printf "%s|%s|%s|%s\n", $2, $11, $3, int($6/1024)}' | \
    while IFS='|' read -r pid cmd cpu_pct ram_mb; do
      if is_system_process "$cmd"; then
        continue
      fi

      local cmd_name=$(basename "$cmd")
      printf "# - %-30s PID %-7s CPU %5.1f%%  RAM %5dMB\n" \
        "$cmd_name" "$pid" "$cpu_pct" "$ram_mb"
      printf "#   Kill: kill %s\n" "$pid"

      ((count++)) || true
      [[ $count -ge 5 ]] && break
    done | sort -t ' ' -k7 -rn
  else
    # Linux
    ps aux --sort=-pcpu | awk '$3 > 10 {printf "%s|%s|%s|%s\n", $2, $11, $3, int($6/1024)}' | \
    head -10 | \
    while IFS='|' read -r pid cmd cpu_pct ram_mb; do
      if is_system_process "$cmd"; then
        continue
      fi

      local cmd_name=$(basename "$cmd")
      printf "# - %-30s PID %-7s CPU %5.1f%%  RAM %5dMB\n" \
        "$cmd_name" "$pid" "$cpu_pct" "$ram_mb"
      printf "#   Kill: kill %s\n" "$pid"

      ((count++)) || true
      [[ $count -ge 5 ]] && break
    done
  fi

  if [[ $count -eq 0 ]]; then
    echo "# - (no heavy CPU users found)"
  fi

  echo "#"
}

# ── Quick Cleanup Commands ────────────────────────────────────────────────────

suggest_quick_cleanup() {
  echo "# Quick Cleanup Commands:"
  echo "#"
  echo "# Close common heavy apps:"
  echo "#   pkill -x 'Google Chrome' 'Brave Browser' 'Firefox' 'Slack' 'Discord'"
  echo "#   pkill -x 'Microsoft Teams' 'Zoom' 'Docker'"
  echo "#"
  echo "# Stop Electron apps:"
  echo "#   pkill Electron"
  echo "#"
  echo "# Nuclear option (close ALL apps except terminal):"
  echo "#   osascript -e 'tell application \"System Events\" to set the visible of every process to true'"
  echo "#   osascript -e 'tell application \"System Events\" to set frontmost of every process whose visible is true and name is not \"Terminal\" to false'"
  echo "#"
}

# ── Main ───────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Cleanup Suggestions                           ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  suggest_ram_cleanup
  suggest_cpu_cleanup
  suggest_quick_cleanup

  echo "# ⚠️  WARNING: Only kill processes you recognize!"
  echo "# Check what each process does before killing it."
  echo ""
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

# ── Aggregated App RAM Usage ───────────────────────────────────────────────────

show_app_ram_totals() {
  echo "# Application RAM Totals (multiple processes grouped):"
  echo "#"
  
  # Group by app name and sum RAM
  ps aux | awk '{cmd=$11; gsub(/.*\//, "", cmd); gsub(/ Helper.*/, "", cmd); ram=int($6/1024); print cmd"|"ram}' | \
  awk -F'|' '
    # Map helpers to parent apps
    {
      app = $1
      if (app ~ /^[Cc]ode/) app = "Visual Studio Code"
      if (app ~ /^[Cc]hrome/) app = "Google Chrome"
      if (app ~ /^[Bb]rave/) app = "Brave Browser"
      if (app ~ /^[Ss]lack/) app = "Slack"
      if (app ~ /^[Dd]iscord/) app = "Discord"
      if (app ~ /^[Tt]eams/) app = "Microsoft Teams"
      
      ram[app] += $2
      count[app]++
    }
    END {
      for (app in ram) {
        if (ram[app] > 200) {  # Only show apps using >200MB total
          printf "%s|%d|%d\n", app, count[app], ram[app]
        }
      }
    }
  ' | sort -t'|' -k3 -rn | head -10 | \
  while IFS='|' read -r app proc_count total_mb; do
    local gb=$(echo "scale=1; $total_mb / 1024" | bc)
    printf "# - %-30s %2d procs  %5dMB  (%.1fGB)\n" "$app" "$proc_count" "$total_mb" "$gb"
    
    # Suggest kill command
    case "$app" in
      "Visual Studio Code")
        echo "#   Kill: code --stop  or  pkill -x 'Code'"
        ;;
      "Google Chrome"|"Brave Browser"|"Slack"|"Discord"|"Microsoft Teams")
        echo "#   Kill: pkill -x '$app'"
        ;;
    esac
  done
  
  echo "#"
  echo "# ⚠️  VSCode example: 8x 'Code Helper' processes = 5GB total!"
  echo "#"
}

# Add to main output
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Called directly - show aggregated view
  echo ""
  show_app_ram_totals
fi
