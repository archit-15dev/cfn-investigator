#!/usr/bin/env bash
# msg - Quick analysis of adhoc-scorer responses
# Usage: msg <message_id> [command]

set -euo pipefail

BASE_PATH='.extension.rtScorerExtension.processedMessageLogs[0]'
OUTPUT_FILE="/tmp/scorer_response.json"

# Helper functions to decode enum values (Bash 3.2 compatible - no associative arrays)
decode_phrase_type() {
  case "$1" in
    0) echo "BITCOIN_RELATED" ;; 1) echo "BITCOIN_ADDRESS" ;; 2) echo "CREDENTIAL_FRAUD" ;; 3) echo "FINANCIAL" ;;
    4) echo "PERSONAL_INFORMATION" ;; 5) echo "MALWARE" ;; 6) echo "HIGH_ENGAGEMENT" ;; 7) echo "BORING_VOCAB" ;;
    8) echo "SENDER_NAME" ;; 9) echo "RECIPIENT_NAME" ;; 10) echo "SENDER_EMAIL" ;; 11) echo "RECIPIENT_EMAILS" ;;
    12) echo "DOLLAR_AMOUNTS" ;; 13) echo "DOLLAR_TEXT_AMOUNTS" ;; 14) echo "BRAND_NAME" ;; 15) echo "NUMERIC_FEATURES" ;;
    16) echo "BAD_WORDS" ;; 17) echo "VOICEMAIL" ;; 18) echo "FAX" ;; 19) echo "PAYROLL" ;; 20) echo "GIFT_CARD" ;;
    21) echo "LOOSE_BITCOIN_ADDRESS" ;; 22) echo "ADMIN" ;; 23) echo "ADULT_CONTENT" ;; 24) echo "ADVANCE_FEE" ;;
    25) echo "HEALTH_MARKETING" ;; 26) echo "SPAM_SOLICITATION" ;; 27) echo "SUSPICIOUS_ATTACHMENT_EXTENSIONS" ;;
    28) echo "KNOWN_BAD_ATTACHMENT_NAMES" ;; 29) echo "LITECOIN_ADDRESS" ;; 30) echo "LOGIN_PAGE_BRANDS" ;;
    31) echo "LOGIN_PAGE_KEYWORDS" ;; 32) echo "ANCHOR_TEXT" ;; 33) echo "DOCUMENT_SHARING" ;; 34) echo "PAYMENT" ;;
    35) echo "PASSWORD" ;; 36) echo "SCAM" ;; 37) echo "IMAGE_EXTENSIONS" ;; 38) echo "INVOICE_VOCAB" ;;
    39) echo "INVOICE_SYMBOLS" ;; 40) echo "SUSPICIOUS_CREATORS_OR_PRODUCERS" ;; 41) echo "ATTACHMENT_EXTENSIONS" ;;
    42) echo "C_SUITE_TITLES" ;; 43) echo "FINANCIAL_INSTITUTION_NAMES" ;; 44) echo "FINANCIAL_INTENT_GRAB_BAG" ;;
    45) echo "URGENT" ;; 46) echo "CHANGE_OF_INTENT" ;; 47) echo "BAD_BANK_ACCOUNTS" ;; 48) echo "SUSPICIOUS_PHYSICAL_ADDRESSES" ;;
    49) echo "ATTACK_EMOJIS" ;; 50) echo "AUTOMATED_SYSTEM_FROM_EMAIL" ;; 51) echo "FACEBOOK" ;; 52) echo "INVOICE_FILE_NAMES" ;;
    53) echo "AUTOMATED_PHRASES" ;; 54) echo "AUTOMATED_MARKETING" ;; 55) echo "COMMON_EMAIL_FORMALITIES" ;;
    56) echo "COMMON_EMAIL_CONVERSATION" ;; 57) echo "CHANGE_FINANCIAL_TRANSACTION_DETAILS" ;; 58) echo "HR_SCAM_VOCAB" ;;
    59) echo "GRAYMAIL_VOCAB" ;; 60) echo "CORONA_VOCAB" ;; 61) echo "CORONA_ECONOMIC_RESPONSE_VOCAB" ;;
    62) echo "CORONA_LOW_PRECISION_VOCAB" ;; 63) echo "DISPLAY_NAME_EMAIL_ADMIN" ;; 64) echo "SUBJECT_EMAIL_ADMIN" ;;
    65) echo "DRAGNET_RULE_DEFINED_PHRASES" ;; 66) echo "EMPLOYEE_TERMINATION_LIST" ;; 67) echo "RFQ_VOCAB" ;;
    68) echo "RFQ_PRICE_QUOTE_VOCAB" ;; 69) echo "BILL_ACCOUNT_VOCAB" ;; 70) echo "UPDATE_ACTION_VOCAB" ;;
    71) echo "UNSOLVED_ISSUE_VOCAB" ;; 72) echo "REQUEST_CONFIRMATION_VOCAB" ;; 73) echo "BODY_VOICEMAIL" ;;
    74) echo "LEGAL_SERVICE_VOCAB" ;; 75) echo "EXECUTABLE_EXTENSIONS" ;; 76) echo "ANCHOR_TEXT_BRANDS" ;;
    77) echo "ANCHOR_TEXT_BORING_TEXT" ;; 78) echo "ANCHOR_TEXT_CALL_TO_ACTION_TEXT" ;; 79) echo "ANCHOR_TEXT_FILE_TEXT" ;;
    80) echo "ANCHOR_TEXT_VERY_SUSPICIOUS_TEXT" ;; 81) echo "ACQUISITION_VOCAB" ;; 82) echo "HELP_VOCAB" ;;
    83) echo "PERSONAL_FINANCIAL_VOCAB" ;; 84) echo "AVAILABILITY_VOCAB" ;; 85) echo "REQUEST_PERSONAL_NUMBER_VOCAB" ;;
    86) echo "QUICK_TASK_VOCAB" ;; 87) echo "BUSY_NOW_VOCAB" ;; 88) echo "RECON_EMAIL_VOCAB" ;; 89) echo "SEG_APPENDED_TEXT_VOCAB" ;;
    90) echo "GREETING_VOCAB" ;; 91) echo "CALENDAR_VOCAB" ;; 92) echo "VIP_NAME" ;; 93) echo "PURCHASE_REQUEST_VOCAB" ;;
    94) echo "EMAIL_DELIVERY_ISSUE_VOCAB" ;; 95) echo "RFQ_SUBJECT_VOCAB" ;; 96) echo "RFQ_VERB_VOCAB" ;;
    97) echo "RFQ_NOUN_VOCAB" ;; 98) echo "HATE_SPEECH_VOCAB" ;; 99) echo "ELECTION_INTERFERENCE_VOCAB" ;;
    100) echo "FILE_SHARING_SERVICES_NAMES" ;; 101) echo "WIRING_INSTRUCTION_VOCAB" ;; 102) echo "INTUIT_QUICKBOOKS_VOCAB" ;;
    103) echo "COMPRESSION_EXTENSIONS" ;; 104) echo "ARCHIVE_EXTENSIONS" ;; 105) echo "REQUEST_RELEASING_PAYMENT_VOCAB" ;;
    106) echo "PHONE_NUMBER" ;; 107) echo "MACRO_ENABLED_EXTENSIONS" ;; 108) echo "EMAIL_ADDRESS" ;;
    109) echo "COMMONLY_IMPERSONATED_BRANDS" ;; 110) echo "AR_VOCAB" ;; 111) echo "NON_MALICIOUS_PAYLOAD_FILE_EXTENSIONS" ;;
    112) echo "DOLLAR_AMOUNT_WITH_CURRENCY_SYMBOL" ;; 113) echo "SUBSCRIPTION_VOCAB" ;; 114) echo "DEMO_VOCAB" ;;
    115) echo "PHONE_ENGAGEMENT_VOCAB" ;; 116) echo "SHIPMENT_VOCAB" ;; 117) echo "CREDIT_SCORE_VOCAB" ;;
    118) echo "CRYPTOCURRENCY_VOCAB" ;; 119) echo "CUSTOMER_SUPPORT_VOCAB" ;; 120) echo "PHONE_SCAM_VOCAB" ;;
    121) echo "SOFTWARE_SUBSCRIPTION_VOCAB" ;; 122) echo "PHONE_SCAM_BRAND_VOCAB" ;; 123) echo "SOCIAL_MEDIA_VOCAB" ;;
    124) echo "PROMOTIONAL_GRAYMAIL_VOCAB" ;; 125) echo "EVENT_INVITE_GRAYMAIL_VOCAB" ;; 126) echo "NEWSLETTER_GRAYMAIL_VOCAB" ;;
    127) echo "SALES_COLD_CALL_GRAYMAIL_VOCAB" ;; 128) echo "TRIGRAM_SEQUENCE" ;; 129) echo "SCAN_VOCAB" ;;
    130) echo "RFP_VOCAB" ;; 131) echo "SHAREPOINT_FILE_SHARING_VOCAB" ;; 132) echo "DOLLAR_AMOUNT_ABBREVIATIONS" ;;
    133) echo "CALL_TO_CHANGE_PASSWORD_VOCAB" ;; 134) echo "ACH_INFORMATION_VOCAB" ;; 135) echo "REMITTANCE_VOCAB" ;;
    136) echo "ATTACKER_ENGAGEMENT_VOCAB" ;; 137) echo "SECURE_ENCRYPTED_MESSAGE_VOCAB" ;; 138) echo "COVID_HEALTH_POLICY_VOCAB" ;;
    139) echo "SECURITY_ANALYST_EMAIL_VOCAB" ;; 140) echo "SECURITY_ANALYST_JOB_TITLE_VOCAB" ;;
    141) echo "SAFE_ENGAGEMENT_ACTION_VOCAB" ;; 142) echo "UNSAFE_ENGAGEMENT_ACTION_VOCAB" ;; 143) echo "RECEIPTS_VOCAB" ;;
    144) echo "NOTIFICATIONS_AND_CONFIRMATIONS_VOCAB" ;; 145) echo "JOB_OFFER_VOCAB" ;; 146) echo "PII_VOCAB" ;;
    147) echo "FINANCE_DEPARTMENT_NAMES" ;; 148) echo "IT_DEPARTMENT_NAMES" ;; 149) echo "ACCOUNT_CHANGE_CALL_TO_ACTION_VOCAB" ;;
    150) echo "FINANCIAL_VOCAB" ;; 151) echo "UKRAINE_RUSSIA_WAR" ;; 152) echo "GRAYMAIL_COLD_CALL_OUTREACH_VOCAB" ;;
    153) echo "SURVEYS_FEEDBACK_REQUEST_VOCAB" ;; 154) echo "GRAYMAIL_FP_MOVEBACK_DERIVED_VOCAB" ;;
    155) echo "VENDOR_FRAUD_EXPERIMENT_VOCAB" ;; 156) echo "HR_IMPERSONATION_VOCAB" ;; 157) echo "JOB_OFFER_SUBJECT_VOCAB" ;;
    158) echo "HR_IMPERSONATION_SUBJECT_VOCAB" ;; 159) echo "COMMON_GREETING_VOCAB" ;; 160) echo "COMMON_GOODBYE_VOCAB" ;;
    161) echo "PASSWORD_GIVEN" ;; 162) echo "ONE_TIME_PASSWORD_VOCAB" ;; 163) echo "MAIL_DELIVERY_VOCAB" ;;
    164) echo "REPLY_OR_FWD_VOCAB" ;; 165) echo "EXTERNAL_OR_PHISH_FLAG_VOCAB" ;; 166) echo "DONATION_VOCAB" ;;
    167) echo "TWO_AUTHENTICATION_VOCAB" ;; 168) echo "JOB_APPLICATION_VOCAB" ;; 169) echo "PAYLOADLESS_RECON" ;;
    170) echo "PAYLOADLESS_PHONE_SCAM" ;; 171) echo "PAYLOADLESS_EMPLOYMENT_SCAM" ;;
    172) echo "PAYLOADLESS_INHERITANCE_LOTTERY_SCAM" ;; 173) echo "PAYLOADLESS_ENGAGEMENT" ;;
    174) echo "PAYLOADLESS_COLD_CALL" ;; 175) echo "PAYLOADLESS_PAYROLL_UPDATE" ;; 176) echo "PAYLOADLESS_EXTORTION" ;;
    177) echo "PAYLOADLESS_QUICK_FAVOR" ;; 178) echo "STORAGE_VOCAB" ;; 179) echo "MEETING_INVITE" ;;
    180) echo "PAYPAL_INVOICE_VOCAB" ;; 181) echo "PAYPAL_INVOICE_EXCLUDED_VOCAB" ;; 182) echo "CONVERSATION_STRUCTURE" ;;
    183) echo "CONVERSATION_STRUCTURE_REGEX" ;; 184) echo "RARE_CREDENTIAL_FRAUD_VOCAB" ;; 185) echo "RARE_PASSWORD_VOCAB" ;;
    186) echo "RARE_DOCUMENT_SHARING_VOCAB" ;; 187) echo "RARE_FINANCIAL_INTENT_GRAB_BAG_VOCAB" ;;
    188) echo "RARE_PERSONAL_INFORMATION_VOCAB" ;; 189) echo "RARE_FINANCIAL_VOCAB" ;; 190) echo "RARE_HIGH_ENGAGEMENT_VOCAB" ;;
    191) echo "RARE_VOICEMAIL_VOCAB" ;; 192) echo "RARE_ADMIN_VOCAB" ;; 193) echo "RARE_ADVANCE_FEE_VOCAB" ;;
    194) echo "RARE_SAFE_ENGAGEMENT_ACTION_VOCAB" ;; 195) echo "RARE_NOTIFICATIONS_AND_CONFIRMATIONS_VOCAB" ;;
    196) echo "RARE_JOB_OFFER_VOCAB" ;; 197) echo "RARE_ACCOUNT_CHANGE_CALL_TO_ACTION_VOCAB" ;;
    198) echo "MICROSOFT_SIGN_OFF" ;; 199) echo "LEGAL_LANGUAGE" ;; 200) echo "ATTACHMENT_ATP_SCAN_VOCAB" ;;
    201) echo "RFQ_DETAILS_VOCAB" ;; 202) echo "SUBJECT_IS_EXTERNAL" ;; 203) echo "NO_SUBJECT" ;;
    204) echo "SUBJECT_IS_REPLY_OR_FORWARD" ;; 205) echo "FREE_PIANO_VOCAB" ;; 206) echo "ATTACHMENT_IS_UNSAFE_VOCAB" ;;
    207) echo "FOLLOWING_UP_ON_OFFLINE_CONNECTION" ;; 208) echo "LOSS_OF_LIFE_VOCAB" ;; 209) echo "COMPROMISE_BAU_VOCAB" ;;
    210) echo "QR_CODE_VOCAB" ;; 211) echo "ABNORMAL_IMPERSONATION_VOCAB" ;; 212) echo "ABNORMAL_IMPERSONATION_HIGH_PRECISION_VOCAB" ;;
    213) echo "OUTLOOK_MOBILE_SIGNOFF" ;; 214) echo "SUSPICIOUS_BANK" ;; 215) echo "SYSTEM_EMAIL_ACCOUNT_USERNAME_EXACT_MATCH" ;;
    216) echo "SYSTEM_EMAIL_ACCOUNT_USERNAME_SUBSTR_MATCH" ;; 217) echo "NON_ENGLISH_CREDENTIAL_PHISHING_VOCAB" ;;
    218) echo "GENERAL_SERVICE_VOCAB" ;; 219) echo "CUSTOMER_SERVICE_VOCAB" ;; 220) echo "GALA_SCAM_VOCAB" ;;
    221) echo "WARNING_PHRASE_FOR_EMAIL_SEGMENTATION" ;; 222) echo "CONVERSATION_PHRASE_FOR_EMAIL_SEGMENTATION" ;;
    223) echo "CRYPTO_VOCAB" ;; 224) echo "PRIZE_WINNING_VOCAB" ;; 225) echo "JOURNAL_SCAM_VOCAB" ;;
    226) echo "UNICODE_BLOCK_VOCAB" ;; 227) echo "SENT_FROM_IPHONE_VOCAB" ;; 228) echo "SEXTORTION_VOCAB" ;;
    229) echo "PANDADOC_VOCAB" ;; 230) echo "VENDOR_FRAUD_INVOICE_VOCAB" ;; 231) echo "VENDOR_FRAUD_PREDICTED_INVOICE_VOCAB" ;;
    232) echo "VENDOR_FRAUD_PREDICTED_NOT_INVOICE_VOCAB" ;; 233) echo "RFI_VOCAB" ;; 234) echo "UNSUBSCRIBE_VOCAB" ;;
    235) echo "OBFUSCATED_VOCAB" ;; 236) echo "SUSPICIOUS_AI_PROMPT_VOCAB" ;; 237) echo "GENERALLY_SUSPICIOUS_VENDOR_FRAUD_PHRASES" ;;
    *) echo "$1" ;;
  esac
}

