# Test Suite

## Overview

This directory contains tests and benchmarks for claudeme routing strategies.

## Files

- **`benchmark.sh`** — Performance benchmarking (latency, throughput)
- **`test-model-switching.sh`** — Functional tests for multi-model support
- **`benchmark_results/`** — Benchmark output (CSV files)

---

## Running Benchmarks

### Prerequisites

**1. Install llama.cpp:**
```bash
# Clone and build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make
```

**2. Download a model:**
```bash
# Example: Llama 3.2 8B
huggingface-cli download \
  meta-llama/Llama-3.2-8B-Instruct-GGUF \
  llama-3.2-8b-instruct-q4_k_m.gguf \
  --local-dir ./models
```

**3. Install LiteLLM:**
```bash
pip install 'litellm[proxy]'
```

---

### Scenario 1: Direct llama.cpp (Baseline)

**Start llama-server:**
```bash
llama-server \
  --model ./models/llama-3.2-8b-instruct-q4_k_m.gguf \
  --port 8080 \
  --api-type anthropic \
  --n-gpu-layers 99
```

**Run benchmark:**
```bash
cd test
./benchmark.sh
```

**Expected output:**
```
Direct llama.cpp: p50=150ms, p95=200ms, p99=250ms, mean=160ms
```

---

### Scenario 2: LiteLLM → llama.cpp (Overhead Test)

**Terminal 1 - llama-server:**
```bash
llama-server \
  --model ./models/llama-3.2-8b-instruct-q4_k_m.gguf \
  --port 8080 \
  --api-type anthropic
```

**Terminal 2 - LiteLLM:**
```bash
litellm \
  --model openai/localhost:8080/v1 \
  --api_base http://localhost:8080 \
  --port 4000
```

**Terminal 3 - Benchmark:**
```bash
cd test
./benchmark.sh
```

**Expected output:**
```
Direct llama.cpp: p50=150ms, p95=200ms, p99=250ms, mean=160ms
LiteLLM single: p50=155ms, p95=210ms, p99=260ms, mean=165ms
LiteLLM overhead: 5ms (3%) - Negligible!
```

---

### Scenario 3: Multi-Model Setup (Full Test)

**Terminal 1 - llama-server (fast):**
```bash
llama-server \
  --model ./models/llama-3.2-8b-instruct-q4_k_m.gguf \
  --port 8080 \
  --api-type anthropic
```

**Terminal 2 - llama-server (smart, if you have 70B):**
```bash
llama-server \
  --model ./models/llama-3.1-70b-instruct-q4_k_m.gguf \
  --port 8081 \
  --api-type anthropic
```

**Terminal 3 - Ollama (optional):**
```bash
ollama serve
```

**Terminal 4 - LiteLLM with multi-model config:**
```bash
litellm --config ../examples/litellm_multi_model.yaml --port 4000
```

**Terminal 5 - Functional tests:**
```bash
cd test
./test-model-switching.sh
```

**Expected output:**
```
╔══════════════════════════════════════════════════╗
║   Model Switching Functional Tests              ║
╚══════════════════════════════════════════════════╝

Available models:
  - fast
  - smart
  - ollama-llama3

✓ fast responded correctly
✓ smart responded correctly
✓ ollama-llama3 responded correctly

╔══════════════════════════════════════════════════╗
║   Test Summary                                   ║
╚══════════════════════════════════════════════════╝

✓ Passed: 3
✓ All tests passed!
```

---

## Benchmark Results

Results are saved to `benchmark_results/benchmark_YYYYMMDD_HHMMSS.csv`:

```csv
scenario,metric,p50,p95,p99,mean
direct_llama,latency,150,200,250,160
litellm_single,latency,155,210,260,165
```

---

## Interpreting Results

### Overhead Thresholds

| Overhead (p99) | Assessment | Recommendation |
|----------------|------------|----------------|
| <5ms | ✅ Negligible | Use LiteLLM by default (flexibility wins) |
| 5-15ms | ⚖️ Acceptable | Document both options, let user choose |
| >15ms | ❌ Significant | Keep direct as default, LiteLLM optional |

### Factors Affecting Overhead

- **Network latency**: All localhost, should be <1ms
- **JSON parsing**: LiteLLM parses request/response
- **Routing logic**: Model lookup and selection
- **Process overhead**: Extra hop through proxy

---

## Troubleshooting

### "llama-server not running"
```bash
# Start llama-server first
llama-server --model model.gguf --port 8080 --api-type anthropic
```

### "LiteLLM not running"
```bash
# Start LiteLLM
litellm --config ../examples/litellm_multi_model.yaml --port 4000
```

### "Model not responding"
Check logs:
```bash
# llama-server logs (stdout)
# LiteLLM logs (add --debug flag)
litellm --config config.yaml --port 4000 --debug
```

---

## Next Steps

After running benchmarks:

1. **Review results** in `benchmark_results/`
2. **Calculate overhead** (LiteLLM vs. direct)
3. **Make decision**: See `SPEC_MULTI_MODEL.md` decision matrix
4. **Document findings** in a benchmark report
5. **Update README** with recommendations

---

## Example Workflow

```bash
# 1. Set up backends
llama-server --model model.gguf --port 8080 --api-type anthropic &
LLAMA_PID=$!

# 2. Run baseline benchmark
./benchmark.sh

# 3. Start LiteLLM
litellm --model openai/localhost:8080/v1 --api_base http://localhost:8080 --port 4000 &
LITELLM_PID=$!

# 4. Run overhead benchmark
./benchmark.sh

# 5. Review results
cat benchmark_results/benchmark_*.csv

# 6. Cleanup
kill $LLAMA_PID $LITELLM_PID
```
