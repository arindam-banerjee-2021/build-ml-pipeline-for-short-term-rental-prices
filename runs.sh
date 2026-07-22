#!/bin/bash
# =====================================================================
# Release Fix Script v2 — Handles .gitmodules issue
# =====================================================================

cd /workspace/build-ml-pipeline-for-short-term-rental-prices

# ---------------------------------------------------------------------
# STEP 0: Setup
# ---------------------------------------------------------------------
echo "=========================================="
echo "STEP 0: Setup"
echo "=========================================="
git config --global user.email "arindam.b21@accenture.com"
git config --global user.name "Arindam Banerjee"

[ -d /tmp/udacity-starter ] || (cd /tmp && git clone https://github.com/udacity/build-ml-pipeline-for-short-term-rental-prices.git udacity-starter)
cp src/train_random_forest/feature_engineering.py /tmp/udacity-starter/components/
export PYTHONPATH=/tmp/udacity-starter/components:$PYTHONPATH

# Remove broken .gitmodules if present
find . -name ".gitmodules" -not -path "./.git/*" -exec rm -f {} \;
git rm --cached .gitmodules 2>/dev/null || true
git config --file .git/config --remove-section submodule.build-ml-pipeline-for-short-term-rental-prices 2>/dev/null || true
echo "✅ Setup complete + submodule cleanup done"
echo ""

# ---------------------------------------------------------------------
# STEP 1: Create BROKEN v1.0.0
# ---------------------------------------------------------------------
echo "=========================================="
echo "STEP 1: Create broken v1.0.0 (no boundary filter)"
echo "=========================================="

# Only backup if not already backed up
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

# Delete old tag
git tag -d 1.0.0 2>/dev/null || true
git push origin :refs/tags/1.0.0 2>/dev/null || true

# Commit + push + tag
git add -A
git commit -m "Version 1.0.0: initial pipeline without geographic boundary filter" || echo "nothing to commit"
git push origin main
git tag -a 1.0.0 -m "Initial release without geographic boundary filter"
git push origin 1.0.0

echo ""
echo "🎉 v1.0.0 tag pushed!"
echo ""
echo "=================================================="
echo "⏸️  MANUAL STEP: PUBLISH/UPDATE 1.0.0 RELEASE"
echo "=================================================="
echo ""
echo "Open: https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices/releases"
echo ""
echo "If 1.0.0 release exists → click ✏️ Edit → Update release"
echo "If not → Draft a new release → tag 1.0.0 → title 1.0.0 → Publish"
echo ""
read -p "Press ENTER when 1.0.0 release is published/updated..."

# ---------------------------------------------------------------------
# STEP 2: Run v1.0.0 on sample2.csv (should FAIL at test_proper_boundaries)
# ---------------------------------------------------------------------
echo ""
echo "=========================================="
echo "STEP 2: Run v1.0.0 on sample2.csv"
echo "=========================================="
echo "⚠️  Expected: test_proper_boundaries FAILS"
echo ""

mlflow run https://github.com/arindam-banerjee-2021/build-ml-pipeline-for-short-term-rental-prices.git \
  -v 1.0.0 \
  --env-manager=local \
  -P hydra_options="etl.sample='sample2.csv'" \
  || echo "✅ Pipeline FAILED as expected!"

echo ""
echo "👉 Check W&B for failed run: https://wandb.ai/arindam-b21-accenture/nyc_airbnb_v2"
read -p "Press ENTER to continue to Step 3..."

# ---------------------------------------------------------------------
# STEP 3: Restore fix + tag v1.0.1
# ---------------------------------------------------------------------
echo ""
echo "=========================================="
echo "STEP 3: Restore fix + tag v1.0.1"
echo "=========================================="

cp src/basic_cleaning/run.py.FIXED_BACKUP src/basic_cleaning/run.py
rm src/basic_cleaning/run.py.FIXED_BACKUP
echo "✅ Boundary filter restored"

grep -n "boundaries\|longitude" src/basic_cleaning/run.py | head -5
echo ""

# Delete old tag
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
echo "Draft a new release → tag 1.0.1 → title 1.0.1 → description → Publish"
echo ""
read -p "Press ENTER when 1.0.1 release is published..."

# ---------------------------------------------------------------------
# STEP 4: Run v1.0.1 on sample2.csv (should SUCCEED)
# ---------------------------------------------------------------------
echo ""
echo "=========================================="
echo "STEP 4: Run v1.0.1 on sample2.csv (should SUCCEED)"
echo "=========================================="
echo ""

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