#!/usr/bin/env bash
# ضوابطُ سالبةٌ لطابور اعتماد التنفيذ في اللوحة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **والحمايةُ ليست هنا.** أنّ المزوّد لا يُتمّ حجزَه محرزٌ في القاعدة
# ومقيسٌ في `supabase/tests/controls_completion_review.sh`. وشيفرةُ اللوحة
# تُنادى من متصفّحٍ يملك صاحبُه أدواتِ المطوّر.
#
# **وأخطرُ ما يُكسر هنا (أ): المرشِّحُ يُقارن الحالة.** «قيد مراجعة
# التنفيذ» ليست قيمةً في `status`، فمقارنةٌ بها تردّ قائمةً فارغةً **أبداً**
# — والمسؤولُ يفتح المرشِّحَ فيرى «لا توجد حجوزات» ويظنّ أنّ لا طلبَ ينتظر،
# والطابورُ يمتلئ والمزوّدون ينتظرون مالَهم.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v npx >/dev/null || { echo "لا npx في المسار"; exit 1; }

SUITE=test/completion_review.test.ts
S=src/services/bookings.ts
M=src/data/mock.ts

BACKUP=$(mktemp -d)
cp "$S" "$BACKUP/s"; cp "$M" "$BACKUP/m"
restore() { cp "$BACKUP/s" "$S"; cp "$BACKUP/m" "$M"; }
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
  local name="$1"; shift
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  if timeout 300 npx vitest run "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 npx vitest run "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) المرشِّحُ يُقارن الحالةَ كغيره ───────────────────────────────────────
#
# **وهذا أخطرُها** — وشرحُه في رأس الملفّ.
run "(أ) المرشِّحُ يُقارن status" \
  sub "$S" \
"  if (query.status === 'completion_review') {
    if (!booking.completion_requested_at) return false
  } else if (query.status !== 'all' && booking.status !== query.status) {
    return false
  }" \
"  if (query.status !== 'all' && booking.status !== query.status) return false"

# ── ب) ويبتلع كلَّ مؤكَّدٍ ولو لم يُطلب اعتمادُه ────────────────────────────
#
# فيَعتمد المسؤولُ تنفيذَ حجزٍ لم يقل صاحبُه إنّه نُفِّذ.
run "(ب) يبتلع كلَّ مؤكَّد" \
  sub "$S" \
"    if (!booking.completion_requested_at) return false" \
"    if (booking.status !== 'confirmed') return false"

# ── ج) والردُّ بلا سبب ──────────────────────────────────────────────────────
run "(ج) الردُّ بلا سبب" \
  sub "$S" \
"  const note = reason.trim()
  if (!note) throw new Error('اكتب سببَ الردّ.')" \
"  const note = reason.trim()"

# ── د) والطابورُ يفرغ من البيانات التجريبيّة ────────────────────────────────
#
# **ولا يسقط هذا بقراءة الشيفرة.** المرشِّحُ سليمٌ والطابورُ فارغ، فيفتحه
# المسؤولُ على «لا توجد حجوزات» — وهو أوّلُ ما يراه من الميزة كلِّها.
run "(د) لا طلبَ اعتمادٍ في البيانات التجريبيّة" \
  sub "$M" \
"        status === 'confirmed' && planPast ? isoAt(intBetween(1, 6), 12) : null," \
"        null,"

# ── هـ) ولا حجزَ مؤكَّدٌ مضى موعدُه أصلاً ───────────────────────────────────
#
# كسرٌ أخبث: العمودُ يُملأ صحيحاً ولا صفَّ يستوفي شرطَه.
run "(هـ) لا مؤكَّدَ مضى موعدُه" \
  sub "$M" \
"  if (planPast && i % 7 === 0) return 'confirmed'" \
"  if (false) return 'confirmed'"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
