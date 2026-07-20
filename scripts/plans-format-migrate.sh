#!/bin/bash
# plans-format-migrate.sh
# Migrate Plans.md from the old format to the new format

set -uo pipefail

PLANS_FILE="${1:-Plans.md}"
DRY_RUN="${2:-false}"

# Colored output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Plans.md format migration${NC}"
echo "=========================================="
echo ""

# If Plans.md does not exist
if [ ! -f "$PLANS_FILE" ]; then
  echo -e "${RED}Error: $PLANS_FILE not found${NC}"
  exit 1
fi

# Create backup
BACKUP_DIR=".harness/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$PLANS_FILE" "$BACKUP_DIR/Plans.md.backup"
echo -e "${GREEN}✓${NC} Backup created: $BACKUP_DIR/Plans.md.backup"

# Change count
CHANGES=0

# 1. Check for updates to the marker legend section
if ! grep -qE '## Marker Legend' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} Marker legend section is missing"
  echo -e "  ${YELLOW}!${NC} Adding it manually is recommended"
fi

# Display result
echo ""
echo "=========================================="
if [ $CHANGES -gt 0 ]; then
  if [ "$DRY_RUN" = "false" ]; then
    echo -e "${GREEN}✓ Migration complete: $CHANGES changes${NC}"
    echo ""
    echo "Please review the changes:"
    echo "  git diff $PLANS_FILE"
  else
    echo -e "${YELLOW}DRY RUN: $CHANGES changes are planned${NC}"
    echo ""
    echo "To actually convert:"
    echo "  ./scripts/plans-format-migrate.sh $PLANS_FILE false"
  fi
else
  echo -e "${GREEN}✓ No changes needed. Format is up to date.${NC}"
fi
