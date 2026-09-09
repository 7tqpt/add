#!/usr/bin/env bash
# ضوابطُ سالبةٌ للحقول المنسدلة في «تقديم خدمة» وفي محفظة الحساب.
#
# وسقط منها ما كان يكسر ورقةَ الاختيار المتعدّد ومربّعاتِها وزرَّ «تمّ»:
# صار القسمُ واحداً بقرار صاحب المنصّة، فلا ورقةَ تُكسر.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/become_provider_test.dart
B=lib/src/screens/become_provider.dart
A=lib/src/screens/account_extras.dart

BACKUP=$(mktemp -d); cp "$B" "$BACKUP/b"; cp "$A" "$BACKUP/a"
restore() { cp "$BACKUP/b" "$B"; cp "$BACKUP/a" "$A"; }
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

# أ) جدارُ الشرائح يعود للمحافظة — وهو ما شكا منه صاحبُ المنصّة: عشرون
#    شريحةً تدفع زرَّ الإرسال تحت الطيّة.
run "أ) شرائحُ المحافظة تعود" sub "$B" \
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

# ب) والمنسدلةُ تُفتح فارغة — تُضغط ولا تُظهر شيئاً، فيظنّها عاطلة.
run "ب) منسدلةٌ بلا خيارات" sub "$B" \
  "                      for (final g in governorates)
                        DropdownMenuItem<String>(
                          value: g.name,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        )," \
  ""

# ج) والاختيارُ لا يُحفظ — تُختار المحافظةُ ويعود الحقلُ فارغاً.
run "ج) الاختيارُ لا يبقى" sub "$B" \
  "                    onChanged: (v) => setState(() => _governorate = v)," \
  "                    onChanged: (v) {},"

# د) جدارُ شرائح الأقسام يعود.
run "د) شرائحُ الأقسام تعود" sub "$B" \
  "                  DropdownButtonFormField<String>(
                    key: const ValueKey('category-field')," \
  "                  Wrap(children: [
                    for (final c in categories)
                      PickChip(
                        label: c.name,
                        active: _category == c.id,
                        onTap: () => setState(() => _category = c.id),
                      ),
                  ]),
                  if (false) DropdownButtonFormField<String>(
                    key: const ValueKey('category-field'),"

# هـ) والقائمةُ تُفتح فارغة — تُضغط ولا تُظهر قسماً، فيظنّها عاطلة.
run "هـ) قائمةُ الأقسام فارغة" sub "$B" \
  "                      for (final c in categories)
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        )," \
  ""

# و) والقسمُ المختارُ لا يُحفظ — يُرسَل الطلبُ بلا قسم، فيصير مزوّداً لا
#    يظهر في أيّ دليل.
run "و) القسمُ لا يُحفظ" sub "$B" \
  "                    onChanged: (v) => setState(() => _category = v)," \
  "                    onChanged: (v) {},"

# ز) والنموذجُ يقبل طلباً بلا قسم — أسوأُ من رفضٍ ظاهر.
run "ز) يمرّ طلبٌ بلا قسم" sub "$B" \
  "        _category == null) {" \
  "        false) {"

# ح) ويُرسَل **اسمُ** القسم بدل معرّفه — يمرّ في العين ويصل الخادمَ نصّاً
#    لا `uuid`، فيُرفض الطلب على الجهاز ولا يظهر ذلك في وضع العرض.
run "ح) يُرسَل الاسمُ بدل المعرّف" sub "$B" \
  "                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis)," \
  "                          value: c.name,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),"

# ط) ومحفظةُ الحساب تعود شرائحَ بلا عنوان.
run "ط) شرائحُ المحفظة تعود" sub "$A" \
  "        DropdownButtonFormField<String>(
          key: const ValueKey('wallet-method')," \
  "        Wrap(children: [
          for (final e in paymentMethodNames().entries)
            PickChip(
              label: e.value,
              active: _method == e.key,
              onTap: () => setState(() => _method = e.key),
            ),
        ]),
        if (false) DropdownButtonFormField<String>(
          key: const ValueKey('wallet-method'),"

# ي) والمنسدلةُ تبقى بلا عنوان — فتُقرأ زينةً لا سؤالاً.
run "ي) منسدلةُ المحفظة بلا عنوان" sub "$A" \
  "          decoration: InputDecoration(labelText: tr('الوسيلة'))," \
  "          decoration: const InputDecoration(),"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
