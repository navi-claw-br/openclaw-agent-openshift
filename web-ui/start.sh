#!/bin/bash
# Startup wrapper: inicializa OpenClaw workspace + sobe Web UI
set -e

echo "╔═══════════════════════════════════════════════╗"
echo "║  ⚔️  OpenClaw Agent — Web UI + MCP Admin     ║"
echo "╚═══════════════════════════════════════════════╝"

DATA_ROOT="${DATA_ROOT:-/data}"
OPENCLAW_AGENT_ID="${OPENCLAW_AGENT_ID:-hanna}"

# ── Garante que o OpenClaw está onboard ──
if [ ! -f "$DATA_ROOT/.openclaw/identity.yaml" ]; then
  echo "[start] Inicializando workspace OpenClaw..."
  openclaw onboard --non-interactive --accept-risk --workspace "$DATA_ROOT" 2>&1 || true
fi

# ── Configura credenciais se DEEPSEEK_API_KEY estiver presente ──
if [ -n "$DEEPSEEK_API_KEY" ]; then
  echo "[start] Configurando modelo e credentials..."
  openclaw models set "$OPENCLAW_INITIAL_MODEL" 2>&1 || true
  openclaw onboard --non-interactive --accept-risk --deepseek-api-key "$DEEPSEEK_API_KEY" --skip-health 2>&1 || true
fi

# ── Configura MCP do Morador Online se MORADOR_ONLINE_MCP_JSON estiver presente ──
if [ -n "$MORADOR_ONLINE_MCP_JSON" ]; then
  echo "[start] Registrando MCP do Morador Online..."
  echo "$MORADOR_ONLINE_MCP_JSON" | openclaw mcp set morador-online --json-stdin 2>&1 || true
fi

# ── Verifica que o openclaw funciona ──
echo "[start] Verificando OpenClaw CLI..."
openclaw --version 2>&1 || echo "[start] AVISO: openclaw CLI não encontrado no PATH"

# ── Start Web UI (foreground) ──
echo "[start] Iniciando Web UI na porta ${WEB_PORT:-8080}..."
exec python3 /opt/openclaw-web/openclaw-web.py
