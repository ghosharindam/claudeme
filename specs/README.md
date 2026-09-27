# Specification Documents

Technical specifications and design documents for claudeme using OpenSpec format.

## OpenSpec Format

We use **OpenSpec** format for spec-driven development:
- Machine-readable (YAML)
- Validatable against schema
- Tool-friendly (can generate docs, tests)
- Human-readable

### Spec Files

Each feature has two files:
1. **`feature-name.openspec.yaml`** - Machine-readable spec
2. **`feature-name.md`** - Human-readable guide (optional)

### Schema

See [`.openspec-schema.yaml`](.openspec-schema.yaml) for the specification format.

---

## Active Specifications

### [auto-start-litellm.openspec.yaml](auto-start-litellm.openspec.yaml)
**Status:** Draft  
**Version:** 0.1.0

Intelligent auto-start system that:
- Detects available tools and loaded models
- Recommends models based on available memory
- Prefers already-loaded models (instant resume)
- Integrates cleanup-advisor for memory management
- 100% config-driven (no hardcoded values)

**Key Components:**
- `model-catalog.yaml` - Model metadata (RAM, quality, speed)
- `preferences.yaml` - User preferences
- `sessions.json` - Session history

**Flows:**
- Startup flow (detection → selection)
- Session continuation (instant resume)
- No coding models (smart recommendations)

---

### [SPEC_MULTI_MODEL.md](SPEC_MULTI_MODEL.md)
**Status:** Planned  
**Version:** N/A (Markdown only, convert to OpenSpec)

Multi-model support via LiteLLM for `/model` switching.

**TODO:** Convert to OpenSpec format

---

### [BEHAVIOR.md](BEHAVIOR.md)
**Status:** Reference  
**Version:** N/A

Documents endpoint resolution behavior.

---

### [TECH_SPEC.md](TECH_SPEC.md)
**Status:** Legacy  
**Version:** N/A

Original technical specification (pre-OpenSpec).

---

## Implementation Status

| Spec | Format | Status | Phase |
|------|--------|--------|-------|
| auto-start-litellm | OpenSpec | Complete | ✅ Implemented |
| phase3-auto-config | OpenSpec | Draft | Next (Ready to implement) |
| multi-model | Markdown | Planned | Waiting on benchmarks |
| behavior | Markdown | Reference | - |
| tech-spec | Markdown | Legacy | - |

---

## OpenSpec Template

### Minimal OpenSpec

```yaml
openspec: 1.0.0

info:
  title: Feature Name
  version: 0.1.0
  status: draft
  created: 2026-MM-DD
  authors:
    - Your Name

summary: |
  Brief description of what this feature does

problem:
  current_state: What's the current situation?
  issues:
    - Issue 1
    - Issue 2
  goal: What do we want to achieve?

design_principles:
  - principle: Config-driven
    description: No hardcoded values
  
  - principle: User control
    description: Everything configurable

components:
  configs:
    - name: config-name
      type: yaml
      location: ~/.claudeme/config-name.yaml
      purpose: What this config does
      schema:
        # Define structure

flows:
  - name: main-flow
    description: What this flow does
    steps:
      - step: step-name
        action: what happens
        outputs:
          - what is produced

success_criteria:
  - criterion: Must work criterion
    validation: How to verify

implementation:
  phases:
    - phase: 1
      name: Phase Name
      tasks:
        - Task 1
        - Task 2
```

---

## Validation

Validate specs against schema:

```bash
# Install yq for YAML validation
brew install yq

# Validate a spec
yq eval-all '. as $spec | 
  load(".openspec-schema.yaml") as $schema | 
  $spec' auto-start-litellm.openspec.yaml
```

---

## Generating Documentation

From OpenSpec, you can generate:
- Markdown docs (human-readable)
- Config file templates
- Test cases
- Implementation checklists

**TODO:** Create generation tools

---

## Spec-Driven Development Workflow

### 1. Write Spec First (OpenSpec)
```bash
# Create new spec
cp auto-start-litellm.openspec.yaml my-feature.openspec.yaml

# Edit with all details:
# - Problem statement
# - Design principles  
# - Components (configs, commands)
# - Flows (step-by-step)
# - Success criteria
```

### 2. Review & Validate
```bash
# Validate against schema
# Get feedback from team
# Ensure no hardcoded values
```

### 3. Create Config Templates
```bash
# From components.configs in spec
# Create examples/*.yaml files
```

### 4. Implement Phase by Phase
```bash
# Follow implementation.phases in spec
# Create tasks for each phase
# Test after each phase
```

### 5. Update Spec as You Learn
```bash
# Document decisions in open_questions
# Update flows if they change
# Mark as "active" when implementing
```

### 6. Mark Complete
```bash
# Update status: completed
# Add metrics achieved
# Link to implementation
```

---

## Benefits of OpenSpec

✅ **Machine-readable** - Tools can parse and validate  
✅ **Structured** - Consistent format across features  
✅ **Validatable** - Schema ensures completeness  
✅ **Config-driven** - Enforces no hardcoding  
✅ **Flow-based** - Step-by-step clarity  
✅ **Measurable** - Clear success criteria  
✅ **Traceable** - Links specs to implementation  

---

## Contributing

### New Features

1. **Start with OpenSpec** - Not code!
2. **Define all configs** - No hardcoded values
3. **Document flows** - Step-by-step behavior
4. **Set success criteria** - How to verify
5. **Get review** - Before implementing
6. **Implement in phases** - Track progress
7. **Update spec** - Document decisions

### Converting Existing Specs

To convert Markdown specs to OpenSpec:

1. Create `feature-name.openspec.yaml`
2. Extract components, flows, configs
3. Define schema for each config
4. Document decision trees as flows
5. Add success criteria
6. Keep Markdown for additional context

---

## Examples

### Good OpenSpec
```yaml
components:
  configs:
    - name: model-catalog
      type: yaml
      location: ~/.claudeme/model-catalog.yaml
      schema:
        coding_models:
          qwen2.5-coder:
            versions:
              "7b":
                ram_gb: 4.3    # FROM CONFIG, not hardcoded!
```

### Bad (Hardcoded)
```yaml
# DON'T DO THIS
flows:
  - step: recommend_model
    model: "qwen2.5-coder:7b"   # ❌ Hardcoded!
    ram: 4.3                    # ❌ Hardcoded!
```

### Good (Config-Driven)
```yaml
# DO THIS
flows:
  - step: recommend_model
    reads: model-catalog.yaml
    path: coding_models.qwen2.5-coder.versions.7b
    extracts:
      - ram_gb
      - quality_score
```

---

**Policy:** All new features require OpenSpec before implementation!
