#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«لا خطة بعد» على صورة صاحب المنصّة — الرسمُ والزرّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/plan_empty_test.dart test/i18n_test.dart"
P=lib/src/screens/plan.dart
ART=assets/brand/plan_empty.webp

BACKUP=$(mktemp -d)
cp "$P" "$BACKUP/p"; cp "$ART" "$BACKUP/art"
restore() { cp "$BACKUP/p" "$P"; cp "$BACKUP/art" "$ART"; }
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
  local out
  out=$(timeout 900 flutter test -r expanded $SUITE 2>&1)
  if echo "$out" | grep -q "All tests passed"; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "\[E\]$" | sed -E 's/^.*test\/([^:]+): /     • \1: /' | sort -u | head -8
    PASS=$((PASS+1))
  fi
  restore
}

run "(أ) الرسمُ من أصلٍ آخر" sub "$P" \
  "                    'assets/brand/plan_empty.webp'," \
  "                    'assets/brand/plan_floral.png',"

narrow_button() {
  sub "$P" "              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // **ولا يطول الرسمُ" "              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // **ولا يطول الرسمُ" &&
  sub "$P" "                    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52))," \
           "                    minimumSize: const WidgetStatePropertyAll(Size(120, 52)),"
}
run "(ب) الزرُّ صغيرٌ لا بعرض الشاشة" narrow_button

# **وكان الكسرُ الأوّلُ هنا يُنزل المحتوى ١٤٠ بكسلاً**، فسقط اختبارُ «يفتح
# خطة جديدة» لا اختبارُ الموضع — سقوطٌ لسببٍ غيرِ المقيس. والصحيحُ يُلصق
# المحتوى بقاع الشاشة بلا حشوةٍ للشريط، فيقع الزرُّ خلفه فعلاً.
behind_nav() {
  sub "$P" "      padding: EdgeInsets.fromLTRB(Space.xl, glassHeaderTop(context), Space.xl, glassNavSpace),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: box.maxHeight - glassHeaderTop(context) - glassNavSpace," \
  "      padding: EdgeInsets.fromLTRB(Space.xl, glassHeaderTop(context), Space.xl, 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: box.maxHeight - glassHeaderTop(context)," &&
  sub "$P" "        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420)," \
  "        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),"
}
run "(ج) الزرُّ خلف الشريط" behind_nav

art_last() {
  python3 - "$P" <<'PY3'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
a = s.index("                // **ولا يطول الرسمُ")
b = s.index("                const SizedBox(height: Space.lg),\n                Text(\n                  tr('لا خطة بعد'),")
art = s[a:b]
s = s[:a] + s[b:]
anchor = "                const SizedBox(height: Space.xl),\n                FilledButton.icon(\n                  key: const ValueKey('plan-create'),"
if s.count(anchor) != 1: sys.exit(1)
s = s.replace(anchor, art + anchor, 1)
open(p, 'w', encoding='utf-8').write(s)
PY3
}
run "(د) الرسمُ تحت العنوان" art_last

run "(هـ) الرسمُ صغيرٌ لا يُرى" sub "$P" \
  "                  constraints: BoxConstraints(maxHeight: box.maxHeight * 0.42)," \
  "                  constraints: BoxConstraints(maxHeight: box.maxHeight * 0.1),"

ivory_art() {
  python3 - "$ART" <<'PY4'
import sys
from PIL import Image
import numpy as np
p = sys.argv[1]
a = np.asarray(Image.open(p).convert('RGB')).astype(float)
a = a * np.array([253, 251, 249.0]) / 255
Image.fromarray(a.astype(np.uint8)).save(p, 'WEBP', quality=88, method=6)
PY4
}
run "(و) أرضيّةُ الرسم عاجيّةٌ كما في الصورة" ivory_art

run "(ز) الزرُّ لا يفتح شيئاً" sub "$P" \
  "                  onPressed: onCreate," "                  onPressed: () {},"

run "(ح) لا تمريرَ على الجوال الصغير" sub "$P" \
  "    builder: (context, box) => SingleChildScrollView(" \
  "    builder: (context, box) => Padding("

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
