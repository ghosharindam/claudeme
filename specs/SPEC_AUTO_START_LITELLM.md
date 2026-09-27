# SPEC: Auto-Start LiteLLM with Smart Model Selection

**Status:** Draft  
**Author:** User + Claude  
**Created:** 2026-09-27  
**Related:** [SPEC_MULTI_MODEL.md](SPEC_MULTI_MODEL.md)

---

## Problem Statement

**Current UX:**
```bash
$ claudeme
warning: Ollama detected but LiteLLM proxy on :4000 is not running
Start it with: litellm --model ollama/qwen2.5:7b-instruct --port 4000
error: no endpoints available
```

**Issues:**
1. User must manually start LiteLLM
2. User must know which model to use
3. No awareness of what's already loaded in memory
4. No memory checks before loading models
5. Wrong models (vision, embedding) might be selected

**Goal:**  
Intelligent, memory-aware auto-start with preference for already-loaded models.

---

## Design Principles

✅ **Config-driven** - All preferences, models, thresholds in config files  
✅ **Memory-aware** - Check resources before loading  
✅ **Smart defaults** - Prefer loaded models, coding models  
✅ **Session continuity** - Remember last-used setup  
✅ **User control** - Can disable, override, configure  

❌ **No hardcoded values** - Everything configurable  
❌ **No assumptions** - Check actual system state  
❌ **No silent failures** - Clear feedback always  

---

## Step-by-Step Flow

### 1. Detect System State

```bash
claudeme-resolve startup:
  ├─ Check available tools (llama-server, Ollama, LiteLLM)
  ├─ Check running status of each
  ├─ Check loaded models (ollama ps, ps aux | grep llama-server)
  ├─ Check available memory
  └─ Read session history
```

### 2. Session Continuation (`claudeme -c`)

**If previous session exists for this directory:**
```
Read ~/.claudeme/sessions.json
  └─ Get: tool, model, endpoint
     └─ Check: Is tool still running?
        ├─ Yes: Is model still loaded?
        │  ├─ Yes: ✓ Resume instantly (0 overhead)
        │  └─ No: Check memory → Load model → Resume
        └─ No: Start tool → Load model → Resume
```

### 3. First Time / Interactive Selection

**Priority order:**
1. Show already-loaded models first (highlighted)
2. Show coding models available but not loaded
3. Show cloud profiles
4. Check memory before each selection
5. Integrate cleanup-advisor for low memory

### 4. No Coding Models Available

**Smart recommendations based on system:**
1. Check available memory
2. Load model catalog config
3. Recommend appropriate model sizes
4. Offer to install interactively
5. Check memory before installation

---

## Configuration Files

### 1. Model Catalog (System-Wide Defaults)

**Location:** `~/.claudeme/model-catalog.yaml`

**Purpose:** Metadata about available coding models (not hardcoded)

