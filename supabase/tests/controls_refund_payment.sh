#!/usr/bin/env bash
# ضوابطُ سالبةٌ لردّ المبلغ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (أ): يعود الردُّ لا يمسّ الحجز.** وهي الحالُ التي
# كانت: تصير الدفعةُ `refunded` و`refunded_amount` صفرٌ، فتحسب التسويةُ
# مستحقَّ المزوّد من `paid_amount - refunded_amount` كأنّ الردَّ لم يكن —
# فتردُّ للعميل ٥٠٠٬٠٠٠ وتدفع للمزوّد ٤٥٠٬٠٠٠ من جيبك، **بلا أثرٍ ولا
# تنبيه**.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE=refund_payment.test.mjs
F=../payments_app.sql

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
  if timeout 400 node --test "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 400 node --test "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) الحجزُ لا يُمسّ ──────────────────────────────────────────────────────
#
# **وهذا أخطرُها** — وشرحُه في رأس الملفّ. وهو العطلُ الذي كان قائماً.
#
# **ولا يسقط هذا بسؤال «أصارت الدفعةُ refunded؟»** — فقد كانت تصير. يسقط
# لأنّ المستحقَّ يُبنى فعلاً ويُقاس رقمُه.
run "(أ) الردُّ لا يُقيَّد في الحجز" \
  sub "$F" \
"    update public.bookings
       set refunded_amount = least(refunded_amount + pay.amount, paid_amount)
     where id = pay.booking_id
    returning * into bk;" \
"    select * into bk from public.bookings where id = pay.booking_id;"

# ── ب) ويُردُّ المبلغُ مرّتين ───────────────────────────────────────────────
#
# مسؤولان يضغطان معاً فيُخصم المبلغُ من الحجز مرّتين — ويصير المزوّدُ مديناً
# بما لم يقبضه.
run "(ب) لا شرطَ يمنع ردّاً ثانياً" \
  sub "$F" \
"   where id = p_payment_id and status = 'paid'" \
"   where id = p_payment_id"

# ── ج) والقيدُ يتجاوز المقبوض ───────────────────────────────────────────────
#
# `least` تحرس `refund_within_paid`. وبلا حراسةٍ تسقط المعاملةُ بقيدٍ لا
# يفهمه المسؤول — ولا يُردّ شيءٌ ولا يعلم لماذا.
run "(ج) المردودُ يتجاوز المقبوض" \
  sub "$F" \
"       set refunded_amount = least(refunded_amount + pay.amount, paid_amount)" \
"       set refunded_amount = refunded_amount + pay.amount * 3"

# ── د) ومن لا يملك الكتابةَ يردّ ────────────────────────────────────────────
#
# **ولا يحرس زرٌّ في اللوحة شيئاً:** حزمةٌ مفكوكةٌ تستدعي الدالّة مباشرةً.
run "(د) لا حارسَ للصلاحية" \
  sub "$F" \
"  if not public.can_write() then
    raise exception 'لا تملك صلاحية ردّ المبالغ';
  end if;

  -- **والشرطُ" \
"  if false then
    raise exception 'لا تملك صلاحية ردّ المبالغ';
  end if;

  -- **والشرطُ"

# ── هـ) والعميلُ لا يُخبَر ──────────────────────────────────────────────────
#
# مالٌ يُردّ ولا يعلم صاحبُه أنّه رُدّ يفتح تذكرةَ دعمٍ — أو يُسيء الظنّ.
run "(هـ) لا خبرَ للعميل" \
  sub "$F" \
"  perform public.notify_user(
    pay.user_id, 'payment', 'رُدَّ مبلغُك'," \
"  perform public.notify_user(
    null, 'payment', 'رُدَّ مبلغُك',"

# ── و) وحالُ التسوية تُقال «لا شيء» أبداً ───────────────────────────────────
#
# **وهذا أخبثُها في بابه:** الدالّةُ تعمل وتُرجع جواباً — جواباً كاذباً
# يُطمئن. فيردُّ المسؤولُ وهو يحسب أنّ المالَ ما زال عنده، وقد دُفع.
run "(و) التسويةُ تُقال «لا شيء» دائماً" \
  sub "$F" \
"  return jsonb_build_object(
    'refundable', pay.status = 'paid',
    'amount',     pay.amount,
    'settlement', coalesce(settled, 'none')
  );" \
"  return jsonb_build_object(
    'refundable', pay.status = 'paid',
    'amount',     pay.amount,
    'settlement', 'none'
  );"

# ── ز) و«دُفع» تُقال «قيد الاحتساب» ─────────────────────────────────────────
#
# فرقٌ بين مستحقٍّ احتُسب ولم يُدفع (يُعدَّل) ومستحقٍّ **دُفع** (لا يُستردّ).
# وطمسُ الفرق يجعل التنبيهَ زينةً.
run "(ز) لا يُفرَّق بين المحتسَب والمدفوع" \
  sub "$F" \
"  select case when s.status = 'paid' then 'paid' else 'pending' end
    into settled
    from public.settlement_items i
    join public.settlements s on s.id = i.settlement_id
   where i.booking_id = pay.booking_id
   order by case when s.status = 'paid' then 0 else 1 end
   limit 1;

  return jsonb_build_object(
    'refundable'," \
"  select 'pending'
    into settled
    from public.settlement_items i
    join public.settlements s on s.id = i.settlement_id
   where i.booking_id = pay.booking_id
   limit 1;

  return jsonb_build_object(
    'refundable',"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
