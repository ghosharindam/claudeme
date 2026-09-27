#!/usr/bin/env bash
# capture-env.sh - Capture system/tool versions for benchmark runs
#
# Usage: source ./capture-env.sh
# Sets variables: BENCH_DATE, BENCH_SYSTEM, BENCH_VERSIONS

BENCH_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
BENCH_SYSTEM="$(uname -s) $(uname -m)"

# Capture tool versions
get_version() {
  local tool="$1"
  local version="unknown"

  case "$tool" in
    llama-server)
      if command -v llama-server &>/dev/null; then
        version=$(llama-server --version 2>&1 | head -1 || echo "unknown")
      fi
      ;;
    litellm)
      if command -v litellm &>/dev/null; then
        version=$(litellm --version 2>&1 | head -1 || echo "unknown")
      fi
      ;;
    ollama)
      if command -v ollama &>/dev/null; then
        version=$(ollama --version 2>&1 || echo "unknown")
      fi
      ;;
    python)
      version=$(python3 --version 2>&1 || echo "unknown")
      ;;
  esac

  echo "$version"
}

# Build version string
LLAMA_VERSION=$(get_version llama-server)
LITELLM_VERSION=$(get_version litellm)
OLLAMA_VERSION=$(get_version ollama)
PYTHON_VERSION=$(get_version python)

# Hardware info
if [[ "$(uname -s)" == "Darwin" ]]; then
  CPU_INFO=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
  TOTAL_RAM=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024) "GB"}' || echo "unknown")
else
  CPU_INFO=$(lscpu | grep "Model name" | cut -d: -f2 | xargs || echo "unknown")
  TOTAL_RAM=$(free -h | awk '/^Mem:/ {print $2}' || echo "unknown")
fi

# Check for GPU
GPU_INFO="none"
if command -v nvidia-smi &>/dev/null; then
  GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "unknown")
elif [[ "$(uname -s)" == "Darwin" ]]; then
  # macOS - check for Apple Silicon GPU
  if sysctl -n machdep.cpu.brand_string | grep -q "Apple"; then
    GPU_INFO="Apple Silicon (integrated)"
  fi
fi

# Export for use in benchmark scripts
export BENCH_DATE
export BENCH_SYSTEM
export BENCH_CPU="$CPU_INFO"
export BENCH_RAM="$TOTAL_RAM"
export BENCH_GPU="$GPU_INFO"
export BENCH_LLAMA_VERSION="$LLAMA_VERSION"
export BENCH_LITELLM_VERSION="$LITELLM_VERSION"
export BENCH_OLLAMA_VERSION="$OLLAMA_VERSION"
export BENCH_PYTHON_VERSION="$PYTHON_VERSION"

# Function to write metadata to file
write_metadata() {
  local output_file="$1"

  cat >> "$output_file" << EOF
# Benchmark Metadata
# Date: $BENCH_DATE
# System: $BENCH_SYSTEM
# CPU: $BENCH_CPU
# RAM: $BENCH_RAM
# GPU: $BENCH_GPU
# llama-server: $BENCH_LLAMA_VERSION
# LiteLLM: $BENCH_LITELLM_VERSION
# Ollama: $BENCH_OLLAMA_VERSION
# Python: $BENCH_PYTHON_VERSION
#
# Results:
EOF
}

# Function to print environment summary
print_env() {
  echo "Benchmark Environment:"
  echo "  Date:          $BENCH_DATE"
  echo "  System:        $BENCH_SYSTEM"
  echo "  CPU:           $BENCH_CPU"
  echo "  RAM:           $BENCH_RAM"
  echo "  GPU:           $BENCH_GPU"
  echo "  llama-server:  $BENCH_LLAMA_VERSION"
  echo "  LiteLLM:       $BENCH_LITELLM_VERSION"
  echo "  Ollama:        $BENCH_OLLAMA_VERSION"
  echo "  Python:        $BENCH_PYTHON_VERSION"
  echo ""
}
