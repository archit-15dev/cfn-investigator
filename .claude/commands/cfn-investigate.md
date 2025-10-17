---
allowed-tools: Bash, Read, Write, Edit
argument-hint: <mid|--batch file> [--deep [N]] [--quick] [--parallel N] [--output DIR]
description: Autonomous CFN investigation using msg tool for single-MID or batch systematic false negative analysis
---

# CFN Investigation - Autonomous Workflow

## Role
You are an autonomous CFN (False Negative) investigator using msg tool to analyze why attack messages weren't caught and generate actionable detection improvements.

**Operating Modes:**
- **Single-MID Mode**: Deep 8-phase investigation of one message (8-15 min)
- **Batch Mode**: Systematic pattern detection across many messages (8-10 hours for 817 CFNs)

## Objective

**Single-MID Mode:**
- Root cause identification (categorized into 4 types)
- Specific detection gaps documented
- Actionable recommendations with test plans
- Impact and FP risk assessment

**Batch Mode:**
- Process 100s of CFNs automatically
- Detect systematic patterns (rule gaps, heuristic gaps, campaign clusters)
- Prioritize fixes by frequency/impact
- Deep dive only on representative examples

---

## Step 0: Mode Detection & Argument Parsing

<mode_detection_and_argument_parsing>
**Goal**: Determine if this is single-MID or batch mode, parse all arguments

### Parse First Argument

Check if first argument is a file path (batch mode) or message ID (single-MID mode):

```bash
# Store first argument
FIRST_ARG="${1}"

# Mode detection logic
if [[ -f "${FIRST_ARG}" ]]; then
    MODE="batch"
    BATCH_FILE="${FIRST_ARG}"
    echo "🔄 BATCH MODE ACTIVATED"
    echo "   File: ${BATCH_FILE}"

elif [[ "${FIRST_ARG}" =~ ^-?[0-9]+$ ]]; then
    MODE="single"
    MID="${FIRST_ARG}"
    echo "🔍 SINGLE-MID MODE"
    echo "   Message ID: ${MID}"

else
    echo "❌ ERROR: Invalid argument"
    echo ""
    echo "Usage:"
    echo "  Single-MID: /cfn-investigate <mid> [--deep]"
    echo "  Batch:      /cfn-investigate --batch <file> [--deep N] [--quick] [--parallel N]"
    echo ""
    echo "Examples:"
    echo "  /cfn-investigate 7213175459145070583"
    echo "  /cfn-investigate -4865185475740621290 --deep"
    echo "  /cfn-investigate --batch data.txt"
    echo "  /cfn-investigate --batch data.txt --deep 5 --parallel 3"
    exit 1
fi
```

### Parse Optional Flags

```bash
# Initialize defaults
DEEP_MODE=false
DEEP_COUNT=3
QUICK_MODE=false
PARALLEL=1
OUTPUT_DIR=""

# Shift past first argument
shift

# Parse remaining flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --deep)
            DEEP_MODE=true
            # Check if next arg is a number (for batch mode)
            if [[ "${2}" =~ ^[0-9]+$ ]]; then
                DEEP_COUNT="${2}"
                shift
            fi
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --parallel)
            PARALLEL="${2}"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="${2}"
            shift 2
            ;;
        --batch)
            # Alternative syntax: /cfn-investigate --batch file.txt
            if [[ "${MODE}" != "batch" ]]; then
                MODE="batch"
                BATCH_FILE="${2}"
            fi
            shift 2
            ;;
        *)
            echo "⚠️  Warning: Unknown flag: $1"
            shift
            ;;
    esac
done
```

### Display Configuration

```bash
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode: ${MODE}"

if [[ "${MODE}" == "batch" ]]; then
    echo "Batch File: ${BATCH_FILE}"
    echo "Deep Dive: ${DEEP_MODE} (${DEEP_COUNT} representatives per pattern)"
    echo "Quick Mode: ${QUICK_MODE}"
    echo "Parallel: ${PARALLEL} concurrent processes"
    echo "Output: ${OUTPUT_DIR:-"auto-generated"}"
else
    echo "Message ID: ${MID}"
    echo "Deep Dive: ${DEEP_MODE}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
```

### Setup Environment (Batch Mode Only)

```bash
if [[ "${MODE}" == "batch" ]]; then
    # Extract MIDs from file
    echo "📊 Extracting MIDs from file..."

    # Auto-detect format: CSV with review-platform URLs or plain text
    if grep -q "review-platform.internal-tools" "${BATCH_FILE}"; then
        MID_LIST=$(grep -oP 'message/\K-?\d+' "${BATCH_FILE}")
        echo "   Format: CSV with review-platform URLs"
    else
        MID_LIST=$(grep -E '^-?[0-9]+' "${BATCH_FILE}")
        echo "   Format: Plain text (one MID per line)"
    fi

    TOTAL_COUNT=$(echo "${MID_LIST}" | grep -c '^' || echo 0)

    if [[ $TOTAL_COUNT -eq 0 ]]; then
        echo "❌ ERROR: No MIDs found in ${BATCH_FILE}"
        exit 1
    fi

    echo "   Extracted: ${TOTAL_COUNT} MIDs"
    echo ""

    # Create output directory structure
    OUTPUT_DIR="${OUTPUT_DIR:-${HOME}/cfn_batch/$(date +%Y-%m-%d_%H%M%S)}"
    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}/cache"
    mkdir -p "${OUTPUT_DIR}/phase_data"

    echo "📁 Output Directory: ${OUTPUT_DIR}"
    echo ""

    # Initialize tracking
    START_TIME=$(date +%s)
    PROCESSED=0
    FAILED=0

    # Create structured data file with header (UPDATE #2: Added 3 new fields)
    echo "MID,Judgement,ReviewDecision,ConfScore,FlaggedRules,NumEntities,NumLinks,NumAttachments,MaxRiskScore,NumHeuristics,NumSecondaryAttrs" > "${OUTPUT_DIR}/batch_data.csv"

    echo "✅ Environment setup complete"
    echo ""
fi
```
</mode_detection_and_argument_parsing>

---

## Step 1: Phase 1 - Triage (Adaptive Data Collection)

<phase1_triage>
**Goal**: Get overview + form initial hypothesis (single-MID) OR collect core data from all messages (batch)

### Single-MID Mode

Execute if `MODE == "single"`:

```bash
if [[ "${MODE}" == "single" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 PHASE 1: TRIAGE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Fetch overview (caches scorer response to /tmp/scorer_response.json)
    echo "🔍 Fetching scorer data..."
    msg ${MID} auto
    echo ""

    # Check detection decision (reads from cache)
    echo "🚨 Checking detection decision..."
    msg ${MID} decision
    echo ""

    # UPDATE #1: Use msg mismatch for automated gap detection
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 INITIAL HYPOTHESIS (Automated Gap Detection)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg ${MID} mismatch
    echo ""
fi
```

### Batch Mode

Execute if `MODE == "batch"`:

