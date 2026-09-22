#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحقول التسجيل: العنوانُ فوقَ الصندوق، والصندوقُ فارغ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/signup_fields_test.dart"
O=lib/src/screens/onboarding.dart

BACKUP=$(mktemp -d)
cp "$O" "$BACKUP/o"
restore() { cp "$BACKUP/o" "$O"; }
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

echo; echo "== العطبُ الأصليُّ يعود =="

# ── أ) يعود عنوانُ الاسم إلى داخل الصندوق ────────────────────────────────
#
# **وهو ما شكا منه بعينه**: نصٌّ في صندوقٍ فارغ.
run "(أ) عنوانُ الاسم في الصندوق" \
  sub "$O" \
"                      labelText: tr('الاسم الكامل'),
                      floatingLabelBehavior: FloatingLabelBehavior.always," \
"                      labelText: tr('الاسم الكامل'),"

# ── ب) ويعود عنوانُ الجوال وحدَه ──────────────────────────────────────────
#
# الضابطُ الذي يمنع نصفَ التنفيذ: حقلٌ صحّ وحقلٌ بقي، والبطاقةُ نصفان.
run "(ب) عنوانُ الجوال في الصندوق" \
  sub "$O" \
"                      labelText: tr('رقم الجوال'),
                      floatingLabelBehavior: FloatingLabelBehavior.always," \
"                      labelText: tr('رقم الجوال'),"

# ── ج) وتفترق المحافظةُ عنهما ─────────────────────────────────────────────
#
# **وأوّلُ كسرٍ جرّبتُه هنا لم يسقط، والعيبُ كان في الكسر لا في الضمانة.**
# شِلتُ `floatingLabelBehavior` وحدَه فبقي العنوانُ طافياً: `DropdownButtonFormField`
# يحسب حقلَه غيرَ فارغٍ ما دام له `hint`، فيطفو العنوانُ من نفسه — والسطرُ
# زائدٌ هناك أصلاً. فصار الكسرُ يُشيلهما معاً، وحينئذٍ يقبع العنوانُ فعلاً.
drop_governorate_float() {
  python3 - <<'PYX'
import io
p = 'lib/src/screens/onboarding.dart'
s = io.open(p, encoding='utf-8').read()
old = """                    decoration: InputDecoration(
                      labelText: tr('المحافظة'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    hint: Text(
                      tr('اختر محافظتك'),
                      style: const TextStyle(color: AppColors.muted),
                    ),"""
new = """                    decoration: InputDecoration(
                      labelText: tr('المحافظة'),
                    ),"""
assert s.count(old) == 1
io.open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PYX
}
run "(ج) عنوانُ المحافظة في صندوقه" drop_governorate_float

echo; echo "== النصُّ في الصندوق =="

# ── د) ويعود المثالُ مع العنوان الطافي ────────────────────────────────────
#
# **وهذه تنكسر بصمت، وهي أخطرُ ما في الجولة.** `hintText` لا يظهر ما دام
# العنوانُ قابعاً — فمن شال العنوانَ وترك المثالَ يظنّ أنّه أفرغ الصندوق،
# وقد **أبدل نصّاً بنصّ**: يطفو العنوانُ فيظهر المثالُ مكانَه.
run "(د) يعود المثالُ في حقل الاسم" \
  sub "$O" \
"                      labelText: tr('الاسم الكامل'),
                      floatingLabelBehavior: FloatingLabelBehavior.always," \
"                      labelText: tr('الاسم الكامل'),
                      hintText: tr('محمد الصنعاني'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,"

# ── هـ) وفي حقل الجوال ────────────────────────────────────────────────────
run "(هـ) يعود مثالُ الجوال" \
  sub "$O" \
"                      labelText: tr('رقم الجوال'),
                      floatingLabelBehavior: FloatingLabelBehavior.always," \
"                      labelText: tr('رقم الجوال'),
                      hintText: '+967 7XX XXX XXX',
                      floatingLabelBehavior: FloatingLabelBehavior.always,"

# ── و) ويُكتب في الحقل نصٌّ لم يكتبه صاحبُه ───────────────────────────────
#
# وهو ما ظنّه صاحبُ المنصّة واقعاً. ولم يكن واقعاً — ويُحرس ألّا يقع.
run "(و) نصٌّ مكتوبٌ في حقل الاسم" \
  sub "$O" \
"  final _name = TextEditingController();" \
"  final _name = TextEditingController(text: 'محمد الصنعاني');"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
