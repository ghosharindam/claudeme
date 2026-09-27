# Benchmark Utility

Performance benchmarking system for claudeme with fair comparison methodology and bias detection.

## Quick Start

```bash
# 1. Check system state and clean up if needed
./benchmark-run cleanup

# 2. Run all benchmarks
./benchmark-run

# 3. View results
cat results/latest.csv
```

## Commands

```bash
benchmark-run              # Run all benchmark scenarios
benchmark-run baseline     # Run baseline benchmark only
benchmark-run cleanup      # Show what's using RAM/CPU
benchmark-run state        # Capture current system state
benchmark-run help         # Show detailed help
```

## What It Does

- **Benchmarks multiple scenarios** (llama-server direct, via LiteLLM, Ollama, etc.)
- **Detects system bias** (memory pressure, CPU load, running servers)
- **Captures metadata** (tool versions, hardware, timestamps)
- **Recommends cleanup** (which apps to kill for fair tests)
- **Groups multi-process apps** (catches VSCode using 5GB across helpers!)

## Example Output

```
# Application RAM Totals (multiple processes grouped):
#
# - Google Chrome       25 procs   7563MB  (7.3GB)
#   Kill: pkill -x 'Google Chrome'
#
# - Visual Studio Code  10 procs   5120MB  (5.0GB)
#   Kill: code --stop
#
# - Claude Code          9 procs   1449MB  (1.4GB)
#   ⚠️  Don't kill - this is your current Claude Code session!
```

## Configuration

Edit `config.yaml` to customize:
- Which backends to test
- Test scenarios
- Number of requests
- Prompts and parameters

## Results

Results are saved to `results/` with full metadata:

```
results/
├── baseline_20260927_095351.csv    ← Timestamped results
├── system_state_20260927_095351.txt
└── environment_20260927_095351.txt
```

Each result includes:
- Latency metrics (p50, p95, p99)
- System state (RAM, CPU, swap)
- Running model servers
- Tool versions
- Bias warnings

## Fair Benchmarking

See [BEST_PRACTICES.md](BEST_PRACTICES.md) for:
- How to ensure fair comparisons
- When to use isolated vs. consistent state
- What makes results valid vs. invalid
- Troubleshooting guide

## Development

Internal scripts are in `lib/`:
- `baseline.sh` - Direct llama-server benchmark
- `run-all.sh` - Run all configured scenarios
- `capture-env.sh` - Capture tool versions
- `capture-system-state.sh` - Detect bias and system state

## Installation

Installed automatically by claudeme's main installer:

```bash
cd ~/Documents/my_workspace/claudeme
./install.sh
# ✅ Installs benchmark-run to ~/.local/bin/

# Then use anywhere:
benchmark-run
```

## Use Cases

- **Before implementing multi-model support** - Measure LiteLLM overhead
- **After performance changes** - Verify no regression
- **Comparing backends** - llama-server vs Ollama
- **System diagnostics** - See what's using resources