decode_entity_type() {
  case "$1" in
    1) echo "FROM_EMAIL" ;; 2) echo "DOMAIN" ;; 3) echo "BODY_LINK" ;; 4) echo "IP" ;;
    5) echo "DOMAIN" ;; 6) echo "REPLY_TO_EMAIL" ;; 7) echo "ATTACHMENT" ;; 8) echo "PHONE_NUMBER" ;;
    *) echo "$1" ;;
  esac
}

decode_judgement() {
  case "$1" in
    1) echo "BAD (ATTACK)" ;; 2) echo "SUSPICIOUS" ;; 3) echo "BORDERLINE" ;; 4) echo "GOOD" ;;
    5) echo "NONE" ;; 6) echo "PROBABLY_GOOD" ;; 7) echo "NOT_JUDGED" ;; 8) echo "UNSURE" ;;
    *) echo "$1" ;;
  esac
}

decode_review_decision() {
  case "$1" in
    0) echo "NULL" ;; 1) echo "REVIEW_MESSAGE" ;; 2) echo "NOT_REVIEW_MESSAGE_SAMPLED" ;;
    3) echo "NOT_REVIEW_MESSAGE" ;; 4) echo "LLM_REVIEW_MESSAGE" ;; 5) echo "LLM_AND_HUMAN_REVIEW_MESSAGE" ;;
    *) echo "$1" ;;
  esac
}