```bash
if [[ "${MODE}" == "batch" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 PHASE 1: TRIAGE (Batch - ${TOTAL_COUNT} CFNs)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Collecting core data from all messages..."
    echo "This will take approximately $(( TOTAL_COUNT * 30 / 3600 + 1)) hours"
    echo ""

    # Process each MID
    for MID in ${MID_LIST}; do
        ((PROCESSED++))

        # Progress indicator (every 50 messages)
        if [[ $((PROCESSED % 50)) -eq 0 ]]; then
            ELAPSED=$(($(date +%s) - START_TIME))
            if [[ $ELAPSED -gt 0 ]]; then
                RATE=$((PROCESSED * 3600 / ELAPSED))
                PCT=$((PROCESSED * 100 / TOTAL_COUNT))
                REMAINING=$(( (TOTAL_COUNT - PROCESSED) * ELAPSED / PROCESSED / 60 ))
                echo "⏱️  [${PROCESSED}/${TOTAL_COUNT}] ${PCT}% | Rate: ${RATE}/hr | ETA: ${REMAINING} min"
            fi
        fi

        # Set MID-specific cache file (msg tool reads this env var)
        export MSG_CACHE_FILE="${OUTPUT_DIR}/cache/scorer_${MID}.json"

        # Fetch overview (caches to MSG_CACHE_FILE)
        if ! msg ${MID} auto > "${OUTPUT_DIR}/phase_data/triage_${MID}.txt" 2>&1; then
            echo "   ❌ Failed: ${MID}" | tee -a "${OUTPUT_DIR}/errors.log"
            ((FAILED++))
            continue
        fi

        # UPDATE #2: Use msg batch-summary for one-line CSV extraction (replaces 8 jq calls)
        msg ${MID} batch-summary >> "${OUTPUT_DIR}/batch_data.csv"
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Phase 1 Complete: ${PROCESSED} CFNs triaged"
    echo "   Success: $((PROCESSED - FAILED)) CFNs"
    echo "   Failed: ${FAILED} CFNs (see ${OUTPUT_DIR}/errors.log)"
    echo "   Rate: $(( (PROCESSED - FAILED) * 3600 / ($(date +%s) - START_TIME) )) CFNs/hour"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi
```
</phase1_triage>

---

## Step 2: Phase 2 - Entity Analysis (Adaptive)

<phase2_entity_analysis>
**Goal**: Identify suspicious entities (single-MID) OR aggregate entity risk distribution (batch)

### Single-MID Mode

Execute if `MODE == "single"`:

```bash
if [[ "${MODE}" == "single" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 PHASE 2: ENTITY ANALYSIS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # List all entities
    echo "📊 All Entities:"
    msg ${MID} entities
    echo ""

    # UPDATE #6: Add domains analysis
    echo "🌐 Domain Entities:"
    msg ${MID} domains
    echo ""

    # Extract high-priority entities (risk > 0.3)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 ENTITY PRIORITY ANALYSIS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    HIGH_PRIORITY_UUIDS=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | select(.value.scores.riskScore > 0.3) | .key' /tmp/scorer_response.json 2>/dev/null)

    if [[ -n "${HIGH_PRIORITY_UUIDS}" ]]; then
        echo "High Priority Entities (risk > 0.3):"
        for UUID in ${HIGH_PRIORITY_UUIDS}; do
            TYPE=$(jq -r ".extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity[\"${UUID}\"].type" /tmp/scorer_response.json)
            RISK=$(jq -r ".extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity[\"${UUID}\"].scores.riskScore" /tmp/scorer_response.json)
            echo "  - UUID: ${UUID:0:16}... | Type: ${TYPE} | Risk: ${RISK}"
        done
        echo ""

        # Deep dive top 2 entities
        echo "📋 Deep Diving Top 2 Entities:"
        echo ""
        COUNT=0
        for UUID in ${HIGH_PRIORITY_UUIDS}; do
            ((COUNT++))
            if [[ $COUNT -gt 2 ]]; then break; fi

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Entity ${COUNT}: ${UUID:0:16}..."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            msg ${MID} entity ${UUID} | head -50
            echo ""
        done
    else
        echo "⚠️  No high-priority entities found (all risk scores < 0.3)"
        echo ""

        # Show medium priority instead
        MEDIUM_PRIORITY_UUIDS=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | select(.value.scores.riskScore >= 0.1 and .value.scores.riskScore <= 0.3) | .key' /tmp/scorer_response.json 2>/dev/null)
        if [[ -n "${MEDIUM_PRIORITY_UUIDS}" ]]; then
            echo "Medium Priority Entities (risk 0.1-0.3):"
            for UUID in ${MEDIUM_PRIORITY_UUIDS}; do
                TYPE=$(jq -r ".extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity[\"${UUID}\"].type" /tmp/scorer_response.json)
                RISK=$(jq -r ".extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity[\"${UUID}\"].scores.riskScore" /tmp/scorer_response.json)
                echo "  - UUID: ${UUID:0:16}... | Type: ${TYPE} | Risk: ${RISK}"
            done
            echo ""
        fi
    fi
fi
```

### Batch Mode

Execute if `MODE == "batch"`:

```bash
if [[ "${MODE}" == "batch" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 PHASE 2: ENTITY ANALYSIS (Aggregate)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Aggregating entity types and risk scores across ${PROCESSED} CFNs..."
    echo ""

    # Initialize arrays for aggregation
    declare -A ENTITY_TYPE_COUNTS
    declare -A ENTITY_TYPE_RISK_SUM
    declare -A ENTITY_TYPE_NAMES=(
        [1]="FROM_EMAIL"
        [2]="DOMAIN"
        [3]="BODY_LINK"
        [4]="IP"
        [5]="DOMAIN"
        [6]="REPLY_TO_EMAIL"
        [7]="ATTACHMENT"
        [8]="PHONE_NUMBER"
    )

    # Aggregate from all cache files
    for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
        [[ ! -f "${CACHE_FILE}" ]] && continue

        # Extract entity type and risk score pairs
        jq -r '.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | "\(.value.type):\(.value.scores.riskScore // 0)"' "${CACHE_FILE}" 2>/dev/null | while IFS=: read -r TYPE RISK; do
            # Convert risk to integer (multiply by 1000 to preserve 3 decimal places)
            RISK_INT=$(echo "$RISK * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "0")

            # Accumulate counts and risk sums
            ((ENTITY_TYPE_COUNTS[$TYPE]++))
            ENTITY_TYPE_RISK_SUM[$TYPE]=$((${ENTITY_TYPE_RISK_SUM[$TYPE]:-0} + RISK_INT))
        done
    done

    # Display entity type distribution
    echo "Entity Type Distribution:"
    echo ""
    printf "%-20s %10s %12s %10s\n" "Type" "Count" "Avg Risk" "Priority"
    echo "────────────────────────────────────────────────────────────────"

    for TYPE in "${!ENTITY_TYPE_COUNTS[@]}"; do
        COUNT=${ENTITY_TYPE_COUNTS[$TYPE]}
        RISK_SUM=${ENTITY_TYPE_RISK_SUM[$TYPE]:-0}

        if [[ $COUNT -gt 0 ]]; then
            AVG_RISK=$(echo "scale=3; $RISK_SUM / $COUNT / 1000" | bc)
        else
            AVG_RISK="0.000"
        fi

        TYPE_NAME=${ENTITY_TYPE_NAMES[$TYPE]:-"TYPE_$TYPE"}

        # Determine priority
        if (( $(echo "$AVG_RISK > 0.5" | bc -l 2>/dev/null || echo 0) )); then
            PRIORITY="⚠️  HIGH"
        elif (( $(echo "$AVG_RISK > 0.2" | bc -l 2>/dev/null || echo 0) )); then
            PRIORITY="⚠  MEDIUM"
        else
            PRIORITY="✓ LOW"
        fi

        echo "${TYPE_NAME}:${COUNT}:${AVG_RISK}:${PRIORITY}"
    done | sort -t: -k3 -rn | while IFS=: read -r TYPE_NAME COUNT AVG_RISK PRIORITY; do
        printf "%-20s %10s %12s %10s\n" "$TYPE_NAME" "$COUNT" "$AVG_RISK" "$PRIORITY"
    done

    echo ""
    echo "💡 Insight: Entity types with high average risk (>0.5) should be prioritized"
    echo "   for detection improvements. These will be analyzed in Phase 5."
    echo ""
fi
```
</phase2_entity_analysis>

