#!/usr/bin/env bash
# Test the llama-server API (requires IAP tunnel to be open via: make llm-tunnel)
# Usage: ./llm/api-test.sh [port]
set -euo pipefail

PORT="${1:-8080}"
BASE="http://localhost:${PORT}"

echo "=== llama-server health check ==="
curl -sf "${BASE}/health" | python3 -m json.tool || {
  echo "ERROR: Cannot reach llama-server on port ${PORT}"
  echo "  Start IAP tunnel first: make llm-tunnel"
  exit 1
}

echo ""
echo "=== Model info ==="
curl -sf "${BASE}/v1/models" | python3 -m json.tool

echo ""
echo "=== Quick chat test (Qwen3 thinking mode) ==="
curl -sf "${BASE}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3",
    "messages": [{"role": "user", "content": "Say hello in 10 words."}],
    "max_tokens": 128,
    "stream": false
  }' | python3 -m json.tool

echo ""
echo "=== OpenAI-compatible endpoint ready at ${BASE}/v1 ==="
