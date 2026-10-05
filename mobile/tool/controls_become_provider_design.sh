#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«تقديم خدمة» على صورة صاحب المنصّة — حقولٌ فارغة، وعناوينُ
# بنجمة، ورقمٌ بمفتاحه، ونبذةٌ مطلوبة، ورأسٌ من صورته، وطائرةُ ورقٍ يسارَ النصّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/become_provider_test.dart"
B=lib/src/screens/become_provider.dart

BACKUP=$(mktemp -d)
cp "$B" "$BACKUP/b"
restore() { cp "$BACKUP/b" "$B"; }
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
    echo "$out" | grep -E "\[E\]$" | sed -E 's/^.*test\/([^:]+): /     • \1: /' | sort -u | head -6
    PASS=$((PASS+1))
  fi
  restore
}

run "(أ) مثالٌ يُقرأ كأنّه مكتوب في «اسم المنشأة»" sub "$B" \
  "                    decoration: _box(
                      tr('اسم المنشأة')," \
  "                    decoration: _box(
                      tr('قاعة التاج'),"

run "(ب) الرقمُ لا يُجمع إلى مفتاحه" sub "$B" \
  "    final phone = composePhone(_dial, _phone.text);" \
  "    final phone = normalisePhone(_phone.text);"

run "(ج) النبذةُ اختياريّةٌ كما كانت" sub "$B" \
  "        _bio.text.trim().isEmpty ||
" ""

run "(د) العناوينُ بلا نجمة" sub "$B" \
  "          const TextSpan(text: ' *', style: TextStyle(color: authGoldEdge))," \
  "          const TextSpan(text: '', style: TextStyle(color: authGoldEdge)),"

run "(هـ) سطرُ الرأس لا يُصغَّر فيُقصّ" sub "$B" \
  "                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(" \
  "                SizedBox(
                  child: Text("

run "(و) المتجرُ أيقونةٌ لا رسمُه" sub "$B" \
  "      'assets/brand/apply_store.png'," \
  "      'assets/brand/app_mark.png',"

run "(ز) طائرةُ الورق يمينَ النصّ" sub "$B" \
  "                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center," \
  "                    child: Row(
                      textDirection: TextDirection.ltr,
                      mainAxisAlignment: MainAxisAlignment.center,"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