---

## Step 3: Phase 3 - Signal Hunting (Adaptive)

<phase3_signal_hunting>
**Goal**: Collect signals and identify gaps (single-MID) OR aggregate heuristic frequencies (batch)

### Single-MID Mode

Execute if `MODE == "single"`:

```bash
if [[ "${MODE}" == "single" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚡ PHASE 3: SIGNAL HUNTING"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check triggered heuristics
    echo "⚡ Triggered Heuristics:"
    msg ${MID} heur
    echo ""

    # UPDATE #5: Use --filter flag to show only phrase matches > 0
    echo "💬 Phrase Matches (filtered - only matches > 0):"
    msg ${MID} phrases --filter
    echo ""

    # Check links (if present)
    NUM_LINKS=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].textSignals.links | length' /tmp/scorer_response.json 2>/dev/null || echo "0")
    if [[ $NUM_LINKS -gt 0 ]]; then
        echo "🔗 Links Analysis (${NUM_LINKS} links):"
        msg ${MID} links
        echo ""
    fi

    # Check detection rules
    echo "📏 Detection Rules:"
    msg ${MID} rules
    echo ""
fi
```

### Batch Mode

Execute if `MODE == "batch"`:

```bash
if [[ "${MODE}" == "batch" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚡ PHASE 3: SIGNAL HUNTING (Aggregate)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Analyzing heuristic frequencies across ${PROCESSED} CFNs..."
    echo ""

    # Initialize arrays for heuristic aggregation
    declare -A HEURISTIC_COUNTS
    declare -A HEURISTIC_REVIEW_COUNTS

    # Aggregate heuristic data from all caches
    for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
        [[ ! -f "${CACHE_FILE}" ]] && continue

        MID=$(basename "$CACHE_FILE" | sed 's/scorer_//; s/\.json//')

        # Get review decision for this MID
        REVIEW=$(grep "^${MID}," "${OUTPUT_DIR}/batch_data.csv" 2>/dev/null | cut -d, -f3)

        # Extract all triggered heuristics
        HEURISTICS=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | .value.heuristicEvaluationResults | to_entries[] | select(.value == true) | .key' "${CACHE_FILE}" 2>/dev/null)

        # Count frequencies
        for HEUR in $HEURISTICS; do
            ((HEURISTIC_COUNTS[$HEUR]++))
            if [[ "$REVIEW" == "1" ]]; then
                ((HEURISTIC_REVIEW_COUNTS[$HEUR]++))
            fi
        done
    done

    # Display top 20 heuristics by frequency
    echo "Top 20 Heuristics by Frequency:"
    echo ""
    printf "%-60s %8s %8s %6s\n" "Heuristic" "Fired" "Reviews" "Rate"
    echo "────────────────────────────────────────────────────────────────────────────────────────"

    for HEUR in "${!HEURISTIC_COUNTS[@]}"; do
        COUNT=${HEURISTIC_COUNTS[$HEUR]}
        REVIEWS=${HEURISTIC_REVIEW_COUNTS[$HEUR]:-0}
        if [[ $COUNT -gt 0 ]]; then
            RATE=$((REVIEWS * 100 / COUNT))
        else
            RATE=0
        fi
        echo "${HEUR}:${COUNT}:${REVIEWS}:${RATE}"
    done | sort -t: -k2 -rn | head -20 | while IFS=: read -r HEUR COUNT REVIEWS RATE; do
        # Flag ignored heuristics (fires often but rarely triggers review)
        if [[ $COUNT -gt 20 && $RATE -lt 5 ]]; then
            printf "%-60s %8d %8d %5d%% ⚠️\n" "${HEUR:0:60}" "$COUNT" "$REVIEWS" "$RATE"

            # Append to systematic gaps file
            echo "HEURISTIC_GAP:${HEUR}:${COUNT}:$((COUNT * 100 / PROCESSED))" >> "${OUTPUT_DIR}/systematic_gaps.txt"
        else
            printf "%-60s %8d %8d %5d%%\n" "${HEUR:0:60}" "$COUNT" "$REVIEWS" "$RATE"
        fi
    done

    echo ""
    echo "⚠️  Heuristics marked with ⚠️ fire frequently but rarely trigger review"
    echo "   → These signals are being ignored by detection rules"
    echo ""
fi
```
</phase3_signal_hunting>

---

## Step 4: Phase 4 - Targeted Search / Pattern Detection

<phase4_targeted_search_or_pattern_detection>
**Goal**: Vector-specific search (single-MID) OR detect systematic patterns (batch)

### Single-MID Mode

Execute if `MODE == "single"`:

```bash
if [[ "${MODE}" == "single" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔎 PHASE 4: TARGETED SEARCH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Determine attack vector from previous phases
    NUM_LINKS=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].textSignals.links | length' /tmp/scorer_response.json 2>/dev/null || echo "0")
    NUM_ATTACHMENTS=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].message.attachments | length' /tmp/scorer_response.json 2>/dev/null || echo "0")
    HAS_CRED_PHRASES=$(jq '[.extension.rtScorerExtension.processedMessageLogs[0].textSignals.phraseMatchesList[] | select(.phraseDef.phraseType == 35)] | length' /tmp/scorer_response.json 2>/dev/null || echo "0")

    echo "Attack Vector Detection:"
    echo "  Links: ${NUM_LINKS}"
    echo "  Attachments: ${NUM_ATTACHMENTS}"
    echo "  Credential Phrases: ${HAS_CRED_PHRASES}"
    echo ""

    # Link-based CFN
    if [[ $NUM_LINKS -gt 0 && $HAS_CRED_PHRASES -gt 0 ]]; then
        echo "🔗 LINK-BASED ATTACK DETECTED"
        echo ""
        echo "Searching for link-related attributes..."
        msg ${MID} search ANCHOR_TEXT
        echo ""
        msg ${MID} search URL_
        echo ""
        msg ${MID} domains
        echo ""

    # Attachment-based CFN
    elif [[ $NUM_ATTACHMENTS -gt 0 ]]; then
        echo "📎 ATTACHMENT-BASED ATTACK DETECTED"
        echo ""
        echo "Searching for attachment-related attributes..."
        msg ${MID} search FILE_EXTENSION
        echo ""
        msg ${MID} search ATTACHMENT
        echo ""
        msg ${MID} search MACRO
        echo ""

    # Sender-based CFN
    else
        echo "📧 SENDER/DOMAIN-BASED ATTACK DETECTED"
        echo ""
        echo "Searching for sender-related attributes..."
        msg ${MID} search FROM_EMAIL
        echo ""
        msg ${MID} search SPF
        echo ""
        msg ${MID} search DOMAIN
        echo ""
    fi
fi
```

