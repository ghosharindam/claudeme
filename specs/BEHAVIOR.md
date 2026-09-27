# Claudeme Behavior Guide

## How `claudeme` routes to backends

### Scenario 1: llama.cpp running (no LiteLLM)

```bash
# Start llama.cpp with Anthropic API support
./llama-server --model model.gguf --port 8080 --api-type anthropic

# Run claudeme
claudeme
```

**Result:** Connects directly to llama.cpp on :8080 (no LiteLLM bridge)

---

### Scenario 2: Only Ollama running (no LiteLLM)

```bash
# Ollama is running on :11434
ollama serve

# Run claudeme
claudeme
```

**Result:** Error message:
```
error: Ollama/Edge Gallery requires a LiteLLM proxy on :4000

litellm is not installed. Run the installer to set it up:
  cd ~/Documents/my_workspace/claudeme && ./install.sh
```

---

### Scenario 3: Ollama + LiteLLM running

```bash
# Terminal 1: Ollama
ollama serve

# Terminal 2: LiteLLM proxy
litellm --model ollama/llama3.2 --port 4000

# Terminal 3: Run claudeme
claudeme
```

**Result:** Connects to LiteLLM on :4000, which forwards to Ollama

---

### Scenario 4: Multiple backends available

```bash
# llama.cpp running on :8080
# LiteLLM running on :4000 (fronting Ollama)
# Named profile "gcp" configured

claudeme
```

**Result:** Interactive menu:
```
Select endpoint:
  1) local   llama.cpp at http://localhost:8080
  2) local   Ollama via LiteLLM at http://localhost:4000
  3) gcp     https://my-litellm.run.app

Choice:
```

- **Choose 1** → Direct to llama.cpp (no bridge)
- **Choose 2** → Through LiteLLM to Ollama
- **Choose 3** → Cloud endpoint

---

### Scenario 5: Only one backend available

```bash
# Only llama.cpp is running
claudeme
```

**Result:** Auto-selects llama.cpp (no menu)

---

## Key Behaviors

### LiteLLM is optional for llama.cpp
- If llama.cpp runs with `--api-type anthropic` → use it directly
- No LiteLLM bridge needed
- Full performance, no extra hop

### LiteLLM is required for Ollama/Edge Gallery
- These don't speak Anthropic API format
- LiteLLM translates requests/responses
- If missing, `claudeme` prompts to run `install.sh`

### Installer is idempotent
```bash
# Safe to run multiple times
./install.sh
```

- Only installs missing dependencies
- Updates outdated components
- Never breaks existing setup
- Auto-installs: `jq`, `litellm[proxy]`

---

## Decision Tree

```
claudeme invoked
    │
    ├─ llama.cpp detected (:8080)
    │   └─> Connect directly (no LiteLLM)
    │
    ├─ LiteLLM detected (:4000)
    │   └─> Use LiteLLM
    │
    ├─ Ollama detected (:11434) + LiteLLM (:4000)
    │   └─> Use LiteLLM (shows "Ollama via LiteLLM")
    │
    ├─ Ollama detected (:11434) + NO LiteLLM
    │   └─> Error: prompt to run install.sh
    │
    └─ Multiple backends detected
        └─> Show menu, user picks one
```
