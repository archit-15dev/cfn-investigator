# CFN Investigator - Technical Documentation

**Version:** 1.0
**Last Updated:** 2025-01-17
**Author:** Archit Singh

---

## 1. Quick Start (5 minutes)

### Installation

```bash
# One-liner installation
curl -sSL https://raw.githubusercontent.com/archit-15dev/cfn-investigator/main/install.sh | bash

# Or manual installation
git clone https://github.com/archit-15dev/cfn-investigator.git
cd cfn-investigator
bash install.sh
```

**Prerequisites:**
- `jq` (install: `brew install jq` on macOS)
- `curl` (usually pre-installed)
- Access to POV rt-scorer API (`https://pov.rt-scorer.abnormal.dev`)

### Your First Investigation

```bash
# Step 1: Quick triage with msg tool
msg -4865185475740621290 auto

# Output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 📊 OVERVIEW
# {
#   "from": "attacker@evil.com",
#   "subject": "Urgent: Update your credentials",
#   "judgement": "GOOD (4)",           ← Should be ATTACK!
#   "numLinks": 2,
#   "numEntities": 5,
#   "maxRiskScores": { "riskScore": 0.45 }
# }
# ...
```

```bash
# Step 2: Full investigation with Claude Code
/cfn-investigate -4865185475740621290

# Runs autonomous 8-phase analysis:
# Phase 1: Triage
# Phase 2: Entity Analysis
# Phase 3: Signal Hunting
# Phase 4: Targeted Search
# Phase 5: Deep Dive (if --deep flag)
# Phase 6: Root Cause Analysis
# Phase 7: Recommendations
# Phase 8: Report Generation
```

### Understanding the Output

```
✅ CFN INVESTIGATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Quick Summary:
   Message: -4865185475740621290
   Attack Type: Credential Phishing
   Root Cause: Category 2 - Missing Heuristic

🎯 Recommended Fix:
   Add heuristic to evaluate URL_ANCHOR_TEXT_MISMATCH feature

📈 Expected Impact:
   Catch Rate: +25%
   FP Risk: Low

📄 Full Report: /tmp/cfn_report_-4865185475740621290.md
```

---

## 2. Core Concepts

### Architecture: Two-Component Design

```
┌─────────────────────────────────────────────────────────┐
│                    CFN Investigator                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐              ┌──────────────────┐   │
│  │   msg tool   │  provides    │  cfn-investigate │   │
│  │ (Bash script)│────data────▶ │   (AI workflow)  │   │
│  │              │              │                  │   │
│  │ • 16 cmds    │              │ • 8 phases       │   │
│  │ • Data fetch │              │ • Root cause     │   │
│  │ • No logic   │              │ • Recommendations│   │
│  └──────────────┘              └──────────────────┘   │
│         │                              │               │
│         │                              │               │
│    Fetches from                   Orchestrates         │
│         │                              │               │
│         ▼                              ▼               │
│  POV Scorer API             Generates Actionable      │
│  (rt-scorer)                     Report               │
└─────────────────────────────────────────────────────────┘
```

**Key Principle: Intelligence Boundary**

- **msg tool** = Dumb data fetcher (no analysis, just JSON extraction)
- **cfn-investigate** = Smart orchestrator (uses msg output to reason)

**Why this design?**
- msg can be used standalone for quick checks
- cfn-investigate can evolve independently
- Clear separation of concerns: data vs analysis

### The msg Tool

**Role:** Fetch and format POV scorer responses

**Core behavior:**
```bash
msg <message_id> [command]

# First command → Fetches from API (~2-3 sec)
# Subsequent commands → Use cached /tmp/scorer_response.json (<100ms)
# Cache expires after 5 minutes
```

**16 Commands organized by frequency:**

| Usage | Command | Args | Output | When to Use |
|-------|---------|------|--------|-------------|
| 80% | `auto` | - | Mixed | Quick triage (overview + decision + links) |
| 10% | `mismatch` | - | JSON | Detect judgement-review gaps |
| 5% | `search` | keyword | JSON | Find specific features |
| 3% | `entities` | - | JSON | List all entities with UUIDs |
| 2% | All others | varies | varies | Deep dive scenarios |

**Complete command reference:**

```bash
# Core Triage (Start here)
msg <mid> auto              # Overview + decision + links (DEFAULT)
msg <mid> overview          # Message metadata
msg <mid> decision          # Detection decision
msg <mid> links             # All links with scores
msg <mid> entities          # All entities with UUIDs

# Deep Dive (Requires entities first)
msg <mid> entity <uuid>     # Deep dive specific entity
msg <mid> domains           # Domain entities only
msg <mid> search <keyword>  # Search secondary attributes

# Signal Analysis
msg <mid> rules             # Detection rules breakdown
msg <mid> heur              # Triggered heuristics
msg <mid> phrases           # Phrase matches (use --filter flag)

# Gap Detection (P0 for CFN analysis)
msg <mid> mismatch          # Automated gap detection
msg <mid> confidence        # Confidence score analysis
msg <mid> batch-summary     # Single-line CSV for batch mode

# Advanced
msg <mid> god               # Run ALL commands (verbose)
msg <mid> raw '<jq_filter>' # Custom jq query
```

