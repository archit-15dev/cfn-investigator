# Deterministic Tools, Smart Workflows: Building Reliable AI Automation

*How we built CFN Investigator with Claude Code to make AI automation fast, safe, and composable*

---

Most "AI-driven automation" fails because it's messy at the edges. Tools mutate state unpredictably. Agents guess at context. Workflows drift out of sync with reality. The fix isn't more intelligence — it's **more determinism**.

This is the story of how we built **CFN Investigator**, an autonomous security investigation system that analyzes why attack emails bypass detection. It processes 817 false negatives in under 5 hours, categorizes detection gaps into 4 types, and generates actionable fixes with 99% success rate.

The secret? A clean separation between dumb tools and smart orchestration.

---

## The Core Idea: Separate Mechanism from Policy

At the foundation, there are only three moving parts:

| Layer | Purpose |
|-------|---------|
| **Tools** (Mechanism) | Deterministic, side-effect-controlled code |
| **Instructions** (Protocol) | Define exactly how to invoke those tools — args, schemas, contracts, safety |
| **Slash Commands** (Policy) | Declare what to achieve; orchestrate multiple tools and reason over outputs |

**Principle:** Stable interfaces beat clever internals.
AI agents stay smart by standing on boring, predictable I/O.

---

## A Concrete Example: CFN Investigator

Let's make this concrete. CFN Investigator has three layers:

### Layer 1: The `msg` Tool (Dumb, Fast, Reliable)

A 667-line bash script with **16 commands**, zero intelligence:

```bash
msg <message_id> auto        # Quick triage (overview + decision + links)
msg <message_id> mismatch    # Detect judgement-review gaps
msg <message_id> search URL_ # Search for URL features
msg <message_id> entities    # List all entities
```

**Key characteristics:**
- **Deterministic**: Same input → same output, every time
- **Idempotent**: Reads from API, caches for 5 minutes, no mutations
- **Structured output**: JSON for machine parsing, formatted text for humans
- **Zero domain logic**: Just fetch, parse, format. No analysis.

**Example:**
```bash
$ msg -4865185475740621290 auto
🔍 Fetching scorer response for mid=-4865185475740621290...
✅ Saved to /tmp/scorer_response.json

📊 OVERVIEW
{
  "from": "admin@paypal-verify.tk",
  "judgement": "GOOD (4)",           ← Should be ATTACK!
  "numLinks": 1,
  "maxRiskScores": { "riskScore": 0.87 }
}
```

**Why it's dumb:**
- Doesn't know what "GOOD" vs "ATTACK" means
- Doesn't decide if 0.87 risk score is high
- Just shows you the data and gets out of the way

**Performance:**
- First call: 2-3 seconds (API fetch + cache)
- Subsequent calls: <100ms (read from cache)
- Batch throughput: ~200 messages/hour with parallelization

---

### Layer 2: The `CLAUDE.md` Instructions (Contract, Not Code)

A 500-line reference document that defines:

**Tool catalog (16 commands organized by frequency):**
```
80% usage → auto, mismatch, search, entities
10% usage → domains, heur, phrases, confidence
5% usage  → rules, links, overview, decision
5% usage  → god, batch-summary, entity, raw
```

**Schemas for every output:**
```yaml
msg <mid> mismatch:
  output:
    mismatchDetected: boolean
    gapType: enum[JUDGEMENT_REVIEW_MISMATCH, RULE_MATCH_NO_REVIEW, ...]
    confidenceScore: float
    recommendation: string
```

**Usage patterns:**
```markdown
# When to use `search`
- Looking for specific attack indicators
- Checking if a feature exists (empty result = Category 1 gap)
- Example: `msg <mid> search HOMOGLYPH` → {} means missing feature

# When NOT to use `search`
- Don't search without a keyword
- Don't use for entity deep dives (use `entity <uuid>` instead)
```

**Caching behavior:**
```
Cache location: /tmp/scorer_response.json
Cache TTL: 5 minutes (auto-refetch)
Custom cache: export MSG_CACHE_FILE=/custom/path.json
```

