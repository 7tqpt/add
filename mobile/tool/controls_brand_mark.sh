#!/usr/bin/env bash
# ضوابطُ سالبةٌ لأيقونة التطبيق في رؤوس الشاشات الثلاث.
#
# **وأدقُّها الأخير:** أصلٌ غيرُ مشحونٍ يرسم مربّعاً فارغاً على الجهاز —
# ويمرّ في اختبارٍ يسأل «أثَمّ صورةٌ في الرأس؟». فيُنزع الأصلُ من `pubspec`
# ويُنظر أتحمرّ.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/brand_mark_test.dart
A=lib/src/screens/auth.dart
L=lib/src/screens/lock.dart
V=lib/src/screens/verify_phone.dart
P=pubspec.yaml

BACKUP=$(mktemp -d)
cp "$A" "$BACKUP/a"; cp "$L" "$BACKUP/l"; cp "$V" "$BACKUP/v"; cp "$P" "$BACKUP/p"
restore() { cp "$BACKUP/a" "$A"; cp "$BACKUP/l" "$L"; cp "$BACKUP/v" "$V"; cp "$BACKUP/p" "$P"; }
trap 'restore; flutter pub get >/dev/null 2>&1; rm -rf "$BACKUP"' EXIT
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

# **والمرساةُ سطرُ المسار وحدَه لا الكتلةُ بإزاحتها:** `dart format` يُزيح
# الكتلةَ بحسب عمقها في كلّ شاشة، فمرساةٌ بإزاحةٍ مكتوبةٍ تُطابق في واحدةٍ
# وتخيب في أختيها — وقد خابت في الثلاث أوّلَ مرّة.
for pair in "أ) الدخول:$A" "ب) القفل:$L" "ج) تأكيد الرقم:$V"; do
  name="${pair%%:*}"; file="${pair##*:}"
  run "$name يرفع أصلاً آخر" sub "$file" \
    "'assets/brand/app_mark.png'," \
    "'assets/brand/not_a_mark.png',"
done

# د) **والأصلُ يُنزع من الحزمة** — فتبقى `Image.asset` في الشيفرة ويخرج
#    مربّعٌ فارغٌ على الجهاز. وهذا ما لا يراه اختبارٌ يسأل «أثَمّ صورة؟».
run "د) الأصلُ غيرُ مشحون" sub "$P" \
  "  assets:
    - assets/brand/app_mark.png
" \
  ""

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