### The cfn-investigate Workflow

**Role:** AI-powered autonomous investigation orchestrator

**Operating Modes:**

1. **Single-MID Mode** (Deep dive on one message)
   ```bash
   /cfn-investigate <mid>           # Standard investigation (8-15 min)
   /cfn-investigate <mid> --deep    # With god mode analysis (15-20 min)
   ```

2. **Batch Mode** (Systematic pattern detection)
   ```bash
   /cfn-investigate <file>                    # Process all MIDs in file
   /cfn-investigate <file> --deep 5           # Deep dive top 5 per pattern
   /cfn-investigate <file> --parallel 3       # Use 3 concurrent processes
   ```

**8-Phase Investigation Process:**

```
Phase 1: Triage           → Get overview + form hypothesis
Phase 2: Entity Analysis  → Identify suspicious entities
Phase 3: Signal Hunting   → Collect heuristics + phrases
Phase 4: Targeted Search  → Vector-specific feature search
Phase 5: Deep Dive        → Comprehensive analysis (if --deep)
Phase 6: Root Cause       → Categorize gap (1-4)
Phase 7: Recommendations  → Generate actionable fix
Phase 8: Report           → Save markdown report
```

### The 4 Gap Categories

**Framework for root cause analysis:**

| Category | Definition | Evidence | Fix | Impact | FP Risk |
|----------|-----------|----------|-----|--------|---------|
| **1: Missing Feature** | Attack indicator exists but we don't extract it | `search <keyword>` returns empty | Add feature extraction | +10-30% | Low |
| **2: Missing Heuristic** | Feature exists but no heuristic evaluates it | Attribute exists but no heuristic fired | Add heuristic logic | +15-40% | Low-Med |
| **3: Rule Gap** | Heuristic fires but rules don't use it | Heuristic triggered but rules didn't match | Update detection rule | +20-50% | Medium |
| **4: Threshold Too Strict** | Rule sees signals but confidence too low | Rules applicable but confidence < threshold | Adjust threshold | +5-15% | High |

**Decision tree for categorization:**

```
Is the attack indicator extracted as a feature?
├─ NO → Category 1 (Missing Feature)
└─ YES
    │
    Is there a heuristic that evaluates this feature?
    ├─ NO → Category 2 (Missing Heuristic)
    └─ YES
        │
        Do detection rules incorporate this heuristic?
        ├─ NO → Category 3 (Rule Gap)
        └─ YES → Category 4 (Threshold Too Strict)
```

**Example scenarios:**

```bash
# Category 1: Missing Feature
msg <mid> search HOMOGLYPH    # Returns: {}
# Evidence: Domain "paypаl.com" (Cyrillic 'a') not detected
# Fix: Add HOMOGLYPH_DOMAIN feature extraction

# Category 2: Missing Heuristic
msg <mid> search URL_SHORTENER    # Returns: {"URL_SHORTENER": true}
msg <mid> heur                     # No heuristic checks URL_SHORTENER
# Fix: Add url_shortener_suspicious heuristic

# Category 3: Rule Gap
msg <mid> heur    # Shows: never_seen_from_email: true
msg <mid> rules   # Rules don't incorporate this heuristic
# Fix: Update credential_phishing_rule to check never_seen_from_email

# Category 4: Threshold Too Strict
msg <mid> confidence    # Shows: confidenceScore: 2.8, threshold: 3.0
msg <mid> mismatch      # Shows: Gap: 0.2 below threshold
# Fix: Lower threshold from 3.0 → 2.5
```

---

## 3. Essential msg Commands

### The 80/20 Command Set

**For 80% of investigations, you only need 4 commands:**

#### 1. `msg <mid> auto` - Your Starting Point

**What it does:** Quick triage with overview, decision, and links

**When to use:** Always start here for any investigation

**Example:**
```bash
msg -4865185475740621290 auto

# Output sections:
# 1. OVERVIEW (from, subject, judgement, entity counts)
# 2. DETECTION DECISION (judgement, reviewDecision, flagged rules)
# 3. LINKS (all URLs with suspicious scores)
# 4. Summary (triggered attributes count)
```

**What you learn:**
- Is this a false negative? (judgement = GOOD but should be ATTACK)
- What vectors exist? (numLinks, numAttachments)
- What's the max risk score? (maxRiskScores.riskScore)
- Was it reviewed? (reviewDecision)

**Time:** ~2-3 seconds (fetches from API, caches result)

#### 2. `msg <mid> mismatch` - Automated Gap Detection

