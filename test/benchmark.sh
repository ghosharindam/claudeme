#!/usr/bin/env bash
# benchmark.sh - Performance benchmarking for claudeme routing strategies
#
# Measures:
#   1. Direct llama.cpp (baseline)
#   2. LiteLLM → llama.cpp (overhead)
#   3. LiteLLM multi-model (routing overhead)
#
# Outputs CSV with: scenario, metric, p50, p95, p99, mean

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────

RESULTS_DIR="./benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/benchmark_$TIMESTAMP.csv"

# Benchmark parameters
NUM_REQUESTS=50              # Number of requests per scenario
PROMPT="Explain quantum computing in one sentence."
MAX_TOKENS=50                # Keep responses short for consistent timing

# Ports
LLAMA_PORT=8080
LITELLM_PORT=4000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Utilities ──────────────────────────────────────────────────────────────────

msg() { echo -e "${BLUE}→${NC} $*"; }
ok() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err() { echo -e "${RED}✗${NC} $*"; }

check_command() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 not found - install it first"
    return 1
  fi
}

wait_for_endpoint() {
  local url="$1"
  local max_wait=30
  local waited=0

  msg "Waiting for $url..."
  while ! curl -sf "$url" &>/dev/null; do
    sleep 1
    ((waited++)) || true
    if [[ $waited -ge $max_wait ]]; then
      err "Timeout waiting for $url"
      return 1
    fi
  done
  ok "Endpoint ready: $url"
}

# ── Benchmark Execution ────────────────────────────────────────────────────────

benchmark_direct_llama() {
  msg "Benchmarking: Direct llama.cpp"

  local times=()
  for i in $(seq 1 $NUM_REQUESTS); do
    local start=$(date +%s%3N)  # milliseconds

    curl -sf http://localhost:$LLAMA_PORT/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"local\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}],
        \"max_tokens\": $MAX_TOKENS,
        \"stream\": false
      }" > /dev/null

    local end=$(date +%s%3N)
    local duration=$((end - start))
    times+=("$duration")

    # Progress
    if (( i % 10 == 0 )); then
      echo -n "."
    fi
  done
  echo ""

  # Calculate statistics
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

  echo "direct_llama,latency,$p50,$p95,$p99,$mean" >> "$RESULTS_FILE"

  ok "Direct llama.cpp: p50=${p50}ms, p95=${p95}ms, p99=${p99}ms, mean=${mean}ms"
}

benchmark_litellm_single() {
  msg "Benchmarking: LiteLLM → single llama.cpp"

  local times=()
  for i in $(seq 1 $NUM_REQUESTS); do
    local start=$(date +%s%3N)

    curl -sf http://localhost:$LITELLM_PORT/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"local\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}],
        \"max_tokens\": $MAX_TOKENS,
        \"stream\": false
      }" > /dev/null

    local end=$(date +%s%3N)
    local duration=$((end - start))
    times+=("$duration")

    if (( i % 10 == 0 )); then
      echo -n "."
    fi
  done
  echo ""

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

  echo "litellm_single,latency,$p50,$p95,$p99,$mean" >> "$RESULTS_FILE"

  ok "LiteLLM single: p50=${p50}ms, p95=${p95}ms, p99=${p99}ms, mean=${mean}ms"
}

# ── Main Benchmark Flow ────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   claudeme Performance Benchmark                ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  # Check prerequisites
  msg "Checking prerequisites..."
  check_command curl || exit 1
  check_command llama-server || warn "llama-server not found - install llama.cpp"
  check_command litellm || warn "litellm not found - run: pip install litellm[proxy]"

  # Create results directory
  mkdir -p "$RESULTS_DIR"

  # Write CSV header
  echo "scenario,metric,p50,p95,p99,mean" > "$RESULTS_FILE"

  msg "Results will be saved to: $RESULTS_FILE"
  msg "Requests per scenario: $NUM_REQUESTS"
  msg "Prompt: \"$PROMPT\""
  msg "Max tokens: $MAX_TOKENS"
  echo ""

  # ── Scenario 1: Check if llama-server is running ──
  msg "Checking for llama-server on :$LLAMA_PORT..."
  if ! curl -sf http://localhost:$LLAMA_PORT/health &>/dev/null; then
    err "llama-server not running on :$LLAMA_PORT"
    msg "Start it with: llama-server --model /path/to/model.gguf --port $LLAMA_PORT --api-type anthropic"
    exit 1
  fi
  ok "llama-server running on :$LLAMA_PORT"
  echo ""

  # ── Scenario 1: Direct llama.cpp (baseline) ──
  benchmark_direct_llama
  echo ""

  # ── Scenario 2: LiteLLM → llama.cpp ──
  msg "Checking for LiteLLM on :$LITELLM_PORT..."
  if ! curl -sf http://localhost:$LITELLM_PORT/health &>/dev/null; then
    warn "LiteLLM not running on :$LITELLM_PORT"
    msg "Start it with: litellm --model openai/localhost:$LLAMA_PORT/v1 --api_base http://localhost:$LLAMA_PORT --port $LITELLM_PORT"
    msg "Skipping LiteLLM benchmarks"
  else
    ok "LiteLLM running on :$LITELLM_PORT"
    echo ""
    benchmark_litellm_single
  fi

  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Benchmark Complete                            ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  # Summary
  msg "Results:"
  cat "$RESULTS_FILE"
  echo ""

  # Calculate overhead if both tests ran
  if [[ $(wc -l < "$RESULTS_FILE") -gt 2 ]]; then
    local direct_mean=$(awk -F, '/direct_llama/ {print $6}' "$RESULTS_FILE")
    local litellm_mean=$(awk -F, '/litellm_single/ {print $6}' "$RESULTS_FILE")
    local overhead=$((litellm_mean - direct_mean))
    local overhead_pct=$((overhead * 100 / direct_mean))

    echo ""
    if [[ $overhead -lt 5 ]]; then
      ok "LiteLLM overhead: ${overhead}ms (${overhead_pct}%) - Negligible!"
    elif [[ $overhead -lt 15 ]]; then
      warn "LiteLLM overhead: ${overhead}ms (${overhead_pct}%) - Acceptable for flexibility"
    else
      err "LiteLLM overhead: ${overhead}ms (${overhead_pct}%) - Significant impact"
    fi
  fi

  echo ""
  msg "Analyze with: cat $RESULTS_FILE"
}

main "$@"
