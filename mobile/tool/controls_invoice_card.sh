#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقة الفاتورة: تقول رقمَ حجزها، والضغطةُ تفتحه.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/invoice_card_test.dart"

M=lib/src/screens/money.dart
D=lib/src/data/models.dart

FILES=("$M" "$D")
BACKUP=$(mktemp -d)
for i in "${!FILES[@]}"; do cp "${FILES[$i]}" "$BACKUP/$i"; done
restore() { for i in "${!FILES[@]}"; do cp "$BACKUP/$i" "${FILES[$i]}"; done; }
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

echo; echo "== ما تقوله البطاقة =="

# ── أ) تعود البطاقةُ صامتةً عن حجزها ──────────────────────────────────────
#
# **وهو الحالُ الذي شُكي منه بعينه**: «كيف يعرف حقّ أيّ حجز».
run "(أ) لا سطرَ للحجز" \
  sub "$M" \
"        if (invoice.bookingReference.isNotEmpty)" \
"        if (false)  // ignore: dead_code"

echo; echo "== الضغط =="

# ── ب) وتعود ساكنةً لا تُفتح ──────────────────────────────────────────────
run "(ب) البطاقةُ ساكنة" \
  sub "$M" \
"                onTap: list[i].bookingReference.isEmpty ? null : () => _open(list[i])," \
"                onTap: null,"

# ── ج) وتُعلَّق بطاقةٌ لا مرجعَ لها ────────────────────────────────────────
#
# سهمٌ فوق بطاقةٍ لا تعرف إلى أين تفتح يَعِد بما لا يقع.
run "(ج) تُعلَّق بلا مرجع" \
  sub "$M" \
"                onTap: list[i].bookingReference.isEmpty ? null : () => _open(list[i])," \
"                onTap: () => _open(list[i]),"

echo; echo "== أيَّ حجزٍ تفتح =="

# ── د) ويُفتح أوّلُ حجزٍ أبداً ─────────────────────────────────────────────
#
# **وهذه تنكسر بصمت**: تعمل وتبدو سليمةً لمن له فاتورةٌ واحدة، ولا يُرى
# نقصُها إلّا لمن له فاتورتان.
run "(د) يُفتح أوّلُ حجزٍ أبداً" \
  sub "$M" \
"        if (b.id == invoice.bookingId) booking = b;" \
"        booking ??= b;"

# ── هـ) وتُفتح شاشةٌ على لا حجز ────────────────────────────────────────────
#
# «حجوزاتي» تُقرأ عند الضغط، وقد لا يجد الحجزَ فيها — فضغطةٌ بلا جوابٍ
# هي الشكوى الأولى عائدةً.
run "(هـ) لا قولَ لمن خرج حجزُه" \
  sub "$M" \
"      if (booking == null) {
        showMessage(context, tr('لم يعد هذا الحجز في قائمة حجوزاتك.'));
        return;
      }" \
"      if (booking == null) {
        return;
      }"

echo; echo "== قراءةُ المرجع من صفّ الخادم =="

# ── و) ويُهمَل الصفُّ المضمَّن ─────────────────────────────────────────────
#
# **ووضعُ العرض يملأ المرجعَ من بيانات الحجوزات نفسِها فلا يقيس القراءة** —
# فلولا اختبارات `fromMap` لَخرجت البطاقةُ فارغةً عند الناس وهي ممتلئةٌ
# في الحزمة.
run "(و) يُهمَل الحجزُ المضمَّن" \
  sub "$D" \
"      bookingReference: (booking?['reference'] ?? '') as String," \
"      bookingReference: '',"

# ── ز) ولا يُقرأ إلّا الشكلُ الواحد ───────────────────────────────────────
#
# PostgREST يُرجع الصفَّ المضمَّن قائمةً في بعض صيغ العلاقة، وخريطةً في
# غيرها. ومن قرأ شكلاً واحداً خرج فارغاً عند الشكل الآخر.
run "(ز) شكلُ القائمة لا يُقرأ" \
  sub "$D" \
"    final booking = joined is List
        ? (joined.isEmpty ? null : joined.first as Map?)
        : joined as Map?;" \
"    final booking = joined is List ? null : joined as Map?;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
