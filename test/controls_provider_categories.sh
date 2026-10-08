#!/usr/bin/env bash
# ضوابطُ سالبةٌ لموافقة الإدارة على الخدمات (ج) و«تغيير القسم» — `test/provider_categories.test.ts`،
# ثمّ المقيسُ في المتصفّح (`tool/dashboard_shots.mjs`). تكسر كلَّ ضمانةٍ مرّةً
# بشيفرةٍ صالحة، وتتأكّد أنّ ما يقيسها يحمرّ، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")/.."

FILES="src/services/directory.ts src/pages/ProviderDetail.tsx src/pages/Providers.tsx src/components/dashboard/ServiceReview.tsx src/data/mock.ts"
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
    out=$(npx vitest run test/provider_categories.test.ts 2>&1)
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

# ── أ) ما خارج أقسامه لا ينتظر — فلا تعرف الإدارةُ به ─────────────────────────
run unit "(أ) لا شيءَ ينتظر" sub src/services/directory.ts \
  "  return provider && isOutsideCategories(service, provider) ? 'pending' : 'approved'" \
  "  return 'approved'"

run unit "(ب) رفضٌ بلا سبب" sub src/services/directory.ts \
  "  if (!approve && !reason) throw new Error('اكتب سبب الرفض — يصل مقدّمَ الخدمة.')" \
  ""

run unit "(ج) إضافةُ القسم لا تقبل المرفوضة" sub src/services/directory.ts \
  "      if (names.includes(s.category_name) && demoDecisions.get(s.id)?.approval === 'rejected') {" \
  "      if (false) {"

run unit "(د) وضعُ العرض بلا خدمةٍ تنتظر" sub src/data/mock.ts \
  "      ...(i === 0 && t === 1 && categoryId !== photo.id" \
  "      ...(i === -1 && t === 1 && categoryId !== photo.id"

# لا يُحذف سطرُ البطاقة: يبقى مكوّنُها بلا استعمالٍ فيسقط البناءُ لا الفحص.
run browser "(هـ) البطاقةُ تغيب عن «مقدّمو الخدمة»" sub src/pages/Providers.tsx \
  "  if (rows.length === 0) return null" \
  "  if (rows.length >= 0) return null"

run browser "(و) لا زرَّين على الخدمة في صفحته" sub src/pages/ProviderDetail.tsx \
  "                            {reviewOf.has(service.id) ? (
                              <div className=\"flex flex-col items-start gap-1.5\">" \
  "                            {false ? (
                              <div className=\"flex flex-col items-start gap-1.5\">"

run browser "(ز) الرفضُ يُضغط بلا سبب" sub src/components/dashboard/ServiceReview.tsx \
  "      confirmDisabled={!note.trim()}" \
  "      confirmDisabled={false}"

run browser "(ح) سببُ الرفض لا يُكتب تحت الخدمة" sub src/pages/ProviderDetail.tsx \
  "                                مرفوضة — {reviewOf.get(service.id)?.approval_note}" \
  "                                مرفوضة"

run browser "(ط) حفظُ الأقسام لا يعيد المراجعات" sub src/pages/ProviderDetail.tsx \
  "      portfolio.reload()
      serviceReviews.reload()" \
  "      portfolio.reload()"

run browser "(ي) «تغيير القسم» لكلّ دور" sub src/pages/ProviderDetail.tsx \
  "                disabled={busy || !canWrite || !allCategories.data}" \
  "                disabled={busy || !allCategories.data}"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