**Why it matters:**
- AI agent reads this once, follows it 817 times
- Humans can audit "did the agent use the tool correctly?"
- Schema drift breaks CI, not silently corrupt outputs
- Zero ambiguity: "should I use `god` or `auto`?" → Check usage %.

---

### Layer 3: The `/cfn-investigate` Workflow (Smart, Adaptive, Auditable)

A 1,530-line workflow specification that orchestrates the `msg` tool through **8 phases**:

```
Phase 1: Triage           → msg auto + msg mismatch
Phase 2: Entity Analysis  → msg entities + msg domains
Phase 3: Signal Hunting   → msg heur + msg phrases --filter
Phase 4: Targeted Search  → msg search <keywords>
Phase 5: Deep Dive        → msg god (if --deep flag)
Phase 6: Root Cause       → Categorize gap (1-4)
Phase 7: Recommendations  → Generate fix based on category
Phase 8: Report           → Save markdown artifact
```

**Example orchestration logic (Phase 4):**
```bash
# Determine attack vector from Phase 1-3 data
NUM_LINKS=$(jq '.numLinks' /tmp/scorer_response.json)
NUM_ATTACHMENTS=$(jq '.numAttachments' /tmp/scorer_response.json)

# If link-based attack → search for URL features
if [[ $NUM_LINKS -gt 0 ]]; then
  msg ${MID} search ANCHOR_TEXT
  msg ${MID} search URL_
  msg ${MID} domains
fi

# If attachment-based → search for file features
if [[ $NUM_ATTACHMENTS -gt 0 ]]; then
  msg ${MID} search FILE_EXTENSION
  msg ${MID} search ATTACHMENT
  msg ${MID} search MACRO
fi
```

**Key characteristics:**
- **Adaptive**: Branches based on attack type detected in earlier phases
- **Auditable**: Every `msg` call logged with args + output
- **Composable**: Each phase is independent, testable
- **Safe**: Reads only, writes to `/tmp/cfn_report_*.md` (reviewable)

**The intelligence is HERE:**
- Decides which `msg` commands to run based on context
- Interprets outputs: "judgement=GOOD but should be ATTACK"
- Categorizes gaps: Missing Feature vs Missing Heuristic vs Rule Gap vs Threshold
- Generates actionable recommendations based on category

**Batch mode** (systematic pattern detection across 100s of messages):
```bash
/cfn-investigate cfn_list.txt --parallel 3

# Outputs:
# - batch_data.csv (structured data for all messages)
# - systematic_gaps.txt (patterns affecting >3% of batch)
# - deep_*.md (reports for representative examples)
```

---

## The Three Interfaces

### 1. Tool Interface (args → output + exit_code)

```bash
# Input: MID + command
msg -4865185475740621290 search HOMOGLYPH

# Output: JSON (stdout)
{}

# Exit code: 0 (success)
```

**Contract:**
- No side effects except API calls (and only on first invocation)
- Cache prevents redundant calls
- Structured output (JSON or formatted text)
- Exit code signals success/failure

### 2. Instruction Interface (intent → tool calls)

```markdown
## Scenario: Check if homoglyph detection triggered

**Intent**: Verify if HOMOGLYPH feature exists

**Tool call**: `msg <mid> search HOMOGLYPH`

**Output schema**:
- Empty `{}` → Feature doesn't exist (Category 1 gap)
- `{HOMOGLYPH_DETECTED: true}` → Feature exists

**Error handling**: Empty output is valid (means feature not triggered)
```

### 3. Task Interface (args → plan → artifacts)

```bash
# Input
/cfn-investigate -4865185475740621290

# Plan (Phase 1-8)
Phase 1: msg auto + msg mismatch → Hypothesis: Category 2 gap
Phase 2: msg entities → 3 entities, 1 high-risk domain
Phase 3: msg heur → 8 heuristics fired
Phase 4: msg search ANCHOR_TEXT → Found mismatch
Phase 6: Categorize as Category 2 (Missing Heuristic)
Phase 7: Generate recommendation
Phase 8: Save report

# Artifacts
/tmp/cfn_report_-4865185475740621290.md
```

