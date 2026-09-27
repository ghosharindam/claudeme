#!/usr/bin/env bash
# benchmark-ollama.sh - Benchmark Ollama direct vs. LiteLLM → Ollama
#
# Measures overhead of LiteLLM proxy when using Ollama

set -euo pipefail

# Configuration
OLLAMA_PORT=11434
LITELLM_PORT=4000
MODEL="qwen2.5:7b-instruct"
NUM_REQUESTS=20
PROMPT="Explain quantum computing in one sentence."

RESULTS_DIR="./benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/ollama_benchmark_$TIMESTAMP.csv"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

msg() { echo -e "${BLUE}→${NC} $*"; }
ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err() { echo -e "${RED}✗${NC} $*"; }

# ── Benchmark Ollama Direct ───────────────────────────────────────────────────

benchmark_ollama_direct() {
  msg "Benchmarking: Ollama direct (native API)"

  local times=()
  for i in $(seq 1 $NUM_REQUESTS); do
    local start=$(python3 -c 'import time; print(int(time.time() * 1000))')

    curl -sf http://localhost:$OLLAMA_PORT/api/generate \
      -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" \
      > /dev/null

    local end=$(python3 -c 'import time; print(int(time.time() * 1000))')
    local duration=$((end - start))
    times+=("$duration")

    if (( i % 5 == 0 )); then
      echo -n "."
    fi
  done
  echo ""

  calculate_stats "ollama_direct" "${times[@]}"
}

# ── Benchmark LiteLLM → Ollama ────────────────────────────────────────────────

benchmark_litellm_ollama() {
  msg "Benchmarking: LiteLLM → Ollama (via Anthropic API)"

  local times=()
  for i in $(seq 1 $NUM_REQUESTS); do
    local start=$(python3 -c 'import time; print(int(time.time() * 1000))')

    curl -sf http://localhost:$LITELLM_PORT/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"$MODEL\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}],
        \"max_tokens\": 50,
        \"stream\": false
      }" > /dev/null

    local end=$(python3 -c 'import time; print(int(time.time() * 1000))')
    local duration=$((end - start))
    times+=("$duration")

    if (( i % 5 == 0 )); then
      echo -n "."
    fi
  done
  echo ""

  calculate_stats "litellm_ollama" "${times[@]}"
}

# ── Statistics ─────────────────────────────────────────────────────────────────

calculate_stats() {
  local scenario="$1"
  shift
  local times=("$@")

  local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
  local count=${#sorted[@]}
  local p50_idx=$((count / 2))
  local p95_idx=$((count * 95 / 100))
  local p99_idx=$((count * 99 / 100))

  local sum=0
  for t in "${times[@]}"; do
    sum=$((sum + t))
  done
  local mean=$((sum / count))

  local p50=${sorted[$p50_idx]}
  local p95=${sorted[$p95_idx]}
  local p99=${sorted[$p99_idx]}

  echo "$scenario,latency,$p50,$p95,$p99,$mean" >> "$RESULTS_FILE"

  ok "$scenario: p50=${p50}ms, p95=${p95}ms, p99=${p99}ms, mean=${mean}ms"
}

# ── Main ───────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Ollama Performance Benchmark                  ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  mkdir -p "$RESULTS_DIR"
  echo "scenario,metric,p50,p95,p99,mean" > "$RESULTS_FILE"

  msg "Model: $MODEL"
  msg "Requests: $NUM_REQUESTS per scenario"
  msg "Results: $RESULTS_FILE"
  echo ""

  # Check Ollama
  msg "Checking Ollama on :$OLLAMA_PORT..."
  if ! curl -sf http://localhost:$OLLAMA_PORT/api/tags &>/dev/null; then
    err "Ollama not running"
    msg "Start with: ollama serve"
    exit 1
  fi
  ok "Ollama running"
  echo ""

  # Benchmark 1: Ollama direct
  benchmark_ollama_direct
  echo ""

  # Check if LiteLLM is running
  msg "Checking LiteLLM on :$LITELLM_PORT..."
  if ! curl -sf http://localhost:$LITELLM_PORT/health &>/dev/null; then
    warn "LiteLLM not running"
    msg "Start with: litellm --model ollama/$MODEL --port $LITELLM_PORT"
    msg "Skipping LiteLLM benchmark"
    LITELLM_AVAILABLE=false
  else
    ok "LiteLLM running"
    LITELLM_AVAILABLE=true
    echo ""

    # Benchmark 2: LiteLLM → Ollama
    benchmark_litellm_ollama
  fi

  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Results                                        ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  cat "$RESULTS_FILE"
  echo ""

  # Calculate overhead if both tests ran
  if [[ "$LITELLM_AVAILABLE" == true ]]; then
    local direct_mean=$(awk -F, '/ollama_direct/ {print $6}' "$RESULTS_FILE")
    local litellm_mean=$(awk -F, '/litellm_ollama/ {print $6}' "$RESULTS_FILE")
    local overhead=$((litellm_mean - direct_mean))
    local overhead_pct=$((overhead * 100 / direct_mean))

    echo ""
    msg "Overhead Analysis:"
    echo "  Direct Ollama:    ${direct_mean}ms"
    echo "  LiteLLM → Ollama: ${litellm_mean}ms"
    echo "  Overhead:         ${overhead}ms (${overhead_pct}%)"
    echo ""

    if [[ $overhead -lt 50 ]]; then
      ok "Overhead <50ms: Acceptable for flexibility!"
    elif [[ $overhead -lt 100 ]]; then
      warn "Overhead 50-100ms: Noticeable but may be worth it"
    else
      err "Overhead >100ms: Significant impact"
    fi
  fi

  echo ""
  msg "Saved to: $RESULTS_FILE"
}

main "$@"
