#!/usr/bin/env bash
# ضوابطُ سالبةٌ للحقول المنسدلة في «تقديم خدمة» وفي محفظة الحساب.
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
                    initialValue: _governorate," \
  "                  Wrap(children: [
                    for (final g in governorates)
                      PickChip(
                        label: g.name,
                        active: _governorate == g.name,
                        onTap: () => setState(() => _governorate = g.name),
                      ),
                  ]),
                  if (false) DropdownButtonFormField<String>(
                    initialValue: _governorate,"

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
  "                  _CategoriesField(
                    all: categories,
                    picked: _picked,
                    onDone: (next) => setState(() {
                      _picked
                        ..clear()
                        ..addAll(next);
                    }),
                  )," \
  "                  Wrap(children: [
                    for (final c in categories)
                      PickChip(
                        label: c.name,
                        active: _picked.contains(c.id),
                        onTap: () => setState(() {
                          if (!_picked.remove(c.id)) _picked.add(c.id);
                        }),
                      ),
                  ]),"

# هـ) الورقةُ تُغلق عند أوّل اختيار — وهي علّةُ ألّا تكون منسدلةً أصلاً:
#     من أراد ثلاثةَ أقسامٍ فتحها ثلاثاً.
run "هـ) الورقةُ تُغلق عند كلّ اختيار" sub "$B" \
  "                onChanged: (_) => setSheet(() {
                  if (!draft.remove(c.id)) draft.add(c.id);
                })," \
  "                onChanged: (_) {
                  if (!draft.remove(c.id)) draft.add(c.id);
                  Navigator.of(sheetContext).pop(true);
                },"

# و) «تمّ» يعمل والورقةُ فارغة — يُغلقها ثمّ يردّ النموذجُ الطلبَ بخطأ.
run "و) «تمّ» يعمل بلا اختيار" sub "$B" \
  "              onPressed: draft.isEmpty
                  ? null
                  : () => Navigator.of(sheetContext).pop(true)," \
  "              onPressed: () => Navigator.of(sheetContext).pop(true),"

# ز) وما اختير لا يصل النموذج — تُغلق الورقةُ ويبقى الحقلُ فارغاً.
run "ز) الاختيارُ لا يصل النموذج" sub "$B" \
  "    if (saved == true) onDone(draft);" \
  "    if (saved == false) onDone(draft);"

# ح) والحقلُ الفارغُ بلا كلمة — لا يقول أمطلوبٌ هو أم اختياريّ.
run "ح) حقلٌ فارغٌ لا يقول شيئاً" sub "$B" \
  "          summary.isEmpty ? tr('اختر قسماً واحداً على الأقل') : summary," \
  "          summary,"

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
