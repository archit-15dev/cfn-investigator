# CFN Investigator

> Investigate why attack emails bypass detection and get actionable fixes

## What is This?

CFN Investigator helps you find out why attack emails weren't caught by your security system. It analyzes detection gaps and tells you exactly what to fix.

**Four files:**
- `msg` - Fetches data from the scorer API (16 commands)
- `cfn-investigate-workflow` - AI-powered investigation workflow (use with Claude Code)
- `CLAUDE.md` - Reference documentation for AI agents
- `README.md` - This file

## Installation

```bash
# Clone the repository
git clone https://github.com/archit-15dev/cfn-investigator.git
cd cfn-investigator

# 1. Install msg tool
mkdir -p ~/.local/bin
cp msg ~/.local/bin/msg
chmod +x ~/.local/bin/msg

# Add to PATH if not already there
if ! echo $PATH | grep -q "$HOME/.local/bin"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  export PATH="$HOME/.local/bin:$PATH"
  echo "✅ Added ~/.local/bin to PATH"
fi

# 2. Install Claude Code workflow
# Uses SOURCE env var, falls back to ~/source if not set
SOURCE="${SOURCE:-${HOME}/source}"
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
msg --help > /dev/null 2>&1 && echo "✅ msg tool installed" || echo "❌ msg tool failed"
[ -f "${SOURCE}/.claude/commands/cfn-investigate.md" ] && echo "✅ /cfn-investigate command installed" || echo "❌ Workflow not found"
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