**What it does:** Detects judgement-review mismatches automatically

**When to use:** After `auto` shows judgement doesn't match expectation

**Example:**
```bash
msg -4865185475740621290 mismatch

# Output:
{
  "mismatchDetected": true,
  "gapType": "JUDGEMENT_REVIEW_MISMATCH",
  "description": "Marked as ATTACK but NOT reviewed - confidence threshold issue",
  "judgement": "BAD (ATTACK) (1)",
  "reviewDecision": "NOT_REVIEW_MESSAGE (3)",
  "confidenceScore": 2.7,
  "confidenceGap": "Score (2.7) likely below threshold (3+)",
  "flaggedRules": [],
  "recommendation": "Category 4 gap: Lower review threshold OR increase signal weights"
}
```

**What you learn:**
- Is there a judgement-review mismatch?
- What type of gap is it?
- What's the confidence gap?
- Initial recommendation for fix

**Time:** <100ms (reads from cache)

#### 3. `msg <mid> search <keyword>` - Feature Hunting

**What it does:** Search secondary attributes by keyword (case-insensitive)

**When to use:** Looking for specific attack indicators or features

**Example:**
```bash
# Check if attachment features triggered
msg -4865185475740621290 search ATTACHMENT

# Output:
{
  "ATTACHMENT_EXTENSIONS": 1,
  "ATTACHMENT_FILE_NAME": "invoice.pdf",
  "ATTACHMENT_IS_MACRO_ENABLED": false,
  "NUM_ATTACHMENTS": 1
}

# Check for credential phishing signals
msg -4865185475740621290 search CREDENTIAL

# Check for URL features
msg -4865185475740621290 search URL_

# Check for domain features
msg -4865185475740621290 search DOMAIN
```

**Common search keywords:**
- `ATTACHMENT` - Attachment-related features
- `URL_` - URL/link features
- `ANCHOR_TEXT` - Link anchor text analysis
- `DOMAIN` - Domain features
- `SPF` / `DKIM` / `DMARC` - Email authentication
- `SHAREPOINT` - SharePoint file sharing
- `CREDENTIAL` - Credential phishing signals
- `HOMOGLYPH` - Homoglyph detection

**What you learn:**
- Does the feature exist? (empty result = Category 1 gap)
- What's the feature value? (true/false, numeric, string)

**Time:** <100ms (reads from cache)

#### 4. `msg <mid> entities` + `msg <mid> heur` - Signal Hunting

**What it does:** List all entities, then show which heuristics fired

**When to use:** Understanding what signals the system detected

**Example:**
```bash
# Step 1: List all entities
msg -4865185475740621290 entities

# Output:
[
  {
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "type": "BODY_LINK (3)",
    "riskScore": 0.87,
    "abnormalityScore": 0.45,
    "numHeuristics": 12,
    "numAttributes": 34
  },
  ...
]

# Step 2: Show triggered heuristics
msg -4865185475740621290 heur

# Output:
[
  {
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "type": "BODY_LINK (3)",
    "triggered": [
      "suspicious_tld",
      "never_seen_domain",
      "anchor_text_mismatch",
      "url_shortener"
    ]
  },
  ...
]
```

**What you learn:**
- Which entities are high risk? (riskScore > 0.5)
- How many heuristics triggered? (numHeuristics)
- Which specific heuristics fired? (triggered array)

**Time:** <100ms each (reads from cache)

### Advanced Commands (20% use cases)

#### `msg <mid> domains` - Domain-Specific Analysis

```bash
msg -4865185475740621290 domains

# Output:
[
  {
    "uuid": "...",
    "url": "https://paypal-verify.tk",
    "registeredDomain": "paypal-verify.tk",
    "riskScore": 0.92,
    "abnormalityScore": 0.78,
    "numTriggeredHeuristics": 8
  }
]
```

#### `msg <mid> phrases --filter` - Phrase Match Analysis

```bash
# Show ALL phrase types (including 0 matches)
msg -4865185475740621290 phrases

# Show ONLY phrase types with matches > 0 (recommended)
msg -4865185475740621290 phrases --filter

# Output:
[
  {
    "phraseType": "CREDENTIAL_FRAUD (2)",
    "numMatches": 3,
    "matches": [
      {"text": "verify your account", "location": "BODY (2)"},
      {"text": "confirm password", "location": "BODY (2)"}
    ]
  }
]
```

#### `msg <mid> confidence` - Threshold Analysis

```bash
msg -4865185475740621290 confidence

# Output:
{
  "confidenceScore": 2.8,
  "reviewDecision": "NOT_REVIEW_MESSAGE (3)",
  "reviewDecisionRule": "credential_phishing_v2",
  "estimatedThreshold": "3+ (inferred from NOT_REVIEW decision)",
  "gap": 0.2,
  "flaggedRules": [],
  "ruleMatchCount": 0,
  "applicableRules": [
    {
      "rule": "credential_phishing_v2",
      "matched": false
    }
  ]
}
```