```yaml
# Model catalog - Coding models for Claude Code
# Updated: 2026-09-27
# Source: Can be updated with 'claudeme update-catalog'

version: "1.0"

# Coding model catalog
coding_models:
  qwen2.5-coder:
    description: "Latest Qwen coding model"
    provider: "Alibaba"
    architecture: "Qwen2.5"
    recommended: true
    
    versions:
      "14b":
        ram_gb: 8.5
        vram_gb: 8.5
        quality_score: 10
        speed_score: 7
        recommended_for: "systems with >16GB available RAM"
        quantization: "Q4_K_M"
        
      "7b":
        ram_gb: 4.3
        vram_gb: 4.3
        quality_score: 8
        speed_score: 9
        recommended_for: "most systems (balanced)"
        quantization: "Q4_K_M"
        
      "3b":
        ram_gb: 2.1
        vram_gb: 2.1
        quality_score: 6
        speed_score: 10
        recommended_for: "low-memory systems"
        quantization: "Q4_K_M"
        
      "1.5b":
        ram_gb: 1.2
        vram_gb: 1.2
        quality_score: 5
        speed_score: 10
        recommended_for: "very constrained systems"
        quantization: "Q4_K_M"
  
  deepseek-coder-v2:
    description: "DeepSeek Coder V2"
    provider: "DeepSeek"
    architecture: "DeepSeek-V2"
    recommended: true
    
    versions:
      "16b":
        ram_gb: 10.2
        quality_score: 9
        speed_score: 7
        recommended_for: "systems with >16GB available RAM"
      
      "6.7b":
        ram_gb: 4.5
        quality_score: 8
        speed_score: 8
        recommended_for: "most systems"
  
  codellama:
    description: "Meta CodeLlama"
    provider: "Meta"
    architecture: "Llama2"
    recommended: false  # Older, prefer qwen2.5-coder
    
    versions:
      "34b":
        ram_gb: 20.5
        quality_score: 9
        speed_score: 5
        recommended_for: "high-memory systems only"
      
      "13b":
        ram_gb: 7.8
        quality_score: 7
        speed_score: 7
        recommended_for: "systems with >12GB available RAM"
      
      "7b":
        ram_gb: 4.3
        quality_score: 6
        speed_score: 8
        recommended_for: "legacy compatibility"
  
  starcoder2:
    description: "BigCode StarCoder2"
    provider: "BigCode"
    recommended: false
    
    versions:
      "15b":
        ram_gb: 9.5
        quality_score: 8
        speed_score: 6

# Models to exclude (patterns)
excluded_patterns:
  - "vision"      # Vision models (not for coding)
  - "llava"       # Vision models
  - "embed"       # Embedding models
  - "image"       # Image generation
  - "xl"          # Extra large diffusion models

# Memory thresholds for recommendations
memory_thresholds:
  high:
    min_available_gb: 16
    recommended_model_size: "14b"
    allow_sizes: ["14b", "7b", "3b", "1.5b"]
  
  medium:
    min_available_gb: 8
    max_available_gb: 16
    recommended_model_size: "7b"
    allow_sizes: ["7b", "3b", "1.5b"]
  
  low:
    min_available_gb: 4
    max_available_gb: 8
    recommended_model_size: "3b"
    allow_sizes: ["3b", "1.5b"]
  
  very_low:
    max_available_gb: 4
    action: "suggest_cleanup_or_cloud"

# Safety margins
safety:
  min_free_after_load_gb: 2    # Always keep 2GB free
  max_memory_usage_pct: 80      # Don't use >80% total RAM
```

---

### 2. User Preferences

**Location:** `~/.claudeme/preferences.yaml`

**Purpose:** User-specific settings and choices

```yaml
# User preferences for claudeme
# Auto-generated on first run, user-editable

version: "1.0"

# Auto-start behavior
auto_start:
  enabled: true                    # Enable auto-start of LiteLLM
  remember_choice: true            # Remember yes/no decision
  last_decision: null              # "yes", "no", or null (ask)

# Model preferences (user's priority order)
# Override catalog defaults
preferred_models:
  - qwen2.5-coder:7b              # User's #1 choice
  - deepseek-coder-v2:6.7b        # User's #2 choice
  - codellama:13b                 # User's #3 choice

# LiteLLM settings
litellm:
  port: 4000
  host: "0.0.0.0"
  extra_args: []                   # Additional CLI flags
  auto_restart: false              # Restart if crashes

# Memory management
memory:
  check_before_load: true          # Always check memory before loading
  auto_cleanup: "ask"              # "yes", "no", or "ask"
  prefer_loaded: true              # Always prefer already-loaded models
  warn_threshold_pct: 80           # Warn if memory >80% after load

# Session management  
sessions:
  auto_resume: true                # Auto-resume with -c
  save_on_exit: true               # Save last-used endpoint
  history_limit: 100               # Keep last 100 sessions

# UI preferences
ui:
  show_memory_status: true         # Show memory in selection UI
  highlight_loaded: true           # Highlight loaded models
  show_quality_scores: true        # Show quality/speed scores
  verbose: false                   # Verbose output
```

---

### 3. Session History

