#!/usr/bin/env bash
# Baseline benchmark - Direct llama-server

# Source environment capture
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/capture-env.sh"

PORT=52123
REQUESTS=10
PROMPT="Explain quantum computing in one sentence."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$SCRIPT_DIR/../results/${TIMESTAMP}_baseline.csv"

# Print environment
print_env

echo "Benchmarking llama-server on :$PORT ($REQUESTS requests)..."
echo "Results will be saved to: $OUTPUT_FILE"
echo ""

times=()
for i in $(seq 1 $REQUESTS); do
  start=$(python3 -c 'import time; print(int(time.time() * 1000))')
  
  curl -sf http://localhost:$PORT/v1/chat/completions \
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
echo "Results:"
echo "  Mean: ${mean}ms"
echo "  p50:  ${p50}ms"
echo "  p95:  ${p95}ms"

# Save results with metadata
mkdir -p "$(dirname "$OUTPUT_FILE")"
write_metadata "$OUTPUT_FILE"
echo "scenario,metric,mean,p50,p95" >> "$OUTPUT_FILE"
echo "direct_llama,latency,$mean,$p50,$p95" >> "$OUTPUT_FILE"

echo ""
echo "✅ Results saved to: $OUTPUT_FILE"
