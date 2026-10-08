#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«تفريغ المنتهية» — `test/promotions_clear.test.ts`، ثمّ المقيسُ في
# المتصفّح (`tool/dashboard_shots.mjs`). تكسر كلَّ ضمانةٍ مرّةً بشيفرةٍ صالحة،
# وتتأكّد أنّ ما يقيسها يحمرّ، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")/.."

FILES="src/services/growth.ts src/pages/Promotions.tsx src/data/mock.ts"
BACKUP=$(mktemp -d)
for f in $FILES; do mkdir -p "$BACKUP/$(dirname "$f")"; cp "$f" "$BACKUP/$f"; done
restore() { for f in $FILES; do cp "$BACKUP/$f" "$f"; done; }
trap 'restore; rm -rf "$BACKUP"' EXIT
PASS=0; FAIL=0

sub() {
  local file="$1" old="$2" new="$3" n
  n=$(python3 - "$file" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1; fi
  python3 - "$file" "$old" "$new" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
}

run() {
  local kind="$1" name="$2"; shift 2
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  local out green
  if [ "$kind" = unit ]; then
    out=$(npx vitest run test/promotions_clear.test.ts 2>&1)
    echo "$out" | grep -qE "Tests +[0-9]+ passed \(" && green=1 || green=0
  else
    if ! npm run build >/dev/null 2>&1; then
      echo "✗ $name — البناءُ سقط، فالمقيسُ نسخةٌ قديمة"; FAIL=$((FAIL+1)); restore; return
    fi
    out=$(SHOTS="$BACKUP/shots" node tool/dashboard_shots.mjs 2>&1)
    echo "$out" | grep -q "كلُّ ما قيس أخضر" && green=1 || green=0
  fi
  if [ "$green" = 1 ]; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "^ +×|^❌" | sort -u | head -3 | sed 's/^/   /'
    PASS=$((PASS+1))
  fi
  restore
}

# ── أ) الزرُّ لكلّ دور ──────────────────────────────────────────────────────
#
# **وهذا ما اختاره صاحبُ المنصّة: «المالك وحده».** والقاعدةُ تردّ غيرَه — لكنّ
# زرّاً يُعرض لمن لا يملكه يُضغط فيُخطئ.
run browser "(أ) الزرُّ يظهر لـ«مدير»" sub src/pages/Promotions.tsx \
  "  const isOwner = role === 'owner'" \
  "  const isOwner = role !== null"

run unit "(ب) الجاريةُ تُعدّ وتُحذف" sub src/services/growth.ts \
  "  return status === 'ended' || status === 'cancelled'" \
  "  return status !== 'scheduled'"

run unit "(ج) «انتهت مدّتها» لا تُحذف" sub src/services/growth.ts \
  "  const status = promotionTiming(promotion, now).status" \
  "  const status = promotion.status"

run unit "(د) اسمُ الصورة بترميزه" sub src/services/growth.ts \
  "  const path = decodeURIComponent(url.slice(at + marker.length).split('?')[0])" \
  "  const path = url.slice(at + marker.length).split('?')[0]"

run unit "(هـ) صورٌ من سلّةٍ أخرى تُحذف" sub src/services/growth.ts \
  "  if (at < 0) return null
  const path" \
  "  if (at < 0) return url.split('/').pop() ?? null
  const path"

run browser "(و) التأكيدُ لا يقول ما لا يُمسّ" sub src/pages/Promotions.tsx \
  "          <li>• الجاريةُ والمجدولةُ لا تُمسّ.</li>
" \
  ""

run browser "(ز) الجدولُ لا يُعاد بعد التفريغ" sub src/pages/Promotions.tsx \
  "      setPage(0)
      reload()
      recount()" \
  "      setPage(0)
      recount()"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