decode_email_segment() {
  case "$1" in
    0) echo "NONE" ;; 1) echo "WARNING" ;; 2) echo "BODY" ;; 3) echo "CONVERSATION" ;;
    *) echo "$1" ;;
  esac
}

# Show help
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -eq 0 ]; then
  cat <<'EOF'
msg - Quick analysis of adhoc-scorer responses

USAGE:
  msg <message_id> [command]

ARGUMENTS:
  message_id  Message ID to analyze (required)
  command     Optional command (default: auto - shows overview/links/decision)

COMMANDS (80/20 essentials):
  auto, a        Auto analysis (overview + links + decision) [DEFAULT]
  overview, o    Message overview with key stats
  links, l       All links with suspicious scores
  decision, d    Detection decision and flagged rules
  search, s      Search attributes by keyword (requires 3rd arg)
  entities, e    All entities with scores

DETECTION COMMANDS:
  rules, ru      Detection rules + models breakdown
  heur, h        Triggered heuristics across all entities
  phrases, ph    Phrase matches found in message (use --filter for matches only)
  entity, ent    Deep dive into specific entity (requires uuid)
  domains, dom   All domain entities with risk scores

DETECTION GAP ANALYSIS (NEW):
  mismatch, mm   Detect judgement-review mismatches (CRITICAL for CFN analysis)
  confidence, cf Confidence score breakdown + threshold analysis
  batch-summary  Single-line CSV summary for batch processing

