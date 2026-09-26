#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحذف الحجز ولرأس صفحته.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وحرزُ القاعدة يُضبط في مكانه** — `supabase/tests/controls_booking_delete.sh`
# يكسر `booking_delete.sql`. ولا يُغني أحدُهما عن الآخر: الشاشةُ قد تُخفي
# زرّاً والخادمُ يقبل الفعلَ لمن ناداه بغير الشاشة.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/booking_detail_test.dart test/booking_card_test.dart"
F=lib/src/screens/booking_detail.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/d" "$D"; }
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
  if timeout 900 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 900 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الحذف =="

# ── أ) الزرُّ يُغلق الشاشةَ ولا يحذف ──────────────────────────────────────
#
# **وهذا أخبثُ ما يقع**: الشاشةُ تُغلق، والقائمةُ تُعاد قراءتُها، والحجزُ
# باقٍ — فيُقرأ نجاحاً وهو فشل. ولذلك يُقاس المخزنُ لا الشاشة.
run "(أ) يُغلق ولا يحذف" \
  sub "$F" \
"      await Api.deleteBooking(_b.id);" \
"      await Future<void>.delayed(Duration.zero);"

# ── ب) ويُحذف بلا سؤال ────────────────────────────────────────────────────
#
# فعلٌ لا رجعةَ فيه بضغطةٍ واحدةٍ بلا حوار.
run "(ب) يُحذف بلا حوار تأكيد" \
  sub "$F" \
"    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await Api.deleteBooking(_b.id);" \
"    if (confirmed == null) return;

    setState(() => _busy = true);
    try {
      await Api.deleteBooking(_b.id);"

# ── ج) ويُخفى ما يقع من الحوار ───────────────────────────────────────────
#
# **«يختفي من قائمتك» كذبٌ**: الصفُّ واحدٌ، فمحوُه يُذهبه من سجلّ المزوّد.
run "(ج) الحوارُ لا يقول إنّه يذهب من سجلّ المزوّد" \
  sub "$F" \
"          tr('يُحذف هذا الحجز من المنصّة نهائيّاً، ويذهب من سجلّ مقدّم '
              'الخدمة كذلك. لا رجعة فيه.')," \
"          tr('يختفي هذا الحجز من قائمتك.'),"

# ── د) ويظهر الزرُّ على حجزٍ دخله مال ────────────────────────────────────
#
# والخادمُ سيرفضه — فزرٌّ يَعِد بما سيُرفض ضغطةٌ في وجه صاحبه.
run "(د) زرُّ حذفٍ على حجزٍ دخله مال" \
  sub "$F" \
"      if (_b.paidAmount <= 0) ...[" \
"      if (_b.paidAmount >= 0) ...["

# ── هـ) ووضعُ العرض يحذف ما لا يُحذف ─────────────────────────────────────
#
# **فتُجرَّب شاشةٌ غيرُ التي على الجهاز**: وضعٌ يقبل ما يرفضه الخادمُ يُري
# صاحبَه نجاحاً سيصير خطأً على القاعدة.
run "(هـ) وضعُ العرض يحذف حجزاً دخله مال" \
  sub "$D" \
"  if (b.paidAmount > 0) {
    throw StateError('لا يُحذف حجزٌ دخله مال. ألغِ الحجز ليُحسب ما يُستردّ لك.');
  }" \
"  if (b.paidAmount < 0) {
    throw StateError('لا يُحذف حجزٌ دخله مال. ألغِ الحجز ليُحسب ما يُستردّ لك.');
  }"

echo; echo "== ورأسُ الصفحة =="

# ── و) ويُنسخ غيرُ رقم الحجز ─────────────────────────────────────────────
#
# ومن لصق اسمَ الخدمة في رسالةٍ إلى المزوّد لم يجد المزوّدُ حجزاً.
run "(و) يُنسخ غيرُ رقم الحجز" \
  sub "$F" \
"    await Clipboard.setData(ClipboardData(text: _b.reference));" \
"    await Clipboard.setData(ClipboardData(text: _b.serviceTitle));"

# ── ز) ويذهب اسمُ مقدّم الخدمة من الرأس ──────────────────────────────────
run "(ز) لا اسمَ لمقدّم الخدمة في الرأس" \
  sub "$F" \
"                      _b.providerName,
                      maxLines: 1," \
"                      '',
                      maxLines: 1,"

# ── ح) ويُقصّ رقمُ الحجز في الرأس ────────────────────────────────────────
#
# **وصفحةُ الحجز آخرُ موضعٍ يُقرأ فيه كاملاً**: في البطاقة عمودُه ربعُ
# العرض فيُقصّ، فإن قُصّ هنا لم يبقَ له موضع. وكان في صفٍّ مع التاريخ
# والوقت فخرج «BK-2026-00…» — فنزل سطراً.
#
# **ولا يُقاس بالسؤال عمّا في النصّ**: نصٌّ مقصوصٌ يحتفظ بحروفه في `data`،
# فالمقيسُ `didExceedMaxLines` على ما رُسم.
run "(ح) رقمُ الحجز يُقصّ في الرأس" \
  sub "$F" \
"              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _HeadFact(
                  icon: Icons.copy_rounded,
                  value: _b.reference,
                  ltr: true,
                  onTap: _copyReference,
                ),
              )," \
"              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: 90,
                  child: _HeadFact(
                    icon: Icons.copy_rounded,
                    value: _b.reference,
                    ltr: true,
                    onTap: _copyReference,
                  ),
                ),
              ),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
