#!/usr/bin/env bash
# ضوابطُ سالبةٌ لمنسدلة المحافظة في «أكمل ملفك».
#
# وهي أوّلُ شاشةٍ يراها من سجّل، وكانت شرائحُها عشرين تدفع زرَّ «متابعة»
# تحت الطيّة.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/onboarding_test.dart
O=lib/src/screens/onboarding.dart
A=lib/src/data/api.dart

BACKUP=$(mktemp -d); cp "$O" "$BACKUP/o"; cp "$A" "$BACKUP/a"
restore() { cp "$BACKUP/o" "$O"; cp "$BACKUP/a" "$A"; }
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

# أ) جدارُ الشرائح يعود — وهو ما شكا منه صاحبُ المنصّة: عشرون شريحةً تدفع
#    زرَّ «متابعة» تحت الطيّة في أوّل شاشةٍ يراها من سجّل.
run "أ) الشرائحُ تعود" sub "$O" \
  "                  DropdownButtonFormField<String>(
                    key: const ValueKey('governorate-field')," \
  "                  Wrap(children: [
                    for (final g in governorates)
                      PickChip(
                        label: g.name,
                        active: _governorate == g.name,
                        onTap: () => setState(() => _governorate = g.name),
                      ),
                  ]),
                  if (false) DropdownButtonFormField<String>(
                    key: const ValueKey('governorate-field'),"

# ب) والمنسدلةُ تُفتح فارغة — تُضغط ولا تُظهر محافظةً، فيظنّها عاطلة.
run "ب) منسدلةٌ بلا خيارات" sub "$O" \
  "                      for (final g in governorates)
                        DropdownMenuItem<String>(
                          value: g.name,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        )," \
  ""

# ج) والاختيارُ لا يُحفظ — يُرى في الحقل ويصل الخادمَ فراغاً.
#
#    **وهذا هو الضابطُ الذي لا يسقط بلا تسجيلِ وضعِ العرض:** الحقلُ يعرض
#    اختيارَه ولو لم يصل `onChanged` شيئاً، فسؤالُ الشاشة يمرّ.
run "ج) الاختيارُ لا يصل الخادم" sub "$O" \
  "                    onChanged: (v) => setState(() => _governorate = v)," \
  "                    onChanged: (v) {},"

# د) ويمرّ نموذجٌ بلا محافظة — فيصير مستخدماً بلا محافظةٍ لا يظهر له قريب.
#
#    **والمرساةُ سطرٌ واحدٌ لا ثلاثة** — الشرطُ في هذه الشاشة مكتوبٌ في سطر،
#    وفي «تقديم خدمة» في ثلاثة. فكتبتُها على شكل الأخرى فلم تطابق شيئاً،
#    وقال الضابطُ «لا كسرَ وقع» — وهو صادقٌ: لا يُقاس بضابطٍ لم يكسر.
run "د) يمرّ بلا محافظة" sub "$O" \
  "_governorate == null) {" \
  "false) {"

# هـ) ووضعُ العرض يعود صامتاً — وهو **كسرٌ في أداة القياس لا في المقيس**،
#     ويجب أن تحمرّ الحزمةُ به: اختبارٌ لا يستطيع أن يرى ما وصل الخادمَ
#     اختبارٌ يقيس الشاشةَ وحدَها.
run "هـ) وضعُ العرض لا يسجّل" sub "$A" \
  "      demoRegisterProfile(
          fullName: fullName, phone: phone, governorate: governorate);
      return;" \
  "      return;"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
