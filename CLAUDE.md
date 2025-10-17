# Personal Claude Code Configuration

## Tools Reference

### msg (Message Scorer Analysis)

**Role**: Dumb data fetcher - extracts and formats POV scorer responses (no intelligence)
**Intelligence lives in**: `~/.claude/commands/cfn-investigate.md`

**Dependencies**: `jq`, `curl`
**Endpoint**: `https://pov.rt-scorer.abnormal.dev/debug/simulate?mid=<MESSAGE_ID>&scoring_instruction=2&force_phrase_extraction=true&force_persist=true&enable_verbose_logging=true`
**Output Cache**: `/tmp/scorer_response.json` (5-minute TTL)
**Cache Override**: Set `MSG_CACHE_FILE` env var for custom cache location (used in batch mode)

---

## Commands (16 Total)

### Core Triage Commands (Start Here)
| Command | Aliases | Args | Output | Description |
|---------|---------|------|--------|-------------|
| `auto` | `a` | - | JSON | Quick triage: overview + decision + links (DEFAULT) |
| `overview` | `o` | - | JSON | Message metadata (from, subject, entity counts, risk scores) |
| `decision` | `d` | - | JSON | Detection decision, flagged rules, confidence score |
| `links` | `l` | - | JSON Array | All links with suspicious scores |
| `entities` | `e` | - | JSON Array | All entities with UUIDs (use to get UUIDs for deep dive) |

### Deep Dive Commands (Requires Prior Command)
| Command | Aliases | Args | Output | Description |
|---------|---------|------|--------|-------------|
| `entity` | `ent` | `<uuid>` | JSON | Deep dive specific entity (run `entities` first to get UUID) |
| `domains` | `dom` | - | JSON Array | Domain entities only (type=5) with risk scores |
| `search` | `s` | `<keyword>` | JSON | Search secondary attributes by keyword (case-insensitive) |

### Signal Analysis Commands
| Command | Aliases | Args | Output | Description |
|---------|---------|------|--------|-------------|
| `rules` | `ru` | - | JSON | Detection rules + models breakdown |
| `heur` | `h` | - | JSON Array | Triggered heuristics across all entities |
| `phrases` | `ph` | `[--filter\|-f]` | JSON Array | Phrase matches (use `--filter` to show only matches > 0) |

### Gap Detection Commands (P0 - CFN Analysis)
| Command | Aliases | Args | Output | Description |
|---------|---------|------|--------|-------------|
| `mismatch` | `mm` | - | JSON | **Detect judgement-review mismatches** (ATTACK but not reviewed) |
| `confidence` | `cf` | - | JSON | Confidence score + threshold gap analysis |
| `batch-summary` | `bs` | - | CSV | **Single-line CSV** (for batch aggregation) |

### Advanced Commands
| Command | Aliases | Args | Output | Description |
|---------|---------|------|--------|-------------|
| `god` | `g` | - | Mixed | Run ALL commands sequentially (complete detection story) |
| `raw` | `r` | `'<jq_filter>'` | * | Custom jq query on cached JSON (escape hatch) |

---

## Output Formats Reference

### JSON Commands (Structured)
- `auto`, `overview`, `decision`, `entity`, `mismatch`, `confidence` → Single JSON object
- `entities`, `links`, `domains`, `heur`, `phrases` → JSON array

### CSV Commands (Batch-Friendly)
- `batch-summary` → Single-line CSV (11 fields):
  ```
  MID,Judgement,ReviewDecision,ConfScore,FlaggedRules,NumEntities,NumLinks,NumAttachments,MaxRiskScore,NumHeuristics,NumSecondaryAttrs
  ```

### Mixed Commands
- `god` → Multiple sections with headers (overview + decision + rules + heuristics + entities + domains + links + phrases + summary)

---

## Reference Tables

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

---

## Usage Patterns

### Single-MID Analysis
```bash
# Quick triage
msg -4865185475740621290

# Check for detection gaps
msg -4865185475740621290 mismatch

# Confidence threshold analysis
msg -4865185475740621290 confidence

# Search for specific attributes
msg -4865185475740621290 search DOCX
msg -4865185475740621290 search ANCHOR_TEXT

# Entity deep dive
msg -4865185475740621290 entities          # Get UUIDs
msg -4865185475740621290 entity <uuid>     # Deep dive

# Filter phrases
msg -4865185475740621290 phrases --filter  # Only matches > 0
```

### Batch Processing (Use in cfn-investigate)
```bash
# Single-line CSV output for aggregation
for mid in $MID_LIST; do
  msg $mid batch-summary >> batch_data.csv
done

# Custom cache per MID (for parallel processing)
for mid in $MID_LIST; do
  export MSG_CACHE_FILE="/tmp/cache_${mid}.json"
  msg $mid auto > "output_${mid}.txt"
done

# Aggregate heuristics (line-based)
for mid in $MID_LIST; do
  msg $mid heur | jq -r '.[].triggered[]'
done | sort | uniq -c | sort -rn

# Detect mismatches
for mid in $MID_LIST; do
  MISMATCH=$(msg $mid mismatch | jq -r '.mismatchDetected')
  [[ "$MISMATCH" == "true" ]] && echo $mid >> mismatches.txt
done
```

