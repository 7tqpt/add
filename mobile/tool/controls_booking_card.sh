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
L=lib/src/screens/labels.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$D" "$BACKUP/d"; cp "$L" "$BACKUP/l"
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/d" "$D"; cp "$BACKUP/l" "$L"; }
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

echo; echo "== حقائقُ البطاقة =="

# ── أ) السعرُ مكتوبٌ لا مأخوذٌ من الحجز ───────────────────────────────────
#
# **وثمنٌ مكتوبٌ يصيب في بطاقةٍ ويخطئ في كلّ بطاقةٍ سواها** — ومن قرأ ثمنَ
# حجزٍ آخرَ على بطاقته ذهب يطالب بما لم يتّفق عليه.
run "(أ) السعرُ رقمٌ مكتوب" \
  sub "$F" \
"            value: formatMoney(b.totalPrice)," \
"            value: formatMoney(850000),"

# ── ب) والوقتُ يعرض التاريخ ───────────────────────────────────────────────
run "(ب) قيمةُ «الوقت» هي التاريخ" \
  sub "$F" \
"            label: tr('الوقت'),
            value: formatTime(b.eventTime)," \
"            label: tr('الوقت'),
            value: formatDate(b.eventDate),"

# ── ج) ورقمُ الحجز يعرض معرّفَ الصفّ ──────────────────────────────────────
#
# المرجعُ هو الذي يُقال للمزوّد في الهاتف، ومعرّفُ الصفّ لا يعرفه أحد.
run "(ج) رقمُ الحجز معرّفُ الصفّ" \
  sub "$F" \
"            value: b.reference," \
"            value: b.id,"

echo; echo "== وشارةُ الحالة =="

# ── د) ولونُها مكتوبٌ لا من الحالة ────────────────────────────────────────
#
# فيخرج «مرفوض» بشارةٍ خضراء.
run "(د) لونُ الشارة ثابتٌ مكتوب" \
  sub "$F" \
"    final c = bookingStatusColor(status);" \
"    final c = AppColors.good;"

# ── هـ) وعلامةُ صحٍّ لكلّ حال ─────────────────────────────────────────────
#
# **وصحٌّ على حجزٍ اعتُذر عنه يُقرأ لمحةً على أنّه تمّ** — والشارةُ تُقرأ
# لمحةً لا تُتهجّى.
run "(هـ) علامةُ صحٍّ لكلّ حالة" \
  sub "$L" \
"  BookingStatus.rejected => Icons.cancel_rounded," \
"  BookingStatus.rejected => Icons.check_circle_rounded,"

echo; echo "== والغلاف =="

# ── و) ويُطلب غلافُ خدمةٍ أخرى ────────────────────────────────────────────
#
# **ولكلّ خدمةٍ في بيانات العرض غلافُها**، فيُقاس أيُّهما طُلب. وبطاقةٌ
# تعرض صورةَ قاعةٍ لم يحجزها تُقرأ خطأً في الحجز لا في الصورة.
run "(و) غلافُ خدمةٍ غيرِ المحجوزة" \
  sub "$D" \
"    [for (final b in demoBookings) b.withCover(demoServiceCover(b.serviceTitle))];" \
"    [for (final b in demoBookings) b.withCover(demoServices.first.coverPath)];"

# ── و٢) وارتفاعُ الغلاف بلا نهاية ────────────────────────────────────────
#
# **وهذا هو العطبُ الذي اختفت به البطاقاتُ كلُّها على جهازٍ حقيقيّ، والحزمةُ
# خضراء.** `Image` المرسومةُ بارتفاعٍ لا نهائيٍّ تُسأل عن ارتفاعها الطبيعيّ
# فتُجيب **بلا نهاية**، فينهار التخطيط. ولم يقع في الاختبار لأنّ
# `Api.mediaUrl` كانت تردّ `null` فلا تُبنى `Image` أصلاً — فصار كلُّ
# اختبارٍ يمرّر رابطاً كما يقع على الجهاز.
run "(و٢) ارتفاعُ الغلاف بلا نهاية" \
  sub "$F" \
"            height: 58 * scale," \
"            height: double.infinity * scale,"

echo; echo "== والزرّان =="

# ── ز) «عرض الحجز» لا يفتح شيئاً ─────────────────────────────────────────
run "(ز) زرُّ العرض لا يفتح شيئاً" \
  sub "$F" \
"            filled: true,
            onTap: onTap," \
"            filled: true,
            onTap: null,"

# ── ح) والمحادثةُ تُفتح مع مزوّدٍ آخر ────────────────────────────────────
#
# **وسؤالٌ عن حجزٍ يصل إلى غريب.** ولولا حجزٌ مزوّدُه ليس الأوّلَ في بيانات
# العرض لصحّ هذا ومرّ.
run "(ح) محادثةُ مزوّدٍ غيرِ مزوّد الحجز" \
  sub "$F" \
"      final id = await Api.openConversation(b.providerId, bookingId: b.id);" \
"      final id = await Api.openConversation('p1', bookingId: b.id);"

