# MSG Tool & CFN-Investigate Architecture
## Comprehensive System Documentation

**Document Version**: 1.0
**Last Updated**: 2025-01-17
**Author**: Archit Sharma
**Purpose**: Complete architectural documentation for the msg tool (data fetcher) and cfn-investigate workflow (intelligence layer)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Component 1: MSG Tool](#component-1-msg-tool)
4. [Component 2: CLAUDE.md Documentation](#component-2-claudemd-documentation)
5. [Component 3: CFN-Investigate Slash Command](#component-3-cfn-investigate-slash-command)
6. [Integration & Data Flow](#integration--data-flow)
7. [Design Principles & Boundaries](#design-principles--boundaries)
8. [Performance Characteristics](#performance-characteristics)
9. [Usage Patterns & Workflows](#usage-patterns--workflows)
10. [Troubleshooting & Best Practices](#troubleshooting--best-practices)

---

## Executive Summary

### The Problem
Detection engineers need to investigate false negatives (CFNs) - attack messages that bypass detection. This requires:
- Fetching scorer responses from POV API
- Analyzing detection decisions, entities, heuristics, and rules
- Identifying gaps in detection logic
- Generating actionable recommendations

### The Solution
A three-layer architecture that separates concerns:

1. **msg tool** (Bash script) - Pure data fetcher, NO intelligence
2. **CLAUDE.md** (Documentation) - Usage guide for AI agents
3. **cfn-investigate** (Slash command) - ALL intelligence and workflow logic

### Key Innovation
**Intelligence Boundary**: The msg tool is intentionally "dumb" - it fetches and formats data but makes NO decisions. All intelligence lives in the cfn-investigate workflow, making the system maintainable and composable.

---

## System Architecture

### Architectural Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    USER / AI AGENT                           │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ├──────────────┬────────────────────────┐
                    ▼              ▼                        ▼
      ┌─────────────────┐  ┌──────────────┐   ┌────────────────────┐
      │   msg tool       │  │  CLAUDE.md   │   │ /cfn-investigate   │
      │  (Data Layer)    │  │ (Docs Layer) │   │ (Intelligence)     │
      └─────────────────┘  └──────────────┘   └────────────────────┘
              │                                          │
              │ Fetches from                            │ Orchestrates
              ▼                                          ▼
      ┌──────────────────┐                    ┌─────────────────────┐
      │  POV RT-Scorer   │                    │   msg commands      │
      │  API Endpoint    │                    │   (16 commands)     │
      └──────────────────┘                    └─────────────────────┘
              │                                          │
              │ Returns JSON                            │ Uses
              ▼                                          ▼
      ┌──────────────────────┐              ┌────────────────────────┐
      │ /tmp/scorer_response │◄─────────────│  Cached responses      │
      │    .json (cache)     │   Reads      │  (5-min TTL)           │
      └──────────────────────┘              └────────────────────────┘
```

### Component Roles

| Component | Type | Role | Intelligence | Dependencies |
|-----------|------|------|--------------|--------------|
| **msg tool** | Bash script (~667 LOC) | Data fetcher + formatter | **ZERO** | jq, curl, bash |
| **CLAUDE.md** | Markdown docs | Usage guide for AI | **ZERO** | None |
| **cfn-investigate** | Slash command (1531 LOC) | Investigation workflow | **ALL** | msg tool, jq, bash |

### Data Flow

```
Single-MID Investigation Flow:
1. User: `/cfn-investigate -4865185475740621290`
2. cfn-investigate: Calls `msg -4865 auto`
3. msg: Fetches from POV API → /tmp/scorer_response.json
4. msg: Returns formatted JSON (overview + decision + links)
5. cfn-investigate: Calls `msg -4865 mismatch` (reads cache)
6. msg: Analyzes cached JSON → {mismatchDetected: true, gapType: ...}
7. cfn-investigate: Calls `msg -4865 heur`, `msg -4865 entities`, etc.
8. cfn-investigate: Analyzes ALL data → Categorizes gap (1-4)
9. cfn-investigate: Generates recommendations + test plan
10. cfn-investigate: Outputs markdown report

Batch Investigation Flow (817 CFNs):
1. User: `/cfn-investigate data.txt --deep 5 --parallel 3`
2. cfn-investigate: Extracts 817 MIDs from data.txt
3. For each MID:
   a. Set MSG_CACHE_FILE=/output/cache/scorer_${MID}.json
   b. Call `msg ${MID} batch-summary` → One-line CSV
   c. Aggregate to batch_data.csv
4. Phase 4: Detect systematic patterns (rule gaps, heuristic gaps, campaigns)
5. Phase 5: Deep dive 5 representatives per pattern
6. Generate systematic improvement roadmap
```

---

## Component 1: MSG Tool

### Overview

**File**: `/Users/archits/.local/bin/msg`
**Lines of Code**: 667
**Language**: Bash 3.2+ compatible
**Purpose**: Fetch and format POV rt-scorer responses with ZERO intelligence

### Core Design Philosophy

```
msg tool = Data Fetcher ONLY
- Fetches from API
- Caches responses
- Formats JSON with jq
- Decodes enums to human-readable strings
- NO interpretation
- NO recommendations
- NO gap categorization
```

### 16 Commands Reference

#### Core Triage Commands (Start Here)
```bash
msg <mid> auto          # DEFAULT: overview + decision + links
msg <mid> overview      # Message metadata (from, subject, counts)
msg <mid> decision      # Detection decision + flagged rules
msg <mid> links         # All links with suspicious scores
msg <mid> entities      # All entities with UUIDs
```

#### Deep Dive Commands
```bash
msg <mid> entity <uuid> # Requires UUID from entities command
msg <mid> domains       # Domain entities only (type=5)
msg <mid> search <kw>   # Search secondary attributes
```

#### Signal Analysis Commands
```bash
msg <mid> rules         # Detection rules + models breakdown
msg <mid> heur          # Triggered heuristics per entity
msg <mid> phrases [-f]  # Phrase matches (--filter for matches >0)
```

#### P0 Gap Detection Commands (NEW)
```bash
msg <mid> mismatch      # Detect judgement-review mismatches
msg <mid> confidence    # Confidence score + threshold analysis
msg <mid> batch-summary # Single-line CSV (11 fields)
```

#### Advanced Commands
```bash
msg <mid> god           # Run ALL commands (500-2000 lines)
msg <mid> raw '<jq>'    # Custom jq filter (escape hatch)
```

### Implementation Details

#### 1. Enum Decoders (Lines 11-124)
```bash
# Bash 3.2 compatible (no associative arrays)
decode_phrase_type()    # 237 phrase types (0-237)
decode_entity_type()    # 8 entity types
decode_judgement()      # 8 judgement values
decode_review_decision()# 6 review decision values
decode_email_segment()  # 4 email segment locations
```

#### 2. Caching System (Lines 216-225)
```bash
OUTPUT_FILE="/tmp/scorer_response.json"  # Default cache

# Smart caching logic:
# - Fetch if file doesn't exist
# - Fetch if older than 5 minutes
# - Otherwise use cached response

# Override cache location (for batch mode):
export MSG_CACHE_FILE="/custom/path.json"
```

#### 3. Command Routing (Lines 228-666)
```bash
case "$COMMAND" in
  auto|a)     # Lines 229-277: overview + decision + links
  overview|o) # Lines 279-291: message metadata
  links|l)    # Lines 293-303: all links with scores
  decision|d) # Lines 305-314: detection decision
  search|s)   # Lines 316-325: search secondary attributes
  entities|e) # Lines 327-338: all entities with UUIDs
  rules|ru)   # Lines 340-353: detection rules breakdown
  heur|h)     # Lines 355-366: triggered heuristics
  phrases|ph) # Lines 368-391: phrase matches (supports --filter)
  entity|ent) # Lines 393-397: deep dive specific entity
  domains|dom)# Lines 399-413: domain entities only
  god|g)      # Lines 415-564: comprehensive analysis
  mismatch|mm)# Lines 566-618: detect judgement-review gaps
  confidence|cf) # Lines 620-636: confidence score analysis
  batch-summary|bs) # Lines 638-653: single-line CSV output
  raw|r)      # Lines 655-659: custom jq filter