---

## Four Invariants That Make It Work

### 1. Tools are Predictable

**msg tool guarantees:**
- Same MID + command → identical output (within 5-min cache window)
- Schema stability (16 commands, stable since v1.0)
- No hidden state mutations
- Explicit cache location (`/tmp/scorer_response.json`)

**How we enforce it:**
```bash
# Every command reads from same cache
BASE_PATH='.extension.rtScorerExtension.processedMessageLogs[0]'
OUTPUT_FILE="/tmp/scorer_response.json"

# Cache check (5-min TTL)
if [ ! -f "$OUTPUT_FILE" ] || [ "$(find "$OUTPUT_FILE" -mmin +5)" ]; then
  curl -sf "$URL" -o "$OUTPUT_FILE"
fi
```

### 2. Instructions are the Single Source of Truth

**CLAUDE.md defines:**
- When to use each command (80/20 breakdown)
- Output schemas for all 16 commands
- Error handling (API timeout → retry once)
- Caching behavior
- Entity types, judgement values, review decisions (enums)

**Agent workflow:**
```
1. Read CLAUDE.md (once per session)
2. Follow usage patterns (817 times in batch mode)
3. Parse outputs using documented schemas
4. Never guess — if unclear, check CLAUDE.md
```

### 3. Tasks are Reviewable

**Every investigation generates:**
```
/tmp/cfn_report_-4865185475740621290.md
├── Message Details (from, subject, attack type)
├── Root Cause Analysis (category 1-4 with evidence)
├── Recommendations (implementation steps)
└── Test Plan (positive/negative cases)
```

**Batch investigations:**
```
~/cfn_batch/2025-01-17_143522/
├── batch_data.csv            # Structured data (11 fields × 817 rows)
├── systematic_gaps.txt       # Patterns (15 detected)
├── BATCH_SUMMARY.md          # Executive summary
└── deep_*.md                 # Representative examples
```

**Why reviewable?**
- Human can audit: "Did the agent categorize this correctly?"
- Reproducible: Same MID → same report (if run within 5 min)
- Version control: All reports are markdown in `/tmp` or `~/cfn_batch`

### 4. No Hidden State

**Every msg call logs:**
```
command: msg -4865185475740621290 auto
duration: 2.3s
cache_hit: false
exit_code: 0
output_size: 128KB
```

**Workflow logs:**
```
Phase 1: Triage (3 msg calls, 2.5s)
Phase 2: Entity Analysis (2 msg calls, 0.2s)
Phase 3: Signal Hunting (4 msg calls, 0.3s)
...
Total: 18 msg calls, 4.2s, 100% cache hit rate after Phase 1
```

---

## Why This Scales

### 1. Composability

**Add new msg commands independently:**
```bash
# Add new command: msg <mid> campaigns
campaigns|camp)
  jq '.extension.rtScorerExtension.processedMessageLogs[0].messageDecisions.detectionControlSystemResult.campaignId' "$OUTPUT_FILE"
  ;;
```

**Add new workflow phases:**
```bash
# Phase 9: Campaign Analysis
if [[ "${MODE}" == "batch" ]]; then
  msg ${MID} campaigns >> "${OUTPUT_DIR}/campaigns.txt"
fi
```

**No coupling:** New commands don't break existing workflows. New phases don't break existing commands.

### 2. Team Portability

**Contracts live in-repo:**
- `CLAUDE.md` → Tool catalog + schemas
- `cfn-investigate-workflow` → Task spec
- `msg` → Executable (installed via `install.sh`)

**Humans + agents follow same playbook:**
```bash
# Human workflow
msg -4865185475740621290 auto
msg -4865185475740621290 mismatch
msg -4865185475740621290 search URL_

# Agent workflow (same commands, orchestrated)
/cfn-investigate -4865185475740621290
```

