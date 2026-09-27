#!/usr/bin/env bash
# run-all.sh - Run all configured benchmark scenarios
#
# Reads benchmark/config.yaml and runs each enabled scenario

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.yaml"
RESULTS_DIR="$SCRIPT_DIR/../results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Source environment capture
source "$SCRIPT_DIR/capture-env.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg() { echo -e "${BLUE}→${NC} $*"; }
ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }

# ── Parse YAML (simplified - reads key values) ────────────────────────────────

get_config() {
  local key="$1"
  grep "^  $key:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"'
}

# ── Check if endpoint is reachable ────────────────────────────────────────────

check_endpoint() {
  local url="$1"
  local api_type="${2:-anthropic}"

  case "$api_type" in
    anthropic)
      curl -sf "${url}/health" &>/dev/null || curl -sf "${url}/v1/models" &>/dev/null
      ;;
    ollama)
      curl -sf "${url}/api/tags" &>/dev/null
      ;;
    *)
      curl -sf "$url" &>/dev/null
      ;;
  esac
}

# ── Run single benchmark ───────────────────────────────────────────────────────

run_benchmark() {
  local name="$1"
  local url="$2"
  local api_type="$3"
  local model="$4"
  local requests="${5:-20}"

  msg "Running: $name"

  local times=()
  for i in $(seq 1 "$requests"); do
    local start=$(python3 -c 'import time; print(int(time.time() * 1000))')

    case "$api_type" in
      anthropic)
        curl -sf "$url/v1/chat/completions" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Test\"}],\"max_tokens\":50,\"stream\":false}" \
          > /dev/null 2>&1
        ;;
      ollama)
        curl -sf "$url/api/generate" \
          -d "{\"model\":\"$model\",\"prompt\":\"Test\",\"stream\":false}" \
          > /dev/null 2>&1
        ;;
    esac

    local end=$(python3 -c 'import time; print(int(time.time() * 1000))')
    local duration=$((end - start))
    times+=($duration)

    [[ $((i % 5)) -eq 0 ]] && echo -n "."
  done
  echo ""

  # Calculate stats
  local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
  local count=${#sorted[@]}
  local sum=0
  for t in "${times[@]}"; do sum=$((sum + t)); done
  local mean=$((sum / count))
  local p50=${sorted[$((count / 2))]}
  local p95=${sorted[$((count * 95 / 100))]}

  ok "$name: mean=${mean}ms, p50=${p50}ms, p95=${p95}ms"

  # Return stats
  echo "$mean $p50 $p95"
}

# ── Main ───────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Benchmark Suite (Config-Driven)               ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  # Print environment
  print_env

  msg "Reading config: $CONFIG_FILE"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    warn "Config file not found: $CONFIG_FILE"
    msg "Create it with: cp config.example.yaml config.yaml"
    exit 1
  fi

  # Create results directory
  mkdir -p "$RESULTS_DIR"
  local summary_file="$RESULTS_DIR/${TIMESTAMP}_summary.csv"

  # Write header
  write_metadata "$summary_file"
  echo "scenario,routing,mean_ms,p50_ms,p95_ms" >> "$summary_file"

  echo ""
  msg "Detecting available backends..."

  # Check llama-server (read from config or use default)
  local llama_direct_url="http://localhost:52123"  # TODO: Read from config.yaml
  local llama_via_litellm_url="http://localhost:4000"

  LLAMA_DIRECT_AVAILABLE=false
  LLAMA_VIA_LITELLM_AVAILABLE=false

  if check_endpoint "$llama_direct_url" "anthropic"; then
    ok "llama-server available at $llama_direct_url"
    LLAMA_DIRECT_AVAILABLE=true
  else
    warn "llama-server not available (direct)"
  fi

  if check_endpoint "$llama_via_litellm_url" "anthropic"; then
    ok "LiteLLM available at $llama_via_litellm_url"
    LLAMA_VIA_LITELLM_AVAILABLE=true
  fi

  echo ""
  msg "Running benchmarks..."
  echo ""

  # Scenario 1: llama-server direct
  if $LLAMA_DIRECT_AVAILABLE; then
    stats=$(run_benchmark "llama-server-direct" "$llama_direct_url" "anthropic" "local" 20)
    read mean p50 p95 <<< "$stats"
    echo "llama-server,direct,$mean,$p50,$p95" >> "$summary_file"
    BASELINE_MEAN=$mean
  fi

  echo ""

  # Scenario 2: llama-server via LiteLLM
  if $LLAMA_VIA_LITELLM_AVAILABLE; then
    stats=$(run_benchmark "llama-server-litellm" "$llama_via_litellm_url" "anthropic" "local" 20)
    read mean p50 p95 <<< "$stats"
    echo "llama-server,via_litellm,$mean,$p50,$p95" >> "$summary_file"

    # Calculate overhead if we have baseline
    if [[ -n "${BASELINE_MEAN:-}" ]]; then
      local overhead=$((mean - BASELINE_MEAN))
      local overhead_pct=$((overhead * 100 / BASELINE_MEAN))
      echo ""
      msg "Overhead: ${overhead}ms (${overhead_pct}%)"

      if [[ $overhead -lt 50 ]]; then
        ok "Overhead <50ms: Negligible!"
      elif [[ $overhead -lt 150 ]]; then
        warn "Overhead <150ms: Acceptable"
      else
        warn "Overhead >${overhead}ms: Significant"
      fi
    fi
  fi

  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Results Summary                                ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  cat "$summary_file" | grep -v "^#"

  echo ""
  ok "Results saved to: $summary_file"
}

main "$@"
