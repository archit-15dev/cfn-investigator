# CFN Investigator

> Autonomous investigation of false negatives (CFNs) in email security detection systems

![Bash](https://img.shields.io/badge/bash-3.2+-green.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)

## Overview

CFN Investigator is a three-layer intelligence system for systematically investigating why attack messages bypass email security detection (false negatives). It combines a pure data fetcher (`msg` tool) with an autonomous AI-driven investigation workflow (`cfn-investigate`) to identify detection gaps and generate actionable recommendations.

### Key Features

- 🎯 **Single-MID Deep Investigation** - Complete root cause analysis in 12-18 minutes
- 📊 **Batch Pattern Detection** - Process 100+ CFNs, detect systematic gaps
- 🤖 **Automated Gap Categorization** - 4 types: Missing Feature, Missing Heuristic, Rule Gap, Threshold Too Strict
- 📋 **Actionable Recommendations** - Implementation steps, test plans, FP risk assessment
- ⚡ **10x Faster with Caching** - Cache-first architecture with 5-minute TTL
- 🔄 **Dual-Mode Operation** - Deep dive OR pattern detection

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Intelligence (cfn-investigate)                 │
│  • Root cause categorization (4 types)                  │
│  • Pattern detection (batch mode)                       │
│  • Recommendations + test plans                         │
└────────────────┬────────────────────────────────────────┘
                 │ orchestrates
┌────────────────▼────────────────────────────────────────┐
│ Layer 2: Documentation (CLAUDE.md)                      │
│  • Usage guide for AI agents                            │
│  • Command reference (16 commands)                      │
└────────────────┬────────────────────────────────────────┘
                 │ documents
┌────────────────▼────────────────────────────────────────┐
│ Layer 1: Data Fetcher (msg tool)                        │
│  • Pure data fetching (ZERO intelligence)               │
│  • 16 commands with intelligent caching                 │
└─────────────────────────────────────────────────────────┘
```

**Key Innovation**: **Intelligence Separation** - The `msg` tool is intentionally "dumb" (fetches and formats data only), while ALL intelligence lives in the `cfn-investigate` workflow. This makes the system maintainable, composable, and reusable.

## Quick Start

### Installation

```bash
# 1. Copy msg tool to your PATH
curl -o ~/.local/bin/msg https://raw.githubusercontent.com/YOUR_USERNAME/cfn-investigator/main/bin/msg
chmod +x ~/.local/bin/msg

# 2. Copy Claude Code slash command
mkdir -p ~/.claude/commands
curl -o ~/.claude/commands/cfn-investigate.md https://raw.githubusercontent.com/YOUR_USERNAME/cfn-investigator/main/.claude/commands/cfn-investigate.md

# 3. Copy documentation for AI agents
curl -o ~/.claude/CLAUDE.md https://raw.githubusercontent.com/YOUR_USERNAME/cfn-investigator/main/.claude/CLAUDE.md

# 4. Verify installation
msg --help
```

### Usage

#### Single-MID Investigation

```bash
# Quick triage (2-3 minutes)
msg -4865185475740621290 auto
msg -4865185475740621290 mismatch

# Full investigation (12-18 minutes)
/cfn-investigate -4865185475740621290

# Deep dive with comprehensive analysis
/cfn-investigate -4865185475740621290 --deep
```

#### Batch Investigation

```bash
# Create MID list
cat > cfn_list.txt <<EOF
-4865185475740621290
-715876989141528867
-2428734771100200806
EOF

# Run batch investigation (8-10 hours for 817 CFNs)
/cfn-investigate cfn_list.txt --deep 5 --parallel 3 --output ~/cfn_batch

# Output:
# ~/cfn_batch/2025-01-17_143022/
#   ├── batch_data.csv          (aggregated data)
#   ├── systematic_gaps.txt     (detected patterns)
#   ├── deep_*.md               (deep dive reports)
#   └── BATCH_SUMMARY.md        (executive summary)
```

## msg Tool Commands

The `msg` tool provides 16 commands organized into 5 categories:

### Core Triage (Start Here)
```bash
msg <mid> auto          # DEFAULT: overview + decision + links
msg <mid> overview      # Message metadata (from, subject, counts)
msg <mid> decision      # Detection decision + flagged rules
msg <mid> links         # All links with suspicious scores
msg <mid> entities      # All entities with UUIDs
```

### Deep Dive
```bash
msg <mid> entity <uuid> # Requires UUID from entities command
msg <mid> domains       # Domain entities only (type=5)
msg <mid> search <kw>   # Search secondary attributes
```

### Signal Analysis
```bash
msg <mid> rules         # Detection rules + models breakdown
msg <mid> heur          # Triggered heuristics per entity
msg <mid> phrases [-f]  # Phrase matches (--filter for matches >0)
```

### Gap Detection (P0 Commands)
```bash
msg <mid> mismatch      # Detect judgement-review mismatches
msg <mid> confidence    # Confidence score + threshold analysis
msg <mid> batch-summary # Single-line CSV (11 fields)
```

### Advanced
```bash
msg <mid> god           # Run ALL commands (500-2000 lines)
msg <mid> raw '<jq>'    # Custom jq filter (escape hatch)
```

## Gap Categories

The system categorizes detection gaps into 4 types:

| Category | Definition | Evidence | Fix | Impact |
|----------|-----------|----------|-----|--------|
| **1: Missing Feature** | Attack indicator exists but not extracted | `msg search <KEYWORD>` returns `{}` | Add secondary attribute + extraction logic | +10-30% catch rate, Low FP risk |
| **2: Missing Heuristic** | Feature exists but no heuristic evaluates it | Attribute exists but no heuristic in `msg heur` | Add heuristic evaluation | +15-40% catch rate, Low-Medium FP risk |
| **3: Rule Gap** | Heuristic fires but no rule uses it | `msg heur` shows triggered but `msg rules` shows not used | Update rule to use heuristic | +20-50% catch rate, Medium FP risk |
| **4: Threshold Too Strict** | Rule sees signals but confidence below threshold | `msg confidence` shows confidenceScore < threshold | Tune threshold | +5-15% catch rate, High FP risk |

## Performance

### msg Tool
| Operation | Cold (API fetch) | Warm (Cache hit) | Speedup |
|-----------|------------------|------------------|---------|
| First command | 2-3 seconds | N/A | N/A |
| Subsequent commands | N/A | <100ms | 20-30x |

### CFN Investigation
| Mode | MIDs | Time | Throughput |
|------|------|------|------------|
| Single-MID | 1 | 12-18 min | N/A |
| Single-MID (--deep) | 1 | 20-30 min | N/A |
| Batch | 100 | 1.5-2 hours | 50-67 CFNs/hr |
| Batch | 817 | 8-10 hours | 82-102 CFNs/hr |
| Batch (--parallel 3) | 817 | 6-8 hours | 102-136 CFNs/hr |

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete system architecture (1384 lines)
- **[.claude/CLAUDE.md](.claude/CLAUDE.md)** - msg tool reference manual for AI agents
- **[.claude/commands/cfn-investigate.md](.claude/commands/cfn-investigate.md)** - Investigation workflow (8 phases)

## Examples

See the `examples/` directory for:
- Single-MID investigation report
- Batch investigation summary
- Real-world traces

## Requirements

- Bash 3.2+ (macOS, Linux)
- `jq` (JSON processor)
- `curl` (HTTP client)
- Access to POV rt-scorer API endpoint

## Design Principles

1. **Intelligence Separation** - Data layer (msg) has ZERO intelligence, ALL intelligence in workflow
2. **Cache-First Architecture** - 5-minute cache with per-MID custom locations (10x speedup)
3. **Composability** - msg tool usable in other workflows, output designed for piping
4. **Adaptive Workflow** - Same 8-phase workflow, behavior adapts to mode (single-MID vs batch)
5. **Systematic Pattern Detection** - Batch mode identifies patterns affecting 30-40% of CFNs

## Contributing

Contributions welcome! Please read the architecture documentation first to understand the intelligence boundary principle.

## Authors

- **Archit Sharma** - Initial work

## Acknowledgments

- Built for detection engineering teams investigating false negatives in email security systems
- Designed to work with Claude Code (AI-powered CLI)
- Architecture emphasizes maintainability through strict separation of concerns
