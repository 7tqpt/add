#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحُرّاس «تعديل بياناتي».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (ج): سؤالُ الخروج يُشال.** وهو الحارسُ الوحيدُ في
# هذه الشاشة الذي يمنع **خسارةً حقيقيّة**: من عدّل اسمَه ثمّ ضغط رجوعاً
# يذهب ما كتب ولا يعلم أنّه ذهب — ولا رسالةَ ولا أثر.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/edit_profile_guard_test.dart
E=lib/src/screens/edit_profile.dart

BACKUP=$(mktemp -d)
cp "$E" "$BACKUP/e"
restore() { cp "$BACKUP/e" "$E"; }
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

# ── أ) الزرُّ يعود حيّاً أبداً ──────────────────────────────────────────────
#
# وهي الحالُ التي كانت.
run "(أ) الزرُّ حيٌّ ولم يتغيّر شيء" \
  sub "$E" \
"                  onPressed: _saving || !_dirty ? null : _save," \
"                  onPressed: _saving ? null : _save,"

# ── ب) و«تغيّر» تعني «لُمس» ─────────────────────────────────────────────────
#
# كسرٌ أخبث: من كتب حرفاً ثمّ محاه لم يغيّر شيئاً، وزرٌّ يبقى حيّاً بعدها
# يكذب — ويُرسل طلباً لا معنى له.
run "(ب) لمسُ الحقل يكفي" \
  sub "$E" \
"    final changed = _picked != null ||
        _name.text.trim() != p.fullName.trim() ||
        _phone.text.trim() != p.phone.trim() ||
        _governorateId != p.governorateId;" \
"    final changed = true;"

# ── ج) وسؤالُ الخروج يُشال ─────────────────────────────────────────────────
#
# **وهذا أخطرُها** — وشرحُه في رأس الملفّ.
run "(ج) الخروجُ بلا سؤال" \
  sub "$E" \
"    if (!_dirty || _saving) return true;" \
"    return true;
    // ignore: dead_code
    if (!_dirty || _saving) return true;"

# ── د) و«أكمل التعديل» تَخرج كما تخرج «اخرج» ───────────────────────────────
#
# السؤالُ يُطرح ويُرى والجوابُ لا يُقرأ — فمن قال «أكمل» ضاع ما كتبه وقد
# ظنّ أنّه منع.
run "(د) الجوابُ لا يُقرأ" \
  sub "$E" \
"    return leave == true;" \
"    return true;"

# ── هـ) والخطأُ يعود إلى القاع ─────────────────────────────────────────────
run "(هـ) خطأُ الاسم لا يصل حقلَه" \
  sub "$E" \
"                        errorText: _nameError,
                        errorMaxLines: 2," \
"" \

# ── و) وشارةُ «لم يُحفظ» تُشال ─────────────────────────────────────────────
run "(و) لا شارةَ تقول إنّ فيه ما لم يُحفظ" \
  sub "$E" \
"                        if (_dirty)
                          StatusBadge(tr('تعديلٌ لم يُحفظ')," \
"                        if (false)
                          StatusBadge(tr('تعديلٌ لم يُحفظ'),"

# ── ز) وشرحُ البريد يُحذف لا يُطوى ─────────────────────────────────────────
#
# **والطيُّ غيرُ الحذف.** من يسأل «لماذا لا أعدّله؟» يجب أن يجد الجواب.
run "(ز) شرحُ البريد يُحذف" \
  sub "$E" \
"        if (_open) ...[" \
"        if (false) ...["

# ── ح) والشرحُ يُعرض دائماً فيعود الثقل ────────────────────────────────────
run "(ح) الشرحُ معروضٌ أبداً" \
  sub "$E" \
"  bool _open = false;" \
"  bool _open = true;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