**Location:** `~/.claudeme/sessions.json`

**Purpose:** Track last-used setup per directory

```json
{
  "/Users/user/projects/myapp": {
    "tool": "ollama",
    "model": "qwen2.5-coder:7b",
    "endpoint": "http://localhost:11434",
    "last_used": "2026-09-27T10:30:00Z",
    "model_was_loaded": true
  },
  "/Users/user/projects/webapp": {
    "tool": "llama-server",
    "model": "deepseek-coder:6.7b",
    "endpoint": "http://localhost:52123",
    "last_used": "2026-09-26T14:22:00Z",
    "model_was_loaded": false
  }
}
```

---

## Implementation Components

### Component 1: System State Detector

**File:** `bin/claudeme-resolve` (enhanced)

**Functions:**
```bash
# Load all configs (no hardcoding!)
load_configs() {
  MODEL_CATALOG="$HOME/.claudeme/model-catalog.yaml"
  USER_PREFS="$HOME/.claudeme/preferences.yaml"
  SESSIONS="$HOME/.claudeme/sessions.json"
  
  # Create defaults if missing
  [[ -f "$MODEL_CATALOG" ]] || install_default_catalog
  [[ -f "$USER_PREFS" ]] || install_default_preferences
}

# Detect running tools and loaded models
detect_system_state() {
  # Check llama-server
  if pgrep -x "llama-server" >/dev/null; then
    LLAMA_SERVER_RUNNING=true
    LLAMA_SERVER_MODEL=$(detect_llama_server_model)
    LLAMA_SERVER_RAM=$(get_process_ram "llama-server")
  fi
  
  # Check Ollama
  if pgrep -x "ollama" >/dev/null; then
    OLLAMA_RUNNING=true
    OLLAMA_LOADED_MODELS=$(ollama ps --format json)
  fi
  
  # Check LiteLLM
  if lsof -i :4000 >/dev/null 2>&1; then
    LITELLM_RUNNING=true
  fi
}

# Get available memory
get_available_memory_gb() {
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    local total=$(sysctl -n hw.memsize)
    local free=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
    # Calculate available in GB
  else
    # Linux
    free -g | awk '/^Mem:/ {print $7}'
  fi
}

# Get memory tier from catalog thresholds
get_memory_tier() {
  local available_gb=$1
  
  # Read thresholds from catalog (not hardcoded!)
  local high_min=$(yq '.memory_thresholds.high.min_available_gb' "$MODEL_CATALOG")
  local med_min=$(yq '.memory_thresholds.medium.min_available_gb' "$MODEL_CATALOG")
  local low_min=$(yq '.memory_thresholds.low.min_available_gb' "$MODEL_CATALOG")
  
  if (( $(echo "$available_gb >= $high_min" | bc) )); then
    echo "high"
  elif (( $(echo "$available_gb >= $med_min" | bc) )); then
    echo "medium"
  elif (( $(echo "$available_gb >= $low_min" | bc) )); then
    echo "low"
  else
    echo "very_low"
  fi
}
```

---

### Component 2: Model Recommender

**Functions:**
```bash
# Recommend models based on memory tier
recommend_models() {
  local available_gb=$1
  local tier=$(get_memory_tier "$available_gb")
  
  # Get recommendations from catalog (not hardcoded!)
  local recommended_size=$(yq ".memory_thresholds.$tier.recommended_model_size" "$MODEL_CATALOG")
  local allowed_sizes=$(yq ".memory_thresholds.$tier.allow_sizes[]" "$MODEL_CATALOG")
  
  # Get user's preferred models
  local user_prefs=$(yq '.preferred_models[]' "$USER_PREFS")
  
  # Filter and sort
  # 1. User preferences first
  # 2. Then catalog recommendations
  # 3. Filter by allowed sizes for tier
  # 4. Sort by quality score
}

# Check if model will fit in memory
check_model_fits() {
  local model=$1
  local available_gb=$2
  
  # Get model RAM requirement from catalog
  local model_ram=$(yq ".coding_models.$model.versions.*.ram_gb" "$MODEL_CATALOG")
  
  # Get safety margins from catalog
  local min_free=$(yq '.safety.min_free_after_load_gb' "$MODEL_CATALOG")
  local max_pct=$(yq '.safety.max_memory_usage_pct' "$MODEL_CATALOG")
  
  # Check if fits
  local needed=$(echo "$model_ram + $min_free" | bc)
  if (( $(echo "$needed <= $available_gb" | bc) )); then
    return 0  # Fits
  else
    return 1  # Doesn't fit
  fi
}
```