#### `msg <mid> god` - Everything at Once

**Warning:** Produces 500-2000 lines of output. Use sparingly.

```bash
msg -4865185475740621290 god

# Runs ALL commands sequentially:
# 1. OVERVIEW
# 2. DETECTION DECISION
# 3. DETECTION RULES + MODELS
# 4. TRIGGERED HEURISTICS
# 5. ALL ENTITIES
# 6. DOMAIN ENTITIES
# 7. ALL LINKS
# 8. PHRASE MATCHES
# 9. SUMMARY
```

**When to use:** Deep dive with `--deep` flag in cfn-investigate workflow

### Caching Behavior

**Critical concept:** msg tool caches API responses to speed up subsequent commands

```bash
# First command fetches from API
msg -4865185475740621290 auto
# 🔍 Fetching scorer response for mid=-4865185475740621290...
# ✅ Saved to /tmp/scorer_response.json
# [2-3 seconds]

# Subsequent commands use cache
msg -4865185475740621290 mismatch      # <100ms
msg -4865185475740621290 search URL_   # <100ms
msg -4865185475740621290 entities      # <100ms
```

**Cache location:** `/tmp/scorer_response.json`

**Cache TTL:** 5 minutes (auto-refetch if older)

**Custom cache location:** Set `MSG_CACHE_FILE` environment variable
```bash
export MSG_CACHE_FILE="/custom/path/cache.json"
msg -4865185475740621290 auto
# Now saves to /custom/path/cache.json
```

**Use case for custom cache:** Batch processing (see Section 4)

---

## 4. Investigation Workflow

### Single-MID Investigation

**Goal:** Deep dive on one message to find root cause and generate fix

**Time:** 8-15 minutes (standard), 15-20 minutes (with --deep)

**Invocation:**
```bash
# Standard investigation
/cfn-investigate -4865185475740621290

# Deep dive (includes god mode analysis)
/cfn-investigate -4865185475740621290 --deep
```

#### Phase-by-Phase Walkthrough

**Phase 1: Triage**

*What happens:*
```bash
msg ${MID} auto          # Get overview
msg ${MID} decision      # Check detection decision
msg ${MID} mismatch      # Automated gap detection
```

*What you learn:*
- Message metadata (from, subject, entity counts)
- Current detection decision (judgement, reviewDecision)
- Initial hypothesis from automated gap detection

*Example output:*
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 PHASE 1: TRIAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 Fetching scorer data...
{
  "from": "admin@paypal-verify.tk",
  "subject": "Account Verification Required",
  "judgement": "GOOD (4)",
  "numLinks": 1,
  "numAttachments": 0,
  "numEntities": 3,
  "maxRiskScores": {
    "riskScore": 0.87
  }
}

💡 INITIAL HYPOTHESIS (Automated Gap Detection)
{
  "mismatchDetected": true,
  "gapType": "JUDGEMENT_REVIEW_MISMATCH",
  "recommendation": "Category 4 gap: Lower review threshold OR increase signal weights"
}
```

**Phase 2: Entity Analysis**

*What happens:*
```bash
msg ${MID} entities      # List all entities
msg ${MID} domains       # Domain-specific analysis

# Extract high-priority entities (risk > 0.3)
# Deep dive top 2 entities
msg ${MID} entity <uuid>
```

*What you learn:*
- Which entities are suspicious (high risk scores)
- Domain characteristics (registered domain, risk)
- Entity attributes and heuristics

*Example output:*
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 PHASE 2: ENTITY ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

High Priority Entities (risk > 0.3):
  - UUID: 550e8400-e29b-41... | Type: BODY_LINK (3) | Risk: 0.87
  - UUID: 7a4b2c3d-1e2f-41... | Type: DOMAIN (5) | Risk: 0.92

🌐 Domain Entities:
[
  {
    "url": "https://paypal-verify.tk",
    "registeredDomain": "paypal-verify.tk",
    "riskScore": 0.92,
    "numTriggeredHeuristics": 8
  }
]
```

**Phase 3: Signal Hunting**

*What happens:*
```bash
msg ${MID} heur              # Triggered heuristics
msg ${MID} phrases --filter  # Phrase matches (filtered)
msg ${MID} links             # Links analysis (if present)
msg ${MID} rules             # Detection rules
```

*What you learn:*
- Which heuristics fired
- What phrases were detected
- Why rules didn't match

*Example output:*
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ PHASE 3: SIGNAL HUNTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ Triggered Heuristics:
[
  {
    "type": "BODY_LINK (3)",
    "triggered": [
      "suspicious_tld",
      "never_seen_domain",
      "anchor_text_mismatch"
    ]
  }
]