### Batch Mode - Pattern Detection (THE INTELLIGENCE)

Execute if `MODE == "batch"`:

```bash
if [[ "${MODE}" == "batch" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔎 PHASE 4: PATTERN DETECTION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Analyzing systematic patterns across ${PROCESSED} CFNs..."
    echo ""

    # Initialize systematic gaps file
    > "${OUTPUT_DIR}/systematic_gaps.txt"

    ### Pattern 1: Rule Gaps (rules match but don't review)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 ANALYZING RULE GAPS..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    declare -A RULE_MATCH_COUNT
    declare -A RULE_REVIEW_COUNT

    for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
        [[ ! -f "${CACHE_FILE}" ]] && continue

        MID=$(basename "$CACHE_FILE" | sed 's/scorer_//; s/\.json//')
        REVIEW=$(grep "^${MID}," "${OUTPUT_DIR}/batch_data.csv" 2>/dev/null | cut -d, -f3)

        # Extract applicable rules that matched
        jq -r '.extension.rtScorerExtension.processedMessageLogs[0].messageDecisions.detectionControlSystemResult.reviewDecisionRuleResults | to_entries[] | select(.value.ruleIsApplicable == true and .value.matchReasons != null) | .key' "${CACHE_FILE}" 2>/dev/null | while read -r RULE; do
            ((RULE_MATCH_COUNT[$RULE]++))
            if [[ "$REVIEW" == "1" ]]; then
                ((RULE_REVIEW_COUNT[$RULE]++))
            fi
        done
    done

    echo ""
    echo "Rules with High Match Rate but Low Review Rate:"
    echo ""
    printf "%-15s %10s %10s %8s\n" "Rule" "Matches" "Reviews" "Rate"
    echo "─────────────────────────────────────────────────────────"

    for RULE in "${!RULE_MATCH_COUNT[@]}"; do
        MATCHES=${RULE_MATCH_COUNT[$RULE]}
        REVIEWS=${RULE_REVIEW_COUNT[$RULE]:-0}
        if [[ $MATCHES -gt 0 ]]; then
            RATE=$((REVIEWS * 100 / MATCHES))
        else
            RATE=0
        fi

        # Flag rules with >10 matches but <10% review rate
        if [[ $MATCHES -gt 10 && $RATE -lt 10 ]]; then
            printf "%-15s %10d %10d %7d%% ⚠️\n" "$RULE" "$MATCHES" "$REVIEWS" "$RATE"
            echo "RULE_GAP:${RULE}:${MATCHES}:$((MATCHES * 100 / PROCESSED))" >> "${OUTPUT_DIR}/systematic_gaps.txt"
        fi
    done | sort -t: -k2 -rn

    ### Pattern 2: Judgement Mismatches (marked BAD but not reviewed)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 ANALYZING JUDGEMENT MISMATCHES..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    BAD_NOT_REVIEWED=$(awk -F, '($2 == "1" || $2 ~ /BAD|ATTACK/) && $3 != "1" {print $1}' "${OUTPUT_DIR}/batch_data.csv")
    MISMATCH_COUNT=$(echo "${BAD_NOT_REVIEWED}" | grep -c . || echo 0)
    MISMATCH_PCT=$((MISMATCH_COUNT * 100 / PROCESSED))

    echo ""
    echo "Messages marked BAD/ATTACK but NOT reviewed:"
    echo "  Count: ${MISMATCH_COUNT}/${PROCESSED} (${MISMATCH_PCT}%)"

    if [[ $MISMATCH_COUNT -gt 0 ]]; then
        echo ""
        echo "⚠️  SYSTEMATIC GAP: ${MISMATCH_PCT}% marked as attacks but bypassed review"
        SAMPLE_MIDS=$(echo "${BAD_NOT_REVIEWED}" | head -5 | tr '\n' ' ')
        echo "  Sample MIDs: ${SAMPLE_MIDS}"
        echo "JUDGEMENT_MISMATCH:BAD_NOT_REVIEWED:${MISMATCH_COUNT}:${MISMATCH_PCT}:${SAMPLE_MIDS}" >> "${OUTPUT_DIR}/systematic_gaps.txt"
    fi

    ### Pattern 3: Campaign Clustering (3+ CFNs from same campaign)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 ANALYZING CAMPAIGN CLUSTERS..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    declare -A CAMPAIGN_COUNTS
    declare -A CAMPAIGN_MIDS

    for CACHE_FILE in ${OUTPUT_DIR}/cache/scorer_*.json; do
        [[ ! -f "${CACHE_FILE}" ]] && continue

        MID=$(basename "$CACHE_FILE" | sed 's/scorer_//; s/\.json//')

        # Extract campaign IDs (if present)
        CAMPAIGNS=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].messageDecisions.detectionControlSystemResult.campaignId // empty' "${CACHE_FILE}" 2>/dev/null)

        for CAMPAIGN in $CAMPAIGNS; do
            [[ -z "$CAMPAIGN" || "$CAMPAIGN" == "null" ]] && continue
            ((CAMPAIGN_COUNTS[$CAMPAIGN]++))
            CAMPAIGN_MIDS[$CAMPAIGN]+="${MID} "
        done
    done

    echo ""
    echo "Campaigns with 3+ CFNs:"
    echo ""
    printf "%-40s %10s %8s\n" "Campaign" "Count" "%"
    echo "───────────────────────────────────────────────────────────────"

    for CAMPAIGN in "${!CAMPAIGN_COUNTS[@]}"; do
        COUNT=${CAMPAIGN_COUNTS[$CAMPAIGN]}
        PCT=$((COUNT * 100 / PROCESSED))

        if [[ $COUNT -ge 3 ]]; then
            printf "%-40s %10d %7d%% ⚠️\n" "${CAMPAIGN:0:40}" "$COUNT" "$PCT"
            SAMPLE_MIDS=$(echo "${CAMPAIGN_MIDS[$CAMPAIGN]}" | tr ' ' '\n' | head -3 | tr '\n' ' ')
            echo "CAMPAIGN:${CAMPAIGN}:${COUNT}:${PCT}:${SAMPLE_MIDS}" >> "${OUTPUT_DIR}/systematic_gaps.txt"
        fi
    done | sort -t: -k3 -rn

    # Summary
    TOTAL_GAPS=$(wc -l < "${OUTPUT_DIR}/systematic_gaps.txt" 2>/dev/null || echo 0)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Pattern Detection Complete: ${TOTAL_GAPS} systematic gaps identified"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi
```
</phase4_targeted_search_or_pattern_detection>

---

## Step 5: Phase 5 - Deep Dive (Conditional)

<phase5_deep_dive>
**Goal**: Comprehensive analysis (single-MID) OR targeted deep dive on pattern representatives (batch)

### Single-MID Mode

Execute if `MODE == "single" && DEEP_MODE == "true"`:

```bash
if [[ "${MODE}" == "single" && "${DEEP_MODE}" == "true" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 PHASE 5: DEEP DIVE (God Mode)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Running comprehensive analysis (all msg tool commands)..."
    echo "This will take 30-60 seconds and output 500-2000 lines."
    echo ""

    msg ${MID} god

    echo ""
    echo "✅ Deep dive complete"
    echo ""
fi
```