**Onboarding time:**
- Read `CLAUDE.md` (15 min)
- Run `/cfn-investigate <mid>` (1 example)
- Understand 80% of capabilities

### 3. Auditability

**Every run leaves machine-readable breadcrumbs:**

**Single-MID mode:**
```
/tmp/scorer_response.json    # Raw API response (128KB)
/tmp/cfn_report_*.md         # Investigation report
```

**Batch mode:**
```
~/cfn_batch/<timestamp>/
├── batch_data.csv           # 817 rows × 11 fields
├── systematic_gaps.txt      # 15 patterns detected
├── cache/scorer_*.json      # 817 API responses
└── phase_data/triage_*.txt  # 817 triage outputs
```

**Audit questions:**
- "Why did agent categorize this as Category 2?" → Read `cfn_report_*.md`, check evidence section
- "Which msg commands were called?" → Check workflow logs
- "What was the raw API response?" → Check `/tmp/scorer_response.json`

### 4. Safety

**Writes require explicit paths:**
```bash
# msg tool: NO writes (only reads + cache)
# Workflow: Writes to /tmp/cfn_report_*.md (reviewable before action)
```

**Batch mode: Isolated output dirs:**
```bash
OUTPUT_DIR="${OUTPUT_DIR:-${HOME}/cfn_batch/$(date +%Y-%m-%d_%H%M%S)}"
mkdir -p "${OUTPUT_DIR}"
# All artifacts land in timestamped directory
```

**No surprise writes:**
- msg never mutates state (except API cache)
- Workflow never writes to arbitrary locations
- Batch mode creates isolated output dirs

---

## The Failure Model

### 1. Tool Fails → Surface, Retry, Raise

```bash
# msg tool error handling
if ! curl -sf "$URL" -o "$OUTPUT_FILE"; then
  echo "❌ Failed to fetch scorer response"
  exit 1
fi
```

**Workflow response:**
```bash
# Single failure
if ! msg ${MID} auto > /dev/null 2>&1; then
  echo "❌ Failed: ${MID}" >> "${OUTPUT_DIR}/errors.log"
  ((FAILED++))
  continue  # Skip to next MID
fi
```

**Result:** 817 MIDs → 808 success, 9 failures (99% success rate)

### 2. Schema Drift → Halt with Contract Violation

```bash
# Expected schema
{
  "mismatchDetected": boolean,
  "gapType": string,
  "confidenceScore": number
}

# Actual output (after API change)
{
  "mismatch": boolean,  # ← Field renamed!
  "gapType": string
}

# jq parsing fails
jq -r '.mismatchDetected'  # → null (not boolean)

# Workflow halts
Error: Contract violation in msg mismatch output
Expected field: mismatchDetected (boolean)
Actual: null
```

**Better than:** Silent corruption (treating `null` as `false`)

### 3. Long Operations → Timeouts + Graceful Degradation

```bash
# API timeout (30s)
timeout 30 curl -sf "$URL" -o "$OUTPUT_FILE"

# Workflow timeout (2 min per phase)
timeout 120 msg ${MID} god

# Graceful degradation
if [[ $? -eq 124 ]]; then
  echo "⏱️ Timeout in god mode, using partial data"
  # Continue with data from auto, mismatch, entities
fi
```

---

## The Minimal Control Schema

### Tool Schema

```yaml
name: msg
version: 1.0
args:
  - message_id: int64 (required)
  - command: enum[auto, mismatch, search, ...] (optional, default: auto)
  - keyword: string (required if command=search)
output_schema:
  auto: mixed (3 sections: overview, decision, links)
  mismatch: json (7 fields: mismatchDetected, gapType, ...)
  search: json (dynamic keys based on keyword)
side_effects:
  - API call to pov.rt-scorer.abnormal.dev (only if cache miss)
  - Write to /tmp/scorer_response.json (cache)
exit_codes:
  0: success
  1: API fetch failed / invalid command
```

