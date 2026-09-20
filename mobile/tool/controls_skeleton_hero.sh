#!/usr/bin/env bash
# ضوابطُ سالبةٌ لهياكل التحميل ولغلافٍ يطير إلى صفحته.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُحرس هنا وسمٌ مكرَّر.** وسمانِ متطابقان في شاشةٍ واحدة يرميان
# استثناءً **وقت الانتقال وحدَه** — فالشاشةُ تُفتح سليمةً وتنفجر تحت إصبعه.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/skeleton_hero_test.dart"

K=lib/src/ui/kit.dart
C=lib/src/ui/service_card.dart
M=lib/src/screens/my_bookings.dart
F=lib/src/screens/favourites.dart
V=lib/src/screens/provider_public.dart

FILES=("$K" "$C" "$M" "$F" "$V")
BACKUP=$(mktemp -d)
for i in "${!FILES[@]}"; do cp "${FILES[$i]}" "$BACKUP/$i"; done
restore() { for i in "${!FILES[@]}"; do cp "$BACKUP/$i" "${FILES[$i]}"; done; }
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
  if timeout 600 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الهيكل =="

# ── أ) تعود الدوّارةُ مكانَ الهيكل ────────────────────────────────────────
run "(أ) دوّارةٌ بدل الهيكل" \
  sub "$M" \
"          // هيكلٌ بشكل بطاقات الحجز لا دوّارةٌ في بياض.
          return const SkeletonList(rows: 3);" \
"          return const LoadingBlock();"

# ── ب) ويبقى الهيكلُ بعد وصول الصفوف ─────────────────────────────────────
#
# فتبدو الشاشةُ كأنّها لم تُحمَّل وهي محمَّلة.
run "(ب) الهيكلُ يبقى بعد الوصول" \
  sub "$M" \
"        if (snap.connectionState != ConnectionState.done) {" \
"        if (true) {"

# ── ج) ويذهب مربّعُ الصورة من هيكل المفضّلة ──────────────────────────────
#
# بطاقاتُها لها صورةٌ إلى جانبها، وهيكلٌ بلا مربّعٍ يقفز حين تصل.
run "(ج) هيكلٌ بلا مربّع صورة" \
  sub "$F" \
"            return const SkeletonList(rows: 3, thumb: true);" \
"            return const SkeletonList(rows: 3);"

# ── د) ويُضغط الهيكل ─────────────────────────────────────────────────────
run "(د) الهيكلُ يستقبل الضغط" \
  sub "$K" \
"    final quiet = IgnorePointer(child: list);" \
"    final quiet = Container(child: list);"

echo; echo "== الغلافُ الطائر =="

# ── هـ) ولا يطير من المفضّلة ─────────────────────────────────────────────
run "(هـ) لا طيرانَ من المفضّلة" \
  sub "$F" \
"                  flyCover: true," \
"                  flyCover: false,"

# ── و) ولا من ملفّ المزوّد ───────────────────────────────────────────────
run "(و) لا طيرانَ من ملفّ المزوّد" \
  sub "$V" \
"                  flyCover: true," \
"                  flyCover: false,"

# ── ز) ويصير الوسمُ واحداً لكلّ الخدمات ─────────────────────────────────
#
# **وهذا أخطرُها**: الشاشةُ تُفتح سليمةً، فإذا ضُغطت بطاقةٌ انفجر الانتقالُ
# بشاشةٍ حمراء — ولا يظهر ذلك في أيّ لقطةٍ ساكنة.
run "(ز) وسمٌ واحدٌ لكلّ الخدمات" \
  sub "$C" \
"String serviceHeroTag(String serviceId) => 'service-cover-\$serviceId';" \
"String serviceHeroTag(String serviceId) => 'service-cover';"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