### Batch Mode (Conditional Deep Dive)

Execute if `MODE == "batch" && systematic_gaps.txt exists and is non-empty`:

```bash
if [[ "${MODE}" == "batch" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔬 PHASE 5: CONDITIONAL DEEP DIVE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if systematic gaps were found
    if [[ ! -f "${OUTPUT_DIR}/systematic_gaps.txt" || ! -s "${OUTPUT_DIR}/systematic_gaps.txt" ]]; then
        echo "⚠️  No systematic gaps detected - skipping deep dive"
        echo "   (All CFNs appear to be isolated incidents)"
        echo ""
    else
        TOTAL_GAPS=$(wc -l < "${OUTPUT_DIR}/systematic_gaps.txt")
        echo "Found ${TOTAL_GAPS} systematic patterns requiring deep dive"
        echo "Deep diving up to ${DEEP_COUNT} representatives per pattern..."
        echo ""

        DEEP_DIVE_COUNT=0

        # Read systematic_gaps.txt line by line
        while IFS=: read -r GAP_TYPE GAP_ID GAP_COUNT GAP_PCT GAP_MIDS; do
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🔍 Pattern: ${GAP_TYPE} - ${GAP_ID}"
            echo "   Frequency: ${GAP_COUNT} CFNs (${GAP_PCT}%)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            # Get representative MIDs (up to DEEP_COUNT)
            if [[ -n "${GAP_MIDS}" ]]; then
                # Sample MIDs are in the 5th field (space-separated)
                REPS=$(echo "${GAP_MIDS}" | tr ' ' '\n' | head -${DEEP_COUNT} | tr '\n' ' ')
            else
                # Fallback: extract from CSV based on pattern
                REPS=$(awk -F, -v type="${GAP_TYPE}" -v id="${GAP_ID}" 'NR>1 {print $1}' "${OUTPUT_DIR}/batch_data.csv" | head -${DEEP_COUNT} | tr '\n' ' ')
            fi

            echo "   Representatives: ${REPS}"
            echo ""

            # Deep dive each representative with tailored commands
            for REP_MID in ${REPS}; do
                ((DEEP_DIVE_COUNT++))

                echo "   ┌─ Representative ${DEEP_DIVE_COUNT}: ${REP_MID}"

                # Set cache file for this MID
                export MSG_CACHE_FILE="${OUTPUT_DIR}/cache/scorer_${REP_MID}.json"

                # Tailor analysis based on gap type
                case "${GAP_TYPE}" in
                    "RULE_GAP")
                        echo "   │  Analyzing rule matching behavior..."
                        msg ${REP_MID} heur > /dev/null 2>&1
                        msg ${REP_MID} rules > /dev/null 2>&1
                        ;;
                    "JUDGEMENT_MISMATCH")
                        echo "   │  Analyzing entity judgements and review decision..."
                        msg ${REP_MID} entities > /dev/null 2>&1
                        msg ${REP_MID} decision > /dev/null 2>&1
                        ;;
                    "HEURISTIC_GAP")
                        echo "   │  Analyzing heuristic evaluation and rule usage..."
                        msg ${REP_MID} heur > /dev/null 2>&1
                        msg ${REP_MID} rules > /dev/null 2>&1
                        ;;
                    "CAMPAIGN")
                        echo "   │  Full campaign analysis..."
                        msg ${REP_MID} auto > /dev/null 2>&1
                        ;;
                esac

                # Save deep dive report
                DEEP_REPORT="${OUTPUT_DIR}/deep_${GAP_TYPE}_${GAP_ID}_${REP_MID}.md"
                {
                    echo "# Deep Dive Report: ${GAP_TYPE} - ${GAP_ID}"
                    echo ""
                    echo "**Representative MID**: ${REP_MID}"
                    echo "**Pattern**: ${GAP_TYPE} affecting ${GAP_COUNT} CFNs (${GAP_PCT}%)"
                    echo "**Generated**: $(date)"
                    echo ""
                    echo "---"
                    echo ""
                    echo "## Overview"
                    echo ""
                    msg ${REP_MID} overview
                    echo ""
                    echo "## Heuristics"
                    echo ""
                    msg ${REP_MID} heur
                    echo ""
                    echo "## Entities"
                    echo ""
                    msg ${REP_MID} entities
                    echo ""
                    echo "## Detection Decision"
                    echo ""
                    msg ${REP_MID} decision
                    echo ""
                } > "${DEEP_REPORT}" 2>&1

                echo "   └─ Saved: ${DEEP_REPORT}"
                echo ""
            done

        done < "${OUTPUT_DIR}/systematic_gaps.txt"

        echo ""
        echo "✅ Deep dive complete: ${DEEP_DIVE_COUNT} representatives analyzed"
        echo ""
    fi
fi
```
</phase5_deep_dive>

---

## Step 6: Phase 6 - Root Cause Analysis

<root_cause_analysis>
**Goal**: Categorize the detection gap into one of 4 types

### UPDATE #3: Integrate msg mismatch for automated gap detection

```bash
# First, use msg mismatch to get automated gap detection
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 AUTOMATED GAP DETECTION (msg mismatch)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MISMATCH_OUTPUT=$(msg ${MID} mismatch)
echo "$MISMATCH_OUTPUT" | jq '.'
echo ""

# Extract automated gap analysis
GAP_TYPE_AUTO=$(echo "$MISMATCH_OUTPUT" | jq -r '.gapType')
RECOMMENDATION_AUTO=$(echo "$MISMATCH_OUTPUT" | jq -r '.recommendation')
MISMATCH_DETECTED=$(echo "$MISMATCH_OUTPUT" | jq -r '.mismatchDetected')

echo "💡 Automated Analysis:"
echo "   Gap Type: ${GAP_TYPE_AUTO}"
echo "   Mismatch Detected: ${MISMATCH_DETECTED}"
echo "   Suggestion: ${RECOMMENDATION_AUTO}"
echo ""
```

### Analysis Framework

Based on all collected data, determine which category:

**Category 1: Missing Feature**
- Definition: Attack indicator exists but we don't extract it as a feature
- Evidence: Search shows zero attributes for expected signal
- Example: Homoglyph domain but no `HOMOGLYPH_DETECTED` attribute

**Category 2: Feature Exists, Heuristic Missing**
- Definition: We extract feature but no heuristic evaluates it
- Evidence: Attribute exists in entity but no corresponding heuristic fired
- Example: `URL_SHORTENER: true` but no `url_shortener_suspicious` heuristic

**Category 3: Heuristic Exists, Rule Doesn't Use It**
- Definition: Heuristic fires but no detection rule incorporates it
- Evidence: Heuristic triggered but rules didn't match
- Example: `never_seen_from_email: true` but rules don't check this signal

**Category 4: Rule Exists, Threshold Too Strict**
- Definition: Rule sees signals but confidence below threshold
- Evidence: Rules applicable but matched=false, ensemble score < threshold
- Example: Credential phishing score = 0.45 but threshold = 0.5

**Display Root Cause**:
```
🎯 ROOT CAUSE ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Category: <1|2|3|4> - <Category Name>

Evidence:
1. <Evidence point 1>
2. <Evidence point 2>
3. <Evidence point 3>

Why This Matters:
<1-2 sentence explanation of impact>

Attack Pattern:
<Brief description of attack type and why it bypassed detection>
```
</root_cause_analysis>