💬 Phrase Matches (filtered - only matches > 0):
[
  {
    "phraseType": "CREDENTIAL_FRAUD (2)",
    "numMatches": 3
  }
]
```

**Phase 4: Targeted Search**

*What happens:* Vector-specific feature search based on attack type

```bash
# Determine attack vector
NUM_LINKS=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].textSignals.links | length' /tmp/scorer_response.json)
NUM_ATTACHMENTS=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].message.attachments | length' /tmp/scorer_response.json)

# If link-based attack
if [[ $NUM_LINKS -gt 0 ]]; then
  msg ${MID} search ANCHOR_TEXT
  msg ${MID} search URL_
  msg ${MID} domains
fi

# If attachment-based attack
if [[ $NUM_ATTACHMENTS -gt 0 ]]; then
  msg ${MID} search FILE_EXTENSION
  msg ${MID} search ATTACHMENT
  msg ${MID} search MACRO
fi

# If sender-based attack
else
  msg ${MID} search FROM_EMAIL
  msg ${MID} search SPF
  msg ${MID} search DOMAIN
fi
```

*What you learn:*
- Vector-specific features that triggered
- Missing features (empty search results = Category 1)

**Phase 5: Deep Dive** (Optional, with --deep flag)

*What happens:*
```bash
msg ${MID} god    # Run ALL commands (500-2000 lines)
```

*When to use:* Complex CFNs requiring comprehensive analysis

**Phase 6: Root Cause Analysis**

*What happens:* Categorize gap using automated detection + manual evidence

```bash
# Get automated analysis
MISMATCH_OUTPUT=$(msg ${MID} mismatch)
GAP_TYPE_AUTO=$(echo "$MISMATCH_OUTPUT" | jq -r '.gapType')

# Analyze evidence from previous phases
# Determine category (1-4)
```

*Output:*
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 ROOT CAUSE ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Category: 2 - Missing Heuristic

Evidence:
1. Feature URL_ANCHOR_TEXT_MISMATCH exists (search returned value)
2. No heuristic evaluates this feature (heur output shows no anchor_text_mismatch)
3. High-risk domain (paypal-verify.tk) with anchor text "PayPal Official"

Why This Matters:
We extract the anchor text mismatch feature but don't evaluate it, so
credential phishing attacks with misleading anchor text bypass detection.

Attack Pattern:
Credential phishing using suspicious domain (.tk TLD) with legitimate-looking
anchor text to trick users into clicking malicious link.
```

**Phase 7: Recommendations**

*What happens:* Generate category-specific actionable fix

*Output structure:*
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 PHASE 7: RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Recommended Fix (Category 2):

**Fix Type**: Add Missing Heuristic

Implementation Steps:
  1. [ ] Identify which existing features should be evaluated
  2. [ ] Define heuristic logic and threshold
  3. [ ] Add heuristic evaluation in entity scoring
  4. [ ] Test heuristic triggers on positive/negative cases
  5. [ ] Monitor heuristic fire rate in production

Expected Impact:
  - Catch Rate: +25% on Credential Phishing attacks
  - FP Risk: Low (heuristic is specific to anchor text mismatches)

False Positive Risk Assessment:
  - Attack specificity: Anchor text mismatch + suspicious TLD is rare in legitimate emails
  - Legitimate use cases: Marketing emails with branded links
  - Mitigation: Add exclusion for known marketing domains

Test Plan:

  Positive Test Cases (should flag):
    1. MID: -4865185475740621290 - This CFN
    2. MID: <find similar CFN> - Same attack pattern
    3. MID: <find similar CFN> - Variant attack

  Negative Test Cases (should NOT flag):
    1. MID: <legitimate email> - Marketing email with branded link
    2. MID: <edge case> - Legitimate .tk domain
```

**Phase 8: Report Generation**

*What happens:* Save investigation report to `/tmp/cfn_report_${MID}.md`

*Final output:*
```
✅ CFN INVESTIGATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Quick Summary:
   Message: -4865185475740621290
   Attack Type: Credential Phishing
   Root Cause: Category 2 - Missing Heuristic

📄 Full Report: /tmp/cfn_report_-4865185475740621290.md
```

### Batch Investigation

**Goal:** Detect systematic patterns across 100s-1000s of messages

**Time:** ~30 minutes per 100 CFNs (with caching)

**Invocation:**
```bash
# Create file with MIDs (one per line)
cat > cfn_list.txt <<EOF
-4865185475740621290
-715876989141528867
7213175459145070583
EOF

# Basic batch investigation
/cfn-investigate cfn_list.txt

# Batch with deep dive on top 3 representatives per pattern
/cfn-investigate cfn_list.txt --deep 3

# Batch with parallelization (3 concurrent processes)
/cfn-investigate cfn_list.txt --parallel 3

