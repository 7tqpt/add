#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«حالُ الحملة من تاريخها» — `test/promotion_timing.test.ts`، ثمّ
# المقيسُ في المتصفّح (`tool/dashboard_shots.mjs`). تكسر كلَّ ضمانةٍ مرّةً بشيفرةٍ
# صالحة، وتتأكّد أنّ ما يقيسها يحمرّ، وتطبع ما سقط.
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
    out=$(npx vitest run test/promotion_timing.test.ts 2>&1)
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

# ── أ) يعود العمودُ هو الحَكَم: «جارية» لِما انقضت ─────────────────────────
#
# **وهذا ما رآه صاحبُ المنصّة بعينه.** لافتةٌ غابت عن التطبيق واللوحةُ تقول «جارية».
run unit "(أ) المنقضيةُ «جارية»" sub src/services/growth.ts \
  "  if (live && left <= 0) {" \
  "  if (live && left <= 0 && promotion.status !== 'active') {"

run unit "(ب) لا تنبيهَ قبل الانتهاء" sub src/services/growth.ts \
  "export const ENDING_SOON_DAYS = 3" "export const ENDING_SOON_DAYS = 0"

run unit "(ج) المدّةُ منذ الانتهاء بالسقف لا بالأرض" sub src/services/growth.ts \
  "  if (ms < DAY_MS) return \`قبل \${formatCount(Math.floor(ms / HOUR_MS), HOUR_FORMS)}\`" \
  "  if (ms < DAY_MS) return \`قبل \${formatCount(Math.ceil(ms / HOUR_MS), HOUR_FORMS)}\`"

run unit "(د) وضعُ العرض بلا حملةٍ منقضية" sub src/data/mock.ts \
  "    ends_at: i === 1 ? isoAt(1, 0) : i === 2 ? isoAt(-2, 0) : isoAt(-15, 9)," \
  "    ends_at: i === 2 ? isoAt(-2, 0) : isoAt(-15, 9),"

# والصفحةُ: تسأل الدالّةَ ثمّ تعرض العمودَ — فالشارةُ تكذب والدالّةُ صادقة.
run browser "(هـ) الشارةُ من العمود لا من التاريخ" sub src/pages/Promotions.tsx \
  "<Badge tone={STATUS_TONE[timing.status]}>{timing.label}</Badge>" \
  "<Badge tone={STATUS_TONE[promotion.status]}>{PROMOTION_STATUS_LABEL[promotion.status]}</Badge>"

run browser "(و) السطرُ الأحمرُ لا يُكتب" sub src/pages/Promotions.tsx \
  "                            {timing.note.text}" \
  "                            {timing.note.tone === 'warning' ? timing.note.text : ''}"

run browser "(ز) «إلغاء» لِما انتهت مدّتُه" sub src/pages/Promotions.tsx \
  "{timing.status === 'scheduled' || timing.status === 'active' ? (" \
  "{promotion.status === 'scheduled' || promotion.status === 'active' ? ("

run browser "(ح) التنبيهُ أصفرُ على أبيض" sub src/pages/Promotions.tsx \
  "'font-semibold text-[color-mix(in_oklab,var(--warning)_55%,var(--text-primary))]'," \
  "'font-semibold text-warning',"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