GOD MODE:
  god, g         Run ALL commands - complete detection story

EXAMPLES:
  # Quick auto analysis
  msg -4865185475740621290

  # Specific command
  msg -4865185475740621290 links
  msg -4865185475740621290 overview

  # Search for features
  msg -4865185475740621290 search FILE
  msg -4865185475740621290 search ANCHOR_TEXT

  # Detection debugging
  msg -4865185475740621290 rules
  msg -4865185475740621290 heur
  msg -4865185475740621290 phrases --filter  # Only show matches > 0

  # Detection gap analysis (P0 commands)
  msg -4865185475740621290 mismatch      # Check for judgement-review gaps
  msg -4865185475740621290 confidence    # Confidence score analysis
  msg -4865185475740621290 batch-summary # CSV output for batch mode

  # God mode - everything at once
  msg -4865185475740621290 god

OUTPUT:
  JSON response saved to: /tmp/scorer_response.json

ENTITY TYPES:
  1 = FROM_EMAIL
  3 = BODY_LINK
  5 = DOMAIN
  6 = REPLY_TO_EMAIL

JUDGEMENT VALUES:
  0 = SURELY_SAFE
  1 = ATTACK
  2 = SPAM
  3 = GRAYMAIL

EOF
  exit 0
fi

# Parse arguments
MID="${1:?Usage: msg <message_id> [command]}"
COMMAND="${2:-auto}"
SEARCH_KEYWORD="${3:-}"

# Config
SCORER_URL="https://pov.rt-scorer.abnormal.dev/debug/simulate"

# Build URL
URL="${SCORER_URL}?mid=${MID}&scoring_instruction=2&force_phrase_extraction=true&force_persist=true&enable_verbose_logging=true"

# Fetch if file doesn't exist or is older than 5 minutes
if [ ! -f "$OUTPUT_FILE" ] || [ "$(find "$OUTPUT_FILE" -mmin +5 2>/dev/null)" ]; then
  echo "🔍 Fetching scorer response for mid=${MID}..."
  if ! curl -sf "$URL" -o "$OUTPUT_FILE"; then
    echo "❌ Failed to fetch scorer response"
    exit 1
  fi
  echo "✅ Saved to ${OUTPUT_FILE}"
  echo ""
fi

