#!/usr/bin/env bash
# ضوابطُ سالبةٌ لرسم «الصفة» في بطاقة الخطّة — أنثى للعروس وذكرٌ للعريس.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/plan_role_test.dart test/i18n_test.dart"
P=lib/src/screens/plan.dart

BACKUP=$(mktemp -d)
cp "$P" "$BACKUP/p"
restore() { cp "$BACKUP/p" "$P"; }
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

run "(أ) العروسُ ترى رسمَ الذكر" sub "$P" \
  "      'bride' => 'assets/brand/role_bride.png'," \
  "      'bride' => 'assets/brand/role_groom.png',"

run "(ب) القلبُ دائماً" sub "$P" \
  "                _RoleMark(role: role)," "                _RoleMark(role: ''),"

run "(ج) الصفةُ لا تُقرأ بعد التعديل" sub "$P" \
  "    // **والصفةُ تُقرأ من جديد**: قد تكون بُدّلت في «خطة جديدة» للتوّ.
    _loadRole();" ""

run "(د) الصفةُ لا تُقرأ عند الفتح" sub "$P" \
  "    _future = Api.myPlans();
    _loadRole();
  }" "    _future = Api.myPlans();
  }"

run "(هـ) الرسمُ أبيضُ لا بذهب القلب" sub "$P" \
  "      color: AppColors.goldOnBrand,
      colorBlendMode: BlendMode.srcIn," \
  "      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,"

run "(و) الرسمُ بعد الاسم لا قبله" sub "$P" \
  "                _RoleMark(role: role)," \
  "                Transform.translate(offset: const Offset(-300, 0), child: _RoleMark(role: role)),"

run "(ز) الكبيرُ غائب" sub "$P" \
  "                  if (role == 'bride' || role == 'groom')
                    PositionedDirectional(" \
  "                  if (false)
                    PositionedDirectional("

run "(ح) الكبيرُ للعروس رسمُ الذكر" sub "$P" \
  "role == 'bride' ? 'assets/brand/role_bride.png' : 'assets/brand/role_groom.png'," \
  "'assets/brand/role_groom.png',"

run "(ط) الكبيرُ غيرُ باهت" sub "$P" \
  "color: Colors.white.withValues(alpha: 0.30)," \
  "color: Colors.white,"

run "(ي) الكبيرُ في الطرف الأيمن" sub "$P" \
  "                    PositionedDirectional(
                      end: 10," \
  "                    PositionedDirectional(
                      start: 10,"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
