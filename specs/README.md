# Specification Documents

Technical specifications and design documents for claudeme.

## Active Specifications

### [auto-start-litellm.md](auto-start-litellm.md)
**Status:** Draft  
**Feature:** Auto-start LiteLLM with smart model selection

Intelligent auto-start system that:
- Detects available tools and loaded models
- Recommends models based on available memory
- Prefers already-loaded models (instant resume)
- Integrates cleanup-advisor for memory management
- 100% config-driven (no hardcoded values)

**Key Files:**
- `~/.claudeme/model-catalog.yaml` - Model metadata
- `~/.claudeme/preferences.yaml` - User preferences
- `~/.claudeme/sessions.json` - Session history

---

### [multi-model.md](multi-model.md)
**Status:** Planned  
**Feature:** Multi-model support via LiteLLM

Enable switching between multiple local models like `/model` in Claude Code.

**Approach:**
- LiteLLM proxy with multi-model config
- Auto-generate config from detected models
- Trade-offs: flexibility vs. performance overhead

**Decision:** Pending benchmark results

---

### [behavior.md](behavior.md)
**Status:** Reference  
**Feature:** Endpoint resolution behavior

Documents how claudeme resolves endpoints:
- Backend detection priority
- Named profile handling
- Model selection logic
- Routing scenarios

---

### [tech-spec.md](tech-spec.md)
**Status:** Reference (Legacy)  
**Feature:** Original technical specification

Early design document. See newer specs for current features.

---

## Implementation Status

| Spec | Status | Phase |
|------|--------|-------|
| auto-start-litellm.md | Draft | Not started |
| multi-model.md | Planned | Waiting on benchmarks |
| behavior.md | Reference | - |
| tech-spec.md | Legacy | - |

---

## Spec Template

When creating new specs, use this structure:

```markdown
# SPEC: Feature Name

**Status:** Draft/Active/Completed  
**Author:** Name  
**Created:** Date  
**Related:** [other-spec.md](other-spec.md)

---

## Problem Statement
What problem are we solving?

## Goals
What do we want to achieve?

## Non-Goals
What are we explicitly NOT doing?

## Design
How will it work?

## Configuration
What's configurable? (No hardcoded values!)

## Implementation Plan
Phases and tasks

## Success Criteria
How do we know it works?

## Open Questions
What needs decisions?
```

---

## Directory Structure

```
specs/
├── README.md                    # This file (index)
├── auto-start-litellm.md        # Active spec
├── multi-model.md               # Planned spec
├── behavior.md                  # Reference
└── tech-spec.md                 # Legacy
```

---

## Contributing

When adding a new feature:
1. Write a spec first (use template above)
2. Get feedback/review
3. Implement in phases
4. Update spec with decisions made
5. Mark as "Completed" when shipped

**No implementation without spec for major features!**