# Execute command
case "$COMMAND" in
  auto|a)
    # Auto analysis: overview + links + decision
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 OVERVIEW"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    jq "$BASE_PATH | {
      from: .fromEmail.address,
      subject: .message.subject,
      judgement: \"$(decode_judgement $JUDGEMENT) ($JUDGEMENT)\",
      numLinks: (.textSignals.links | length),
      numAttachments: (.message.attachments | length),
      numEntities: (.entities.entityUuidToEntity | length),
      maxRiskScores: .entities.maxRiskScores
    }" "$OUTPUT_FILE"
    echo ""

    echo "🚨 DETECTION DECISION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    REVIEW_DEC=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.reviewDecision" "$OUTPUT_FILE")
    jq "$BASE_PATH | {
      judgement: \"$(decode_judgement $JUDGEMENT) ($JUDGEMENT)\",
      reviewDecision: \"$(decode_review_decision $REVIEW_DEC) ($REVIEW_DEC)\",
      flaggedRules: [.messageDecisions.detectionControlSystemResult.ruleReasons[]]
    }" "$OUTPUT_FILE"
    echo ""

    echo "🔗 LINKS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    jq -r "$BASE_PATH.textSignals.links[] | @json" "$OUTPUT_FILE" | while read -r link; do
      URL=$(echo "$link" | jq -r '.absoluteUrl')
      ANCHOR=$(echo "$link" | jq -r '.anchorText // "null"')
      SCORE=$(echo "$link" | jq -r '.suspiciousUrlModelScore')
      LOC=$(echo "$link" | jq -r '.linkLocation // 2')
      LOC_NAME=$(decode_email_segment $LOC)
      echo "{\"url\": \"$URL\", \"anchor\": \"$ANCHOR\", \"suspiciousScore\": $SCORE, \"location\": \"$LOC_NAME ($LOC)\"}"
    done | jq -s '.'
    echo ""

    TRIGGERED=$(jq "$BASE_PATH.secondaryAttributes |
      to_entries |
      map(select(.value == true or ((.value | type) == \"number\" and .value > 0))) |
      length" "$OUTPUT_FILE")
    echo "📈 Triggered: $TRIGGERED / 1544 secondary attributes"
    echo ""
    echo "💡 Try: msg $MID search <KEYWORD>"
    echo "    Or: msg $MID entities"
    ;;

  overview|o)
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    jq "$BASE_PATH | {
      messageId: .nativeMessageId,
      from: .fromEmail.address,
      subject: .message.subject,
      judgement: \"$(decode_judgement $JUDGEMENT) ($JUDGEMENT)\",
      numLinks: (.textSignals.links | length),
      numAttachments: (.message.attachments | length),
      numEntities: (.entities.entityUuidToEntity | length),
      maxRiskScores: .entities.maxRiskScores
    }" "$OUTPUT_FILE"
    ;;

  links|l)
    jq -r "$BASE_PATH.textSignals.links[] | @json" "$OUTPUT_FILE" | while read -r link; do
      IDX=$(echo "$link" | jq -r '.linkIndex')
      URL=$(echo "$link" | jq -r '.absoluteUrl')
      ANCHOR=$(echo "$link" | jq -r '.anchorText // "null"')
      LOC=$(echo "$link" | jq -r '.linkLocation // 2')
      SCORE=$(echo "$link" | jq -r '.suspiciousUrlModelScore')
      LOC_NAME=$(decode_email_segment $LOC)
      echo "{\"index\": $IDX, \"url\": \"$URL\", \"anchor\": \"$ANCHOR\", \"location\": \"$LOC_NAME ($LOC)\", \"suspiciousScore\": $SCORE}"
    done | jq -s '.'
    ;;

  decision|d)
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    REVIEW_DEC=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.reviewDecision" "$OUTPUT_FILE")
    jq "$BASE_PATH | {
      judgement: \"$(decode_judgement $JUDGEMENT) ($JUDGEMENT)\",
      reviewDecision: \"$(decode_review_decision $REVIEW_DEC) ($REVIEW_DEC)\",
      flaggedRules: [.messageDecisions.detectionControlSystemResult.ruleReasons[]],
      confidenceScore: .messageDecisions.detectionControlSystemResult.confidenceScore
    }" "$OUTPUT_FILE"
    ;;

  search|s)
    if [ -z "$SEARCH_KEYWORD" ]; then
      echo "❌ Usage: msg <mid> search <keyword>"
      exit 1
    fi
    jq --arg kw "$SEARCH_KEYWORD" "$BASE_PATH.secondaryAttributes |
      to_entries |
      map(select(.key | test(\$kw;\"i\"))) |
      from_entries" "$OUTPUT_FILE"
    ;;

  entities|e)
    jq -r "$BASE_PATH.entities.entityUuidToEntity | to_entries[] | @json" "$OUTPUT_FILE" | while read -r entity; do
      UUID=$(echo "$entity" | jq -r '.key')
      TYPE=$(echo "$entity" | jq -r '.value.type')
      TYPE_NAME=$(decode_entity_type $TYPE)
      RISK=$(echo "$entity" | jq -r '.value.scores.riskScore // 0')
      ABN=$(echo "$entity" | jq -r '.value.scores.abnormalityScore // 0')
      NUM_H=$(echo "$entity" | jq -r '.value.heuristicEvaluationResults | length')
      NUM_A=$(echo "$entity" | jq -r '.value.entityAttributes | length')
      echo "{\"uuid\": \"$UUID\", \"type\": \"$TYPE_NAME ($TYPE)\", \"riskScore\": $RISK, \"abnormalityScore\": $ABN, \"numHeuristics\": $NUM_H, \"numAttributes\": $NUM_A}"
    done | jq -s '.'
    ;;

  rules|ru)
    # Detection rules + models breakdown
    jq "$BASE_PATH.messageDecisions.detectionControlSystemResult | {
      reviewDecision: .reviewDecision,
      reviewDecisionRule: .reviewDecisionRule,
      flaggedRules: .ruleReasons,
      applicableRules: [.reviewDecisionRuleResults | to_entries[] | select(.value.ruleIsApplicable == true) | {
        rule: .key,
        matched: (.value.matchReasons != null),
        models: [.value.matchReasons? // {} | to_entries[] | .value.flaggingDetectors.flaggingModels[]? | .modelId],
        rules: [.value.matchReasons? // {} | to_entries[] | .value.flaggingDetectors.flaggingRules[]? | .ruleName]
      }]
    }" "$OUTPUT_FILE"
    ;;

  heur|h)
    # Triggered heuristics across all entities
    jq -r "[$BASE_PATH.entities.entityUuidToEntity | to_entries[] |
      {uuid: .key, type: .value.type, triggered: [.value.heuristicEvaluationResults | to_entries[] | select(.value == true) | .key]} |
      select(.triggered | length > 0)] | .[] | @json" "$OUTPUT_FILE" | while read -r entity; do
      UUID=$(echo "$entity" | jq -r '.uuid')
      TYPE=$(echo "$entity" | jq -r '.type')
      TYPE_NAME=$(decode_entity_type $TYPE)
      TRIGGERED=$(echo "$entity" | jq -c '.triggered')
      echo "{\"uuid\": \"$UUID\", \"type\": \"$TYPE_NAME ($TYPE)\", \"triggered\": $TRIGGERED}"
    done | jq -s '.'
    ;;

  phrases|ph)
    # Phrase matches found in message (supports --filter flag)
    FILTER_FLAG="${3:-}"

    if [[ "$FILTER_FLAG" == "--filter" || "$FILTER_FLAG" == "-f" ]]; then
      # Filter mode: only show matches > 0
      jq -r "$BASE_PATH.textSignals.phraseMatchesList[] | select((.matchInfos | length) > 0) | @json" "$OUTPUT_FILE" | while read -r phrase; do
        PT=$(echo "$phrase" | jq -r '.phraseDef.phraseType')
        PT_NAME=$(decode_phrase_type $PT)
        NUM=$(echo "$phrase" | jq -r '.matchInfos | length')
        MATCHES=$(echo "$phrase" | jq -c '[.matchInfos[] | {text: .matchedStr, location: .location}]')
        echo "{\"phraseType\": \"$PT_NAME ($PT)\", \"numMatches\": $NUM, \"matches\": $MATCHES}"
      done | jq -s '.'
    else
      # Default mode: show all phrases (including zeros)
      jq -r "$BASE_PATH.textSignals.phraseMatchesList[] | @json" "$OUTPUT_FILE" | while read -r phrase; do
        PT=$(echo "$phrase" | jq -r '.phraseDef.phraseType')
        PT_NAME=$(decode_phrase_type $PT)
        NUM=$(echo "$phrase" | jq -r '.matchInfos | length')
        MATCHES=$(echo "$phrase" | jq -c '[.matchInfos[] | {text: .matchedStr, location: .location}]')
        echo "{\"phraseType\": \"$PT_NAME ($PT)\", \"numMatches\": $NUM, \"matches\": $MATCHES}"
      done | jq -s '.'
    fi
    ;;

  entity|ent)
    # Deep dive into specific entity
    UUID="${3:?Usage: msg <mid> entity <uuid>}"
    jq --arg uuid "$UUID" "$BASE_PATH.entities.entityUuidToEntity[\$uuid] // empty" "$OUTPUT_FILE"
    ;;

  domains|dom)
    # All domain entities with risk scores
    jq "[
      $BASE_PATH.entities.entityUuidToEntity | to_entries[] |
      select(.value.type == 5) |
      {
        uuid: .key,
        url: .value.entityAttributes.URL_STRING,
        registeredDomain: .value.entityAttributes.URL_REGISTERED_DOMAIN,
        riskScore: .value.scores.riskScore,
        abnormalityScore: .value.scores.abnormalityScore,
        numTriggeredHeuristics: [.value.heuristicEvaluationResults | to_entries[] | select(.value == true)] | length
      }
    ]" "$OUTPUT_FILE"
    ;;

  god|g)
    # God mode - run all commands
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔱 GOD MODE - COMPLETE DETECTION STORY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 1. OVERVIEW"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    jq "$BASE_PATH | {
      messageId: .nativeMessageId,
      from: .fromEmail.address,
      subject: .message.subject,
      judgement: \"$(decode_judgement $JUDGEMENT) ($JUDGEMENT)\",
      numLinks: (.textSignals.links | length),
      numAttachments: (.message.attachments | length),
      numEntities: (.entities.entityUuidToEntity | length),
      maxRiskScores: .entities.maxRiskScores
    }" "$OUTPUT_FILE"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚨 2. DETECTION DECISION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    REVIEW_DEC=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.reviewDecision" "$OUTPUT_FILE")
    jq "$BASE_PATH | {
      judgement: \"$(decode_judgement $JUDGEMENT) ($JUDGEMENT)\",
      reviewDecision: \"$(decode_review_decision $REVIEW_DEC) ($REVIEW_DEC)\",
      flaggedRules: [.messageDecisions.detectionControlSystemResult.ruleReasons[]],
      confidenceScore: .messageDecisions.detectionControlSystemResult.confidenceScore
    }" "$OUTPUT_FILE"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  3. DETECTION RULES + MODELS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    jq "$BASE_PATH.messageDecisions.detectionControlSystemResult | {
      reviewDecision: .reviewDecision,
      reviewDecisionRule: .reviewDecisionRule,
      flaggedRules: .ruleReasons,
      applicableRules: [.reviewDecisionRuleResults | to_entries[] | select(.value.ruleIsApplicable == true) | {
        rule: .key,
        matched: (.value.matchReasons != null),
        models: [.value.matchReasons? // {} | to_entries[] | .value.flaggingDetectors.flaggingModels[]? | .modelId],
        rules: [.value.matchReasons? // {} | to_entries[] | .value.flaggingDetectors.flaggingRules[]? | .ruleName]
      }]
    }" "$OUTPUT_FILE"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎯 4. TRIGGERED HEURISTICS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    jq -r "[$BASE_PATH.entities.entityUuidToEntity | to_entries[] |
      {uuid: .key, type: .value.type, triggered: [.value.heuristicEvaluationResults | to_entries[] | select(.value == true) | .key]} |
      select(.triggered | length > 0)] | .[] | @json" "$OUTPUT_FILE" | while read -r entity; do
      UUID=$(echo "$entity" | jq -r '.uuid')
      TYPE=$(echo "$entity" | jq -r '.type')
      TYPE_NAME=$(decode_entity_type $TYPE)
      TRIGGERED=$(echo "$entity" | jq -c '.triggered')
      echo "{\"uuid\": \"$UUID\", \"type\": \"$TYPE_NAME ($TYPE)\", \"triggered\": $TRIGGERED}"
    done | jq -s '.'
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧬 5. ALL ENTITIES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    jq -r "$BASE_PATH.entities.entityUuidToEntity | to_entries[] | @json" "$OUTPUT_FILE" | while read -r entity; do
      UUID=$(echo "$entity" | jq -r '.key')
      TYPE=$(echo "$entity" | jq -r '.value.type')
      TYPE_NAME=$(decode_entity_type $TYPE)
      RISK=$(echo "$entity" | jq -r '.value.scores.riskScore // 0')
      ABN=$(echo "$entity" | jq -r '.value.scores.abnormalityScore // 0')
      NUM_H=$(echo "$entity" | jq -r '.value.heuristicEvaluationResults | length')
      NUM_A=$(echo "$entity" | jq -r '.value.entityAttributes | length')
      echo "{\"uuid\": \"$UUID\", \"type\": \"$TYPE_NAME ($TYPE)\", \"riskScore\": $RISK, \"abnormalityScore\": $ABN, \"numHeuristics\": $NUM_H, \"numAttributes\": $NUM_A}"
    done | jq -s '.'
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 6. DOMAIN ENTITIES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    jq "[
      $BASE_PATH.entities.entityUuidToEntity | to_entries[] |
      select(.value.type == 5) |
      {
        uuid: .key,
        url: .value.entityAttributes.URL_STRING,
        registeredDomain: .value.entityAttributes.URL_REGISTERED_DOMAIN,
        riskScore: .value.scores.riskScore,
        abnormalityScore: .value.scores.abnormalityScore,
        numTriggeredHeuristics: [.value.heuristicEvaluationResults | to_entries[] | select(.value == true)] | length
      }
    ]" "$OUTPUT_FILE"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 7. ALL LINKS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    jq -r "$BASE_PATH.textSignals.links[] | @json" "$OUTPUT_FILE" | while read -r link; do
      IDX=$(echo "$link" | jq -r '.linkIndex')
      URL=$(echo "$link" | jq -r '.absoluteUrl')
      ANCHOR=$(echo "$link" | jq -r '.anchorText // "null"')
      LOC=$(echo "$link" | jq -r '.linkLocation // 2')
      SCORE=$(echo "$link" | jq -r '.suspiciousUrlModelScore')
      LOC_NAME=$(decode_email_segment $LOC)
      echo "{\"index\": $IDX, \"url\": \"$URL\", \"anchor\": \"$ANCHOR\", \"location\": \"$LOC_NAME ($LOC)\", \"suspiciousScore\": $SCORE}"
    done | jq -s '.'
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 8. PHRASE MATCHES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    PHRASE_COUNT=$(jq "$BASE_PATH.textSignals.phraseMatchesList | length" "$OUTPUT_FILE")
    echo "Total phrase matches: $PHRASE_COUNT"
    if [ "$PHRASE_COUNT" -gt 10 ]; then
      echo "(Showing first 10 of $PHRASE_COUNT with decoded names)"
      jq -r "[$BASE_PATH.textSignals.phraseMatchesList[] | {phraseType: .phraseDef.phraseType, numMatches: (.matchInfos | length)}] | .[:10] | .[] | @json" "$OUTPUT_FILE" | while read -r phrase; do
        PT=$(echo "$phrase" | jq -r '.phraseType')
        PT_NAME=$(decode_phrase_type $PT)
        NUM=$(echo "$phrase" | jq -r '.numMatches')
        echo "{\"phraseType\": \"$PT_NAME ($PT)\", \"numMatches\": $NUM}"
      done | jq -s '.'
    else
      jq -r "$BASE_PATH.textSignals.phraseMatchesList[] | @json" "$OUTPUT_FILE" | while read -r phrase; do
        PT=$(echo "$phrase" | jq -r '.phraseDef.phraseType')
        PT_NAME=$(decode_phrase_type $PT)
        NUM=$(echo "$phrase" | jq -r '.matchInfos | length')
        echo "{\"phraseType\": \"$PT_NAME ($PT)\", \"numMatches\": $NUM}"
      done | jq -s '.'
    fi
    echo ""

    TRIGGERED=$(jq "$BASE_PATH.secondaryAttributes |
      to_entries |
      map(select(.value == true or ((.value | type) == \"number\" and .value > 0))) |
      length" "$OUTPUT_FILE")
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📈 9. SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Triggered secondary attributes: $TRIGGERED / 1544"
    echo "Phrase matches: $PHRASE_COUNT"
    echo ""
    echo "💡 Next steps:"
    echo "   msg $MID search <KEYWORD>     - Search for specific attribute"
    echo "   msg $MID entity <uuid>        - Deep dive into entity"
    echo "   fx $OUTPUT_FILE               - Interactive JSON explorer"
    ;;

  mismatch|mm)
    # Detect judgement-review mismatches (P0 command)
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    REVIEW_DEC=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.reviewDecision" "$OUTPUT_FILE")
    CONF_SCORE=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.confidenceScore // 0" "$OUTPUT_FILE")

    # Determine gap type
    MISMATCH_DETECTED="false"
    GAP_TYPE="NO_GAP"
    GAP_DESC="Detection appears correct"
    RECOMMENDATION=""

    if [[ "$JUDGEMENT" == "1" && "$REVIEW_DEC" == "3" ]]; then
      MISMATCH_DETECTED="true"
      GAP_TYPE="JUDGEMENT_REVIEW_MISMATCH"
      GAP_DESC="Marked as ATTACK but NOT reviewed - confidence threshold issue"
      RECOMMENDATION="Category 4 gap: Lower review threshold OR increase signal weights"
    elif [[ "$REVIEW_DEC" == "3" ]]; then
      FLAGGED_RULES_COUNT=$(jq "$BASE_PATH.messageDecisions.detectionControlSystemResult.ruleReasons | length" "$OUTPUT_FILE")
      if [[ "$FLAGGED_RULES_COUNT" -gt 0 ]]; then
        MISMATCH_DETECTED="true"
        GAP_TYPE="RULE_MATCH_NO_REVIEW"
        GAP_DESC="Rule matched but NOT reviewed - threshold or rule logic issue"
        RECOMMENDATION="Category 3 or 4 gap: Check rule logic OR adjust threshold"
      fi
    elif [[ "$JUDGEMENT" == "4" || "$JUDGEMENT" == "0" ]]; then
      MISMATCH_DETECTED="true"
      GAP_TYPE="MISCLASSIFIED_AS_SAFE"
      GAP_DESC="Incorrectly judged as GOOD/SAFE - feature or heuristic missing"
      RECOMMENDATION="Category 1 or 2 gap: Add missing features OR heuristics"
    fi

    jq -n \
      --arg detected "$MISMATCH_DETECTED" \
      --arg type "$GAP_TYPE" \
      --arg desc "$GAP_DESC" \
      --arg judg "$(decode_judgement $JUDGEMENT) ($JUDGEMENT)" \
      --arg rev "$(decode_review_decision $REVIEW_DEC) ($REVIEW_DEC)" \
      --argjson conf "$CONF_SCORE" \
      --argjson rules "$(jq "$BASE_PATH.messageDecisions.detectionControlSystemResult.ruleReasons" "$OUTPUT_FILE")" \
      --arg rec "$RECOMMENDATION" \
      '{
        mismatchDetected: ($detected == "true"),
        gapType: $type,
        description: $desc,
        judgement: $judg,
        reviewDecision: $rev,
        confidenceScore: $conf,
        confidenceGap: (if $conf < 3 then "Score (\($conf)) likely below threshold (3+)" else "Score appears adequate" end),
        flaggedRules: $rules,
        recommendation: $rec
      }'
    ;;

  confidence|cf)
    # Confidence score breakdown + threshold analysis (P0 command)
    REVIEW_DEC=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.reviewDecision" "$OUTPUT_FILE")
    jq "$BASE_PATH.messageDecisions.detectionControlSystemResult | {
      confidenceScore: .confidenceScore,
      reviewDecision: \"$(decode_review_decision $REVIEW_DEC) ($REVIEW_DEC)\",
      reviewDecisionRule: .reviewDecisionRule,
      estimatedThreshold: (if .confidenceScore < 3 and ($REVIEW_DEC | tonumber) == 3 then \"3+ (inferred from NOT_REVIEW decision)\" elif .confidenceScore >= 3 and ($REVIEW_DEC | tonumber) == 1 then \"Met (triggered review)\" else \"Unknown\" end),
      gap: (if .confidenceScore < 3 and ($REVIEW_DEC | tonumber) == 3 then (3 - .confidenceScore) else 0 end),
      flaggedRules: .ruleReasons,
      ruleMatchCount: (.ruleReasons | length),
      applicableRules: [.reviewDecisionRuleResults | to_entries[] |
        select(.value.ruleIsApplicable == true) |
        {rule: .key, matched: (.value.matchReasons != null)}
      ]
    }" "$OUTPUT_FILE"
    ;;

  batch-summary|bs)
    # Single-line CSV summary for batch processing (P0 command)
    JUDGEMENT=$(jq -r "$BASE_PATH.judgement" "$OUTPUT_FILE")
    REVIEW_DEC=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.reviewDecision" "$OUTPUT_FILE")
    CONF_SCORE=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.confidenceScore // 0" "$OUTPUT_FILE")
    RULES=$(jq -r "$BASE_PATH.messageDecisions.detectionControlSystemResult.ruleReasons | join(\";\")" "$OUTPUT_FILE")
    NUM_ENT=$(jq "$BASE_PATH.entities.entityUuidToEntity | length" "$OUTPUT_FILE")
    NUM_LINKS=$(jq "$BASE_PATH.textSignals.links | length" "$OUTPUT_FILE")
    NUM_ATT=$(jq "$BASE_PATH.message.attachments | length" "$OUTPUT_FILE")
    MAX_RISK=$(jq -r "[.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | .value.scores.riskScore // 0] | max" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    NUM_HEUR=$(jq "[.extension.rtScorerExtension.processedMessageLogs[0].entities.entityUuidToEntity | to_entries[] | .value.heuristicEvaluationResults | to_entries[] | select(.value == true)] | length" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    NUM_ATTRS=$(jq "[.extension.rtScorerExtension.processedMessageLogs[0].secondaryAttributes | to_entries[] | select(.value == true or ((.value | type) == \"number\" and .value > 0))] | length" "$OUTPUT_FILE" 2>/dev/null || echo "0")

    # Output CSV format (no header, assuming batch mode adds header separately)
    echo "${MID},${JUDGEMENT},${REVIEW_DEC},${CONF_SCORE},\"${RULES}\",${NUM_ENT},${NUM_LINKS},${NUM_ATT},${MAX_RISK},${NUM_HEUR},${NUM_ATTRS}"
    ;;

  raw|r)
    # Raw jq filter
    FILTER="${3:?Usage: msg <mid> raw '<jq_filter>'}"
    jq "$FILTER" "$OUTPUT_FILE"
    ;;

  *)
    echo "❌ Unknown command: $COMMAND"
    echo "Run 'msg --help' to see available commands"
    exit 1
    ;;
esac