# ── ط) وزرُّ محادثةٍ لمن لا معرّفَ لمزوّده ───────────────────────────────
#
# فيُضغط ويُردّ من الخادم بخطأٍ في وجهه.
run "(ط) زرُّ محادثةٍ بلا مزوّد" \
  sub "$F" \
"    final chat = booking.providerId.isEmpty ? null : onMessage;" \
"    final chat = onMessage;"

echo; echo "== وما شيل يبقى مشيلاً =="

# ── ط٢) ويعود شريطُ الدفع ────────────────────────────────────────────────
#
# **عُرضت عليه ثلاثُ خلايا فاختار «تُشال كلُّها كما في صورتك»** — وعودتُها
# بلا أن يُسأل نقضٌ لاختياره. والمبالغُ كلُّها في صفحة الحجز.
run "(ط٢) شريطُ الدفع يعود إلى البطاقة" \
  sub "$F" \
"              _Facts(booking: b),
              const SizedBox(height: 12)," \
"              _Facts(booking: b),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: b.paidAmount / b.totalPrice),
              const SizedBox(height: 12),"

# ── ط٣) ويعود العدُّ التنازليُّ ──────────────────────────────────────────
run "(ط٣) العدُّ التنازليُّ يعود إلى البطاقة" \
  sub "$F" \
"              _Head(booking: b),
              const SizedBox(height: 12)," \
"              _Head(booking: b),
              BigNumberIn(countdownLabel(daysUntil(b.eventDate))),
              const SizedBox(height: 12),"

echo; echo "== وملخّصُ الصدر =="

# ── ي) ويعود السهمُ الذي لا يفتح شيئاً ────────────────────────────────────
#
# البطاقةُ في الشاشة التي تشير إليها، فسهمٌ فيها يُضغط ولا يقع شيء —
# **ويُعلّم صاحبَه أنّ الضغطَ في هذا التطبيق قد لا يفعل**. وفي تصميم صاحب
# المنصّة سهمٌ، وتُرك حتى يكون له ما يفتحه.
run "(ي) سهمٌ في الملخّص لا يفتح شيئاً" \
  sub "$F" \
"              // **والعددُ في قرصٍ لا في الجملة**: يُلتقط بلمحةٍ ولا يُقرأ.
              _CountBadge(count: summary.count)," \
"              _CountBadge(count: summary.count),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Colors.white),"
# ── ك) ويُكتب عددُ الملخّص بدل حسابه ─────────────────────────────────────
#
# فيقول القرصُ ثمانيةً ولو كانت ثلاثة — **وهو أوّلُ ما تقع عليه العين**.
run "(ك) عددُ الملخّص مكتوبٌ لا محسوب" \
  sub "$F" \
"              _CountBadge(count: summary.count)," \
"              const _CountBadge(count: 8),"
# ── ل) ويُترك من لا قادمَ له بلا تفسير ───────────────────────────────────
#
# فيقرأ قرصاً فيه صفرٌ فوق قائمةٍ مملوءةٍ بحجوزاته الماضية فيظنّها عطباً.
run "(ل) لا يُقال أين ذهب ما مضى" \
  sub "$F" \
"              tr('حجوزاتك السابقة محفوظة أدناه')," \
"              '',"

# ── م) ويعود لوحُ التلاشي ذو اللون الصلب ─────────────────────────────────
#
# **وهذا هو الخيطُ الذي رآه صاحبُ المنصّة** — الصياغةُ الساقطةُ حرفاً: لوحٌ
# يبدأ بـ`_brand.first` صلباً فوق تدرّجٍ قُطريّ، فلا يطابق ما تحته إلّا في
# ركنٍ واحد. والمقياسُ بكسلات: صفٌّ من صورة البطاقة لا يقفز بين بكسلٍ وجاره.
run "(م) لوحُ تلاشٍ بلونٍ صلبٍ فوق التدرّج" \
  sub "$F" \
"    if (url == null) return const SizedBox.shrink();
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF)],
        stops: [0.0, 0.72],
      ).createShader(rect, textDirection: Directionality.of(context)),
      child: MediaThumb(url: url, icon: Icons.photo_camera_back_outlined),
    );" \
"    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          MediaThumb(url: url, icon: Icons.photo_camera_back_outlined),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                BookingsSummaryCard._brand.first,
                BookingsSummaryCard._brand.first.withValues(alpha: 0.55),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.85],
            ),
          ),
        ),
      ],
    );"

# ── ن) والصورةُ تُغطّى بالتدرّج بدل أن تذوب فيه ──────────────────────────
#
# `BlendMode.srcOver` يرسم التدرّجَ **فوق** الصورة، و`dstIn` يضربه في
# شفافيّتها. والأوّلُ يعيد اللوحَ من بابٍ آخر.
run "(ن) التدرّجُ يُرسم فوق الصورة لا في شفافيّتها" \
  sub "$F" \
"      blendMode: BlendMode.dstIn," \
"      blendMode: BlendMode.srcOver,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