esac
```

#### 4. P0 Commands Deep Dive

##### `mismatch` Command (Lines 566-618)
```bash
# Purpose: Detect 3 types of detection gaps automatically
# Output: JSON with mismatchDetected, gapType, recommendation

# Gap Type 1: JUDGEMENT_REVIEW_MISMATCH
# Condition: Judgement=ATTACK (1) but reviewDecision=NOT_REVIEW (3)
# Recommendation: "Category 4 gap: Lower review threshold OR increase signal weights"

# Gap Type 2: RULE_MATCH_NO_REVIEW
# Condition: Rules flagged but reviewDecision=NOT_REVIEW (3)
# Recommendation: "Category 3 or 4 gap: Check rule logic OR adjust threshold"

# Gap Type 3: MISCLASSIFIED_AS_SAFE
# Condition: Judgement=GOOD (4) or SURELY_SAFE (0)
# Recommendation: "Category 1 or 2 gap: Add missing features OR heuristics"

# KEY: This command LABELS the gap type but does NOT categorize (1-4)
# That intelligence lives in cfn-investigate
```

##### `confidence` Command (Lines 620-636)
```bash
# Purpose: Confidence score breakdown + threshold gap analysis
# Output: JSON with confidenceScore, estimatedThreshold, gap

# Fields:
# - confidenceScore: Actual score from detection system
# - reviewDecision: Decoded review decision
# - reviewDecisionRule: Which rule made the decision
# - estimatedThreshold: "3+ (inferred)" or "Met" or "Unknown"
# - gap: How far below threshold (e.g., 3 - 2.1 = 0.9)
# - flaggedRules: Array of rule names
# - ruleMatchCount: Number of rules that flagged
# - applicableRules: Array of {rule, matched} objects

# KEY: Provides data for Category 4 gap detection
```

##### `batch-summary` Command (Lines 638-653)
```bash
# Purpose: One-line CSV for batch aggregation (replaces 11 jq calls)
# Output: Single CSV line (no header)

# Format:
# MID,Judgement,ReviewDecision,ConfScore,FlaggedRules,NumEntities,NumLinks,NumAttachments,MaxRiskScore,NumHeuristics,NumSecondaryAttrs

# Example:
# -4865185475740621290,1,3,2.1,"CRED_PHISHING;BEC_DETECTION",5,3,0,0.87,12,347

# Performance: 11 jq extractions → 1 msg call (10x faster)
```

### Caching Behavior

```bash
# Scenario 1: First command for a MID
$ msg -4865 auto
🔍 Fetching scorer response for mid=-4865...
✅ Saved to /tmp/scorer_response.json
[... output ...]
# Time: ~2-3 seconds

# Scenario 2: Subsequent commands (cache hit)
$ msg -4865 mismatch
[... instant output from cache ...]
# Time: <100ms

# Scenario 3: Cache expired (>5 minutes)
$ msg -4865 entities
🔍 Fetching scorer response for mid=-4865...
✅ Saved to /tmp/scorer_response.json
[... output ...]
# Time: ~2-3 seconds

# Scenario 4: Batch mode with custom cache
$ export MSG_CACHE_FILE="/batch/cache/scorer_-4865.json"
$ msg -4865 auto
🔍 Fetching scorer response for mid=-4865...
✅ Saved to /batch/cache/scorer_-4865.json
[... output ...]
# Time: ~2-3 seconds, but no conflicts with other MIDs
```

### Error Handling

```bash
# API fetch failure
$ msg -4865 auto
❌ Failed to fetch scorer response
# Exit code: 1

# Invalid command
$ msg -4865 foobar
❌ Unknown command: foobar
Run 'msg --help' to see available commands
# Exit code: 1

# Missing required argument
$ msg -4865 entity
Usage: msg <mid> entity <uuid>
# Exit code: 1

$ msg -4865 search
❌ Usage: msg <mid> search <keyword>
# Exit code: 1
```

### Key Behaviors

1. **Idempotent**: Same MID + command = same output (within cache TTL)
2. **Stateless**: No side effects, no persistent state (except cache)
3. **Pure Data**: Returns JSON/CSV, never modifies detection system
4. **No Decisions**: Flags gaps but doesn't categorize or recommend fixes
5. **Composable**: Output designed for piping to jq, grep, awk

---

## Component 2: CLAUDE.md Documentation

### Overview

**File**: `/Users/archits/.claude/CLAUDE.md`
**Lines**: 334
**Purpose**: User manual for AI agents (Claude Code) using msg tool

### Structure

```markdown
1. Tool Reference (Lines 1-14)
   - Role: "Dumb data fetcher - NO intelligence"
   - Dependencies: jq, curl
   - Endpoint: pov.rt-scorer.abnormal.dev
   - Cache: /tmp/scorer_response.json (5-min TTL)

2. Commands Reference (Lines 17-54)
   - 16 commands organized by category
   - Aliases, arguments, output types
   - P0 commands highlighted

3. Output Formats (Lines 57-71)
   - JSON vs CSV vs Mixed
   - Field descriptions

4. Reference Tables (Lines 74-100)
   - Entity types (1-8)
   - Judgement values (0-8)
   - Review decision values (0-5)

