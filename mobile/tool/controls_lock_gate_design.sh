#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«اقفل تطبيقك قبل أن تبدأ» على صورة صاحب المنصّة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/lock_gate_design_test.dart test/force_lock_test.dart test/i18n_test.dart"
L=lib/src/screens/lock.dart
F=lib/src/ui/auth_frame.dart

BACKUP=$(mktemp -d)
cp "$L" "$BACKUP/l"; cp "$F" "$BACKUP/f"
restore() { cp "$BACKUP/l" "$L"; cp "$BACKUP/f" "$F"; }
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

run "(أ) بطاقةٌ حول بطاقة الحقائق" sub "$L" \
  "      bare: true,
      crestOnTop: true," "      crestOnTop: true,"

run "(ب) الوردُ فوق العنوان" sub "$L" \
  "      bare: true,
      crestOnTop: true," "      bare: true,"

run "(ج) مخملُ الورد تحت السطر الأوّل" python3 - <<'PYX'
import sys
p = 'lib/src/ui/auth_frame.dart'
s = open(p, encoding='utf-8').read()
a = s.index("          // ── ورقةٌ كريميّةٌ بحافّةٍ مستديرة")
b = s.index("          // ── البطاقة ──")
sheet = s[a:b]
s = s[:a] + s[b:]
anchor = "          // ── الوردُ في الزاويتين"
if s.count(anchor) != 1: sys.exit(1)
open(p, 'w', encoding='utf-8').write(s.replace(anchor, sheet + anchor, 1))
PYX

run "(د) لا قلبَ في القفل" sub "$L" \
  "                    key: ValueKey('gate-lock-heart')," \
  "                    key: ValueKey('gate-lock-heart-x'),"

run "(هـ) وعدٌ ببصمةٍ ليست في الجهاز" sub "$L" \
  "                title: _hasSensor ? tr('بصمتك تفتحه أسرع') : tr('ولا بصمةَ في جهازك')," \
  "                title: tr('بصمتك تفتحه أسرع'),"

# **والكسرُ يُشيل التصغيرَ لا `maxLines`**: بلا `maxLines` يبقى السطرُ واحداً
# لأنّ `FittedBox` تعطيه عرضاً بلا حدّ — فالضابطُ كان يسأل الشيفرةَ لا ما يُرى.
run "(و) «خطوة واحدة…» تُقصّ على الجوال الصغير" sub "$L" \
  "                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr('خطوة واحدة لحماية خصوصيتك'),"  \
  "                child: SizedBox(
                  child: Text(
                    tr('خطوة واحدة لحماية خصوصيتك'),"

run "(ز) الزرُّ بلا تدرّج" sub "$L" \
  "          key: const ValueKey('gate-set-pin'),
          style: authPrimaryStyle," \
  "          key: const ValueKey('gate-set-pin'),"

run "(ح) نصٌّ قديمٌ بدل نصّه" sub "$L" \
  "                title: tr('رمز من أربعة أرقام')," \
  "                title: tr('رمزٌ من أربعة أرقام'),"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