### Instruction Schema

```yaml
command: msg <mid> mismatch
when_to_use:
  - After `auto` shows judgement doesn't match expectation
  - Checking for detection gaps
when_not_to_use:
  - First command (use `auto` instead)
  - Without prior context
examples:
  - cmd: msg -4865185475740621290 mismatch
    output: { mismatchDetected: true, gapType: "JUDGEMENT_REVIEW_MISMATCH", ... }
constraints:
  - Requires cache (run `auto` first)
retries: 0 (reads from cache, no network call)
timeout: N/A (instant, <100ms)
```

### Task Schema

```yaml
goal: Investigate why attack email bypassed detection
steps:
  - phase: 1
    name: Triage
    commands: [msg auto, msg decision, msg mismatch]
    duration: 2-3s
  - phase: 2
    name: Entity Analysis
    commands: [msg entities, msg domains]
    duration: <1s
  ...
artifacts:
  - /tmp/cfn_report_${MID}.md
  - /tmp/scorer_response.json (cache)
apply_mode: read-only (no mutations)
rollback_note: N/A (no state changes)
```

---

## Anti-Patterns We Avoided

### 1. Tools That Guess Inputs

**❌ Bad:**
```bash
msg auto  # Guesses MID from context? From last command?
```

**✅ Good:**
```bash
msg -4865185475740621290 auto  # Explicit MID required
```

### 2. Instructions Full of "Maybe" and "Usually"

**❌ Bad:**
```markdown
Usually returns JSON, but sometimes might return text.
Maybe use `--filter` if you want fewer results.
```

**✅ Good:**
```markdown
Returns JSON with 7 fields: mismatchDetected (boolean), gapType (string), ...
Use `--filter` flag to show only matches > 0 (reduces output by 60%).
```

### 3. Tasks That Mutate by Default

**❌ Bad:**
```bash
/cfn-fix -4865185475740621290  # Immediately applies fix to production
```

**✅ Good:**
```bash
/cfn-investigate -4865185475740621290  # Investigates, writes report
# Human reviews report
# Human creates Jira ticket
# Human implements fix
```

### 4. Unversioned JSON Outputs

**❌ Bad:**
```json
{
  "mismatch": true,
  "type": "gap"
}
```

**✅ Good:**
```json
{
  "mismatchDetected": true,
  "gapType": "JUDGEMENT_REVIEW_MISMATCH",
  "description": "Marked as ATTACK but NOT reviewed - confidence threshold issue",
  "confidenceScore": 2.7,
  "recommendation": "Category 4 gap: Lower review threshold OR increase signal weights"
}
```

**Why:** Versioned field names (`mismatchDetected` not `mismatch`) + enums (`JUDGEMENT_REVIEW_MISMATCH` not `gap`) + detailed context.

---

## Measuring Success

### 1. Mean Time to Complete Task ↓

**Single-MID investigation:**
- Before: 30-45 minutes (manual analysis)
- After: 8-15 minutes (autonomous with `cfn-investigate`)
- Improvement: **3x faster**

**Batch investigation:**
- Before: 2-3 weeks (manual analysis of 817 CFNs)
- After: 5 hours (autonomous batch mode)
- Improvement: **67x faster**

### 2. Re-runs Produce Identical Artifacts

**Test:**
```bash
/cfn-investigate -4865185475740621290 > report1.md
rm /tmp/scorer_response.json
/cfn-investigate -4865185475740621290 > report2.md
diff report1.md report2.md
```

**Result:** Zero differences (within 5-min cache window)

**Why it matters:**
- Reproducibility for auditing
- Debugging is easier (same input → same output)
- Trust in automation increases

### 3. Contract Checks Pass in CI

**Checks:**
```bash
# Schema validation
jq -e '.mismatchDetected | type == "boolean"' /tmp/scorer_response.json

# Shellcheck (msg script)
shellcheck msg

# Workflow frontmatter validation
head -5 cfn-investigate-workflow | grep -q 'allowed-tools: Bash, Read, Write, Edit'
```