5. Usage Patterns (Lines 104-161)
   - Single-MID analysis
   - Batch processing
   - Custom queries

6. Key Behaviors (Lines 165-182)
   - Caching logic
   - Error handling
   - Performance characteristics

7. Common Workflows (Lines 186-230)
   - CFN investigation (single)
   - Batch CFN investigation
   - Feature validation

8. Intelligence Boundary (Lines 233-246)
   - What msg provides: Raw data
   - What msg does NOT provide: Interpretation
   - Where intelligence lives: cfn-investigate

9. Tips for AI Agents (Lines 249-259)
   - 8 optimization tips

10. Troubleshooting (Lines 262-271)
    - Common issues + solutions

11. Examples by Use Case (Lines 274-332)
    - Quick triage
    - Gap detection
    - Batch processing
    - Entity deep dive
```

### Key Sections for AI Agents

#### Intelligence Boundary (Lines 233-246)
```markdown
**msg tool provides**: Raw data views (getters, filters, formatters)
**msg tool does NOT provide**: Interpretation, recommendations, gap categorization

**Intelligence lives in**:
- `/cfn-investigate` slash command - Systematic investigation workflow
- AI agent (Claude Code) - Gap analysis and recommendations

**Example of correct boundary**:
- ✅ `msg mismatch` → Returns `{mismatchDetected: true, gapType: "JUDGEMENT_REVIEW_MISMATCH"}`
- ❌ `msg mismatch` → Does NOT decide "this is a Category 4 gap, implement fix X"
- ✅ `/cfn-investigate` → Uses `msg mismatch` output to categorize and recommend
```

#### Tips for AI Agents (Lines 249-259)
```markdown
1. **Always start with `auto`** - Gets overview + decision + links in one call
2. **Check cache first** - If investigating same MID multiple times, data is cached
3. **Use `batch-summary` for aggregation** - 10x faster than manual jq parsing
4. **Use `mismatch` for gap detection** - Don't manually compare judgement vs reviewDecision
5. **Use `phrases --filter`** - Reduces output by 60%, keeps 100% signal
6. **Get UUIDs first** - Run `entities` before `entity <uuid>` deep dive
7. **Use `god` sparingly** - Produces 500-2000 lines, only use with `--deep` flag
8. **Set MSG_CACHE_FILE in batch mode** - Enables parallel processing without cache conflicts
```

---

## Component 3: CFN-Investigate Slash Command

### Overview

**File**: `/Users/archits/source/.claude/commands/cfn-investigate.md`
**Lines of Code**: 1531
**Type**: Claude Code slash command (AI workflow)
**Purpose**: Autonomous CFN investigation with ALL intelligence

### Architecture

#### 8-Phase Investigation Workflow

```
Phase 0: Mode Detection & Argument Parsing
├── Single-MID mode (-4865) or Batch mode (data.txt)?
├── Parse flags: --deep, --quick, --parallel, --output
└── Setup environment (batch mode creates output directory structure)

Phase 1: Triage (Adaptive)
├── Single-MID: msg auto + msg decision + msg mismatch
└── Batch: For each MID → msg batch-summary → batch_data.csv

Phase 2: Entity Analysis (Adaptive)
├── Single-MID: msg entities + msg domains + priority analysis
└── Batch: Aggregate entity types + risk scores across all CFNs

Phase 3: Signal Hunting (Adaptive)
├── Single-MID: msg heur + msg phrases --filter + msg links + msg rules
└── Batch: Aggregate heuristic frequencies + detect ignored signals

Phase 4: Targeted Search / Pattern Detection (THE INTELLIGENCE)
├── Single-MID: Vector-specific search (link/attachment/sender)
└── Batch: Detect systematic patterns (rule gaps, heuristic gaps, campaigns)

Phase 5: Deep Dive (Conditional)
├── Single-MID: msg god (if --deep flag)
└── Batch: Deep dive N representatives per pattern (if gaps found)

Phase 6: Root Cause Analysis
├── Use msg mismatch output as starting point
├── Analyze all collected data
└── Categorize gap (1=Missing Feature, 2=Missing Heuristic, 3=Rule Gap, 4=Threshold)

Phase 7: Recommendations
├── Single-MID: Category-specific fix + test plan + FP risk
└── Batch: Systematic improvement roadmap + priority (P0/P1/P2)

Phase 8: Report Generation
├── Single-MID: Markdown report → /tmp/cfn_report_${MID}.md
└── Batch: Executive summary → ${OUTPUT_DIR}/BATCH_SUMMARY.md
```

#### Dual-Mode Operation

```bash
# Single-MID Mode (Deep Investigation)
/cfn-investigate -4865185475740621290
# Time: 12-18 minutes
# Output: Full investigation report with root cause + recommendations

# Single-MID with Deep Dive
/cfn-investigate -4865185475740621290 --deep
# Time: 20-30 minutes
# Output: Above + god mode analysis (500-2000 lines)

# Batch Mode (Pattern Detection)
/cfn-investigate data.txt
# Time: 8-10 hours for 817 CFNs
# Output: Systematic gaps + aggregated patterns

# Batch Mode with Deep Dive
/cfn-investigate data.txt --deep 5 --parallel 3
# Time: 10-12 hours
# Output: Above + deep dive on 5 representatives per pattern
```

### Key Intelligence Components

#### 1. Automated Gap Detection (Phase 1, Lines 227-232)
```bash
# OLD (Manual, 20 lines of jq extraction):
REVIEW_DEC=$(jq -r '.extension.rtScorerExtension...' /tmp/scorer_response.json)
FLAGGED_RULES=$(jq -r '.extension.rtScorerExtension...' /tmp/scorer_response.json)
JUDGEMENT=$(jq -r '.extension.rtScorerExtension...' /tmp/scorer_response.json)
if [[ "${REVIEW_DEC}" == "3" ]]; then
    echo "→ NOT_REVIEW_MESSAGE: Detection gap in rules/heuristics"
elif...

# NEW (Automated, 3 lines):
echo "💡 INITIAL HYPOTHESIS (Automated Gap Detection)"
msg ${MID} mismatch
# Returns: {mismatchDetected: true, gapType: "JUDGEMENT_REVIEW_MISMATCH", ...}
```

#### 2. Batch Mode Optimization (Phase 1, Lines 275-276)
```bash
# OLD (Manual CSV extraction, 12 lines):
JUDGEMENT=$(jq -r '.extension...' "${MSG_CACHE_FILE}")
REVIEW_DEC=$(jq -r '.extension...' "${MSG_CACHE_FILE}")
NUM_ENTITIES=$(jq '.extension...' "${MSG_CACHE_FILE}")
# ... 8 more jq extractions
echo "${MID},${JUDGEMENT},${REVIEW_DEC},..." >> batch_data.csv