# Quick mode (skip some analysis phases)
/cfn-investigate cfn_list.txt --quick
```

#### Batch Process Flow

**Phase 1: Triage (Batch)**

*What happens:* Collect core data from all messages

```bash
# Process each MID
for MID in ${MID_LIST}; do
  # Set MID-specific cache file (prevents conflicts)
  export MSG_CACHE_FILE="${OUTPUT_DIR}/cache/scorer_${MID}.json"

  # Fetch overview (caches to MSG_CACHE_FILE)
  msg ${MID} auto > "${OUTPUT_DIR}/phase_data/triage_${MID}.txt"

  # Extract structured data with batch-summary command
  msg ${MID} batch-summary >> "${OUTPUT_DIR}/batch_data.csv"
done
```

*Output:* `batch_data.csv` with columns:
```
MID,Judgement,ReviewDecision,ConfScore,FlaggedRules,NumEntities,NumLinks,NumAttachments,MaxRiskScore,NumHeuristics,NumSecondaryAttrs
-4865185475740621290,4,3,2.8,"",3,1,0,0.87,8,42
-715876989141528867,1,3,2.5,"",5,2,0,0.92,12,56
```

**Phase 2: Entity Analysis (Batch)**

*What happens:* Aggregate entity types and risk scores

```bash
# Aggregate from all cache files
for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
  # Extract entity type and risk score pairs
  jq -r '.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | "\(.value.type):\(.value.scores.riskScore // 0)"' "${CACHE_FILE}"
done
```

*Output:*
```
Entity Type Distribution:

Type                    Count   Avg Risk  Priority
────────────────────────────────────────────────────────────
DOMAIN                    487      0.782  ⚠️  HIGH
BODY_LINK                 312      0.654  ⚠️  HIGH
FROM_EMAIL                817      0.234  ✓ LOW
ATTACHMENT                 89      0.445  ⚠  MEDIUM
```

**Phase 3: Signal Hunting (Batch)**

*What happens:* Aggregate heuristic frequencies

```bash
# Aggregate heuristic data from all caches
for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
  HEURISTICS=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | .value.heuristicEvaluationResults | to_entries[] | select(.value == true) | .key' "${CACHE_FILE}")

  # Count frequencies
  for HEUR in $HEURISTICS; do
    ((HEURISTIC_COUNTS[$HEUR]++))
  done
done
```

*Output:*
```
Top 20 Heuristics by Frequency:

Heuristic                                               Fired  Reviews   Rate
────────────────────────────────────────────────────────────────────────────
suspicious_tld                                            487      23     5% ⚠️
never_seen_domain                                         412      18     4% ⚠️
anchor_text_mismatch                                      298      87    29%
url_shortener                                             156       4     3% ⚠️
```

⚠️ = Heuristics marked with ⚠️ fire frequently but rarely trigger review (ignored signals)

**Phase 4: Pattern Detection** (THE INTELLIGENCE)

*What happens:* Detect systematic gaps across 3 dimensions

**Pattern 1: Rule Gaps**
```bash
# Find rules that match but don't review
for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
  # Extract applicable rules that matched
  jq -r '.extension.rtScorerExtension.processedMessageLogs[0].messageDecisions.detectionControlSystemResult.reviewDecisionRuleResults | to_entries[] | select(.value.ruleIsApplicable == true and .value.matchReasons != null) | .key' "${CACHE_FILE}"
done
```

*Output:*
```
Rules with High Match Rate but Low Review Rate:

Rule              Matches    Reviews     Rate
────────────────────────────────────────────
credential_v2        234         12      5% ⚠️
sender_domain        189          8      4% ⚠️
```

**Pattern 2: Judgement Mismatches**
```bash
# Find messages marked BAD but not reviewed
BAD_NOT_REVIEWED=$(awk -F, '($2 == "1" || $2 ~ /BAD|ATTACK/) && $3 != "1" {print $1}' "${OUTPUT_DIR}/batch_data.csv")
```

*Output:*
```
Messages marked BAD/ATTACK but NOT reviewed:
  Count: 87/817 (11%)

⚠️  SYSTEMATIC GAP: 11% marked as attacks but bypassed review
  Sample MIDs: -4865185475740621290 -715876989141528867 ...
```

**Pattern 3: Campaign Clusters**
```bash
# Find campaigns with 3+ CFNs
for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
  CAMPAIGNS=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].messageDecisions.detectionControlSystemResult.campaignId // empty' "${CACHE_FILE}")
done
```

*Output:*
```
Campaigns with 3+ CFNs:

