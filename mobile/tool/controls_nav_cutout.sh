#!/usr/bin/env bash
# ضوابطُ سالبةٌ للشريط العائم وحفرته الدائريّة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وقد وقعت هنا واحدةٌ بعينها**: الاختبارُ القديمُ كان يقيس `GlassNavBar`
# نفسَها ويسأل أتبلغ حافّةَ الشاشة. وهي تبلغها في الحالين — الهامشُ داخلَها —
# فمرّ بعد التحويل إلى العائم وهو يحرس ما لم يعد قائماً. فصار يُقاس الزجاجُ
# المقصوصُ نفسُه.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/nav_raised_test.dart test/shell_test.dart test/provider_shell_nav_test.dart"

K=lib/src/ui/kit.dart

BACKUP=$(mktemp -d)
cp "$K" "$BACKUP/k"
restore() { cp "$BACKUP/k" "$K"; }
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
  if timeout 900 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 900 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== ضوابطُ الحفرة =="

# ── أ) لا حفرةَ أصلاً ──────────────────────────────────────────────────────
#
# **وهو الشكلُ الذي رفضه**: القرصُ يقف على زجاجٍ متّصلٍ لا يجلس في حفرة.
run "(أ) الزجاجُ متّصلٌ بلا حفرة" \
  sub "$K" \
"    final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
    return Path.combine(PathOperation.intersect, rounded, notched);" \
"    return rounded;"

# ── ب) وتقف الحفرةُ في مكانها ولا تتبع المختار ────────────────────────────
#
# قصٌّ مربوطٌ بخانةٍ ثابتةٍ: المختارُ على زجاجٍ متّصلٍ وحفرةٌ فارغةٌ بجانبه.
# ولا يكشفه اختبارٌ يسأل «أثَمّ حفرة؟» — ثَمّ حفرةٌ في الحالين.
run "(ب) الحفرةُ لا تتبع المختار" \
  sub "$K" \
"            final centre = (index + 0.5) * cell;" \
"            final centre = 0.5 * cell;"

# ── ج) وتلتصق حافّةُ الحفرة بالقرص ─────────────────────────────────────────
#
# بلا فرجةٍ لا يُرى ما تحت الشريط حولَه، فيعود ملتصقاً بالزجاج — وهي كلُّ
# الفكرة في الشكل الذي أرسله.
run "(ج) لا فرجةَ بين القرص وحفرته" \
  sub "$K" \
"  static const double notchGap = 7;" \
"  static const double notchGap = 0;"

# ── د) وينزل القرصُ عن حافّة الشريط ────────────────────────────────────────
#
# مركزُه على الحافّة نصفُه فوقها ونصفُه فيها. ولو نزل لَغرق في الحفرة، ولو
# علا لَطار فوقها — وكلاهما يُرى قبل أن يُسمّى.
run "(د) القرصُ ينزل عن الحافّة" \
  sub "$K" \
"  static const double raise = discSize / 2;" \
"  static const double raise = 4;"

echo; echo "== ضوابطُ الهامش =="

# ── هـ) ويعود ملتصقاً بحافّتَي الشاشة ──────────────────────────────────────
#
# **وهذا هو الذي مرّ صامتاً من قبل**: الاختبارُ القديمُ كان يقيس الصندوقَ
# الخارجيَّ فلا يفرّق بين الحالين.
run "(هـ) يعود ملتصقاً بالحافّة" \
  sub "$K" \
"  static const double sideMargin = Space.lg;" \
"  static const double sideMargin = 0;"

# ── ز) وتذهب الفرجةُ السفليّة ──────────────────────────────────────────────
#
# فيقف الشريطُ على حافّة الشاشة ويعود نصفَ عائم.
run "(ز) الفرجةُ السفليّةُ تذهب" \
  sub "$K" \
"  static const double bottomGap = 10;" \
"  static const double bottomGap = 0;"

# ── و) وتنقص المسافةُ تحت المحتوى ─────────────────────────────────────────
#
# الشريطُ يطفو والمحتوى يمرّ تحته؛ ولو نقصت المسافةُ عن قدره وقرصِه وهامشِه
# لَاختفى آخرُ سطرٍ في كلّ قائمة — ولا يراه إلّا من بلغ آخرَ قائمته.
run "(و) المسافةُ تنقص عن الهامش" \
  sub "$K" \
"const double glassNavSpace =
    GlassNavBar.barHeight + GlassNavBar.raise + GlassNavBar.bottomGap + 36;" \
"const double glassNavSpace = GlassNavBar.barHeight;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