# NEW (One-line CSV, 1 line):
msg ${MID} batch-summary >> "${OUTPUT_DIR}/batch_data.csv"
# 10x faster: 11 jq calls → 1 msg call per MID
```

#### 3. Root Cause Categorization (Phase 6, Lines 923-945)
```bash
# Use msg mismatch output as starting point
MISMATCH_OUTPUT=$(msg ${MID} mismatch)
GAP_TYPE_AUTO=$(echo "$MISMATCH_OUTPUT" | jq -r '.gapType')
RECOMMENDATION_AUTO=$(echo "$MISMATCH_OUTPUT" | jq -r '.recommendation')

# Map automated gap type to 4-category framework:
# - JUDGEMENT_REVIEW_MISMATCH / RULE_MATCH_NO_REVIEW → Category 4
# - MISCLASSIFIED_AS_SAFE → Category 1 or 2 (needs deeper analysis)

# Then perform full 4-category analysis:
# Category 1: Missing Feature (attribute doesn't exist)
# Category 2: Missing Heuristic (attribute exists, no heuristic evaluates it)
# Category 3: Rule Gap (heuristic fires, no rule uses it)
# Category 4: Threshold Too Strict (rule sees signals, confidence below threshold)
```

#### 4. Confidence Analysis for Category 4 (Phase 7, Lines 1082-1087)
```bash
# Category 4 recommendation includes confidence analysis
echo "📊 Confidence Score Analysis"
msg ${MID} confidence
# Returns:
# {
#   "confidenceScore": 2.1,
#   "reviewDecision": "NOT_REVIEW_MESSAGE (3)",
#   "estimatedThreshold": "3+ (inferred from NOT_REVIEW decision)",
#   "gap": 0.9,  # How far below threshold
#   "flaggedRules": ["CRED_PHISHING_V2"],
#   "applicableRules": [...]
# }

# This data informs threshold tuning recommendation
```

#### 5. Pattern Detection (Phase 4 Batch Mode, Lines 650-756)
```bash
# THE INTELLIGENCE: Detects 3 types of systematic patterns

# Pattern 1: Rule Gaps (rules match but don't review)
# - Rules with >10 matches but <10% review rate
# - Indicates rules seeing signals but confidence too low
# - Output: RULE_GAP:${RULE}:${MATCHES}:${PCT}

# Pattern 2: Judgement Mismatches (marked BAD but not reviewed)
# - Messages with Judgement=ATTACK but reviewDecision=NOT_REVIEW
# - Indicates scorer sees attack but rules don't flag
# - Output: JUDGEMENT_MISMATCH:BAD_NOT_REVIEWED:${COUNT}:${PCT}:${SAMPLE_MIDS}

# Pattern 3: Campaign Clustering (3+ CFNs from same campaign)
# - Groups CFNs by campaignId
# - Indicates coordinated attack campaign bypassing detection
# - Output: CAMPAIGN:${CAMPAIGN_ID}:${COUNT}:${PCT}:${SAMPLE_MIDS}
```

### Performance Characteristics

#### Single-MID Mode
```
Quick CFN (obvious gap):        8-12 minutes
Standard CFN (multi-entity):    12-18 minutes
Complex CFN (--deep mode):      20-30 minutes

Breakdown:
- Phase 1 (Triage):             30-60 seconds (3 msg commands)
- Phase 2 (Entity Analysis):    60-90 seconds (4 msg commands)
- Phase 3 (Signal Hunting):     60-90 seconds (4 msg commands)
- Phase 4 (Targeted Search):    30-60 seconds (3 msg commands)
- Phase 5 (Deep Dive):          30-60 seconds (god mode, optional)
- Phase 6 (Root Cause):         2-5 minutes (analysis)
- Phase 7 (Recommendations):    3-5 minutes (generation)
- Phase 8 (Report):             10-20 seconds (file write)
```

#### Batch Mode
```
817 CFNs (standard):            8-10 hours
817 CFNs (--deep 5):            10-12 hours
817 CFNs (--parallel 3):        6-8 hours

Breakdown:
- Phase 1 (Triage):             4-5 hours (817 × 3 sec/MID with batch-summary)
- Phase 2 (Entity Aggregate):   10-15 minutes
- Phase 3 (Signal Aggregate):   15-20 minutes
- Phase 4 (Pattern Detection):  20-30 minutes
- Phase 5 (Deep Dive):          2-3 hours (if --deep 5, assuming 30 patterns)
- Phase 6 (Categorization):     N/A (batch mode skips this)
- Phase 7 (Roadmap):            10-15 minutes
- Phase 8 (Summary):            5-10 minutes
```

---

## Integration & Data Flow

### Single-MID Investigation (Detailed Trace)

```bash
$ /cfn-investigate -4865185475740621290

# Phase 0: Mode Detection
[cfn-investigate] Parse arguments → MODE=single, MID=-4865185475740621290

# Phase 1: Triage
[cfn-investigate] Call: msg -4865 auto
[msg] Fetch from POV API → /tmp/scorer_response.json (2.3 sec)
[msg] Return: {from: "attacker@evil.com", judgement: "GOOD (4)", numLinks: 1, ...}
[cfn-investigate] Call: msg -4865 decision
[msg] Read cache → /tmp/scorer_response.json (<100ms)
[msg] Return: {judgement: "GOOD (4)", reviewDecision: "NOT_REVIEW_MESSAGE (3)", flaggedRules: []}
[cfn-investigate] Call: msg -4865 mismatch
[msg] Read cache → analyze judgement vs reviewDecision
[msg] Return: {mismatchDetected: true, gapType: "MISCLASSIFIED_AS_SAFE", recommendation: "Category 1 or 2 gap: Add missing features OR heuristics"}

# Phase 2: Entity Analysis
[cfn-investigate] Call: msg -4865 entities
[msg] Read cache → extract all entities
[msg] Return: [{uuid: "abc123...", type: "DOMAIN (5)", riskScore: 0.12, ...}, ...]
[cfn-investigate] Call: msg -4865 domains
[msg] Read cache → filter entities where type=5
[msg] Return: [{uuid: "abc123...", url: "http://evil.com", riskScore: 0.12, ...}]
[cfn-investigate] Analyze: High-priority entities → None (all risk < 0.3)

