#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«خطة جديدة» على صورة صاحب المنصّة — «الصفة» والشكل.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/plan_editor_design_test.dart test/plan_editor_test.dart"
P=lib/src/screens/plan_editor.dart

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

# ── الصفة ───────────────────────────────────────────────────────────────────
run "(أ) الصفةُ لا تصل الملفّ" sub "$P" \
  "        await Api.setWeddingRole(_role);" ""

run "(ب) ما في الملفّ لا يُختار" sub "$P" \
  "            if (_role.isEmpty) _role = role;" ""

run "(ج) «أنا عروس» تختار العريس" sub "$P" \
  "setState(() => _role = 'bride')," "setState(() => _role = 'groom'),"

run "(د) الرسمُ داكنٌ على النبيذيّ" sub "$P" \
  "    final ink = selected ? Colors.white : AppColors.ink;" \
  "    final ink = AppColors.ink;"

run "(هـ) العلامةُ فوق الرسم" sub "$P" \
  "                    const Icon(
                      Icons.check_circle," \
  "                    Transform.translate(offset: const Offset(-26, 0), child: const Icon(
                      Icons.check_circle,),),
                    if (false) const Icon(
                      Icons.check_circle,"

# ── الشكل ───────────────────────────────────────────────────────────────────
run "(و) العنوانُ بعيدٌ عن صندوقه" sub "$P" \
  "    padding: const EdgeInsets.only(top: 10, bottom: 6)," \
  "    padding: const EdgeInsets.only(top: 10, bottom: 30),"

run "(ز) مثالٌ في صندوق الميزانية" sub "$P" \
  "                        decoration: _box(),
                      ),
                      _FieldLabel(icon: Icons.location_on_outlined," \
  "                        decoration: _box(hint: '2000000'),
                      ),
                      _FieldLabel(icon: Icons.location_on_outlined,"

run "(ح) الزهرُ في الزاوية الأخرى" sub "$P" \
  "              top: 0,
              end: 0," "              top: 0,
              start: 0,"

run "(ط) مربّعُ الصفة بارتفاعٍ ثابت" sub "$P" \
  "            constraints: const BoxConstraints(minHeight: 58)," \
  "            constraints: const BoxConstraints.tightFor(height: 58),"

run "(ي) «يومك» يعود مكانَ «عرسك»" sub "$P" \
  "tr('لنبدأ بتنظيم عرسك المميز')" "tr('لنبدأ بتنظيم يومك المميز')"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