---

### Component 3: Interactive Selection UI

**Display format (from config):**
```bash
show_model_selection() {
  local available_gb=$1
  local loaded_models=$2
  
  echo "Available memory: ${available_gb}GB"
  echo ""
  
  # Show loaded models first (from detection)
  if [[ -n "$loaded_models" ]]; then
    echo "Already loaded (instant, no RAM needed):"
    for model in $loaded_models; do
      local ram=$(get_model_ram_from_catalog "$model")
      echo "  ✓ $model (using ${ram}GB)"
    done
    echo ""
  fi
  
  # Show available coding models (from catalog)
  echo "Coding models available:"
  local tier=$(get_memory_tier "$available_gb")
  local recommendations=$(get_recommendations_for_tier "$tier")
  
  for model in $recommendations; do
    local ram=$(yq ".coding_models.$model.*.ram_gb" "$MODEL_CATALOG")
    local quality=$(yq ".coding_models.$model.*.quality_score" "$MODEL_CATALOG")
    local speed=$(yq ".coding_models.$model.*.speed_score" "$MODEL_CATALOG")
    
    if check_model_fits "$model" "$available_gb"; then
      echo "  $model - RAM: ${ram}GB, Quality: $quality/10, Speed: $speed/10"
    else
      echo "  $model - RAM: ${ram}GB ⚠️ Insufficient memory"
    fi
  done
}
```

---

## Decision Trees

### Tree 1: Startup Flow

```
claudeme invoked
│
├─ Load configs (catalog, prefs, sessions)
│
├─ Detect system state
│  ├─ Running tools?
│  ├─ Loaded models?
│  └─ Available memory?
│
├─ Is this -c (continue)?
│  ├─ Yes: Read session history
│  │  └─ Auto-resume (check if still loaded)
│  │
│  └─ No: Interactive selection
│     │
│     ├─ Show loaded models first (highlighted)
│     ├─ Get memory tier from catalog
│     ├─ Get recommendations from catalog + user prefs
│     ├─ Check each against memory
│     └─ Present sorted list
│
└─ Execute selection
   ├─ Already loaded? → Use immediately
   └─ Not loaded?
      ├─ Check memory (from catalog thresholds)
      ├─ Fits? → Load and use
      └─ Doesn't fit?
         ├─ Run cleanup-advisor
         ├─ Ask to kill processes
         └─ Retry or suggest cloud
```

---

### Tree 2: No Coding Models Flow

```
No coding models detected
│
├─ Get available memory
├─ Get memory tier from catalog
│
├─ Load recommendations from catalog for this tier
│  └─ Filter by:
│     ├─ Memory tier allowed sizes
│     ├─ User preferences
│     └─ Quality scores
│
├─ Present top 3 recommendations
│  └─ Show:
│     ├─ Model name
│     ├─ RAM requirement (from catalog)
│     ├─ Quality/Speed scores (from catalog)
│     └─ Recommended for (from catalog)
│
├─ User selects
│
└─ Check memory
   ├─ Fits? → Install via ollama pull → Load → Use
   └─ Doesn't fit?
      ├─ Suggest cleanup
      ├─ Suggest smaller model
      └─ Suggest cloud endpoint
```

---

## Config Update Mechanism

### Updating Model Catalog

```bash
# Command to update catalog from remote source
claudeme update-catalog

# Downloads latest catalog from:
# https://claudeme.dev/model-catalog.yaml
# Or uses bundled default

# User can also manually edit:
# ~/.claudeme/model-catalog.yaml
```

