#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبياض «المحادثات» و«الإشعارات».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (ج): يُبيَّض التطبيقُ كلُّه من الثيمة.** وهو أقصرُ
# طريقٍ إلى البياض المطلوب — سطرٌ واحدٌ يُغني عن سطرين — **وهو يقلب كلَّ شاشةٍ
# في التطبيق**، وذلك ما لم يُطلب. ولولا هذا الضابطِ لَمرّ.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/white_lists_test.dart"

C=lib/src/screens/conversations.dart
N=lib/src/screens/notifications.dart
T=lib/src/core/theme.dart

FILES=("$C" "$N" "$T")
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

echo; echo "== الضوابط =="

run "(أ) تعود «المحادثات» ورديّة" \
  sub "$C" "      backgroundColor: AppColors.surface," "      // كُسر"

run "(ب) تعود «الإشعارات» ورديّة" \
  sub "$N" "      backgroundColor: AppColors.surface," "      // كُسر"

# ── ج) ويُبيَّض التطبيقُ كلُّه من الثيمة ────────────────────────────────────
#
# **وهذا أخطرُها، وهو أقصرُ طريقٍ إلى ما طُلب.** الشاشتان تصيران بيضاوين
# فيمرّ الشرطان الأوّلان — ويُبيَّض معهما كلُّ شيءٍ لم يُطلب.
run "(ج) بياضٌ من الثيمة يعمّ التطبيق" \
  sub "$T" "    scaffoldBackgroundColor: AppColors.page," \
           "    scaffoldBackgroundColor: AppColors.surface,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