Campaign                                  Count      %
──────────────────────────────────────────────────────
credential_phish_paypal_tk_campaign         23      3% ⚠️
invoice_scam_sharepoint_campaign            18      2% ⚠️
```

**Phase 5: Deep Dive (Conditional)**

*What happens:* Deep dive on representative MIDs for each systematic pattern

```bash
# Read systematic_gaps.txt line by line
while IFS=: read -r GAP_TYPE GAP_ID GAP_COUNT GAP_PCT GAP_MIDS; do
  # Get up to DEEP_COUNT representatives
  REPS=$(echo "${GAP_MIDS}" | tr ' ' '\n' | head -${DEEP_COUNT})

  # Deep dive each representative
  for REP_MID in ${REPS}; do
    export MSG_CACHE_FILE="${OUTPUT_DIR}/cache/scorer_${REP_MID}.json"

    # Tailor analysis based on gap type
    case "${GAP_TYPE}" in
      "RULE_GAP")
        msg ${REP_MID} heur
        msg ${REP_MID} rules
        ;;
      "JUDGEMENT_MISMATCH")
        msg ${REP_MID} entities
        msg ${REP_MID} decision
        ;;
    esac

    # Save deep dive report
    # ... generate markdown report
  done
done < "${OUTPUT_DIR}/systematic_gaps.txt"
```

**Phase 6-8:** Root cause analysis, recommendations, and report generation for batch

*Output structure:*
```
${OUTPUT_DIR}/
├── batch_data.csv                 # Structured data for all MIDs
├── systematic_gaps.txt            # Detected patterns
├── categorized_gaps.txt          # Gaps categorized into 4 types
├── BATCH_SUMMARY.md              # Executive summary
├── deep_RULE_GAP_credential_v2_<mid>.md
├── deep_JUDGEMENT_MISMATCH_<mid>.md
└── cache/
    ├── scorer_-4865185475740621290.json
    └── ...
```

**Final Summary:**
```
✅ BATCH INVESTIGATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Summary:
   Processed: 817 CFNs in 247 minutes
   Gaps Found: 15 systematic patterns
   Success Rate: 99%

📄 Full Report: /Users/user/cfn_batch/2025-01-17_143522/BATCH_SUMMARY.md

📂 Output Directory: /Users/user/cfn_batch/2025-01-17_143522
```

---

## 5. Troubleshooting

### Common Issues and Solutions

#### Issue: "Failed to fetch scorer response"

**Symptoms:**
```bash
msg -4865185475740621290 auto
# 🔍 Fetching scorer response for mid=-4865185475740621290...
# ❌ Failed to fetch scorer response
```

**Causes:**
1. Invalid MID
2. Network issues
3. No access to POV rt-scorer API
4. API timeout

**Solutions:**
```bash
# 1. Verify MID format (should be signed integer)
echo "-4865185475740621290" | grep -E '^-?[0-9]+$'

# 2. Check network connectivity
curl -I https://pov.rt-scorer.abnormal.dev
# Should return HTTP 200

# 3. Try fetching directly with curl
curl -sf "https://pov.rt-scorer.abnormal.dev/debug/simulate?mid=-4865185475740621290&scoring_instruction=2" -o /tmp/test.json

# 4. Check if you're on VPN (required for internal API)
```

#### Issue: msg command not found

**Symptoms:**
```bash
msg --help
# bash: msg: command not found
```

**Cause:** `~/.local/bin` not in PATH or terminal not restarted

**Solutions:**
```bash
# 1. Check if msg is installed
ls -la ~/.local/bin/msg

# 2. Add to PATH manually
export PATH="$HOME/.local/bin:$PATH"

# 3. Restart terminal (to load updated .zshrc or .bashrc)

# 4. Or source config file
source ~/.zshrc    # For zsh
source ~/.bashrc   # For bash
```

#### Issue: Cache showing stale data

**Symptoms:**
- Running `msg <mid> auto` shows old data
- Making changes but not seeing updates

**Cause:** Cache is less than 5 minutes old

**Solutions:**
```bash
# 1. Force refetch by deleting cache
rm /tmp/scorer_response.json
msg -4865185475740621290 auto

# 2. Or wait 5 minutes for cache to expire

# 3. Check cache age
ls -lh /tmp/scorer_response.json
# -rw-r--r--  1 user  wheel   128K Jan 17 14:35 /tmp/scorer_response.json

# 4. Use custom cache location to avoid conflicts
export MSG_CACHE_FILE="/tmp/cache_custom.json"
msg -4865185475740621290 auto
```

#### Issue: jq errors in output

**Symptoms:**
```bash
msg -4865185475740621290 auto
# jq: error: ... at line 1, column 42
```

**Cause:** Malformed JSON response from API

**Solutions:**
```bash
# 1. Check raw API response
cat /tmp/scorer_response.json | jq '.'

# 2. If JSON is valid, check msg script version
msg --help | head -1

# 3. Re-download msg script
cd cfn-investigator
git pull
cp msg ~/.local/bin/msg
```

#### Issue: /cfn-investigate command not recognized in Claude Code

**Symptoms:**
- Typing `/cfn-investigate <mid>` shows "Unknown command"

**Cause:** Workflow not installed in correct location

**Solutions:**
```bash
# 1. Check if workflow file exists
ls -la ~/.claude/commands/cfn-investigate.md

