#!/usr/bin/env bash
# ضوابطُ سالبةٌ لردّ المبلغ في اللوحة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (أ): يعود الردُّ يكتب في الجدول مباشرةً.** وهي الحالُ
# التي كانت: تصير الدفعةُ `refunded` والحجزُ لا يعلم، فيحسب `settlements.sql`
# مستحقَّ المزوّد من `paid_amount - refunded_amount` كأنّ الردَّ لم يكن —
# فتردُّ للعميل ٥٠٠٬٠٠٠ وتدفع للمزوّد ٤٥٠٬٠٠٠ من جيبك.
#
# **وحارسُ القاعدة في `supabase/tests/controls_refund_payment.sh`.** هذه
# للوحة وحدَها: أنّها تطرق البابَ الصحيح وتُري ما وراءه قبل الضغط.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v npx >/dev/null || { echo "لا npx في المسار"; exit 1; }

SUITE=test/refund.test.ts
F=src/services/finance.ts
P=src/pages/Payments.tsx

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$P" "$BACKUP/p"
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/p" "$P"; }
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

# **والبناءُ يُحسب كسقوط.** كسرٌ يمنع `tsc -b` عطلٌ يمسكه المسار، فلا يُعدّ
# «حزمةً خضراءَ وضمانةً مكسورة».
green() {
  npx vitest run "$SUITE" >/dev/null 2>&1 && npx tsc -b >/dev/null 2>&1
}

run() {
  local name="$1"; shift
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  if green; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if green; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) يعود الردُّ يكتب في الجدول ───────────────────────────────────────────
#
# **وهذا أخطرُها** — وشرحُه في رأس الملفّ. وهو العطلُ الذي كان قائماً.
run "(أ) الردُّ يكتب في الجدول مباشرةً" \
  sub "$F" \
"    const { error } = await requireSupabase().rpc('api_admin_refund_payment', {
      p_payment_id: payment.id,
      p_reason: '',
    })" \
"    const { error } = await requireSupabase()
      .from('payments')
      .update({ status: 'refunded', refunded_at })
      .eq('id', payment.id)
      .eq('status', 'paid')"

# ── ب) وخطأُ القاعدة يُبتلع ─────────────────────────────────────────────────
#
# ردٌّ يفشل ويُقال للمسؤول «تمّ» أسوأُ من ردٍّ لم يقع: يُغلق الملفَّ ويظنّ
# المالَ خرج.
run "(ب) الخطأُ يُبتلع" \
  sub "$F" \
"    if (error) throw error
  }

  await recordAudit({
    action: 'payment.refund'," \
"  }

  await recordAudit({
    action: 'payment.refund',"

# ── ج) ولا يُسأل عن حال التسوية ─────────────────────────────────────────────
run "(ج) لا سؤالَ عن حال التسوية" \
  sub "$F" \
"  const { data, error } = await requireSupabase().rpc('api_refund_outlook', {
    p_payment_id: payment.id,
  })" \
"  const { data, error } = { data: { refundable: true, amount: payment.amount,
    settlement: 'none' }, error: null }"

# ── د) و«دُفع» تُقرأ «قيد الاحتساب» ─────────────────────────────────────────
#
# **وطمسُ الفرق يجعل التنبيهَ زينة:** ما دُفع لا يُستردّ، وما هو قيد الاحتساب
# يُعدَّل تلقائياً — ولونُ الشريط ونصُّه يقومان على هذا الفرق وحدَه.
run "(د) لا يُفرَّق بين المحتسَب والمدفوع" \
  sub "$F" \
"  return data as RefundOutlook" \
"  return { ...(data as RefundOutlook), settlement: 'pending' }"

# ── هـ) والحوارُ لا يعرض الشريط ─────────────────────────────────────────────
#
# **ولا تسقط هذه بحزمة `test/`** — لا jsdom فيها، والشرطُ في الصفحة لا في
# الخدمة. فيُقاس ببناء الأنواع: الشريطُ يُشال فيبقى المكوّنُ بلا مستعمل،
# و`tsc -b` يُسقطه (`noUnusedLocals`). وهو قياسٌ غيرُ مباشرٍ ويُقال إنّه كذلك.
run "(هـ) الشريطُ لا يُعرض في الحوار" \
  sub "$P" \
"        {action === 'refund' && outlook && outlook.settlement !== 'none' ? (
          <SettlementNotice paid={outlook.settlement === 'paid'} />
        ) : null}" \
"        {null}"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
