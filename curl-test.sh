#!/bin/bash
# Teste do OpenClaw Agent com DeepSeek via OpenShift
# (ajuste a URL conforme sua rota)

OPENCLAW_URL="${1:-https://openclaw-agent-openclaw.apps.cluster1.sandbox1992.opentlc.com}"

echo "=== Health Check ==="
curl -sk "$OPENCLAW_URL/" | head -5

echo ""
echo "=== Login Test ==="
curl -sk -X POST "$OPENCLAW_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"test123"}' | python3 -m json.tool 2>/dev/null || echo "(login esperado - precisa de credenciais reais)"

echo ""
echo "=== MCP Tools List ==="
# Primeiro faz login para pegar token
TOKEN=$(curl -sk -X POST "$OPENCLAW_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"test123"}' 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)

if [ -n "$TOKEN" ]; then
  curl -sk "$OPENCLAW_URL/api/mcp/tools" \
    -H "Authorization: Bearer $TOKEN" | python3 -m json.tool 2>/dev/null
fi