**Default catalog bundled with claudeme:**
- `examples/model-catalog.yaml` → copied to `~/.claudeme/` on install
- Can be updated with `claudeme update-catalog`
- User edits preserved (merged with updates)

---

## Installation

### install.sh Enhancement

```bash
# Create default configs
install_default_configs() {
  local config_dir="$HOME/.claudeme"
  mkdir -p "$config_dir"
  
  # Install model catalog
  if [[ ! -f "$config_dir/model-catalog.yaml" ]]; then
    cp examples/model-catalog.yaml "$config_dir/"
    check "Installed model catalog"
  fi
  
  # Install preferences template
  if [[ ! -f "$config_dir/preferences.yaml" ]]; then
    cp examples/preferences.yaml "$config_dir/"
    check "Installed preferences"
  fi
  
  # Create empty sessions file
  if [[ ! -f "$config_dir/sessions.json" ]]; then
    echo '{}' > "$config_dir/sessions.json"
    check "Created sessions file"
  fi
}
```

---

## Files to Create

### Required Files

1. **`examples/model-catalog.yaml`** - Default model catalog (see structure above)
2. **`examples/preferences.yaml`** - Default user preferences template
3. **Enhanced `bin/claudeme-resolve`** - Implement config-driven logic
4. **Updated `install.sh`** - Install default configs

### Config Locations

```
~/.claudeme/
├── model-catalog.yaml      # Model metadata (can be updated)
├── preferences.yaml        # User preferences (user edits)
├── sessions.json           # Session history (auto-managed)
└── litellm-config.yaml     # LiteLLM multi-model config (future)
```

---

## Success Criteria

✅ **Zero hardcoded values** - All in configs  
✅ **Memory-aware** - Checks before loading  
✅ **Prefers loaded** - Instant when already in RAM  
✅ **Smart recommendations** - Based on system capabilities  
✅ **User control** - Can configure all behavior  
✅ **Session continuity** - Remembers last setup  
✅ **Cleanup integration** - Helps free memory when needed  

**Metrics:**
- Time to start: <5s with loaded model, <30s with new model
- Memory accuracy: 100% (never OOM)
- User satisfaction: Prefer auto-start over manual

---

## Future Enhancements

### Phase 2: Multi-Model Support
- Generate LiteLLM config with all loaded models
- Enable `/model` switching
- See SPEC_MULTI_MODEL.md

### Phase 3: Cloud Fallback
- Auto-suggest cloud when memory too low
- One-command cloud setup

### Phase 4: Model Performance Tracking
- Track which models user actually uses
- Auto-recommend based on usage patterns
- Quality feedback loop

---

## Open Questions

1. **Catalog updates:** How often to update model catalog?
   - Manual: User runs `claudeme update-catalog`
   - Auto: Check weekly? On install?

2. **Model size detection:** Trust catalog or verify?
   - Trust catalog (faster, curated)
   - Verify with `ollama show` (slower, accurate)

3. **Background LiteLLM:** Keep running or stop on exit?
   - Keep running (faster next time)
   - Stop on exit (cleaner)

---

## Implementation Order

### Phase 1: Config Infrastructure
1. Create `examples/model-catalog.yaml`
2. Create `examples/preferences.yaml`
3. Update `install.sh` to copy configs
4. Add config loading to `claudeme-resolve`

### Phase 2: Detection
1. Implement tool/model detection
2. Implement memory detection
3. Implement loaded model detection

### Phase 3: Smart Selection
1. Implement memory tier logic (from config)
2. Implement model recommendations (from catalog)
3. Implement selection UI

### Phase 4: Auto-Start
1. Implement LiteLLM auto-start
2. Implement memory checks
3. Integrate cleanup-advisor

### Phase 5: Session Management
1. Implement session history
2. Implement auto-resume
3. Test continuity

---

**Status:** Ready for review and implementation

**Next:** Review this spec, then implement Phase 1
