#!/usr/bin/env bash
# capture-system-state.sh - Capture detailed system state for fair benchmarking
#
# Detects:
# - Memory usage (total, available, used)
# - CPU load
# - Running model servers (and their memory usage)
# - GPU usage
# - Other heavy processes
#
# Warns about potential bias and suggests fair comparison setups

# ── System Metrics ─────────────────────────────────────────────────────────────

get_memory_info() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS
    local total_bytes=$(sysctl -n hw.memsize)
    local total_gb=$((total_bytes / 1024 / 1024 / 1024))

    # Get memory pressure
    local memory_pressure=$(memory_pressure 2>&1 | grep "System-wide memory free percentage" | awk '{print $5}' | tr -d '%')
    local used_pct=$((100 - memory_pressure))
    local used_gb=$((total_gb * used_pct / 100))
    local available_gb=$((total_gb - used_gb))

    echo "total_gb=$total_gb"
    echo "used_gb=$used_gb"
    echo "available_gb=$available_gb"
    echo "used_pct=$used_pct"
  else
    # Linux
    local mem_info=$(free -g | awk '/^Mem:/ {print $2,$3,$7}')
    read total used available <<< "$mem_info"
    local used_pct=$((used * 100 / total))

    echo "total_gb=$total"
    echo "used_gb=$used"
    echo "available_gb=$available"
    echo "used_pct=$used_pct"
  fi
}

get_cpu_load() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS - 5 minute load average
    sysctl -n vm.loadavg | awk '{print $3}'
  else
    # Linux
    uptime | awk -F'load average:' '{print $2}' | awk '{print $2}' | tr -d ','
  fi
}

# ── Running Model Servers ──────────────────────────────────────────────────────

detect_running_servers() {
  echo "# Running Model Servers:"

  local found_any=false

  # llama-server
  if pgrep -x "llama-server" &>/dev/null; then
    local pid=$(pgrep -x "llama-server" | head -1)
    local port=$(lsof -p "$pid" | grep LISTEN | awk '{print $9}' | cut -d: -f2 | head -1)
    local mem_mb=$(ps -p "$pid" -o rss= | awk '{print int($1/1024)}')
    echo "# - llama-server (PID $pid, Port $port, RAM ${mem_mb}MB)"
    found_any=true
  fi

  # Ollama
  if pgrep -x "ollama" &>/dev/null; then
    local pid=$(pgrep -x "ollama" | head -1)
    local mem_mb=$(ps -p "$pid" -o rss= | awk '{print int($1/1024)}')
    echo "# - ollama (PID $pid, RAM ${mem_mb}MB)"
    found_any=true
  fi

  # LiteLLM
  if pgrep -f "litellm" &>/dev/null; then
    local pid=$(pgrep -f "litellm" | head -1)
    local mem_mb=$(ps -p "$pid" -o rss= | awk '{print int($1/1024)}')
    echo "# - litellm (PID $pid, RAM ${mem_mb}MB)"
    found_any=true
  fi

  if ! $found_any; then
    echo "# - (none detected)"
  fi

  echo "#"
}

# ── Heavy Processes ────────────────────────────────────────────────────────────

detect_heavy_processes() {
  echo "# Heavy Processes (>500MB RAM):"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    ps aux | awk '$6 > 512000 {printf "# - %s (PID %s, RAM %dMB, CPU %.1f%%)\n", $11, $2, $6/1024, $3}' | head -10
  else
    ps aux | awk '$6 > 512000 {printf "# - %s (PID %s, RAM %dMB, CPU %.1f%%)\n", $11, $2, $6/1024, $3}' | head -10
  fi

  echo "#"
}

# ── GPU Usage ──────────────────────────────────────────────────────────────────

detect_gpu_usage() {
  if command -v nvidia-smi &>/dev/null; then
    echo "# GPU Usage:"
    nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader | \
      awk -F, '{printf "# - GPU %s (%s): %s / %s, %s util\n", $1, $2, $3, $4, $5}'
    echo "#"
  elif [[ "$(uname -s)" == "Darwin" ]] && sysctl -n machdep.cpu.brand_string | grep -q "Apple"; then
    echo "# GPU: Apple Silicon (integrated)"
    echo "#"
  fi
}

# ── Bias Detection ─────────────────────────────────────────────────────────────

detect_bias() {
  local warnings=()

  # Count running model servers
  local server_count=0
  pgrep -x "llama-server" &>/dev/null && ((server_count++)) || true
  pgrep -x "ollama" &>/dev/null && ((server_count++)) || true

  # Check memory pressure
  eval $(get_memory_info)

  if [[ $used_pct -gt 80 ]]; then
    warnings+=("High memory usage (${used_pct}%) - may cause swapping")
  fi

  if [[ $server_count -gt 1 ]]; then
    warnings+=("Multiple model servers running - memory/CPU contention possible")
  fi

  # Check CPU load
  local cpu_load=$(get_cpu_load)
  if (( $(echo "$cpu_load > 2.0" | bc -l 2>/dev/null || echo 0) )); then
    warnings+=("High CPU load (${cpu_load}) - system under stress")
  fi

  # Print warnings
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "# ⚠️  BIAS WARNINGS:"
    for warning in "${warnings[@]}"; do
      echo "#    - $warning"
    done
    echo "#"
  fi
}

# ── Recommendations ────────────────────────────────────────────────────────────

print_recommendations() {
  echo "# Fair Comparison Recommendations:"
  echo "#"
  echo "# Option A: Isolated Testing (most accurate)"
  echo "#   1. Stop all model servers"
  echo "#   2. Start ONLY the server you're benchmarking"
  echo "#   3. Run benchmark"
  echo "#   4. Repeat for each server/scenario"
  echo "#"
  echo "# Option B: Consistent State (faster)"
  echo "#   1. Start ALL servers you want to compare"
  echo "#   2. Run all benchmarks with same system state"
  echo "#   3. Overhead comparisons are valid"
  echo "#   4. Absolute numbers may be slower than isolated"
  echo "#"
  echo "# Warmup: Run 2-3 requests before timing to warm caches"
  echo "#"
}

# ── Main Capture ───────────────────────────────────────────────────────────────

capture_system_state() {
  local output_file="${1:-}"

  {
    echo "# System State Snapshot"
    echo "# Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "#"

    # Memory
    echo "# Memory:"
    eval $(get_memory_info)
    echo "# - Total: ${total_gb}GB"
    echo "# - Used: ${used_gb}GB (${used_pct}%)"
    echo "# - Available: ${available_gb}GB"
    echo "#"

    # CPU
    echo "# CPU Load (5min avg): $(get_cpu_load)"
    echo "#"

    # Model servers
    detect_running_servers

    # Heavy processes
    detect_heavy_processes

    # GPU
    detect_gpu_usage

    # Bias warnings
    detect_bias

    # Recommendations
    print_recommendations

  } | if [[ -n "$output_file" ]]; then
    tee -a "$output_file"
  else
    cat
  fi
}

# ── Export Functions ───────────────────────────────────────────────────────────

export -f get_memory_info
export -f get_cpu_load
export -f detect_running_servers
export -f detect_heavy_processes
export -f detect_gpu_usage
export -f detect_bias
export -f print_recommendations
export -f capture_system_state
