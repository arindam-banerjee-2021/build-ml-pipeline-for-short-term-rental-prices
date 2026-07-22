cd /workspace/build-ml-pipeline-for-short-term-rental-prices

# 1. Check what git thinks is a submodule
echo "=== Submodule status ==="
git submodule status
git ls-files --stage | grep 160000

# 2. Find the submodule path
SUBMODULE_PATH=$(git ls-files --stage | grep 160000 | awk '{print $4}')
echo "Submodule path: $SUBMODULE_PATH"

# 3. Force-remove submodule references
if [ -n "$SUBMODULE_PATH" ]; then
    git rm --cached "$SUBMODULE_PATH" 2>/dev/null
    rm -rf "$SUBMODULE_PATH"
    rm -rf ".git/modules/$SUBMODULE_PATH"
fi

# 4. Remove ALL .gitmodules files (including hidden)
find . -name ".gitmodules" -not -path "./.git/*" -delete
git rm --cached .gitmodules 2>/dev/null

# 5. Clean git config
git config --file .git/config --remove-section "submodule.$SUBMODULE_PATH" 2>/dev/null || true
git config --file .git/config --remove-section "submodule.build-ml-pipeline-for-short-term-rental-prices" 2>/dev/null || true

# 6. Verify clean
echo ""
echo "=== After cleanup ==="
git submodule status
git ls-files --stage | grep 160000 || echo "✅ No more submodule entries"
ls -la .gitmodules 2>/dev/null || echo "✅ No .gitmodules file"

# 7. Commit cleanup
git add -A
git commit -m "Remove broken submodule reference from tree" || echo "nothing to commit"
git push origin main

# 8. Re-tag 1.0.0 on the CLEAN commit
git tag -d 1.0.0 2>/dev/null
git push origin :refs/tags/1.0.0 2>/dev/null
git tag -a 1.0.0 -m "Initial release without geographic boundary filter"
git push origin 1.0.0

echo ""
echo "✅ 1.0.0 re-tagged on clean commit!"
echo ""
echo "👉 NOW: Delete + republish 1.0.0 release in browser"