---

## Step 7: Phase 7 - Recommendations

<phase7_recommendations>
**Goal**: Generate actionable fix (single-MID) OR systematic improvement roadmap (batch)

### Single-MID Mode

Execute if `MODE == "single"`:

```bash
if [[ "${MODE}" == "single" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 PHASE 7: RECOMMENDATIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Extract message details
    FROM_EMAIL=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].fromEmail.address' /tmp/scorer_response.json 2>/dev/null || echo "unknown")
    SUBJECT=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].message.subject' /tmp/scorer_response.json 2>/dev/null || echo "unknown")
    JUDGEMENT=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].judgement' /tmp/scorer_response.json 2>/dev/null || echo "unknown")

    # Determine attack type
    NUM_LINKS=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].textSignals.links | length' /tmp/scorer_response.json 2>/dev/null || echo "0")
    NUM_ATTACHMENTS=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].message.attachments | length' /tmp/scorer_response.json 2>/dev/null || echo "0")
    HAS_CRED_PHRASES=$(jq '[.extension.rtScorerExtension.processedMessageLogs[0].textSignals.phraseMatchesList[] | select(.phraseDef.phraseType == 35)] | length' /tmp/scorer_response.json 2>/dev/null || echo "0")

    if [[ $NUM_LINKS -gt 0 && $HAS_CRED_PHRASES -gt 0 ]]; then
        ATTACK_TYPE="Credential Phishing"
    elif [[ $NUM_ATTACHMENTS -gt 0 ]]; then
        ATTACK_TYPE="Attachment Threat"
    elif [[ $HAS_CRED_PHRASES -gt 0 ]]; then
        ATTACK_TYPE="BEC / Credential Request"
    else
        ATTACK_TYPE="Domain / Sender Impersonation"
    fi

    # Generate category-specific recommendations
    echo "Recommended Fix (Category ${CATEGORY}):"
    echo ""

    case "${CATEGORY}" in
        "1")
            echo "**Fix Type**: Add Missing Feature"
            echo ""
            echo "Implementation Steps:"
            echo "  1. [ ] Identify specific attack indicator not currently extracted"
            echo "  2. [ ] Add secondary attribute definition to schema"
            echo "  3. [ ] Implement extraction logic in feature pipeline"
            echo "  4. [ ] Add unit tests for feature extraction"
            echo "  5. [ ] Deploy and monitor feature prevalence"
            echo ""
            echo "Expected Impact:"
            echo "  - Catch Rate: +10-30% on ${ATTACK_TYPE} attacks"
            echo "  - FP Risk: Low (new features don't affect existing rules initially)"
            echo ""
            ;;
        "2")
            echo "**Fix Type**: Add Missing Heuristic"
            echo ""
            echo "Implementation Steps:"
            echo "  1. [ ] Identify which existing features should be evaluated"
            echo "  2. [ ] Define heuristic logic and threshold"
            echo "  3. [ ] Add heuristic evaluation in entity scoring"
            echo "  4. [ ] Test heuristic triggers on positive/negative cases"
            echo "  5. [ ] Monitor heuristic fire rate in production"
            echo ""
            echo "Expected Impact:"
            echo "  - Catch Rate: +15-40% on ${ATTACK_TYPE} attacks"
            echo "  - FP Risk: Low-Medium (depends on heuristic specificity)"
            echo ""
            ;;
        "3")
            echo "**Fix Type**: Update Detection Rule"
            echo ""
            echo "Implementation Steps:"
            echo "  1. [ ] Identify which heuristics should influence detection"
            echo "  2. [ ] Update rule ensemble to incorporate these signals"
            echo "  3. [ ] Adjust signal weights in ensemble model"
            echo "  4. [ ] Backtest on historical CFN dataset"
            echo "  5. [ ] A/B test with conservative rollout"
            echo ""
            echo "Expected Impact:"
            echo "  - Catch Rate: +20-50% on ${ATTACK_TYPE} attacks"
            echo "  - FP Risk: Medium (rule changes affect broader traffic)"
            echo ""
            ;;
        "4")
            echo "**Fix Type**: Adjust Rule Threshold"
            echo ""

            # UPDATE #4: Use msg confidence to get detailed threshold analysis
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📊 Confidence Score Analysis"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            msg ${MID} confidence
            echo ""

            echo "Implementation Steps:"
            echo "  1. [ ] Analyze confidence score distribution for ${ATTACK_TYPE}"
            echo "  2. [ ] Determine optimal threshold (balance catch rate vs FP)"
            echo "  3. [ ] Update rule threshold in config"
            echo "  4. [ ] Backtest on last 30 days of data"
            echo "  5. [ ] Monitor FP rate in production for 1 week"
            echo ""
            echo "Expected Impact:"
            echo "  - Catch Rate: +5-15% on ${ATTACK_TYPE} attacks"
            echo "  - FP Risk: High (threshold changes affect all matches)"
            echo ""
            ;;
    esac

    echo "False Positive Risk Assessment:"
    echo "  - Attack specificity: Check if indicators are unique to attacks"
    echo "  - Legitimate use cases: Identify scenarios where fix could FP"
    echo "  - Mitigation: Add negative signals or exclusion logic"
    echo ""

    echo "Test Plan:"
    echo ""
    echo "  Positive Test Cases (should flag):"
    echo "    1. MID: ${MID} - This CFN"
    echo "    2. MID: <find similar CFN> - Same attack pattern"
    echo "    3. MID: <find similar CFN> - Variant attack"
    echo ""
    echo "  Negative Test Cases (should NOT flag):"
    echo "    1. MID: <legitimate email> - Similar features but safe"
    echo "    2. MID: <edge case> - Boundary condition"
    echo ""
fi
```

### Batch Mode

Execute if `MODE == "batch"`:

```bash
if [[ "${MODE}" == "batch" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 PHASE 7: RECOMMENDATIONS (Systematic Improvements)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -f "${OUTPUT_DIR}/categorized_gaps.txt" || ! -s "${OUTPUT_DIR}/categorized_gaps.txt" ]]; then
        echo "⚠️  No categorized gaps to recommend fixes for"
        echo ""
    else
        echo "Generating systematic improvement roadmap..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "## SYSTEMATIC DETECTION IMPROVEMENTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Prioritized by impact (% of batch affected):"
        echo ""

        # Sort gaps by frequency (descending)
        sort -t: -k5 -rn "${OUTPUT_DIR}/categorized_gaps.txt" | while IFS=: read -r CATEGORY CATEGORY_NAME GAP_TYPE GAP_ID GAP_COUNT GAP_PCT; do
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "### Priority: ${GAP_PCT}% (${GAP_COUNT} CFNs)"
            echo ""
            echo "**Gap:** ${GAP_TYPE} - ${GAP_ID}"
            echo "**Category:** ${CATEGORY} - ${CATEGORY_NAME}"
            echo ""

            # Category-specific recommendations
            case "${CATEGORY}" in
                "1")
                    echo "**Fix:** Add missing feature extraction"
                    echo ""
                    echo "Implementation:"
                    echo "  - Analyze representative CFNs to identify attack indicator"
                    echo "  - Create secondary attribute for this indicator"
                    echo "  - Add extraction logic in feature pipeline"
                    echo "  - Expected timeline: 2-3 sprints"
                    echo ""
                    echo "Impact: High catch rate improvement (+20-40%)"
                    echo "FP Risk: Low (new features don't affect existing rules)"
                    ;;
                "2")
                    echo "**Fix:** Add heuristic evaluation"
                    echo ""
                    echo "Implementation:"
                    echo "  - Define heuristic logic using existing features"
                    echo "  - Add heuristic to entity evaluation"
                    echo "  - Test on representative samples"
                    echo "  - Expected timeline: 1-2 sprints"
                    echo ""
                    echo "Impact: Medium-High catch rate improvement (+15-35%)"
                    echo "FP Risk: Low-Medium (depends on heuristic specificity)"
                    ;;
                "3")
                    echo "**Fix:** Update detection rules"
                    echo ""
                    echo "Implementation:"
                    echo "  - Identify signals/heuristics to incorporate"
                    echo "  - Update rule ensemble or create new rule"
                    echo "  - Backtest on historical data"
                    echo "  - Expected timeline: 1 sprint + A/B testing"
                    echo ""
                    echo "Impact: High catch rate improvement (+25-50%)"
                    echo "FP Risk: Medium (affects broader traffic)"
                    ;;
                "4")
                    echo "**Fix:** Adjust rule threshold"
                    echo ""
                    echo "Implementation:"
                    echo "  - Analyze confidence score distribution"
                    echo "  - Tune threshold to balance catch vs FP"
                    echo "  - Monitor FP rate in production"
                    echo "  - Expected timeline: 1-2 weeks"
                    echo ""
                    echo "Impact: Low-Medium catch rate improvement (+5-20%)"
                    echo "FP Risk: Medium-High (affects all rule matches)"
                    ;;
            esac

            echo ""
            echo "**Next Steps:**"
            echo "  1. Create Jira ticket for this gap"
            echo "  2. Assign to detection engineering team"
            echo "  3. Review deep dive reports: ${OUTPUT_DIR}/deep_${GAP_TYPE}_${GAP_ID}_*.md"
            echo ""
        done

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "## IMPLEMENTATION PRIORITY"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "**P0 (Immediate)**: Gaps affecting >15% of CFNs"
        echo "**P1 (This Sprint)**: Gaps affecting 5-15% of CFNs"
        echo "**P2 (Next Sprint)**: Gaps affecting <5% of CFNs"
        echo ""

        # Prioritize by percentage
        P0_COUNT=$(awk -F: '$6 > 15 {count++} END {print count+0}' "${OUTPUT_DIR}/categorized_gaps.txt")
        P1_COUNT=$(awk -F: '$6 >= 5 && $6 <= 15 {count++} END {print count+0}' "${OUTPUT_DIR}/categorized_gaps.txt")
        P2_COUNT=$(awk -F: '$6 < 5 {count++} END {print count+0}' "${OUTPUT_DIR}/categorized_gaps.txt")

        echo "  P0 Gaps: ${P0_COUNT}"
        echo "  P1 Gaps: ${P1_COUNT}"
        echo "  P2 Gaps: ${P2_COUNT}"
        echo ""
    fi
fi
```
</phase7_recommendations>

---

## Step 8: Phase 8 - Report Generation

<phase8_report_generation>
**Goal**: Generate investigation report (single-MID) OR batch summary (batch)

### Single-MID Mode

Execute if `MODE == "single"`:

```bash
if [[ "${MODE}" == "single" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 PHASE 8: REPORT GENERATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    REPORT_FILE="/tmp/cfn_report_${MID}.md"

    # Extract message details
    FROM_EMAIL=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].fromEmail.address' /tmp/scorer_response.json 2>/dev/null || echo "unknown")
    SUBJECT=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].message.subject' /tmp/scorer_response.json 2>/dev/null || echo "unknown")
    JUDGEMENT=$(jq -r '.extension.rtScorerExtension.processedMessageLogs[0].judgement' /tmp/scorer_response.json 2>/dev/null || echo "unknown")
    NUM_ENTITIES=$(jq '.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | length' /tmp/scorer_response.json 2>/dev/null || echo "0")
    NUM_HEURISTICS=$(jq "[.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | .value.heuristicEvaluationResults | to_entries[] | select(.value == true)] | length" /tmp/scorer_response.json 2>/dev/null || echo "0")
    FLAGGED_RULES=$(jq -c '.extension.rtScorerExtension.processedMessageLogs[0].messageDecisions.detectionControlSystemResult.ruleReasons // []' /tmp/scorer_response.json 2>/dev/null || echo "[]")

    # Generate report (save to file)
    cat > "${REPORT_FILE}" <<EOF
# CFN Investigation Report

## Message Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**Message ID**: ${MID}
**Attack Type**: ${ATTACK_TYPE}
**From**: ${FROM_EMAIL}
**Subject**: ${SUBJECT}

## Summary
**Current Detection**: Judgement=${JUDGEMENT} (should be ATTACK)
**Root Cause**: Category ${CATEGORY} - ${CATEGORY_NAME}
**Entities Analyzed**: ${NUM_ENTITIES}
**Heuristics Triggered**: ${NUM_HEURISTICS}
**Rules Flagged**: ${FLAGGED_RULES}

## Recommended Fix
See Phase 7 output above for detailed recommendations.

**Next Steps:**
1. [ ] Create Jira ticket: DT-XXXXX
2. [ ] Implement fix in code
3. [ ] Write unit tests
4. [ ] Validate with test cases
5. [ ] Run backtesting
6. [ ] Deploy to production
7. [ ] Monitor metrics

## Additional Context
**Investigation Date**: $(date)
**Cache Location**: /tmp/scorer_response.json (valid for 5min)
**Rerun Investigation**: \`/cfn-investigate ${MID}\`
**Deep Dive**: \`/cfn-investigate ${MID} --deep\`
EOF

    echo "✅ Report saved: ${REPORT_FILE}"
    echo ""

    # Display summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ CFN INVESTIGATION COMPLETE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Quick Summary:"
    echo "   Message: ${MID}"
    echo "   Attack Type: ${ATTACK_TYPE}"
    echo "   Root Cause: Category ${CATEGORY} - ${CATEGORY_NAME}"
    echo ""
    echo "📄 Full Report: ${REPORT_FILE}"
    echo ""
fi
```

### Batch Mode

Execute if `MODE == "batch"`:

