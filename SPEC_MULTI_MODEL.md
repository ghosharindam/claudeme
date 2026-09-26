# Multi-Model Support Specification

## Overview

Enable model switching via `/model` command when using local backends (llama.cpp, Ollama) by leveraging LiteLLM's multi-model routing.

## Current State

### Direct llama.cpp
```bash
llama-server --model model.gguf --port 8080 --api-type anthropic
claudeme  # connects to :8080
```
- ✅ **Pros**: Direct connection, minimal latency overhead
- ❌ **Cons**: Single model, no switching without restart

### Ollama via LiteLLM
```bash
ollama serve  # :11434
litellm --model ollama/llama3.2 --port 4000
claudeme  # connects to :4000 → :11434
```
- ✅ **Pros**: Works with Ollama (API translation)
- ❌ **Cons**: Single model, extra hop (latency overhead)

## Proposed Solution

### LiteLLM Multi-Model Config

**Setup:**
```yaml
# ~/.claudeme/litellm_config.yaml
model_list:
  - model_name: fast
    litellm_params:
      model: openai/localhost:8080/v1
      api_base: http://localhost:8080
      
  - model_name: smart
    litellm_params:
      model: openai/localhost:8081/v1
      api_base: http://localhost:8081
      
  - model_name: ollama-code
    litellm_params:
      model: ollama/qwen2.5-coder:7b
```

**Usage:**
```bash
claudeme
/model fast      # Switch to llama.cpp on :8080
/model smart     # Switch to llama.cpp on :8081
/model ollama-code  # Switch to Ollama model
```

## Trade-offs to Measure

### Performance Impact
- **Latency overhead**: Direct vs. LiteLLM proxy
- **Throughput**: Requests/second
- **Memory**: Extra process overhead
- **Streaming**: Impact on token streaming latency

### Benefits
- Model switching without restart
- Mix llama.cpp + Ollama + cloud
- Load balancing across instances
- Unified logging/monitoring

## Success Criteria

1. **Functionality**: `/model` command works to switch between models
2. **Performance**: LiteLLM overhead <10ms (p99) for typical requests
3. **Reliability**: No crashes under load, graceful failover
4. **UX**: Clear error messages if model unavailable

## Test Plan

### 1. Functional Tests
- ✅ Model switching works (`/model X`)
- ✅ Each model responds correctly
- ✅ Streaming works with all models
- ✅ Error handling when model unavailable
- ✅ Fallback behavior

### 2. Performance Benchmarks

#### Scenarios to test:
1. **Direct llama.cpp** (baseline)
2. **LiteLLM → single llama.cpp** (overhead measurement)
3. **LiteLLM → multi llama.cpp** (routing overhead)
4. **LiteLLM → Ollama** (existing case)

#### Metrics:
- **Time to first token (TTFT)**: Streaming responsiveness
- **Tokens per second (TPS)**: Throughput
- **Request latency (p50, p95, p99)**: Distribution
- **Memory usage**: Process overhead

#### Test cases:
- **Short prompt (10 tokens)** → measure routing overhead
- **Long prompt (1000 tokens)** → measure processing
- **Concurrent requests** → measure queueing/parallelism

### 3. Load Tests
- 10 concurrent requests
- 100 sequential requests
- Mixed workload (short + long)

## Benchmark Tooling

### Tools needed:
1. `benchmark.sh` - Run performance tests
2. `test-model-switching.sh` - Functional tests
3. `analyze-results.py` - Parse and visualize results

### Benchmark script outline:
```bash
# benchmark.sh
# 1. Start backends (llama.cpp on :8080, :8081)
# 2. Test direct llama.cpp (baseline)
# 3. Start LiteLLM with single-model config
# 4. Test LiteLLM → single llama.cpp (overhead)
# 5. Update LiteLLM to multi-model config
# 6. Test LiteLLM → multi llama.cpp (routing)
# 7. Compare results
```

## Implementation Plan

### Phase 1: Benchmarking (Current State)
- [ ] Create benchmark script
- [ ] Measure direct llama.cpp performance
- [ ] Measure LiteLLM → llama.cpp overhead
- [ ] Document baseline metrics

### Phase 2: Multi-Model Implementation
- [ ] Create example `litellm_config.yaml`
- [ ] Document setup in README
- [ ] Add to BEHAVIOR.md
- [ ] Create helper script to generate config

### Phase 3: Validation
- [ ] Run benchmarks with multi-model config
- [ ] Compare against baseline
- [ ] Decision: Keep both options or recommend one?

### Phase 4: Documentation
- [ ] Document performance characteristics
- [ ] Provide guidance: when to use direct vs. LiteLLM
- [ ] Add troubleshooting section

## Decision Matrix

After benchmarking, decide based on:

| Overhead | Recommendation |
|----------|----------------|
| <5ms p99 | ✅ Recommend LiteLLM by default (flexibility wins) |
| 5-15ms p99 | ⚖️ Document both, let user choose based on need |
| >15ms p99 | ❌ Keep direct as default, LiteLLM optional for multi-model |

## Open Questions

1. **Config location**: `~/.claudeme/litellm_config.yaml` or per-project?
2. **Auto-detection**: Should claudeme detect and use existing LiteLLM config?
3. **Model naming**: Convention for model names in config?
4. **Fallback**: What happens if requested model unavailable?
5. **Cloud models**: Should config support API keys for cloud fallback?

## Non-Goals (Out of Scope)

- ❌ Auto-starting llama-server instances
- ❌ Auto-downloading models
- ❌ Model quantization or optimization
- ❌ Built-in model management (that's Ollama's job)

## References

- LiteLLM docs: https://docs.litellm.ai/docs/proxy/configs
- llama.cpp API docs: https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md
- Ollama API docs: https://github.com/ollama/ollama/blob/main/docs/api.md
