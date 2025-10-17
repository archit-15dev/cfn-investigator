# CFN Investigation Report

## Message Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**Message ID**: 4283786237931339625
**Attack Type**: Financial Fraud/BEC (Campaign-based)
**From**: rhodes@pro-machineengineering.com
**Subject**: (null/empty)

## Summary
**Current Detection**: Judgement=BAD (ATTACK) but reviewDecision=NOT_REVIEW (confidence=0)
**Root Cause**: Category 4 - Campaign Rule Scoring Bug (confidence returns 0 instead of 8-10)
**Entities Analyzed**: 6 (2 domains, 2 from_emails, 1 phone, 1 reply-to)
**Heuristics Triggered**: 21 total across entities
**Rules Flagged**: campaign_consistency_surely_attack:::199958

## Key Findings

### Campaign Detection Gap
This message is part of condemned campaign 199958. The campaign rule correctly triggered, but the confidence scoring mechanism returned 0 instead of the expected high value (8-10), preventing review.

### Attack Indicators Present
- **Young domain**: 201 days old (< 1 year threshold)
- **High junk frequency**: 722/780 = 92.6% of messages in junk folder
- **Financial phrases**: statement, payment, check, immediate
- **Urgency language**: "immediate", "immediately"
- **Never-seen attack**: Multiple heuristics for never-seen domains
- **Campaign membership**: Part of condemned attack campaign

### Systemic Issue
This is not an isolated CFN - this is likely affecting 100s-1000s of campaign-based attacks where:
- Judgement = ATTACK (correctly identified)
- Campaign rule triggers (correct)
- Confidence score = 0 (BUG)
- Review bypassed (gap)

## Recommended Fix
See Phase 6 output above for detailed recommendations.

**Priority**: P0 - Blocking entire campaign-based detection mechanism

**Fix Type**: Fix confidence scoring for campaign rules OR create bypass threshold

**Implementation Time**: 1-2 sprints (investigate + fix + test + deploy)

**Expected Impact**:
- Catch Rate: +40-60% on campaign-based attacks
- FP Risk: Very Low (campaigns are post-analysis condemned)
- Scope: All messages in campaign 199958 + similar campaign CFNs

## Next Steps
1. [ ] Create Jira ticket: DT-XXXXX (Campaign Confidence Scoring Bug)
2. [ ] Investigate campaign_consistency_surely_attack rule configuration
3. [ ] Review confidence calculation logic for campaign-based rules
4. [ ] Find other messages in campaign 199958 for testing
5. [ ] Query database for similar CFNs (judgement=ATTACK, confidence=0, campaign rule)
6. [ ] Implement fix (scoring correction OR threshold bypass)
7. [ ] Backtest on historical data
8. [ ] Deploy to production with monitoring
9. [ ] Verify campaign-based detections now trigger review

## Additional Context
**Investigation Date**: $(date)
**Cache Location**: /tmp/scorer_response.json (valid for 5min)
**Rerun Investigation**: `/cfn-investigate 4283786237931339625`
**Deep Dive**: `/cfn-investigate 4283786237931339625 --deep`

## Files to Review
- Detection rule configs for campaign_consistency_surely_attack
- Confidence scoring logic (likely in rt-scorer codebase)
- Review decision threshold configs (rule 72)
- Campaign database schema and campaign 199958 metadata

## Related Campaign Info
- **Campaign ID**: 199958 (from HISTORIAN_FINAL_CONDEMNED_CAMPAIGN_DEFINITION_ID)
- **Campaign Type**: Condemned IOC surely attack
- **Campaign Results**: HISTORIAN_CONDEMNED_CAMPAIGN_RESULTS = {10: 1, 16: 1}