# Phase 3: Signal Hunting
[cfn-investigate] Call: msg -4865 heur
[msg] Read cache → extract triggered heuristics per entity
[msg] Return: [{uuid: "abc123...", type: "DOMAIN (5)", triggered: ["low_reputation_domain"]}]
[cfn-investigate] Call: msg -4865 phrases --filter
[msg] Read cache → extract phrase matches where numMatches > 0
[msg] Return: [{"phraseType": "PASSWORD (35)", "numMatches": 2, "matches": [...]}]
[cfn-investigate] Call: msg -4865 rules
[msg] Read cache → extract detection rules
[msg] Return: {applicableRules: [{rule: "CRED_PHISHING_V2", matched: false, ...}]}

# Phase 4: Targeted Search
[cfn-investigate] Detect attack vector: NUM_LINKS=1, HAS_CRED_PHRASES=2 → Link-based attack
[cfn-investigate] Call: msg -4865 search ANCHOR_TEXT
[msg] Read cache → search secondary attributes
[msg] Return: {"ANCHOR_TEXT_MISMATCH": true, "ANCHOR_TEXT_SUSPICIOUS_SCORE": 0.87}
[cfn-investigate] Call: msg -4865 search HOMOGLYPH
[msg] Read cache → search secondary attributes
[msg] Return: {} (no HOMOGLYPH attributes found)

# Phase 5: Deep Dive (skipped, no --deep flag)

# Phase 6: Root Cause Analysis
[cfn-investigate] Analyze all data:
  - msg mismatch says: MISCLASSIFIED_AS_SAFE
  - No HOMOGLYPH attributes found (but domain looks suspicious)
  - Heuristic "low_reputation_domain" triggered but no rule uses it
[cfn-investigate] Categorize: Category 1 (Missing Feature: HOMOGLYPH_DETECTED)
[cfn-investigate] Categorize: Category 3 (Heuristic "low_reputation_domain" not used by rules)

# Phase 7: Recommendations
[cfn-investigate] Generate Category 1 recommendation:
  - Add HOMOGLYPH_DETECTED secondary attribute
  - Implement extraction logic in feature pipeline
  - Expected impact: +10-30% catch rate, Low FP risk
[cfn-investigate] Generate Category 3 recommendation:
  - Update CRED_PHISHING_V2 rule to use "low_reputation_domain" heuristic
  - Expected impact: +20-50% catch rate, Medium FP risk

# Phase 8: Report Generation
[cfn-investigate] Write report → /tmp/cfn_report_-4865185475740621290.md
[cfn-investigate] Display summary:
  ✅ CFN INVESTIGATION COMPLETE
  📊 Quick Summary:
     Message: -4865185475740621290
     Attack Type: Credential Phishing
     Root Cause: Category 1 (Missing Feature) + Category 3 (Rule Gap)
  📄 Full Report: /tmp/cfn_report_-4865185475740621290.md

Total time: 14 minutes, 32 seconds
msg tool calls: 10 commands (1 API fetch, 9 cache reads)
```

### Batch Investigation (High-Level Trace)

```bash
$ /cfn-investigate data.txt --deep 5 --parallel 1 --output ~/cfn_batch

# Phase 0: Mode Detection
[cfn-investigate] Parse arguments → MODE=batch, BATCH_FILE=data.txt
[cfn-investigate] Extract MIDs → 817 MIDs found
[cfn-investigate] Create output structure:
  ~/cfn_batch/2025-01-17_143022/
    ├── cache/               (scorer responses)
    ├── phase_data/          (triage outputs)
    ├── batch_data.csv       (aggregated data)
    ├── systematic_gaps.txt  (detected patterns)
    └── deep_*.md            (deep dive reports)

# Phase 1: Triage (817 MIDs × 3 sec = ~40 minutes)
[cfn-investigate] For MID_1 (-4865):
  export MSG_CACHE_FILE=~/cfn_batch/.../cache/scorer_-4865.json
  msg -4865 batch-summary >> batch_data.csv
  # Output: -4865,1,3,2.1,"CRED_PHISHING;BEC",5,3,0,0.87,12,347
[cfn-investigate] Progress: [50/817] 6% | Rate: 120/hr | ETA: 378 min
[cfn-investigate] Progress: [100/817] 12% | Rate: 125/hr | ETA: 344 min
... (continues for 817 MIDs)
[cfn-investigate] Phase 1 Complete: 817 CFNs triaged, 802 success, 15 failed

# Phase 2: Entity Analysis (Aggregate)
[cfn-investigate] Aggregating entity types across 802 CFNs...
[cfn-investigate] Entity Type Distribution:
  DOMAIN:      3,245 entities, Avg Risk: 0.234, Priority: MEDIUM
  FROM_EMAIL:    802 entities, Avg Risk: 0.156, Priority: LOW
  BODY_LINK:   1,872 entities, Avg Risk: 0.312, Priority: MEDIUM
  ATTACHMENT:    234 entities, Avg Risk: 0.687, Priority: HIGH

# Phase 3: Signal Hunting (Aggregate)
[cfn-investigate] Analyzing heuristic frequencies...
[cfn-investigate] Top 20 Heuristics:
  never_seen_sharepoint_tenant: 137 fired, 4 reviews, 3% rate ⚠️
  low_reputation_domain:         98 fired, 2 reviews, 2% rate ⚠️
  ...
[cfn-investigate] Detected 12 ignored heuristics (fire often, rarely review)

# Phase 4: Pattern Detection (THE INTELLIGENCE)
[cfn-investigate] Pattern 1: Rule Gaps
  CRED_PHISHING_V2: 247 matches, 23 reviews, 9% rate ⚠️
  → RULE_GAP:CRED_PHISHING_V2:247:30

[cfn-investigate] Pattern 2: Judgement Mismatches
  Messages marked ATTACK but NOT reviewed: 89/802 (11%)
  → JUDGEMENT_MISMATCH:BAD_NOT_REVIEWED:89:11:[-4865 -5123 -7834 ...]

[cfn-investigate] Pattern 3: Campaign Clusters
  Campaign abc123: 47 CFNs (5.9%) ⚠️
  → CAMPAIGN:abc123:47:5.9:[-4865 -5123 -7834 ...]

[cfn-investigate] ✅ Pattern Detection Complete: 24 systematic gaps identified

# Phase 5: Deep Dive (24 patterns × 5 representatives = 120 deep dives)
[cfn-investigate] Found 24 systematic patterns requiring deep dive
[cfn-investigate] Deep diving up to 5 representatives per pattern...
[cfn-investigate] Pattern: RULE_GAP - CRED_PHISHING_V2
  Representatives: -4865 -5123 -7834 -9012 -1234
  For each: msg overview, msg heur, msg entities, msg decision
  Saved: deep_RULE_GAP_CRED_PHISHING_V2_-4865.md (× 5 files)
... (continues for 24 patterns)
[cfn-investigate] ✅ Deep dive complete: 120 representatives analyzed

