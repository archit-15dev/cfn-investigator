# CFN Investigator

> Investigate why attack emails bypass detection and get actionable fixes

## What is This?

CFN Investigator helps you find out why attack emails weren't caught by your security system. It analyzes detection gaps and tells you exactly what to fix.

**Four files:**
- `msg` - Fetches data from the scorer API (16 commands)
- `cfn-investigate-workflow` - AI-powered investigation workflow (use with Claude Code)
- `CLAUDE.md` - Reference documentation for AI agents
- `README.md` - This file

## Documentation

**📖 [Technical Documentation](TECHNICAL_DOCUMENTATION.md)** - Complete guide (30,000 words)
- Quick start, core concepts, essential commands
- Phase-by-phase workflow walkthrough
- Troubleshooting and performance tips

**✍️ [Blog Post](BLOG_POST.md)** - Architecture deep dive (8,000 words)
- How we built reliable AI automation
- Deterministic tools + smart workflows pattern
- Real metrics: 67x speedup, 99% success rate

## Examples

Real-world CFN investigations demonstrating the tool's capabilities:

**🔍 [Example 1: Financial Fraud/BEC](examples/4283786237931339625/)**
- **Attack Vector**: Business email compromise with financial urgency
- **Gap Category**: Category 4 - Threshold Too Strict
- **Key Findings**: Young domain (201 days), 92.6% junk rate, 21 heuristics triggered
- View: [Investigation Report](examples/4283786237931339625/cfn_investigation_report.md)

**🔍 [Example 2: Crypto Phishing](examples/1342608625997540702/)**
- **Attack Vector**: Brand impersonation (crypto.com) with reply-to mismatch
- **Gap Category**: Category 4 - Threshold Too Strict
- **Key Findings**: Young reply-to domain (139 days, 22% junk rate), 14 critical signals, recurring pattern (CFN-317391)
- View: [Investigation Report](examples/1342608625997540702/cfn_investigation_report.md)

**🔍 [Example 3: Credential Phishing](examples/6085996778321132573/)**
- **Attack Vector**: Document sharing lure with multi-redirect chain
- **Gap Category**: Category 3+4 Hybrid - Rule Gap + Threshold
- **Key Findings**: Never-seen sender from domain with 15,385 sure attacks, 19 heuristics triggered
- View: [Investigation Report](examples/6085996778321132573/cfn_investigation_report.md)

Each example includes complete investigation report with root cause analysis, evidence, recommended fixes, test plans, and implementation timelines.

## Installation

