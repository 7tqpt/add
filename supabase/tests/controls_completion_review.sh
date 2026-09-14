#!/usr/bin/env bash
# ضوابطُ سالبةٌ لمراجعة الإدارة لتنفيذ الحجز.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (أ): يعود المزوّد يُتمّ حجزَه بنفسه.** وهو لبُّ
# الطلب كلِّه: سطرٌ واحدٌ يُعاد فيصير كلُّ ما بُني — الزرُّ والسؤالُ
# والشريطُ والمرشِّحُ في اللوحة — زينةً فوق بابٍ مفتوح.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE=completion_review.test.mjs
F=../completion_review.sql

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"
restore() { cp "$BACKUP/f" "$F"; }
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
  if timeout 300 node "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 node "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) يعود المزوّد يُتمّ حجزَه بنفسه ───────────────────────────────────────
#
# **وهذا أخطرُها.** هو الحارسُ الذي من أجله بُني هذا كلُّه.
run "(أ) المزوّد يُتمّ حجزَه" \
  sub "$F" \
"  if not public.can_write_area('bookings') then
    raise exception 'اعتمادُ التنفيذ للإدارة وحدَها.' using errcode = '42501';
  end if;" \
"  if false then
    raise exception 'اعتمادُ التنفيذ للإدارة وحدَها.' using errcode = '42501';
  end if;"

# ── ب) وأيُّ مسؤولٍ يعتمد ولو كان «مطّلعاً» ─────────────────────────────────
#
# كسرٌ أخبث: الحارسُ قائمٌ لكنّه يسأل «أمسؤولٌ أنت؟» لا «أتملك الحجوزات؟» —
# فيعتمد المحاسبُ والمطّلعُ صرفَ مالٍ ليس من مجالهما.
run "(ب) أيُّ مسؤولٍ يعتمد ولو بلا صلاحية الحجوزات" \
  sub "$F" \
"  if not public.can_write_area('bookings') then
    raise exception 'اعتمادُ التنفيذ للإدارة وحدَها.'" \
"  if not public.is_admin() then
    raise exception 'اعتمادُ التنفيذ للإدارة وحدَها.'"

# ── ج) والطلبُ يُحرّك المال قبل المراجعة ────────────────────────────────────
#
# **ولا تُرى هذه في شاشة.** الشاشةُ تقول «قيد مراجعة الإدارة» والمالُ قد
# دخل — فتدفع المنصّةُ عن عملٍ لم يُراجَع، ولا ينبّه شيء.
run "(ج) الطلبُ يُتمّ الحجز" \
  sub "$F" \
"  update public.bookings
     set completion_requested_at  = now(),
         completion_rejected_at   = null,
         completion_reject_reason = ''
   where id = booking.id" \
"  update public.bookings
     set completion_requested_at  = now(),
         status                   = 'completed',
         completed_at             = now(),
         completion_rejected_at   = null,
         completion_reject_reason = ''
   where id = booking.id"

# ── د) ويطلب المزوّدُ اعتمادَ حجزِ غيره ─────────────────────────────────────
run "(د) اعتمادُ حجزِ غيره" \
  sub "$F" \
"  if booking.provider_id is distinct from me then
    raise exception 'الحجز ليس لك.' using errcode = '42501';
  end if;" \
"  if false then
    raise exception 'الحجز ليس لك.' using errcode = '42501';
  end if;"

# ── هـ) والردُّ بلا سبب ─────────────────────────────────────────────────────
run "(هـ) الردُّ بلا سبب" \
  sub "$F" \
"  if reason = '' then
    raise exception 'اكتب سببَ الردّ.' using errcode = '22023';
  end if;" \
"  if false then
    raise exception 'اكتب سببَ الردّ.' using errcode = '22023';
  end if;"

# ── و) والسببُ لا يصل المزوّد ───────────────────────────────────────────────
run "(و) السببُ لا يُرسَل إشعاراً" \
  sub "$F" \
"  perform public.notify_provider(
    booking.provider_id, 'booking', 'رُدَّ طلبُ اعتماد التنفيذ',
    reason," \
"  perform public.notify_provider(
    booking.provider_id, 'booking', 'رُدَّ طلبُ اعتماد التنفيذ',
    'تعذّر'," \

# ── ز) والطلبُ يُعاد ولا يُمحى أثرُ الردّ ───────────────────────────────────
#
# فيبقى المزوّدُ يرى سببَ ردٍّ قديمٍ وقد أعاد طلبَه، فيظنّه رُدَّ ثانيةً.
run "(ز) أثرُ الردّ يبقى بعد الطلب الجديد" \
  sub "$F" \
"         completion_rejected_at   = null,
         completion_reject_reason = ''
   where id = booking.id
  returning * into booking;

  return booking;
end;
\$\$;" \
"   where id = booking.id
  returning * into booking;

  return booking;
end;
\$\$;"

# ── ح) والاعتمادُ لا يفتح بابَ التقييم ──────────────────────────────────────
#
# وهو ما يتأخّر بهذا التغيير كلِّه، فلا يُقبل أن يضيع معه.
run "(ح) لا يُفتح بابُ التقييم للعميل" \
  sub "$F" \
"  perform public.notify_user(
    booking.user_id, 'review', 'كيف كانت الخدمة؟'," \
"  perform public.notify_user(
    booking.user_id, 'booking', 'كيف كانت الخدمة؟',"

# ── ط) والمستحقّاتُ تزيد بالإجمالي لا بالصافي ───────────────────────────────
#
# فتدفع المنصّةُ عمولتَها للمزوّد — وهي خسارةٌ صامتةٌ لا يشكو منها أحد.
run "(ط) المستحقّاتُ بالإجمالي لا بالصافي" \
  sub "$F" \
"         total_earnings = total_earnings + (booking.total_price - booking.commission_amount)" \
"         total_earnings = total_earnings + booking.total_price"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
