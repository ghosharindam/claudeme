#!/usr/bin/env bash
# test-model-switching.sh - Functional tests for model switching
#
# Tests that /model command works correctly with LiteLLM multi-model config

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────

LITELLM_PORT=4000
TEST_PROMPT="Say 'test passed' and nothing else."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Utilities ──────────────────────────────────────────────────────────────────

ok() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
msg() { echo -e "${BLUE}→${NC} $*"; }

test_model() {
  local model_name="$1"
  msg "Testing model: $model_name"

  local response
  response=$(curl -sf http://localhost:$LITELLM_PORT/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$model_name\",
      \"messages\": [{\"role\": \"user\", \"content\": \"$TEST_PROMPT\"}],
      \"max_tokens\": 20
    }" 2>/dev/null) || {
    fail "Failed to get response from $model_name"
    return 1
  }

  if echo "$response" | grep -q "test passed"; then
    ok "$model_name responded correctly"
    return 0
  else
    fail "$model_name response unexpected"
    echo "Response: $response"
    return 1
  fi
}

# ── Main ───────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Model Switching Functional Tests              ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""

  # Check if LiteLLM is running
  msg "Checking LiteLLM on :$LITELLM_PORT..."
  if ! curl -sf http://localhost:$LITELLM_PORT/health &>/dev/null; then
    fail "LiteLLM not running on :$LITELLM_PORT"
    msg "Start it with: litellm --config examples/litellm_multi_model.yaml --port $LITELLM_PORT"
    exit 1
  fi
  ok "LiteLLM running"
  echo ""

  # Test each configured model
  local passed=0
  local failed=0

  # Get list of models
  msg "Fetching available models..."
  local models
  models=$(curl -sf http://localhost:$LITELLM_PORT/v1/models | jq -r '.data[].id' 2>/dev/null) || {
    fail "Could not fetch model list"
    exit 1
  }

  echo "Available models:"
  echo "$models" | sed 's/^/  - /'
  echo ""

  # Test each model
  for model in $models; do
    if test_model "$model"; then
      ((passed++)) || true
    else
      ((failed++)) || true
    fi
    echo ""
  done

  # Summary
  echo "╔══════════════════════════════════════════════════╗"
  echo "║   Test Summary                                   ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  ok "Passed: $passed"
  if [[ $failed -gt 0 ]]; then
    fail "Failed: $failed"
    exit 1
  else
    ok "All tests passed!"
  fi
}

main "$@"
