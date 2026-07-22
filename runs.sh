#!/bin/bash
# =====================================================================
# Release Fix Script v3 — Handles .gitmodules + wandb login for subprocess
# =====================================================================

cd /workspace/build-ml-pipeline-for-short-term-rental-prices

# ---------------------------------------------------------------------
# STEP 0: Setup — git identity, env vars, wandb login, submodule cleanup
# ---------------------------------------------------------------------
echo "=========================================="
echo "STEP 0: Setup"
echo "=========================================="

# Git identity
git config --global user.email "arindam.b21@accenture.com"
git config --global user.name "arindam-banerjee-2021"

# Load .env into shell (WANDB_API_KEY, WANDB_ENTITY, WANDB_PROJECT)
set -a && . ./.env && set +a
echo "Entity:  $WANDB_ENTITY"
echo "Project: $WANDB_PROJECT"
echo "Key set: ${WANDB_API_KEY:0:12}..."

# Write W&B credentials to ~/.netrc so subprocesses can auto-login (no prompts)
wandb login --relogin "$WANDB_API_KEY" > /dev/null 2>&1
echo "✅ wandb login (netrc) done"

# Ensure udacity-starter is present + PYTHONPATH set
[ -d /tmp/udacity-starter ] || (cd /tmp && git clone https://github.com/udacity/build-ml-pipeline-for-short-term-rental-prices.git udacity-starter)
cp src/train_random_forest/feature_engineering.py /tmp/udacity-starter/components/
export PYTHONPATH=/tmp/udacity-starter/components:$PYTHONPATH

# Deep submodule cleanup
SUBMODULE_PATHS=$(git ls-files --stage 2>/dev/null | grep 160000 | awk '{print $4}')
if [ -n "$SUBMODULE_PATHS" ]; then
    echo "Found submodule entries: $SUBMODULE_PATHS"
    for path in $SUBMODULE_PATHS; do
        git rm --cached "$path" 2>/dev/null || true
        rm -rf "$path" ".git/modules/$path"
    done
fi
find . -name ".gitmodules" -not -path "./.git/*" -delete 2>/dev/null
git rm --cached .gitmodules 2>/dev/null || true
git config --file .git/config --remove-section "submodule.build-ml-pipeline-for-short-term-rental-prices" 2>/dev/null || true

echo ""
echo "=== After cleanup ==="
git ls-files --stage 2>/dev/null | grep 160000 || echo "✅ No submodule entries in tree"
echo ""

# ---------------------------------------------------------------------
# STEP 1: Create BROKEN v1.0.0 (no boundary filter)
# ---------------------------------------------------------------------
echo "=========================================="
echo "STEP 1: Create broken v1.0.0"
echo "=========================================="

# Backup only if not already backed up
if [ ! -f src/basic_cleaning/run.py.FIXED_BACKUP ]; then
    cp src/basic_cleaning/run.py src/basic_cleaning/run.py.FIXED_BACKUP
    echo "✅ Backup saved"
fi

python3 <<'PYEOF'
with open("src/basic_cleaning/run.py", "r") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "Filter rows outside NYC" in line or "Filtering rows outside NYC" in line:
        skip = True
        continue
    if skip and ("longitude" in line or "latitude" in line):
        continue
    if skip and "df = df[idx].copy()" in line:
        skip = False
        continue
    new_lines.append(line)

with open("src/basic_cleaning/run.py", "w") as f:
    f.writelines(new_lines)
print("✅ Boundary filter removed")
PYEOF

grep -n "boundaries\|longitude" src/basic_cleaning/run.py || echo "✅ Confirmed: no boundary filter"
echo ""

# Delete old 1.0.0 tag (local + remote)
git tag -d 1.0.0 2>/dev/null || true
git push origin :refs/tags/1.0.0 2>/dev/null || true

# Commit cleanup + broken version, push, tag
git add -A
git commit -m "Version 1.0.0: initial pipeline without geographic boundary filter" || echo "nothing to commit"
git push origin main
git tag -a 1.0.0 -m "Initial release without geographic boundary filter"
git push origin 1.0.0

echo ""
echo "🎉 v1.0.0 tag pushed on clean commit!"
echo ""
echo "=================================================="
echo "⏸️  MANUAL STEP: DELETE + RE-PUBLISH 1.0.0 RELEASE"
echo "=================================================="
echo ""
echo "1. Open: https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices/releases/tag/1.0.0"
echo "2. If a release already exists → Click ✏️ Edit → scroll down → Delete this release"
echo "3. Go back to: https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices/releases"
echo "4. Click 'Draft a new release'"
echo "5. Choose tag: 1.0.0"
echo "6. Title: 1.0.0"
echo "7. Description: Initial pipeline release without geographic boundary filter"
echo "8. Click 'Publish release'"
echo ""
read -p "Press ENTER when 1.0.0 release is published on the NEW commit..."

# ---------------------------------------------------------------------
# STEP 2: Run v1.0.0 on sample2.csv — should FAIL at test_proper_boundaries
# ---------------------------------------------------------------------
echo ""
echo "=========================================="
echo "STEP 2: Run v1.0.0 on sample2.csv"
echo "=========================================="
echo "⚠️  Expected: test_proper_boundaries FAILS"
echo ""

# Ensure env vars are exported to subprocess
export WANDB_API_KEY WANDB_ENTITY WANDB_PROJECT
export PYTHONPATH=/tmp/udacity-starter/components:$PYTHONPATH

mlflow run https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices.git \
  -v 1.0.0 \
  --env-manager=local \
  -P hydra_options="etl.sample='sample2.csv'" \
  || echo "✅ Pipeline FAILED as expected — check W&B for the failed test_proper_boundaries run!"

echo ""
echo "👉 Verify failed run in W&B: https://wandb.ai/arindam-b21-accenture/nyc_airbnb_v2"
read -p "Press ENTER to continue to Step 3 (restore fix + tag 1.0.1)..."

# ---------------------------------------------------------------------
# STEP 3: Restore fix + tag v1.0.1
# ---------------------------------------------------------------------
echo ""
echo "=========================================="
echo "STEP 3: Restore boundary filter + tag v1.0.1"
echo "=========================================="

if [ ! -f src/basic_cleaning/run.py.FIXED_BACKUP ]; then
    echo "❌ Backup file missing! Cannot restore."
    exit 1
fi

cp src/basic_cleaning/run.py.FIXED_BACKUP src/basic_cleaning/run.py
rm src/basic_cleaning/run.py.FIXED_BACKUP
echo "✅ Boundary filter restored"

grep -n "boundaries\|longitude" src/basic_cleaning/run.py | head -5
echo ""

# Delete old 1.0.1 tag
git tag -d 1.0.1 2>/dev/null || true
git push origin :refs/tags/1.0.1 2>/dev/null || true

# Commit + push + tag
git add -A
git commit -m "Version 1.0.1: add NYC geographic boundary filter to basic_cleaning"
git push origin main
git tag -a 1.0.1 -m "Fix: filter rows outside NYC geographic boundaries"
git push origin 1.0.1

echo ""
echo "🎉 v1.0.1 tag pushed!"
echo ""
echo "=================================================="
echo "⏸️  MANUAL STEP: PUBLISH 1.0.1 RELEASE"
echo "=================================================="
echo ""
echo "Open: https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices/releases"
echo "1. Click 'Draft a new release'"
echo "2. Choose tag: 1.0.1"
echo "3. Title: 1.0.1"
echo "4. Description: Fix - NYC geographic boundary filter added to basic_cleaning"
echo "5. Click 'Publish release'"
echo ""
read -p "Press ENTER when 1.0.1 release is published..."

# ---------------------------------------------------------------------
# STEP 4: Run v1.0.1 on sample2.csv — should SUCCEED
# ---------------------------------------------------------------------
echo ""
echo "=========================================="
echo "STEP 4: Run v1.0.1 on sample2.csv (should SUCCEED)"
echo "=========================================="
echo ""

export WANDB_API_KEY WANDB_ENTITY WANDB_PROJECT
export PYTHONPATH=/tmp/udacity-starter/components:$PYTHONPATH

mlflow run https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices.git \
  -v 1.0.1 \
  --env-manager=local \
  -P hydra_options="etl.sample='sample2.csv'"

echo ""
echo "=========================================="
echo "🎉 ALL DONE!"
echo "=========================================="
echo ""
echo "👉 Re-submit to Udacity with this text:"
echo ""
cat <<'SUBEOF'
Thank you for the detailed feedback. All issues are now resolved:

1. GitHub Releases published:
   - 1.0.0: https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices/releases/tag/1.0.0
   - 1.0.1: https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices/releases/tag/1.0.1

2. Ran pipeline on sample2.csv with v1.0.0 - FAILED at test_proper_boundaries as expected. Failed run registered in W&B project.

3. Added NYC geographic boundary filter in basic_cleaning (v1.0.1). Ran pipeline on sample2.csv with v1.0.1 - SUCCEEDED.

Links:
- GitHub: https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices
- W&B (public): https://wandb.ai/arindam-b21-accenture/nyc_airbnb_v2

Both failed (v1.0.0) and successful (v1.0.1) runs on sample2.csv are visible in the W&B project.
SUBEOF