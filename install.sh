#!/bin/bash
SKILL_NAME="buyingunits"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"
DATA_DIR="$HOME/claude-skills-data/$SKILL_NAME"

# Create skills directory if needed
mkdir -p "$HOME/.claude/skills"

# Create symlink (overwrite if exists)
ln -sf "$(pwd)" "$SKILL_DIR"
echo "Linked $(pwd) → $SKILL_DIR"

# Create data directories
mkdir -p "$DATA_DIR/companies" "$DATA_DIR/runs"
echo "Created data directory: $DATA_DIR"

echo ""
echo "Installed $SKILL_NAME skill. Use /$SKILL_NAME in Claude Code."