```bash
# Clone the repository
git clone https://github.com/archit-15dev/cfn-investigator.git
cd cfn-investigator

# 0. Check dependencies
echo "Checking dependencies..."
command -v jq >/dev/null 2>&1 || {
  echo "❌ jq required but not installed"
  echo "   Install: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo "❌ curl required but not installed"
  exit 1
}
echo "✅ Dependencies OK (jq, curl)"
echo ""

# 1. Install msg tool
mkdir -p ~/.local/bin
cp msg ~/.local/bin/msg
chmod +x ~/.local/bin/msg

# Add to PATH if not already there
if ! echo $PATH | grep -q "$HOME/.local/bin"; then
  # Detect shell config file
  if [ -n "$ZSH_VERSION" ]; then
    RC_FILE="$HOME/.zshrc"
  elif [ -n "$BASH_VERSION" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      RC_FILE="$HOME/.bash_profile"
    else
      RC_FILE="$HOME/.bashrc"
    fi
  else
    RC_FILE="$HOME/.profile"
  fi

  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
  export PATH="$HOME/.local/bin:$PATH"
  echo "✅ Added ~/.local/bin to PATH (updated $RC_FILE)"
  echo "   ⚠️  Restart terminal or run: source $RC_FILE"
fi

# 2. Install Claude Code workflow
# Uses SOURCE env var (should already be set in your org)
SOURCE="${SOURCE:-${HOME}/source}"
echo "Using SOURCE directory: ${SOURCE}"
mkdir -p "${SOURCE}/.claude/commands"
cp cfn-investigate-workflow "${SOURCE}/.claude/commands/cfn-investigate.md"
echo "✅ Installed /cfn-investigate command in ${SOURCE}/.claude/commands"

# 3. Install CLAUDE.md (with backup protection)
if [ -f ~/.claude/CLAUDE.md ]; then
  if grep -q "### msg (Message Scorer Analysis)" ~/.claude/CLAUDE.md; then
    echo "⚠️  CFN Investigator docs already installed in CLAUDE.md"
  else
    cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup
    echo "" >> ~/.claude/CLAUDE.md
    echo "---" >> ~/.claude/CLAUDE.md
    echo "" >> ~/.claude/CLAUDE.md
    cat CLAUDE.md >> ~/.claude/CLAUDE.md
    echo "✅ Appended CFN docs to CLAUDE.md (backup: CLAUDE.md.backup)"
  fi
else
  cp CLAUDE.md ~/.claude/CLAUDE.md
  echo "✅ Created CLAUDE.md"
fi

# 4. Verify installation
echo ""
echo "Verifying installation..."
msg --help > /dev/null 2>&1 && echo "✅ msg tool" || echo "❌ msg tool (restart terminal)"
[ -f "${SOURCE}/.claude/commands/cfn-investigate.md" ] && echo "✅ /cfn-investigate workflow" || echo "❌ Workflow missing"
[ -f ~/.claude/CLAUDE.md ] && echo "✅ CLAUDE.md" || echo "❌ CLAUDE.md missing"
echo ""
echo "🎉 Installation complete!"
echo "   Try: msg --help"
echo "   Or: /cfn-investigate <message-id> (in Claude Code)"
```

## Quick Start

### Analyze a single message

```bash
# Quick triage
msg -4865185475740621290 auto

# Full investigation with Claude Code
/cfn-investigate -4865185475740621290
```

### Analyze many messages (batch mode)

```bash
# Create a file with message IDs (one per line)
cat > mids.txt <<EOF
-4865185475740621290
-715876989141528867
EOF

# Run batch investigation
/cfn-investigate mids.txt
```

## How It Works

### Gap Categories

The tool identifies 4 types of detection gaps:

| Category | What's Wrong | How to Fix | Impact |
|----------|-------------|------------|---------|
| **1: Missing Feature** | We don't extract the attack indicator | Add feature extraction | +10-30% catch rate |
| **2: Missing Heuristic** | We extract it but don't evaluate it | Add heuristic | +15-40% catch rate |
| **3: Rule Gap** | We evaluate it but rules don't use it | Update rule | +20-50% catch rate |
| **4: Threshold Too Strict** | Rule sees it but confidence too low | Tune threshold | +5-15% catch rate |

### msg Commands

**Basic commands:**
```bash
msg <mid> auto       # Quick overview
msg <mid> mismatch   # Detect gaps
msg <mid> entities   # Show all entities
msg <mid> links      # Show all links
```

**Search commands:**
```bash
msg <mid> search KEYWORD    # Search for features
msg <mid> domains           # Domain analysis
```

**Advanced:**
```bash
msg <mid> god        # Show everything (verbose)
msg <mid> heur       # Show triggered heuristics
msg <mid> phrases    # Show phrase matches
```

## Requirements

- Bash 3.2+
- `jq` (install: `brew install jq` or `apt-get install jq`)
- `curl`
- Access to POV rt-scorer API

## Output

### Single message investigation

Creates a report with:
- Root cause (which of the 4 categories)
- Evidence from the data
- Specific fix recommendations
- Test plan

### Batch investigation

Creates:
- Summary of systematic patterns
- Prioritized list of gaps by impact
- Representative examples for each pattern

## Author

Archit Singh
