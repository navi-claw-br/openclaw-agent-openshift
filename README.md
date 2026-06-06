# OpenClaw Agent on OpenShift ⚔️

Deploy [OpenClaw](https://openclaw.ai) — o executor de código com loop de aprendizado contínuo — no Red Hat OpenShift, com **Web UI própria** que autentica via **MCP do Morador Online Admin**.

```
┌─────────────────────────────────┐
│     OpenShift Cluster           │
│  ┌─────────────────────────┐    │
│  │  OpenClaw Agent Pod     │    │
│  │                         │    │
│  │  ┌───────────────────┐  │    │
│  │  │ Web UI (Python)   │  │    │
│  │  │ Port 8080         │  │    │
│  │  │ GET  /            │  │    │
│  │  │ POST /api/login   │  │    │
│  │  │ POST /api/chat    │  │    │
│  │  │ GET  /api/mcp/... │  │    │
│  │  └────────┬──────────┘  │    │
│  │           │              │    │
│  │  ┌────────▼──────────┐  │    │
│  │  │ openclaw agent    │  │    │
│  │  │ --local --json    │  │    │
│  │  │ CLI runtime       │  │    │
│  │  └────────┬──────────┘  │    │
│  │           │              │    │
│  │  ┌────────▼──────────┐  │    │
│  │  │ MCP Client        │  │    │
│  │  │ (admin auth)      │  │    │
│  │  └────────┬──────────┘  │    │
│  └───────────┼─────────────┘    │
│              │                   │
│    ┌─────────▼─────────┐        │
│    │ MCP Server Admin  │        │
│    │ (Morador Online)  │        │
│    └───────────────────┘        │
│                                  │
│    LLM Provider ─────────────────►│
│    (DeepSeek / OpenAI)           │
└─────────────────────────────────┘
         │
    OpenShift Route (TLS)
         │
    Browser / HTTP Clients
```

## O que este repositório entrega

- **Web UI responsiva** com login via MCP `autenticar` do condomínio
- **Chat em tempo real** com o OpenClaw Agent via CLI (`openclaw agent --local --json`)
- **Autenticação segura** — sessão HMAC, token MCP nunca exposto ao usuário
- **Página de MCP Tools** — lista ao vivo das ferramentas disponíveis no admin
- **Persistência** — workspace OpenClaw em PVC de 10Gi
- **Imagem UBI 9** sem root, compatível com restricted-v2 SCC
- **Kustomization completa** para deploy no OpenShift

## Arquitetura

| Componente | Tecnologia |
|------------|------------|
| Runtime de IA | OpenClaw Agent (`openclaw agent --local --json`) |
| Web UI | Python aiohttp + HTML/JS vanilla |
| Autenticação | MCP `autenticar` → sessão HMAC |
| Chat proxy | Web UI → subprocess OpenClaw CLI |
| MCP Admin | JSON-RPC sobre HTTP ao MCP Server Admin |
| Container | UBI 9, Node.js 20, Python 3.11 |
| Orquestração | OpenShift (Kustomize) |

## Pré-requisitos

- OpenShift 4.x cluster (qualquer plataforma)
- `oc` CLI autenticado
- Chave de API DeepSeek (ou OpenAI)
- URL do MCP Server Admin do Morador Online
- URL base do condomínio

## Quick Start

```bash
# 1. Clone este repositório
git clone https://github.com/navi-claw-br/openclaw-agent-openshift.git
cd openclaw-agent-openshift

# 2. Crie namespace e todos os recursos
oc apply -k manifests/

# 3. Configure as secrets (REQUERIDO — o agente não inicia sem API key)
oc create secret generic openclaw-secrets \
  --from-literal=DEEPSEEK_API_KEY=sk-your-deepseek-key \
  --from-literal=MORADOR_ONLINE_MCP_JSON='{"url":"https://mcp-server-mo-admin.mo.app.br/mcp","transport":"streamable-http"}' \
  -n openclaw

# 4. Aguarde o pod ficar pronto
oc get pods -n openclaw -w

# 5. Obtenha a URL
oc get route openclaw-agent -n openclaw -o jsonpath='https://{.spec.host}'
```

## Configuração

### ConfigMap (`04-openclaw-config.yaml`)

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `OPENCLAW_INITIAL_MODEL` | `deepseek/deepseek-v4-flash` | Modelo inicial do runtime |
| `OPENCLAW_AGENT_ID` | `hanna` | Agent ID do OpenClaw |
| `DATA_ROOT` | `/data` | Raiz persistente |
| `CONDOMINIO` | `dev.mo.app.br` | URL do condomínio |
| `MCP_ADMIN_URL` | `https://mcp-server-mo-admin.mo.app.br/mcp` | Endpoint MCP Admin |

### Secrets (criar via `oc create secret`)

| Chave | Descrição |
|-------|-----------|
| `DEEPSEEK_API_KEY` | API key DeepSeek (principal) |
| `OPENAI_API_KEY` | API key OpenAI (fallback bootstrap) |
| `MORADOR_ONLINE_MCP_JSON` | JSON de configuração MCP |

Exemplo de `MORADOR_ONLINE_MCP_JSON`:

```json
{"url":"https://mcp-server-mo-admin.mo.app.br/mcp","transport":"streamable-http"}
```

## Web UI

Após o deploy, acesse a URL do Route. Você verá:

1. **Tela de login** — entre com seu login/senha do condomínio
2. **Chat** — converse com o Agente Administrativo
3. **Integrações** — guia de canais disponíveis
4. **MCP Tools** — lista ao vivo das ferramentas MCP disponíveis
5. **Sobre** — informações da stack

### Fluxo de autenticação

```
Usuário → [login/senha] → Web UI → MCP autenticar → token MCP
                                                         ↓
Web UI armazena token em sessão HMAC ──→ usado em tools/call
                                                         ↓
Chat: system prompt injeta CONDOMINIO + token MCP ──→ OpenClaw Agent
```

O token MCP **nunca** é exposto ao usuário final. Toda chamada a ferramentas MCP é feita pelo backend da Web UI.

## Building a Imagem

```bash
# Build da imagem UBI 9
podman build -f Dockerfile.ubi \
  -t ghcr.io/navi-claw-br/openclaw-agent:latest \
  --platform linux/amd64 .

# Push
podman push ghcr.io/navi-claw-br/openclaw-agent:latest

# Atualize o deployment
oc set image deployment/openclaw-agent openclaw=ghcr.io/navi-claw-br/openclaw-agent:latest -n openclaw
```

## Armazenamento Persistente

O OpenClaw armazena em `/data` (montado via PVC de 10Gi):

- **Workspace completo** — `~/.openclaw/`
- **Identidade e auth** — `identity.yaml`, credenciais
- **Memórias e sessões** — histórico de conversas
- **Skills** — habilidades autônomas
- **Configuração MCP** — servidores registrados

Ajuste o tamanho em `03-openclaw-storage.yaml`:

```yaml
resources:
  requests:
    storage: 50Gi
```

## Comandos Úteis

```bash
# Logs
oc logs -n openclaw deployment/openclaw-agent --tail=50 -f

# Shell no pod
POD=$(oc get pods -n openclaw -l app.kubernetes.io/name=openclaw-agent -o jsonpath='{.items[0].metadata.name}')
oc exec -it "$POD" -n openclaw -- /bin/bash

# Verificar OpenClaw
oc exec "$POD" -n openclaw -- openclaw --version

# Escalar
oc scale deployment/openclaw-agent -n openclaw --replicas=0
oc scale deployment/openclaw-agent -n openclaw --replicas=1

# Atualizar env
oc set env deployment/openclaw-agent OPENCLAW_INITIAL_MODEL="deepseek/deepseek-v4" -n openclaw

# Restart
oc rollout restart deployment/openclaw-agent -n openclaw
```

## Uninstall

```bash
oc delete namespace openclaw
# Ou:
oc delete -k manifests/
```

## Estrutura do Repositório

```
openclaw-agent-openshift/
├── Dockerfile.ubi            # Imagem UBI 9 para OpenShift
├── README.md                 # Esta documentação
├── curl-test.sh              # Script de teste HTTP
├── .gitignore
├── web-ui/
│   ├── openclaw-web.py       # Web UI Python (aiohttp)
│   └── start.sh              # Startup wrapper
└── manifests/
    ├── kustomization.yaml    # Kustomize root
    ├── 01-namespace.yaml
    ├── 02-openclaw-serviceaccount.yaml
    ├── 03-openclaw-storage.yaml
    ├── 04-openclaw-config.yaml
    ├── 04-openclaw-secrets-template.yaml
    ├── 05-openclaw-deployment.yaml
    ├── 06-openclaw-service.yaml
    ├── 07-openclaw-route.yaml
    └── 08-openclaw-web-config.yaml
```

## Diferenças para o Hermes Agent

| Característica | Hermes Agent | OpenClaw Agent |
|---------------|--------------|----------------|
| Runtime | `hermes gateway` + OpenAI API | `openclaw agent --local --json` |
| Chat proxy | HTTP POST `/v1/chat/completions` | Subprocess CLI |
| Web UI | Python aiohttp | Python aiohttp (adaptado) |
| Imagem base | UBI 9 + Node + Python | UBI 9 + Node + Python |
| Autenticação MCP | Sim | Sim |
| OpenShift SCC | restricted-v2 | restricted-v2 |

## Licença

MIT — veja [LICENSE](LICENSE).

Built for [Nebbie Corporation](https://nebbie.com.br).
