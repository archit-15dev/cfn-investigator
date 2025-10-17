# CFN Investigation Report

## Message Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**Message ID**: 6085996778321132573
**Attack Type**: Credential Phishing (Document Sharing Lure)
**From**: info@alexanderpoole.com
**Subject**: (null - likely redacted)
**Campaign**: 199958 (Historian Condemned ID: 10, 16)

## Summary
**Current Detection**: Judgement=BAD/ATTACK (1) **BUT** reviewDecision=NOT_REVIEW (3) ❌
**Root Cause**: **Category 3+4 (Hybrid Gap)** - Rules matched but confidence threshold not met
**Entities Analyzed**: 4 (1 FROM_EMAIL, 2 DOMAINs, 1 REPLY_TO_EMAIL)
**Heuristics Triggered**: 19 total across entities
**Rules Matched**: 3 rules (10, 24, 72) but confidence=0

## Key Findings

### Detection Gap Analysis
1. **Strong Heuristics Present** ✅
   - `never_seen_from_email`: Never received from this sender before
   - `from_email_has_human_review_high_attack_ratio`: 1,071 human-reviewed attacks
   - Cross-company attack history: **15,385 sure attacks** from alexanderpoole.com
   - High junk folder rate: 17.5% (3,611/20,549 messages)

2. **Multiple Rules Matched** ✅
   - Rule 10 (PHISHING_IOC): matched=true
   - Rule 24 (auto_generated + rsa-message-group-id-llm): matched=true
   - Rule 72 (condemned_ioc_surely_attack_mgid_customer): matched=true

3. **Confidence Score Gap** ❌
   - Confidence Score: **0** (below threshold of ~3)
   - Only 1 flagged rule despite 3 matches
   - Campaign rule fired but didn't boost confidence sufficiently

### Attack Pattern Details
- **Vector**: Multi-redirect link chain (mjt.lu → urldefense.proofpoint.com → captcha.totallao.com)
- **Anchor Text**: "START SIGNING" (all-caps, suspicious=true)
- **Social Engineering**: Document sharing invitation with sign-in requirement
- **Phrases**: "sign in", "confirm identity", "secure document", urgency indicators
- **URL Suspicious Score**: 0.0628 (moderate)
- **Evasion**: ProofPoint URL defense wrapper, legitimate security warning banners

## Root Cause

### Category 3: Heuristic Exists, Rule Doesn't Use It Properly
The system extracted powerful signals (never-seen sender with massive attack history, high junk rate) and heuristics fired correctly, but the detection rules don't weight these signals heavily enough in the ensemble.

### Category 4: Rule Exists, Threshold Too Strict
Three rules matched (10, 24, 72) indicating the attack pattern is recognized, but the confidence scoring gave 0 points. The threshold of ~3 was not met despite:
- Campaign membership in condemned campaign
- Multiple applicable rules
- Strong sender reputation signals

**Combined Effect**: The message was correctly judged as ATTACK but fell through the cracks because the rule ensemble doesn't properly aggregate campaign + sender reputation + credential phishing signals.

## Recommended Fixes

### 1. Update Rule Ensemble Signal Weights (Primary - Category 3)
**Timeline**: 1-2 sprints + backtesting
**Complexity**: Medium

Increase weights for:
- `never_seen_from_email` + `from_email_has_human_review_high_attack_ratio` combination
- Campaign-condemned messages (auto-boost confidence)
- Suspicious anchor text + credential phrases combination

**Implementation**:
- File: Detection rules configuration (likely `src/py/abnormal/detection/rules/`)
- Add compound signal: never-seen sender from domain with 10k+ cross-company attacks
- Boost confidence by +2-3 points when multiple credential phishing signals present

**Expected Impact**:
- Catch Rate: +30-45% on campaign-based credential phishing
- FP Risk: Low-Medium

### 2. Auto-Review Condemned Campaign Messages (Secondary - Category 4)
**Timeline**: 1 sprint
**Complexity**: Low

Add bypass logic: If message in condemned campaign AND judgement=ATTACK, force review regardless of confidence score.

**Implementation**:
- Check for `HISTORIAN_FINAL_CONDEMNED_CAMPAIGN_DEFINITION_ID` presence
- Set minimum confidence score of 3 for campaign members
- Bypass normal threshold logic

**Expected Impact**:
- Catch Rate: +15-25% on all condemned campaign CFNs
- FP Risk: Low (historian campaigns are high-confidence)

### 3. Create High-Risk Never-Seen Sender Heuristic (Tertiary - Category 3)
**Timeline**: 2-3 sprints
**Complexity**: Medium-High

New compound heuristic:
```
HIGH_RISK_NEVER_SEEN_SENDER = (
    never_seen_from_email AND
    FQDN_CROSS_COMPANY_SYSTEM_SURE_ATTACK_COUNT > 10000 AND
    FQDN_IN_JUNK_FOLDER_FREQUENCY > 0.15
)
```

**Expected Impact**:
- Catch Rate: +10-20% on never-seen attacks from abused domains
- FP Risk: Very Low

## Test Plan

### Positive Cases (should trigger review after fix)
1. **MID 6085996778321132573** - This CFN
2. **Campaign 199958 samples** - Find 3-5 other members
3. **Pattern match** - Never-seen + 10k+ attacks + credential lure

### Negative Cases (should NOT trigger review)
1. **Legitimate DocuSign** - Real signing from docusign.com
2. **Known sender** - Document sharing from seen sender
3. **Internal IT** - Password reset from known domain
4. **Marketing CTA** - All-caps from known brand

### Backtesting
- **Dataset**: 90 days, judgement=ATTACK, reviewDecision=NOT_REVIEW, campaign-flagged
- **Target Metrics**:
  - Catch rate improvement: +30%
  - Precision: >95%
  - Recall on credential phishing: >85%

## Next Steps

1. [ ] **Create Jira Ticket**: DT-XXXXX for rule ensemble update
2. [ ] **Implement Primary Fix**: Update signal weights in rules 10, 24, 72
3. [ ] **Write Unit Tests**: Test confidence scoring with new weights
4. [ ] **Backtest**: Run on 90-day CFN dataset
5. [ ] **A/B Test**: 50/50 split, monitor FP rate for 2 weeks
6. [ ] **Deploy**: Roll out to production
7. [ ] **Monitor**: Track catch rate on credential phishing patterns

## Additional Context

**Investigation Date**: 2025-10-17
**Investigation Time**: ~14 minutes
**Cache Location**: /tmp/scorer_response.json (valid for 5 minutes)
**Rerun Investigation**: `/cfn-investigate 6085996778321132573`
**Deep Dive**: `/cfn-investigate 6085996778321132573 --deep`

**Review Platform**: https://review-platform.internal-tools.usea1.pm.abnml.io/message/6085996778321132573

---

**Generated by**: `/cfn-investigate` autonomous workflow
