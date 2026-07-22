cd /workspace/build-ml-pipeline-for-short-term-rental-prices

# Restore the fixed version
cp src/basic_cleaning/run.py.FIXED_BACKUP src/basic_cleaning/run.py
rm src/basic_cleaning/run.py.FIXED_BACKUP
echo "✅ Boundary filter restored"

# Verify fix is back
grep -n "boundaries\|longitude" src/basic_cleaning/run.py | head -5

# Delete old 1.0.1 tag (if any)
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
echo "👉 NEXT: Publish 1.0.1 release in browser"