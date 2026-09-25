#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقة الحجز في «حجوزاتي».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وكسرٌ يُسقط الحزمةَ بعطبٍ في الترجمة ضابطٌ كاذبٌ كذلك**: يحمرّ لسببٍ غير
# الذي يدّعيه. فكلُّ كسرٍ هنا يُتحقَّق من وقوعه أوّلاً (المرساةُ تطابق مرّةً
# واحدة)، والسطرُ المكسورُ Dart صحيحٌ يُصرَّف.
#
# **وحرزُ القاعدة يُضبط في مكانه** — `supabase/tests/controls_booking_cover.sh`
# يكسر `booking_cover.sql` خمسةَ كسور. ولا يُغني أحدُهما عن الآخر: الشاشةُ
# قد تعرض صواباً ما تضمّه القاعدةُ خطأً، والعكس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/booking_card_test.dart test/booking_stages_test.dart \
       test/booking_order_test.dart test/payment_test.dart"
F=lib/src/screens/my_bookings.dart
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

echo; echo "== شريطُ الدفع =="

# ── أ) يُقاس الشريطُ بالعربون لا بالمدفوع ─────────────────────────────────
#
# **والفرقُ بينهما هو الالتزامُ القادم**: من دفع عربونَه يرى شريطَه ممتلئاً
# فيظنّ أنّه سدّد.
run "(أ) الشريطُ يقيس العربونَ لا المدفوع" \
  sub "$F" \
"        ? (b.paidAmount / b.totalPrice).clamp(0.0, 1.0).toDouble()" \
"        ? (b.depositAmount / b.totalPrice).clamp(0.0, 1.0).toDouble()"

# ── ب) وتُكتب النسبةُ في الحلقة لا تُحسب ──────────────────────────────────
run "(ب) نسبةُ الحلقة مكتوبةٌ لا محسوبة" \
  sub "$F" \
"                            label: trf('{0}٪', ['\${(ratio * 100).round()}'])," \
"                            label: trf('{0}٪', ['30']),"

# ── ج) ولا تتبع الحلقةُ الشريط ────────────────────────────────────────────
#
# والعينُ تصدّق القوسَ قبل أن تقرأ الرقم.
run "(ج) الحلقةُ لا تتبع النسبة" \
  sub "$F" \
"                            key: ValueKey('paid-ring-\${b.id}'),
                            value: ratio," \
"                            key: ValueKey('paid-ring-\${b.id}'),
                            value: 0.6,"

# ── د) ويُقال «سُدّد كاملاً» لمن بقي عليه ────────────────────────────────
#
# **وهذا يُسكت المطالبة**: من بقي عليه ٥٩٥ ألفاً يُقرأ عليه أنّه سدّد.
run "(د) «سُدّد كاملاً» لمن بقي عليه" \
  sub "$F" \
"                              left <= 0" \
"                              left >= 0"

echo; echo "== والعدُّ التنازلي =="

# ── هـ) وتُركَّب جملةُ العدّ في الشاشة ────────────────────────────────────
#
# فتخرج «بقي 2 يوماً» حين يبقى يومان — وصيغةُ العدد العربيّة أربع.
run "(هـ) الجملةُ تُركَّب لا تُؤخذ" \
  sub "$F" \
"          BigNumberIn(countdownLabel(daysUntil(b.eventDate)))," \
"          BigNumberIn('بقي \${daysUntil(b.eventDate) ?? 0} يوماً'),"

echo; echo "== والغلاف =="

# ── و) ويُطلب غلافُ خدمةٍ أخرى ────────────────────────────────────────────
#
# **ولكلّ خدمةٍ في بيانات العرض غلافُها**، فيُقاس أيُّهما طُلب. وبطاقةٌ
# تعرض صورةَ قاعةٍ لم يحجزها تُقرأ خطأً في الحجز لا في الصورة.
run "(و) غلافُ خدمةٍ غيرِ المحجوزة" \
  sub "$D" \
"    [for (final b in demoBookings) b.withCover(demoServiceCover(b.serviceTitle))];" \
"    [for (final b in demoBookings) b.withCover(demoServices.first.coverPath)];"

echo; echo "== وما بقي كما كان =="

# ── ز) ويُشال السهمُ الذي يقول إنّها تُفتح ───────────────────────────────
#
# اختاره صاحبُ المنصّة: الانخفاضُ تحت الإصبع لا يُعلم إلّا بعد أن يُجرَّب.
run "(ز) لا سهمَ يقول إنّها تُفتح" \
  sub "$F" \
"                          const Icon(Icons.chevron_right,
                              size: 18, color: AppColors.muted)," \
"                          const SizedBox.shrink(),"

# ── ح) وتُشال مراحلُ الحجز ────────────────────────────────────────────────
#
# اختار صاحبُ المنصّة بقاءَها: «أين وصل حجزي؟» يُقرأ بلا فتح.
run "(ح) لا مراحلَ في البطاقة" \
  sub "$F" \
"                      BookingStages(stages: bookingStages(b))," \
"                      const SizedBox.shrink(),"

# ── ط) وتصير البطاقةُ نبيذيّةً ────────────────────────────────────────────
#
# رجعت إلى البياض بطلبٍ صريحٍ من صاحب المنصّة، والملوَّنُ هو الملخّصُ وحدَه.
run "(ط) بطاقةُ الحجز نبيذيّة" \
  sub "$F" \
"            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline)," \
"            color: AppColors.accent,
            border: Border.all(color: AppColors.hairline),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