# Or check SOURCE directory
SOURCE="${SOURCE:-${HOME}/source}"
ls -la "${SOURCE}/.claude/commands/cfn-investigate.md"

# 2. Verify file has correct frontmatter
head -5 "${SOURCE}/.claude/commands/cfn-investigate.md"
# Should show:
# ---
# allowed-tools: Bash, Read, Write, Edit
# argument-hint: <mid|--batch file> [--deep [N]]
# description: Autonomous CFN investigation...
# ---

# 3. Restart Claude Code to reload commands
```

#### Issue: Batch mode running out of disk space

**Symptoms:**
- Batch investigation fails midway with "No space left on device"

**Cause:** Cache files accumulate in `/tmp` or custom output directory

**Solutions:**
```bash
# 1. Check disk usage
df -h /tmp
du -sh ~/cfn_batch/*

# 2. Clean up old cache files
find /tmp -name "scorer_*.json" -mtime +1 -delete

# 3. Use custom output directory on larger disk
/cfn-investigate cfn_list.txt --output /data/cfn_investigation

# 4. Clean up after investigation
rm -rf ~/cfn_batch/2025-01-17_*
```

#### Issue: Batch mode taking too long

**Symptoms:**
- Batch of 100 MIDs taking >2 hours

**Expected:** ~30 minutes for 100 MIDs

**Solutions:**
```bash
# 1. Use parallel processing
/cfn-investigate cfn_list.txt --parallel 3

# 2. Check API response times
time msg -4865185475740621290 auto
# Should be ~2-3 seconds

# 3. Use quick mode (skip deep analysis)
/cfn-investigate cfn_list.txt --quick

# 4. Check network latency
ping pov.rt-scorer.abnormal.dev
```

### Performance Tips

#### Cache Strategy for Speed

```bash
# BAD: Shared cache conflicts in parallel processing
for mid in $(cat mids.txt); do
  msg $mid auto &  # All processes fight over /tmp/scorer_response.json
done

# GOOD: Custom cache per MID
for mid in $(cat mids.txt); do
  export MSG_CACHE_FILE="/tmp/cache_${mid}.json"
  msg $mid auto &
done
```

#### Efficient Batch Processing

```bash
# Instead of manual loop, use built-in batch mode
/cfn-investigate cfn_list.txt --parallel 3

# Advantages:
# - Automatic cache management
# - Progress tracking
# - Error recovery
# - Structured output
```

#### Reduce msg god Output

```bash
# Instead of full god mode (500-2000 lines)
msg <mid> god

# Use targeted commands (50-100 lines)
msg <mid> auto
msg <mid> mismatch
msg <mid> entities
msg <mid> heur
```

### Debugging Tips

#### Enable Verbose Mode

```bash
# Add set -x to msg script for debugging
bash -x ~/.local/bin/msg -4865185475740621290 auto
```

#### Inspect Cache File Directly

```bash
# Pretty-print entire cache
cat /tmp/scorer_response.json | jq '.'

# Extract specific field
jq '.extension.rtScorerExtension.processedMessageLogs[0].judgement' /tmp/scorer_response.json

# Check cache modification time
stat /tmp/scorer_response.json
```

#### Test Individual Components

```bash
# Test API fetch
curl -sf "https://pov.rt-scorer.abnormal.dev/debug/simulate?mid=-4865185475740621290&scoring_instruction=2" | jq '.extension.rtScorerExtension.processedMessageLogs[0].judgement'

# Test jq parsing
echo '{"test": 123}' | jq '.test'

# Test msg commands individually
msg -4865185475740621290 overview
msg -4865185475740621290 decision
msg -4865185475740621290 mismatch
```

---

## Appendix: Reference Tables

### Entity Types
```
1 = FROM_EMAIL       6 = REPLY_TO_EMAIL
2 = DOMAIN           7 = ATTACHMENT
3 = BODY_LINK        8 = PHONE_NUMBER
4 = IP
5 = DOMAIN
```

### Judgement Values
```
0 = SURELY_SAFE      5 = NONE
1 = ATTACK (BAD)     6 = PROBABLY_GOOD
2 = SUSPICIOUS       7 = NOT_JUDGED
3 = BORDERLINE       8 = UNSURE
4 = GOOD
```

### Review Decision Values
```
0 = NULL                           4 = LLM_REVIEW_MESSAGE
1 = REVIEW_MESSAGE                 5 = LLM_AND_HUMAN_REVIEW_MESSAGE
2 = NOT_REVIEW_MESSAGE_SAMPLED
3 = NOT_REVIEW_MESSAGE
```

### Email Segment Types
```
0 = NONE
1 = WARNING
2 = BODY
3 = CONVERSATION
```

---

**End of Documentation**

*For questions or issues, file a ticket at: https://github.com/archit-15dev/cfn-investigator/issues*
