#!/usr/bin/env bash
# ضوابطُ سالبةٌ لضغط اللافتة — بعد أن شال صاحبُ المنصّة شارةَ «إعلان».
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/polish_test.dart
H=lib/src/screens/home.dart
BACKUP=$(mktemp -d); cp "$H" "$BACKUP/home.dart"
restore() { cp "$BACKUP/home.dart" "$H"; }
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
  if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# أ) الشرطُ القديم يعود: من لا مزوّدَ له لا يُضغط — والإصبعُ لا يعرف أيَّ
#    لافتةٍ لها مزوّد، فيضغط فلا يقع شيءٌ ويظنّ التطبيقَ متجمّداً.
run "أ) لافتةٌ بلا مزوّدٍ لا تُضغط" sub "$H" \
  "    return Pressable(
      onTap: () {
        if (banner.providerId.isNotEmpty) {" \
  "    if (banner.providerId.isEmpty) return card;
    return Pressable(
      onTap: () {
        if (banner.providerId.isNotEmpty) {"

# ب) الضغطةُ تُبتلع صامتةً: `Pressable` باقيةٌ والفعلُ فارغ — وهي أسوأُ من
#    الأولى، فالبطاقةُ تومض تحت الإصبع ثمّ لا يقع شيء.
run "ب) ضغطةٌ تومض ولا تفعل" sub "$H" \
  "        if (banner.imageUrl.isNotEmpty) {
          openImageViewer(context, url: banner.imageUrl);
        }" \
  "        // لا شيء"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