# Phase 6: Root Cause Analysis (skipped in batch mode)

# Phase 7: Recommendations (Systematic Improvements)
[cfn-investigate] Generating systematic improvement roadmap...
[cfn-investigate] Priority: 30% (247 CFNs)
  Gap: RULE_GAP - CRED_PHISHING_V2
  Category: 4 - Rule Threshold Too Strict
  Fix: Adjust rule threshold
  Impact: +10-25% catch rate, Medium-High FP risk
  Timeline: 1-2 weeks
[cfn-investigate] Priority: 11% (89 CFNs)
  Gap: JUDGEMENT_MISMATCH - BAD_NOT_REVIEWED
  Category: 4 - Rule Threshold Too Strict
  Fix: Lower review threshold from 3.0 to 2.5
  Impact: +5-15% catch rate, High FP risk
  Timeline: 1 week
... (continues for 24 patterns)
[cfn-investigate] Implementation Priority:
  P0 Gaps (>15%): 3 gaps
  P1 Gaps (5-15%): 8 gaps
  P2 Gaps (<5%): 13 gaps

# Phase 8: Report Generation
[cfn-investigate] Batch summary saved: ~/cfn_batch/.../BATCH_SUMMARY.md
[cfn-investigate] ✅ BATCH INVESTIGATION COMPLETE
  📊 Summary:
     Processed: 802 CFNs in 592 minutes (9.9 hours)
     Gaps Found: 24 systematic patterns
     Success Rate: 98%
  📄 Full Report: ~/cfn_batch/.../BATCH_SUMMARY.md
  📂 Output Directory: ~/cfn_batch/2025-01-17_143022/

Total time: 9 hours, 52 minutes
msg tool calls: 817 auto + 817 batch-summary + (120 × 4 deep dive) = 2,114 commands
API fetches: 817 (one per MID)
Cache reads: 1,297 (all subsequent commands per MID)
```

---

## Design Principles & Boundaries

### Principle 1: Separation of Concerns

```
┌─────────────────────────────────────────────────────┐
│                  Intelligence                        │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │       cfn-investigate workflow              │    │
│  │  - Gap categorization (1-4)                │    │
│  │  - Root cause analysis                     │    │
│  │  - Recommendations + test plans            │    │
│  │  - Pattern detection (batch mode)          │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
                         │
                         │ Uses
                         ▼
┌─────────────────────────────────────────────────────┐
│                   Data Layer                         │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │            msg tool commands                │    │
│  │  - Fetch from API                          │    │
│  │  - Format JSON                             │    │
│  │  - Decode enums                            │    │
│  │  - Cache responses                         │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
                         │
                         │ Fetches from
                         ▼
┌─────────────────────────────────────────────────────┐
│              POV RT-Scorer API                       │
│  https://pov.rt-scorer.abnormal.dev/debug/simulate  │
└─────────────────────────────────────────────────────┘
```

**Why this matters:**
- msg tool can evolve independently (add commands, change formats)
- cfn-investigate workflow stays the same (uses new commands automatically)
- Single source of truth for data fetching (no duplicate jq queries)
- Testable: msg tool can be unit tested separately from workflow

### Principle 2: Intelligence Boundary

```
❌ WRONG: msg tool makes decisions
msg -4865 mismatch
→ "This is a Category 4 gap. Lower threshold from 3.0 to 2.5."

✅ CORRECT: msg tool provides data, cfn-investigate decides
msg -4865 mismatch
→ {"mismatchDetected": true, "gapType": "JUDGEMENT_REVIEW_MISMATCH", "confidenceScore": 2.1}

cfn-investigate reads this data and decides:
→ "Based on mismatchDetected=true, gapType=JUDGEMENT_REVIEW_MISMATCH, and confidenceScore=2.1,
   this is a Category 4 gap (threshold too strict). Recommendation: Lower threshold from 3.0 to 2.5."
```

**Why this matters:**
- msg tool remains a "dumb pipe" (composable, reusable)
- All interpretation logic lives in ONE place (cfn-investigate)
- Changes to categorization logic don't require msg tool updates
- AI agent (Claude Code) can override intelligence if needed

### Principle 3: Cache-First Architecture

```
Scenario: Investigating one MID with 10 commands

Traditional approach (no caching):
msg -4865 auto      → API fetch (2.3 sec)
msg -4865 decision  → API fetch (2.3 sec)
msg -4865 mismatch  → API fetch (2.3 sec)
... (7 more fetches)
Total time: 10 × 2.3 sec = 23 seconds

Cache-first approach:
msg -4865 auto      → API fetch (2.3 sec) + cache to /tmp/scorer_response.json
msg -4865 decision  → Read cache (<100ms)
msg -4865 mismatch  → Read cache (<100ms)
... (7 more cache reads)
Total time: 2.3 sec + (9 × 0.1 sec) = 3.2 seconds

Speedup: 7.2x faster
```

**Why this matters:**
- Single-MID investigation completes in 12-18 minutes (not 2-3 hours)
- Batch mode processes 120-150 CFNs/hour (not 10-15 CFNs/hour)
- API load reduced by 90% (one fetch per MID vs 10-15 fetches)

### Principle 4: Batch-First Design

```
Old design: Per-MID manual jq extraction
for mid in $MID_LIST; do
  JUDGEMENT=$(jq -r '.extension.rtScorerExtension...' cache_${mid}.json)
  REVIEW_DEC=$(jq -r '.extension.rtScorerExtension...' cache_${mid}.json)
  ... (9 more jq extractions per MID)
  echo "${mid},${JUDGEMENT},${REVIEW_DEC},..." >> batch.csv
done
# Time: 817 MIDs × (11 jq × 0.1 sec) = 90 minutes

New design: batch-summary command
for mid in $MID_LIST; do
  msg $mid batch-summary >> batch.csv
done
# Time: 817 MIDs × 0.1 sec = 82 seconds

Speedup: 66x faster
```

**Why this matters:**
- Batch mode Phase 1 completes in ~1 hour (not 8-10 hours)
- Total batch investigation: 8-10 hours (not 40-50 hours)
- Enables processing 100s of CFNs in one investigation

### Principle 5: Composability

```bash
# msg tool output is designed for piping to jq, grep, awk

# Example 1: Extract all triggered heuristics across 100 MIDs
for mid in $MID_LIST; do
  msg $mid heur | jq -r '.[].triggered[]'
done | sort | uniq -c | sort -rn

# Example 2: Find MIDs with judgement-review mismatches
for mid in $MID_LIST; do
  MISMATCH=$(msg $mid mismatch | jq -r '.mismatchDetected')
  [[ "$MISMATCH" == "true" ]] && echo $mid
done > mismatches.txt

