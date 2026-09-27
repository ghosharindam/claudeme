# Quick Start - No Installation Required

For one-time or quick testing without installation.

## TL;DR

```bash
# 1. Start Ollama
ollama serve

# 2. Download and run
curl -O https://raw.githubusercontent.com/ghosharindam/claudeme/main/claudeme-quick
chmod +x claudeme-quick
./claudeme-quick --auto-start
```

Done! Claude Code now uses your local Ollama model.

---

## What is `claudeme-quick`?

A **standalone script** (no installation needed) that routes Claude Code to local models.

- ✅ No `./install.sh` required
- ✅ Single file, ~100 lines
- ✅ Works immediately
- ✅ Perfect for:
  - Quick testing
  - CI/CD environments
  - One-off usage
  - Trying before installing

---

## Usage

### Option 1: Auto-start (easiest)

```bash
./claudeme-quick --auto-start
```

This will:
1. Check if Ollama is running
2. Start LiteLLM automatically
3. Launch Claude Code with local model

### Option 2: Manual setup

```bash
# Terminal 1: Start Ollama
ollama serve

# Terminal 2: Start LiteLLM
litellm --model ollama/qwen2.5-coder:7b --port 4000

# Terminal 3: Run claudeme-quick
./claudeme-quick
```

### Using different models

```bash
./claudeme-quick qwen2.5-coder:7b
./claudeme-quick deepseek-coder:6.7b
./claudeme-quick qwen2.5-coder:3b -c  # Continue session
```

### Environment variables

```bash
# Use different ports
LITELLM_PORT=5000 ./claudeme-quick
OLLAMA_PORT=11435 ./claudeme-quick
```

---

## What it does

```bash
# Sets these environment variables:
ANTHROPIC_BASE_URL=http://localhost:4000
ANTHROPIC_API_KEY=local
ANTHROPIC_MODEL=ollama/qwen2.5-coder:7b

# Then runs:
claude "$@"
```

---

## Comparison: Quick vs Full Install

| Feature | `claudeme-quick` | Full `claudeme` |
|---------|------------------|-----------------|
| Installation | ❌ None | ✅ `./install.sh` |
| Auto-detection | ❌ No | ✅ Yes |
| Model selection | ❌ Manual | ✅ Interactive |
| Memory checks | ❌ No | ✅ Yes |
| Session resume | ❌ No | ✅ Yes (instant) |
| Auto-start LiteLLM | ⚠️ With flag | ✅ Automatic |
| Cloud profiles | ❌ No | ✅ Yes (gcp, aws) |
| Multi-model | ❌ One at a time | ✅ Prompts to choose |
| Best for | Testing, CI/CD | Daily use, teams |

---

## When to use which

### Use `claudeme-quick` when:
- 🧪 Testing local models for first time
- 🚀 CI/CD pipelines
- 📦 Containerized environments
- ⚡ Quick one-off usage
- 🔧 Don't want to install

### Use full `claudeme` when:
- 💼 Daily development work
- 👥 Team usage (shared configs)
- 🧠 Multiple models (selection prompts)
- ⚡ Session resume (instant when model loaded)
- ☁️ Need cloud profiles (GCP, AWS)
- 🎯 Automatic model detection

---

## Upgrading to full install

When you're ready for the full experience:

```bash
git clone https://github.com/ghosharindam/claudeme.git
cd claudeme
./install.sh
```

Then use `claudeme` instead of `./claudeme-quick`.

---

## Troubleshooting

### "claude CLI not found"
```bash
# Install Claude Code CLI
# See: https://docs.anthropic.com/claude-code
```

### "Ollama not running"
```bash
ollama serve
```

### "LiteLLM not running"
```bash
# Auto-start:
./claudeme-quick --auto-start

# Or manually:
litellm --model ollama/qwen2.5-coder:7b --port 4000
```

### Works with managed Claude Code?

**Yes!** The `ANTHROPIC_MODEL` environment variable overrides managed settings:

```bash
# Even if your org sets haiku as default:
./claudeme-quick
# → Uses ollama/qwen2.5-coder:7b instead! ✅
```

---

## Examples

### Basic usage
```bash
./claudeme-quick
# Uses default qwen2.5-coder:7b
```

### Specific model
```bash
./claudeme-quick deepseek-coder:6.7b
# Uses deepseek-coder:6.7b
```

### Continue session
```bash
./claudeme-quick qwen2.5-coder:7b -c
# Continues last session with that model
```

### Auto-start everything
```bash
./claudeme-quick --auto-start
# Checks and starts LiteLLM if needed
```

### Custom ports
```bash
LITELLM_PORT=5000 ./claudeme-quick
# Uses port 5000 instead of 4000
```

---

## Source

Single file: [`claudeme-quick`](claudeme-quick)

View source to see exactly what it does (it's just ~100 lines of bash).

---

**Ready to try?**

```bash
curl -O https://raw.githubusercontent.com/ghosharindam/claudeme/main/claudeme-quick
chmod +x claudeme-quick
./claudeme-quick --auto-start
```
