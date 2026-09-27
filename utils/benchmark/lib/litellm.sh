#!/usr/bin/env bash
# Benchmark LiteLLM → llama-server

LITELLM_PORT=4000
REQUESTS=10
PROMPT="Explain quantum computing in one sentence."

echo "Checking LiteLLM on :$LITELLM_PORT..."
if ! curl -sf http://localhost:$LITELLM_PORT/health &>/dev/null; then
  echo "❌ LiteLLM not running"
  echo "Start it with: /tmp/start-litellm.sh"
  exit 1
fi
echo "✅ LiteLLM running"
echo ""

echo "Benchmarking LiteLLM → llama-server ($REQUESTS requests)..."

times=()
for i in $(seq 1 $REQUESTS); do
  start=$(python3 -c 'import time; print(int(time.time() * 1000))')
  
  curl -sf http://localhost:$LITELLM_PORT/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"local\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":50,\"stream\":false}" \
    > /dev/null
  
  end=$(python3 -c 'import time; print(int(time.time() * 1000))')
  duration=$((end - start))
  times+=($duration)
  echo "Request $i: ${duration}ms"
done

# Calculate stats
sorted=($(printf '%s\n' "${times[@]}" | sort -n))
count=${#sorted[@]}
sum=0
for t in "${times[@]}"; do sum=$((sum + t)); done
mean=$((sum / count))
p50=${sorted[$((count / 2))]}
p95=${sorted[$((count * 95 / 100))]}

echo ""
echo "Results (LiteLLM):"
echo "  Mean: ${mean}ms"
echo "  p50:  ${p50}ms"
echo "  p95:  ${p95}ms"
echo ""

# Compare with baseline (from previous run)
BASELINE_MEAN=1393
overhead=$((mean - BASELINE_MEAN))
overhead_pct=$((overhead * 100 / BASELINE_MEAN))

echo "Comparison:"
echo "  Direct llama-server: ${BASELINE_MEAN}ms (baseline)"
echo "  LiteLLM → llama:     ${mean}ms"
echo "  Overhead:            ${overhead}ms (${overhead_pct}%)"
echo ""

if [[ $overhead -lt 50 ]]; then
  echo "✅ Overhead <50ms: Negligible - LiteLLM is worth it for flexibility!"
elif [[ $overhead -lt 150 ]]; then
  echo "⚠️  Overhead <150ms: Noticeable but acceptable for multi-model support"
else
  echo "❌ Overhead >${overhead}ms: Significant - may want to keep direct connection"
fi