```bash
if [[ "${MODE}" == "batch" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 PHASE 8: REPORT GENERATION (Batch Summary)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    SUMMARY_FILE="${OUTPUT_DIR}/BATCH_SUMMARY.md"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    # Calculate throughput
    if [[ $DURATION -gt 0 ]]; then
        CFNS_PER_HOUR=$((PROCESSED * 3600 / DURATION))
    else
        CFNS_PER_HOUR=0
    fi

    # Count gaps by type
    if [[ -f "${OUTPUT_DIR}/systematic_gaps.txt" ]]; then
        TOTAL_GAPS=$(wc -l < "${OUTPUT_DIR}/systematic_gaps.txt")
        RULE_GAPS=$(grep -c "^RULE_GAP:" "${OUTPUT_DIR}/systematic_gaps.txt" || echo 0)
        HEUR_GAPS=$(grep -c "^HEURISTIC_GAP:" "${OUTPUT_DIR}/systematic_gaps.txt" || echo 0)
        JUDG_GAPS=$(grep -c "^JUDGEMENT_MISMATCH:" "${OUTPUT_DIR}/systematic_gaps.txt" || echo 0)
        CAMP_GAPS=$(grep -c "^CAMPAIGN:" "${OUTPUT_DIR}/systematic_gaps.txt" || echo 0)
    else
        TOTAL_GAPS=0
        RULE_GAPS=0
        HEUR_GAPS=0
        JUDG_GAPS=0
        CAMP_GAPS=0
    fi

    # Generate summary report
    cat > "${SUMMARY_FILE}" <<EOF
# CFN Batch Investigation Summary

**Date:** $(date +"%Y-%m-%d %H:%M:%S")
**Input File:** ${BATCH_FILE}
**Total CFNs:** ${TOTAL_COUNT}
**Processed:** ${PROCESSED}
**Failed:** ${FAILED}
**Duration:** $((DURATION / 60)) minutes ($((DURATION / 3600)) hours)
**Throughput:** ${CFNS_PER_HOUR} CFNs/hour

---

## Executive Summary

### Systematic Detection Gaps Identified

**${TOTAL_GAPS}** patterns detected affecting **${PROCESSED}** CFNs across **4** gap types:
- **Rule Gaps**: ${RULE_GAPS} patterns (rules match but don't review)
- **Heuristic Gaps**: ${HEUR_GAPS} patterns (heuristics fire but ignored)
- **Judgement Mismatches**: ${JUDG_GAPS} patterns (marked bad but not reviewed)
- **Campaign Clusters**: ${CAMP_GAPS} patterns (coordinated attack campaigns)

### Top 5 Gaps by Impact

$(if [[ -f "${OUTPUT_DIR}/categorized_gaps.txt" ]]; then
    sort -t: -k6 -rn "${OUTPUT_DIR}/categorized_gaps.txt" | head -5 | while IFS=: read -r CAT CAT_NAME TYPE ID COUNT PCT; do
        echo "**${PCT}%** (${COUNT} CFNs): ${TYPE} - ${ID}"
        echo "  - Category: ${CAT} - ${CAT_NAME}"
        echo ""
    done
else
    echo "No categorized gaps available"
fi)

---

## Files Generated

- **Summary:** \`${SUMMARY_FILE}\`
- **Batch Data:** \`${OUTPUT_DIR}/batch_data.csv\`
- **Systematic Gaps:** \`${OUTPUT_DIR}/systematic_gaps.txt\`
- **Categorized Gaps:** \`${OUTPUT_DIR}/categorized_gaps.txt\`
- **Deep Dive Reports:** \`${OUTPUT_DIR}/deep_*.md\`
- **Cache Files:** \`${OUTPUT_DIR}/cache/scorer_*.json\`

---

**Generated by:** \`/cfn-investigate ${BATCH_FILE}\`

**Rerun:** \`/cfn-investigate ${BATCH_FILE}\` (uses cached data if within 5min)

**Deep Dive:** \`/cfn-investigate ${BATCH_FILE} --deep ${DEEP_COUNT}\`
EOF

    echo "✅ Batch summary saved: ${SUMMARY_FILE}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ BATCH INVESTIGATION COMPLETE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Summary:"
    echo "   Processed: ${PROCESSED} CFNs in $((DURATION / 60)) minutes"
    echo "   Gaps Found: ${TOTAL_GAPS} systematic patterns"
    echo "   Success Rate: $(( (PROCESSED - FAILED) * 100 / PROCESSED ))%"
    echo ""
    echo "📄 Full Report: ${SUMMARY_FILE}"
    echo ""
    echo "📂 Output Directory: ${OUTPUT_DIR}"
    echo ""
fi
```
</phase8_report_generation>

---

<summary_output>
After generating the full report, display a concise summary:

```
✅ CFN INVESTIGATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Quick Summary:
   Message: ${MID}
   Attack Type: <type>
   Root Cause: Category <X> - <Name>

🎯 Recommended Fix:
   <1 sentence fix description>

📈 Expected Impact:
   Catch Rate: +<X>%
   FP Risk: <Low|Medium|High>

📄 Full Report: /tmp/cfn_report_${MID}.md

🔄 Next Actions:
   1. Review full report
   2. Create Jira ticket
   3. Implement fix
   4. Validate with test cases
```

**Ask user**: "Would you like me to:
1. Dive deeper into any specific aspect?
2. Search for similar CFN cases?
3. Generate test cases for this fix?
4. Help implement the recommended fix?"
</summary_output>

---

## Implementation Notes

### Tools Used
- ✅ `msg` (message scorer analysis tool) - All analysis commands
- ✅ `bash` - Command execution and text processing
- ✅ `jq` - JSON parsing (automatically handled by msg tool)

### Performance Targets
- **Quick CFN**: 8-12 minutes (single vector, obvious gap)
- **Standard CFN**: 12-18 minutes (multi-entity, deep dive required)
- **Complex CFN**: 20-30 minutes (multi-vector, requires --deep mode)

### Error Handling
- If `msg ${MID} auto` fails → Check MID validity and scorer accessibility
- If entity UUID not found → Use entity list to find correct UUID
- If msg tool returns "jq error" → Ignore, use available data
- If --deep produces >2000 lines → Summarize key sections

### Success Criteria
- ✅ Root cause identified and categorized
- ✅ Specific detection gap documented with evidence
- ✅ Actionable fix proposed with implementation details
- ✅ Test plan includes positive and negative cases
- ✅ FP risk assessed and mitigations identified
- ✅ Report saved and ready for Jira ticket creation

### Key Principles
1. **Use msg tool exclusively** - Leverages POV scorer with 5-min caching
2. **5-minute cache** - All commands after first `auto` use cached data
3. **Evidence-based** - Every claim backed by msg tool output
4. **Actionable** - Recommendations include file paths, thresholds, logic
5. **Risk-aware** - Every fix includes FP risk assessment

---

## Example Execution Flow

User runs: `/cfn-investigate 7213175459145070583`

1. Parse arguments: MID=7213175459145070583, DEEP_MODE=false
2. Run `msg 7213175459145070583 auto` → Get overview (judgement=GOOD)
3. Run `msg 7213175459145070583 decision` → flaggedRules=[]
4. Run `msg 7213175459145070583 mismatch` → Automated gap detection
5. Run `msg 7213175459145070583 entities` → Find 5 entities, 1 URL with risk=0.12
6. Run `msg 7213175459145070583 domains` → Domain analysis
7. Run `msg 7213175459145070583 heur` → Only 2 heuristics triggered
8. Run `msg 7213175459145070583 phrases --filter` → Find CREDENTIAL_PHISHING phrases
9. Run `msg 7213175459145070583 links` → Anchor text mismatch detected
10. Search: `msg 7213175459145070583 search HOMOGLYPH` → No results (missing feature!)
11. Run `msg 7213175459145070583 confidence` → Confidence threshold analysis
12. Categorize: Category 1 (Missing Feature) + Category 4 (Threshold Too Strict)
13. Generate recommendation: Implement homoglyph detection + lower domain age threshold
14. Create test plan with 3 positive + 2 negative cases
15. Save report to `/tmp/cfn_report_7213175459145070583.md`
16. Display summary with next actions

Total time: ~12 minutes