**Result:** All checks pass before merge

### 4. Zero "Surprise Writes" Incidents

**Tracking:**
- msg: Only writes to `/tmp/scorer_response.json` (documented)
- Workflow: Only writes to `/tmp/cfn_report_*.md` or `~/cfn_batch/<timestamp>/`
- No writes to production systems, databases, or arbitrary locations

**Incidents in 6 months:** 0

---

## Next Moves: How to Apply This Pattern

### 1. Add JSON Schema for Every Tool Output

**Current state:**
```bash
msg <mid> mismatch
# Returns JSON, but schema is in CLAUDE.md (text documentation)
```

**Target state:**
```bash
msg <mid> mismatch --validate
# Validates output against mismatch.schema.json before returning
```

**Implementation:**
```bash
# Generate schema
msg <mid> mismatch | jq 'walk(if type == "object" then with_entries(.value = (.value | type)) else . end)' > mismatch.schema.json

# Validate in CI
jq -e --schema mismatch.schema.json /tmp/output.json
```

### 2. Standardize `--dry-run` / `--apply` Across All Write-Capable Tools

**Current:**
- msg has no writes (except cache)
- Workflow has implicit dry-run (writes to `/tmp`)

**Target:**
```bash
/cfn-investigate <mid> --dry-run   # Writes to /tmp (default)
/cfn-investigate <mid> --apply     # Creates Jira ticket + implements fix
```

### 3. Create Template Slash Command

**Pattern:**
```markdown
---
allowed-tools: Bash, Read, Write, Edit
argument-hint: <input>
description: Template for new workflows
---

# Phase 1: Fetch
tool fetch <input>

# Phase 2: Parse
jq '.field' output.json

# Phase 3: Plan
Generate recommendation based on parsed data

# Phase 4: Artifact
Save report to /tmp/report_<input>.md
```

**Usage:**
```bash
cp template-workflow.md ~/.claude/commands/my-workflow.md
# Edit phases
/my-workflow <input>
```

### 4. Extend CLAUDE.md with Catalog

**Current structure:**
```markdown
## msg (Message Scorer Analysis)
- 16 commands
- Cache behavior
- Output formats
```

**Target structure:**
```markdown
## Tool Catalog

| Tool | Owner | SLA | Version | Status |
|------|-------|-----|---------|--------|
| msg | @archit | <3s | 1.0 | ✅ Stable |
| analyze | @team | <10s | 0.9 | ⚠️ Beta |

## msg Tool
- Owner: @archit
- SLA: 95th percentile <3s
- On-call: Slack #cfn-investigator
- Runbook: docs/runbook.md
```

---

## The Bottom Line

**Mechanism is deterministic, protocol is explicit, policy is intelligent.**

- **msg** does the exact work (fetch, parse, format)
- **CLAUDE.md** defines the rules (when to use, schemas, errors)
- **/cfn-investigate** expresses the goals (8-phase investigation)

That separation is how we built reliable AI automation that:
- Processes 817 false negatives in 5 hours (67x faster than manual)
- Achieves 99% success rate
- Generates reproducible, auditable reports
- Scales from 1 message to 1000s without code changes

The pattern works because:
1. **Dumb tools** → predictable, testable, composable
2. **Explicit instructions** → no guessing, no drift
3. **Smart workflows** → adaptive, auditable, safe

Want to try it? Clone the repo:
```bash
git clone https://github.com/archit-15dev/cfn-investigator.git
cd cfn-investigator
bash install.sh
msg -4865185475740621290 auto
```

**Or read the docs:**
- [README.md](README.md) - Quick start guide
- [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) - Deep dive (30,000 words)
- [CLAUDE.md](CLAUDE.md) - Tool reference

---

*Archit Singh • 2025-01-17*

*Questions? File an issue at [github.com/archit-15dev/cfn-investigator](https://github.com/archit-15dev/cfn-investigator/issues)*
