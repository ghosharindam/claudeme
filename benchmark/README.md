# Benchmark Suite

Performance benchmarking for claudeme routing strategies.

## Structure

```
benchmark/
├── scripts/          # Benchmark scripts
│   ├── baseline.sh   # Direct llama-server/Ollama (baseline)
│   ├── litellm.sh    # LiteLLM overhead test
│   └── ollama.sh     # Ollama-specific benchmarks
└── results/          # Results (gitignored except baselines)
    ├── YYYY-MM-DD_baseline.csv
    └── YYYY-MM-DD_litellm.csv
```

## Quick Start

### 1. Baseline (Direct Connection)

**If using llama-server:**
```bash
# Make sure llama-server is running
./benchmark/scripts/baseline.sh
```

**If using Ollama:**
```bash
# Make sure Ollama is running
./benchmark/scripts/ollama.sh
```

Results: `benchmark/results/<timestamp>_baseline.csv`

### 2. LiteLLM Overhead

**Start LiteLLM:**
```bash
# For llama-server on port 52123:
litellm --model openai/localhost:52123/v1 --api_base http://localhost:52123 --port 4000

# For Ollama:
litellm --model ollama/qwen2.5:7b-instruct --port 4000
```

**Run overhead test:**
```bash
./benchmark/scripts/litellm.sh
```

Results: `benchmark/results/<timestamp>_litellm.csv`

## Interpreting Results

### Overhead Thresholds

| Overhead (mean) | Assessment | Recommendation |
|----------------|------------|----------------|
| <50ms | ✅ Negligible | Use LiteLLM for flexibility |
| 50-150ms | ⚖️ Acceptable | Worth it for multi-model |
| >150ms | ❌ Significant | Consider direct only |

### Example Output

```
Comparison:
  Direct llama-server: 1393ms (baseline)
  LiteLLM → llama:     1420ms
  Overhead:            27ms (2%)

✅ Overhead <50ms: Negligible - LiteLLM is worth it!
```

## Tracking Performance Over Time

Results are timestamped and stored in `benchmark/results/`:

```bash
# List all benchmark runs
ls -lh benchmark/results/*.csv

# Compare two runs
diff benchmark/results/20260927_baseline.csv benchmark/results/20260928_baseline.csv
```

## What Each Script Tests

### `baseline.sh`
- **Measures**: Direct connection latency
- **Requires**: llama-server running
- **Output**: Mean, p50, p95 latency

### `litellm.sh`
- **Measures**: LiteLLM proxy overhead
- **Requires**: llama-server + LiteLLM running
- **Output**: Overhead vs. baseline

### `ollama.sh`
- **Measures**: Ollama direct vs. via LiteLLM
- **Requires**: Ollama running (± LiteLLM)
- **Output**: Overhead for Ollama setup

## Decision Matrix

After running benchmarks, use these results to decide:

1. **<50ms overhead** → Document LiteLLM multi-model as recommended approach
2. **50-150ms overhead** → Document both options, explain trade-offs
3. **>150ms overhead** → Keep direct connection as default, LiteLLM optional

See `SPEC_MULTI_MODEL.md` for full decision criteria.

## Example Workflow

```bash
# 1. Run baseline
./benchmark/scripts/baseline.sh
# Output: benchmark/results/20260927_095500_baseline.csv

# 2. Start LiteLLM
litellm --model openai/localhost:52123/v1 --api_base http://localhost:52123 --port 4000 &

# 3. Run LiteLLM test
./benchmark/scripts/litellm.sh
# Output: benchmark/results/20260927_095600_litellm.csv

# 4. Review results
cat benchmark/results/*_baseline.csv
cat benchmark/results/*_litellm.csv

# 5. Make decision based on overhead
```

## Troubleshooting

### "Connection refused"
Check that the backend is running:
```bash
curl http://localhost:52123/health  # llama-server
curl http://localhost:11434/api/tags  # Ollama
curl http://localhost:4000/health  # LiteLLM
```

### Results seem inconsistent
- Run multiple times and average
- Ensure no other heavy processes running
- Check CPU/GPU load during benchmark
- Use same model and prompt length

## Contributing Results

When contributing baseline results:
1. Run on a clean system (no background load)
2. Document hardware: CPU, RAM, GPU
3. Document model: name, size, quantization
4. Run at least 3 times, report median