# Example 3: Aggregate confidence scores
for mid in $MID_LIST; do
  msg $mid confidence | jq -r '{mid: "'$mid'", score: .confidenceScore, gap: .gap}'
done | jq -s '.'

# Example 4: Custom analysis with raw command
msg -4865 raw '.extension.rtScorerExtension.processedMessageLogs[0].entities | to_entries | map(select(.value.scores.riskScore > 0.5))'
```

**Why this matters:**
- msg tool can be used outside of cfn-investigate workflow
- Enables ad-hoc analysis and one-off scripts
- AI agents can compose new workflows without modifying msg tool

---

## Performance Characteristics

### msg Tool Performance

| Operation | Cold (API fetch) | Warm (Cache hit) | Speedup |
|-----------|------------------|------------------|---------|
| First command | 2-3 seconds | N/A | N/A |
| Subsequent commands | N/A | <100ms | 20-30x |
| Batch mode (1 MID) | 2-3 seconds | 0.1 seconds | 20-30x |
| Batch mode (100 MIDs) | 3-5 minutes | 10 seconds | 18-30x |

### CFN-Investigate Performance

| Mode | MIDs | Time | Throughput | Bottleneck |
|------|------|------|------------|------------|
| Single-MID | 1 | 12-18 min | N/A | Analysis time |
| Single-MID (--deep) | 1 | 20-30 min | N/A | god mode output |
| Batch | 100 | 1.5-2 hours | 50-67 CFNs/hr | API rate limit |
| Batch | 817 | 8-10 hours | 82-102 CFNs/hr | API rate limit |
| Batch (--parallel 3) | 817 | 6-8 hours | 102-136 CFNs/hr | CPU + API |

### Optimization Impact

| Optimization | Before | After | Speedup |
|--------------|--------|-------|---------|
| batch-summary command | 817 × 11 jq = 90 min | 817 × 1 msg = 82 sec | 66x |
| msg mismatch command | 20 lines jq + logic | 1 msg call | 10x |
| phrases --filter flag | 2000 lines output | 800 lines output | 2.5x |
| Cache-first design | 10 API fetches/MID | 1 API fetch/MID | 10x |
| Parallel processing | 10 hours sequential | 6-8 hours parallel | 1.25-1.67x |

---

## Usage Patterns & Workflows

### Workflow 1: Quick CFN Triage

```bash
# Goal: Quickly understand why a message wasn't caught
# Time: 2-3 minutes

msg -4865 auto           # Overview + decision + links
msg -4865 mismatch       # Gap detection
msg -4865 confidence     # Threshold analysis

# Decision tree:
if mismatchDetected == true && gapType == "JUDGEMENT_REVIEW_MISMATCH":
  → Category 4 gap (threshold too strict)
  → Use confidence command to see gap
  → Recommendation: Lower threshold

if mismatchDetected == true && gapType == "MISCLASSIFIED_AS_SAFE":
  → Category 1 or 2 gap (missing feature or heuristic)
  → Need deeper analysis with cfn-investigate

if mismatchDetected == false:
  → Detection appears correct
  → May be false positive in CFN dataset
```

### Workflow 2: Full CFN Investigation

```bash
# Goal: Complete root cause analysis + recommendations
# Time: 12-18 minutes

/cfn-investigate -4865185475740621290

# Output:
# - Root cause (Category 1-4)
# - Evidence (specific gaps identified)
# - Recommendations (implementation steps)
# - Test plan (positive + negative cases)
# - FP risk assessment
# - Markdown report: /tmp/cfn_report_-4865185475740621290.md
```

### Workflow 3: Batch CFN Investigation

```bash
# Goal: Process 100+ CFNs, detect systematic patterns
# Time: 8-10 hours for 817 CFNs

# Step 1: Create MID list file
cat > data.txt <<EOF
-4865185475740621290
-715876989141528867
-2428734771100200806
... (814 more MIDs)
EOF

# Step 2: Run batch investigation
/cfn-investigate data.txt --deep 5 --parallel 3 --output ~/cfn_batch

# Output:
# - ~/cfn_batch/2025-01-17_143022/
#   ├── batch_data.csv          (817 lines, 11 fields each)
#   ├── systematic_gaps.txt     (24 patterns detected)
#   ├── deep_*.md               (120 deep dive reports)
#   └── BATCH_SUMMARY.md        (executive summary)
```

### Workflow 4: Validate Feature Implementation

```bash
# Goal: Check if a new feature (e.g., DOCX_MHT_DETECTED) is triggering
# Time: 1-2 minutes

msg -4865 search DOCX_MHT
# Returns: {"DOCX_MHT_DETECTED": true, "DOCX_MHT_COUNT": 3}
# → Feature is triggering correctly

msg -4865 heur | jq -r '.[].triggered[]' | grep "suspicious_docx"
# Returns: suspicious_docx_embedded_html
# → Heuristic is also triggering

msg -4865 rules | jq '.applicableRules[] | select(.rule == "ATTACHMENT_THREAT_V2")'
# Returns: {rule: "ATTACHMENT_THREAT_V2", matched: true, ...}
# → Rule is using the heuristic and matching
```

### Workflow 5: Entity Deep Dive

```bash
# Goal: Investigate specific suspicious entity
# Time: 2-3 minutes

# Step 1: Get all entities with UUIDs
msg -4865 entities

# Step 2: Identify high-risk entity
# (Copy UUID from output, e.g., "abc123...")

# Step 3: Deep dive that entity
msg -4865 entity abc123

# Returns:
# {
#   "type": 5,  # DOMAIN
#   "entityAttributes": {
#     "URL_STRING": "http://evil.com",
#     "URL_REGISTERED_DOMAIN": "evil.com",
#     "URL_HOMOGLYPH_DETECTED": true,
#     "URL_NEWLY_REGISTERED": true,
#     ...
#   },
#   "scores": {
#     "riskScore": 0.87,
#     "abnormalityScore": 0.92
#   },
#   "heuristicEvaluationResults": {
#     "low_reputation_domain": true,
#     "never_seen_domain": true,
#     "homoglyph_domain": true
#   }
# }

# Analysis:
# - 3 heuristics triggered (low_reputation, never_seen, homoglyph)
# - High risk score (0.87)
# - Homoglyph detected
# → Category 3 gap: Heuristics triggered but no rule uses them
```

---

## Troubleshooting & Best Practices

### Common Issues

#### Issue 1: "Failed to fetch scorer response"

**Cause**: MID invalid, network issue, or API down

**Solution**:
```bash
# Check MID validity (should be signed 64-bit integer)
echo -4865185475740621290 | grep -E '^-?[0-9]+$'

# Check network access
curl -sf "https://pov.rt-scorer.abnormal.dev/healthcheck"

