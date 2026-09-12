#!/usr/bin/env bash
# ضوابطُ سالبةٌ لمنسدلة المحافظة في «خطة جديدة».
#
# **وما لا يسقط بالكسر ضمانةٌ كاذبة.** فيُكسر كلُّ ما تدّعيه الحزمةُ كسراً
# واحداً، ويُتأكّد أنّها تحمرّ به.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/plan_editor_test.dart
P=lib/src/screens/plan_editor.dart
A=lib/src/data/api.dart

BACKUP=$(mktemp -d); cp "$P" "$BACKUP/p"; cp "$A" "$BACKUP/a"
restore() { cp "$BACKUP/p" "$P"; cp "$BACKUP/a" "$A"; }
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

# أ) جدارُ الشرائح يعود — وهو ما شكا منه صاحبُ المنصّة بلقطة: عشرون شريحةً
#    تدفع «إنشاء الخطة» إلى أسفل البطاقة.
run "أ) الشرائحُ تعود" sub "$P" \
  "                  return DropdownButtonFormField<String>(
                    key: const ValueKey('plan-governorate-field')," \
  "                  if (rows.isNotEmpty) {
                    return Wrap(children: [
                      for (final g in rows)
                        PickChip(
                          label: g.name,
                          active: _governorate == g.name,
                          onTap: () => setState(() => _governorate = g.name),
                        ),
                    ]);
                  }
                  return DropdownButtonFormField<String>(
                    key: const ValueKey('plan-governorate-field'),"

# ب) والمنسدلةُ تُفتح فارغة — تُضغط ولا تُظهر محافظةً، فيظنّها عاطلة.
run "ب) منسدلةٌ بلا خيارات" sub "$P" \
  "                      for (final g in rows)
                        DropdownMenuItem<String>(
                          value: g.name,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        )," \
  ""

# ج) والاختيارُ لا يصل الخادم — يُرى في الحقل ويُحفظ فراغاً.
#
#    **وهذا هو الضابطُ الذي لا يسقط بلا سؤالِ `demoPlans`:** الحقلُ يعرض
#    اختيارَه ولو لم يستقبل `onChanged` شيئاً، فسؤالُ الشاشة يمرّ.
run "ج) الاختيارُ لا يصل الخادم" sub "$P" \
  "                        : (v) => setState(() => _governorate = v)," \
  "                        : (v) {},"

# د) وتمرّ خطّةٌ بلا محافظة — فتُحفظ خطّةٌ لا يعرف أحدٌ أين عرسُها.
run "د) تمرّ بلا محافظة" sub "$P" \
  "|| _governorate == null) {" \
  "|| false) {"

# هـ) والقيمةُ تُمرَّر بلا فحصٍ أنّها في القائمة — وهو الكسرُ الذي يُسقط
#     شاشةَ التعديل بدعوى `There should be exactly one item…` حين تُطفأ
#     محافظةٌ من `governorates` بعد أن حُفظت الخطّة.
run "هـ) قيمةٌ ليست في الخيارات" sub "$P" \
  "                  final value =
                      rows.any((g) => g.name == _governorate) ? _governorate : null;" \
  "                  final value = _governorate;"

# و) ووضعُ العرض يعود صامتاً — وهو **كسرٌ في أداة القياس لا في المقيس**،
#    ويجب أن تحمرّ الحزمةُ به: اختبارٌ لا يرى ما وصل الخادمَ يقيس الشاشةَ
#    وحدَها.
run "و) وضعُ العرض لا يسجّل" sub "$A" \
  "      demoSavePlan(id: id, values: values);
      return;" \
  "      return;"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
