#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

MSG="${1:-$(date +%H:%M:%S)}"
REPO="zrwqalmslh2003-sudo/quran-exam-app"
TOKEN=$(grep -o 'ghp_[A-Za-z0-9]*' ~/.git-credentials | head -1)
[ -z "$TOKEN" ] && { echo "❌ لا يوجد توكن"; exit 1; }

echo "📦 رفع..."
git add -A
CHANGED=$(git diff --cached --name-only)
[ -z "$CHANGED" ] && { echo "✅ لا تغييرات"; exit 0; }
git commit -m "$MSG" -q
git push -q
SHA=$(git rev-parse --short HEAD)
echo "✅ تم الرفع [$SHA]: $MSG"
echo "🔄 مراقبة البناء..."

for i in $(seq 1 20); do
  sleep 20
  DATA=$(curl -sf -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/$REPO/actions/runs?per_page=1")
  STATUS=$(echo "$DATA"  | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs'][0]; print(r['status'],r.get('conclusion',''))")
  if echo "$STATUS" | grep -q completed; then
    if echo "$STATUS" | grep -q success; then
      AID=$(echo "$DATA" | python3 -c "import json,sys; print(json.load(sys.stdin)['workflow_runs'][0]['artifacts'][0]['id'])")
      curl -sfL -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$REPO/actions/artifacts/$AID/zip" -o /tmp/apk.zip
      unzip -qo /tmp/apk.zip -d /tmp/apk 2>/dev/null
      cp /tmp/apk/app-release.apk "/storage/emulated/0/Download/quran-exam-app.apk" 2>/dev/null
      echo "🎉 نجاح — APK: ~/Download/quran-exam-app.apk"
    else
      echo "❌ فشل البناء"
    fi
    exit 0
  fi
  echo "   ⏳ $(date +%H:%M:%S)..."
done
echo "⏰ انتهت المهلة — تحقق يدوياً: https://github.com/$REPO/actions"