### Custom Queries (Advanced)
```bash
# Raw jq filter
msg -4865185475740621290 raw '.extension.rtScorerExtension.processedMessageLogs[0].judgement'

# Extract specific field
msg -4865185475740621290 raw '.extension.rtScorerExtension.processedMessageLogs[0].entities.maxRiskScores.riskScore'
```

---

## Key Behaviors

### Caching
- First command for a MID fetches from API (~2-3 seconds)
- Subsequent commands use cached `/tmp/scorer_response.json` (instant)
- Cache expires after 5 minutes (auto-refetch)
- Override cache location: `export MSG_CACHE_FILE=/custom/path.json`

### Error Handling
- API fetch failure → exits with error
- Invalid command → shows help
- Missing required args (uuid, keyword, jq filter) → usage error

### Performance
- Cold fetch: ~2-3 seconds
- Cached commands: <100ms
- Batch throughput: ~3 sec/MID with custom cache files

---

## Common Workflows

### CFN Investigation (Single MID)
```bash
# Phase 1: Triage
msg $MID auto

# Phase 2: Gap detection
msg $MID mismatch
msg $MID confidence

# Phase 3: Signal hunting
msg $MID heur
msg $MID phrases --filter

# Phase 4: Entity analysis
msg $MID entities
msg $MID domains

# Phase 5: Deep dive (if needed)
msg $MID god
```

### Batch CFN Investigation (Many MIDs)
```bash
# Phase 1: Collect data
for mid in $MID_LIST; do
  msg $mid batch-summary >> batch.csv
done

# Phase 2: Detect patterns
awk -F, '$2 == 1 && $3 == 3' batch.csv  # Judgement=ATTACK, Review=NOT_REVIEW

# Phase 3: Deep dive representatives
# (Intelligence in cfn-investigate, not msg)
```

### Validate Feature Triggered
```bash
# Check if DOCX feature triggered
msg $MID search DOCX

# Check if specific heuristic fired
msg $MID heur | jq -r '.[].triggered[]' | grep "never_seen_sharepoint_tenant"
```

---

## Intelligence Boundary

**msg tool provides**: Raw data views (getters, filters, formatters)
**msg tool does NOT provide**: Interpretation, recommendations, gap categorization

**Intelligence lives in**:
- `/cfn-investigate` slash command - Systematic investigation workflow
- AI agent (Claude Code) - Gap analysis and recommendations

**Example of correct boundary**:
- ✅ `msg mismatch` → Returns `{mismatchDetected: true, gapType: "JUDGEMENT_REVIEW_MISMATCH"}`
- ❌ `msg mismatch` → Does NOT decide "this is a Category 4 gap, implement fix X"
- ✅ `/cfn-investigate` → Uses `msg mismatch` output to categorize and recommend

---

## Tips for AI Agents Using msg

1. **Always start with `auto`** - Gets overview + decision + links in one call
2. **Check cache first** - If investigating same MID multiple times, data is cached
3. **Use `batch-summary` for aggregation** - 10x faster than manual jq parsing
4. **Use `mismatch` for gap detection** - Don't manually compare judgement vs reviewDecision
5. **Use `phrases --filter`** - Reduces output by 60%, keeps 100% signal
6. **Get UUIDs first** - Run `entities` before `entity <uuid>` deep dive
7. **Use `god` sparingly** - Produces 500-2000 lines, only use with `--deep` flag in cfn-investigate
8. **Set MSG_CACHE_FILE in batch mode** - Enables parallel processing without cache conflicts

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Failed to fetch scorer response" | Check MID validity, network access to pov.rt-scorer.abnormal.dev |
| "Unknown command" | Run `msg --help` to see available commands |
| "Usage: msg <mid> entity <uuid>" | Run `msg <mid> entities` first to get UUIDs |
| Empty output from `search` | Keyword not found in secondary attributes (case-insensitive) |
| `phrases` output too large | Use `msg <mid> phrases --filter` to show only matches > 0 |

---

## Examples by Use Case

### Quick Triage
```bash
msg -715876989141528867
# Returns: overview + decision + links
```

### Detect Detection Gaps
```bash
msg -715876989141528867 mismatch
# Returns: {mismatchDetected: true, gapType: "JUDGEMENT_REVIEW_MISMATCH", ...}
```

### Batch Process 100 CFNs
```bash
for mid in $(cat cfn_list.txt); do
  msg $mid batch-summary >> results.csv
done
# Outputs: 100 lines of CSV (11 fields each)
```

### Find Why Not Flagged
```bash
# Step 1: Check decision
msg $MID decision

# Step 2: Check what heuristics fired
msg $MID heur

# Step 3: Check confidence gap
msg $MID confidence

# Step 4: Search for specific features
msg $MID search SHAREPOINT
```

### Investigate URLs
```bash
# Option 1: All links
msg $MID links

# Option 2: Domain entities only
msg $MID domains
```

### Entity Deep Dive
```bash
# Step 1: Get all entities and UUIDs
msg $MID entities

# Step 2: Copy UUID from output

# Step 3: Deep dive
msg $MID entity <uuid-from-step-1>
```

---

**Last Updated**: 2025-01-17 (P0 commands added: mismatch, confidence, batch-summary)
