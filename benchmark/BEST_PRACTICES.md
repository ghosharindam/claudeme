# Benchmarking Best Practices

## Goal: Apples-to-Apples Comparison

Fair benchmarks require **consistent system state** across all test runs.

## The Problem

**Bad Example:**
```bash
# Test 1: Only Ollama running
ollama serve
./benchmark ollama           # 1500ms

# Test 2: Both Ollama + llama-server running
llama-server --model model.gguf --port 8080 &
./benchmark llama-server     # 2000ms ← BIASED!
```

**Why biased?**
- llama-server test has **less available RAM** (Ollama still loaded)
- llama-server test has **CPU contention** (Ollama in background)
- Results aren't comparable

---

## Solution A: Isolated Testing (Most Accurate)

**Stop all servers between tests:**

```bash
# Test 1: Ollama only
pkill ollama llama-server litellm  # Clean slate
ollama serve
./benchmark ollama-via-litellm
pkill ollama litellm

# Test 2: llama-server only
pkill ollama llama-server litellm  # Clean slate again
llama-server --model model.gguf --port 8080
./benchmark llama-direct
pkill llama-server
```

**Pros:**
- ✅ Most accurate absolute numbers
- ✅ No memory/CPU contention
- ✅ True apples-to-apples comparison

**Cons:**
- ❌ Slower (restart between tests)
- ❌ More manual work

---

## Solution B: Consistent State (Faster)

**Start ALL servers, test all scenarios:**

```bash
# Start everything ONCE
ollama serve &
llama-server --model model.gguf --port 8080 &
litellm --config config.yaml --port 4000 &

# Run ALL benchmarks with same system state
./benchmark ollama-via-litellm
./benchmark llama-direct
./benchmark llama-via-litellm

# Overhead comparisons are valid!
```

**Pros:**
- ✅ Faster (no restarts)
- ✅ Overhead comparisons still valid
- ✅ Reflects real multi-model usage

**Cons:**
- ❌ Absolute numbers slower than isolated
- ❌ Not true baseline performance

---

## What Gets Captured

Every benchmark run logs:

```
# System State Snapshot
# Date: 2026-09-27 09:05:13 UTC
#
# Memory:
# - Total: 36GB
# - Used: 15GB (43%)
# - Available: 21GB
#
# CPU Load (5min avg): 2.89
#
# Running Model Servers:
# - llama-server (PID 11926, Port 52123, RAM 1833MB)
# - ollama (PID 13090, RAM 31MB)
# - litellm (PID 14523, RAM 145MB)
#
# Heavy Processes (>500MB RAM):
# - Bitdefender (1209MB, CPU 37.2%)
# - Brave Browser (546MB, CPU 0.5%)
#
# ⚠️  BIAS WARNINGS:
#    - Multiple model servers running - memory/CPU contention possible
#    - High CPU load (2.89) - system under stress
```

---

## Best Practices Checklist

### Before Benchmarking:

- [ ] **Close heavy apps** (browsers, IDEs, Slack, etc.)
- [ ] **Stop background processes** (antivirus scans, backups, indexing)
- [ ] **Decide on approach**: Isolated (accurate) or Consistent (fast)
- [ ] **Warmup**: Run 2-3 requests before timing (warm caches)
- [ ] **Check system load**: `uptime` - should be <1.0 ideally

### During Benchmarking:

- [ ] **Don't use the computer** (browsing, coding, etc.)
- [ ] **Run multiple times** (3-5 runs, report median)
- [ ] **Check for outliers** (if one run is 2x slower, discard it)

### After Benchmarking:

- [ ] **Review system state logs** in result files
- [ ] **Compare only same-state runs** (both isolated, or both consistent)
- [ ] **Document your approach** (which method you used)

---

## Interpreting Results

### Valid Comparisons:

✅ **Overhead measurement** (Consistent State):
```
All servers running:
  llama-direct:      1500ms
  llama-via-litellm: 1530ms
  Overhead: 30ms (2%) ← VALID
```

✅ **Absolute performance** (Isolated):
```
Only one server per test:
  llama-direct:      1200ms ← True baseline
  ollama-via-litellm: 1800ms ← Different backend
```

### Invalid Comparisons:

❌ **Mixed approaches**:
```
Isolated:
  llama-direct:      1200ms

Consistent (all servers):
  llama-via-litellm: 1530ms
  
  Overhead: 330ms ← WRONG! Comparing different system states
```

---

## Example Workflow

### Scenario: Measure LiteLLM Overhead

**Goal:** Is the LiteLLM proxy overhead acceptable?

**Approach:** Consistent State (faster, overhead comparison valid)

```bash
# 1. Start all servers
llama-server --model model.gguf --port 8080 &
litellm --model openai/localhost:8080/v1 --port 4000 &

# 2. Run benchmarks (same system state)
./benchmark/scripts/run-all.sh

# 3. Results
# llama-direct:      1450ms
# llama-via-litellm: 1480ms
# Overhead: 30ms (2%) ← VALID comparison
```

**Conclusion:** 30ms overhead is negligible → LiteLLM is worth it!

---

## Troubleshooting

### "Results are inconsistent"
- Check CPU load during test (`uptime`)
- Close background apps
- Run more iterations (5-10 instead of 3)
- Check if thermal throttling (long tests on laptop)

### "Bias warnings"
- Follow recommendations in benchmark output
- Restart tests with proper isolation
- Document the warnings in results

### "Overhead seems huge"
- Verify you're comparing same system state
- Check if LiteLLM is actually routing to the right backend
- Test direct connection first to establish baseline

---

## Statistical Validity

For production-grade benchmarks:

1. **Multiple runs**: Minimum 10 iterations
2. **Discard outliers**: Remove top/bottom 10%
3. **Report distribution**: Mean, median, p50, p95, p99, stddev
4. **Control temperature**: Let GPU cool between runs
5. **Same time of day**: System load varies (avoid peak hours)

---

## Summary

| Approach | When to Use | Pros | Cons |
|----------|-------------|------|------|
| **Isolated** | Absolute performance | Most accurate | Slow, manual |
| **Consistent** | Overhead comparison | Fast, valid overhead | Slower absolute |

**Key Rule:** Whatever approach you choose, **stay consistent** across all test scenarios!