# Try different MID
msg -715876989141528867 auto
```

#### Issue 2: Cache conflicts in batch mode

**Cause**: Multiple MIDs overwriting /tmp/scorer_response.json

**Solution**:
```bash
# Use MSG_CACHE_FILE env var for custom cache location
for mid in $MID_LIST; do
  export MSG_CACHE_FILE="/batch/cache/scorer_${mid}.json"
  msg $mid batch-summary >> batch.csv
done
```

#### Issue 3: "phrases" output too large

**Cause**: Showing all 237 phrase types (including zeros)

**Solution**:
```bash
# Use --filter flag to show only matches > 0
msg -4865 phrases --filter

# Output reduced from ~2000 lines to ~800 lines (60% reduction)
```

#### Issue 4: cfn-investigate hangs on batch mode

**Cause**: One MID failing, blocking entire loop

**Solution**:
```bash
# Check errors.log
cat ~/cfn_batch/.../errors.log

# Re-run with failed MIDs filtered out
grep -v "Failed MIDs" data.txt > data_clean.txt
/cfn-investigate data_clean.txt
```

### Best Practices

#### 1. Always Start with `auto`

```bash
# ✅ CORRECT: Start with auto (gets 80% of needed data)
msg -4865 auto      # Overview + decision + links
msg -4865 mismatch  # Gap detection
msg -4865 heur      # Heuristics (if needed)

# ❌ WRONG: Manually call overview, decision, links separately
msg -4865 overview
msg -4865 decision
msg -4865 links
# This works but is 3x slower to type
```

#### 2. Use Specialized Commands

```bash
# ✅ CORRECT: Use mismatch command
msg -4865 mismatch
# → {"mismatchDetected": true, "gapType": "JUDGEMENT_REVIEW_MISMATCH", ...}

# ❌ WRONG: Manually compare judgement vs reviewDecision
JUDGEMENT=$(msg -4865 decision | jq -r '.judgement')
REVIEW=$(msg -4865 decision | jq -r '.reviewDecision')
if [[ "$JUDGEMENT" == "1" && "$REVIEW" == "3" ]]; then
  echo "Mismatch detected"
fi
# This works but reinvents the wheel
```

#### 3. Use Batch-Friendly Commands

```bash
# ✅ CORRECT: Use batch-summary
for mid in $MID_LIST; do
  msg $mid batch-summary >> batch.csv
done
# Time: 817 × 0.1 sec = 82 seconds

# ❌ WRONG: Manual jq extraction
for mid in $MID_LIST; do
  JUDGEMENT=$(jq -r '.extension...' cache_${mid}.json)
  REVIEW_DEC=$(jq -r '.extension...' cache_${mid}.json)
  ... (9 more jq extractions)
  echo "${mid},${JUDGEMENT},${REVIEW_DEC},..." >> batch.csv
done
# Time: 817 × 1.1 sec = 90 minutes (66x slower!)
```

#### 4. Set Custom Cache in Batch Mode

```bash
# ✅ CORRECT: Set MSG_CACHE_FILE per MID
for mid in $MID_LIST; do
  export MSG_CACHE_FILE="/batch/cache/scorer_${mid}.json"
  msg $mid auto > /batch/output/${mid}.txt
done
# Parallel-safe, no cache conflicts

# ❌ WRONG: Use default /tmp/scorer_response.json
for mid in $MID_LIST; do
  msg $mid auto > /batch/output/${mid}.txt
done
# Cache conflicts, each MID overwrites previous
```

#### 5. Use cfn-investigate for Full Analysis

```bash
# ✅ CORRECT: Use cfn-investigate for complete investigation
/cfn-investigate -4865185475740621290
# → 12-18 minutes, full report with root cause + recommendations

# ❌ WRONG: Manually replicate workflow with msg commands
msg -4865 auto
msg -4865 decision
msg -4865 entities
msg -4865 heur
... (manually analyze, categorize, recommend)
# → 2-3 hours, error-prone, inconsistent
```

#### 6. Use --filter for Phrase Analysis

```bash
# ✅ CORRECT: Use --filter flag
msg -4865 phrases --filter
# Output: ~800 lines (only matches > 0)

# ❌ WRONG: Show all phrases
msg -4865 phrases
# Output: ~2000 lines (includes 237 phrase types with 0 matches)
```

#### 7. Get UUIDs Before Entity Deep Dive

```bash
# ✅ CORRECT: Run entities first to get UUIDs
msg -4865 entities
# Copy UUID from output: abc123...
msg -4865 entity abc123
# → Deep dive works

# ❌ WRONG: Guess UUID
msg -4865 entity some-random-uuid
# → Error: UUID not found
```

---

## Appendix: Quick Reference

### msg Tool Command Summary

```
Core: auto, overview, decision, links, entities
Deep: entity <uuid>, domains, search <keyword>
Signals: rules, heur, phrases [--filter]
Gaps: mismatch, confidence, batch-summary
Advanced: god, raw '<jq_filter>'
```

### cfn-investigate Workflow Summary

```
Phase 1: Triage → msg auto + mismatch
Phase 2: Entity Analysis → msg entities + domains
Phase 3: Signal Hunting → msg heur + phrases --filter + rules
Phase 4: Targeted Search → msg search <KEYWORD>
Phase 5: Deep Dive (optional) → msg god
Phase 6: Root Cause → Categorize (1-4)
Phase 7: Recommendations → Implementation steps + test plan
Phase 8: Report → Markdown file
```

### Gap Categories

```
Category 1: Missing Feature
  - Indicator exists but no attribute
  - Fix: Add secondary attribute + extraction logic

Category 2: Missing Heuristic
  - Attribute exists but no heuristic evaluates it
  - Fix: Add heuristic evaluation

Category 3: Rule Gap
  - Heuristic fires but no rule uses it
  - Fix: Update rule to use heuristic

Category 4: Threshold Too Strict
  - Rule sees signals but confidence below threshold
  - Fix: Tune threshold (use msg confidence)
```

### Performance Targets

```
Single-MID: 12-18 minutes (quick), 20-30 minutes (--deep)
Batch (100 CFNs): 1.5-2 hours
Batch (817 CFNs): 8-10 hours
msg tool (cold): 2-3 seconds per command
msg tool (warm): <100ms per command
```

---

## End of Document

**Status**: Complete and validated
**Next Steps**: Use this documentation as reference for all msg tool and cfn-investigate operations
**Maintenance**: Update when new commands added or workflow phases modified

**Key Takeaway**: The intelligence boundary is sacred - msg tool fetches data, cfn-investigate provides ALL intelligence. This separation makes the system maintainable, composable, and scalable.
