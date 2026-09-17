#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقة العميل.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وهذه الدالّةُ `security definer` — أي أنّها تتجاوز سياسةَ `app_users`
# بتصميمها.** فحدُّها الوحيدُ ما كُتب في جسدها، وهذه الضوابطُ هي التي تُثبت
# أنّ ذلك الحدَّ يحرس فعلاً. وأخطرُ ثلاثةٍ فيها:
#
#   ــ (أ) يُشال شرطُ «وأن يكون هو طرفَها»، فيقرأ أيُّ مقدّمِ خدمةٍ بطاقةَ
#     أيّ عميلٍ بمعرّف محادثةٍ ليست له.
#   ــ (ج) يخرج البريدُ مع الصورة — وهو ما قيل إنّه لن يخرج.
#   ــ (د) يُحسب سجلُّ العميل مع **كلّ** المزوّدين لا معك، فيرى مقدّمُ خدمةٍ
#     كم أنفق عميلُه عند منافسيه.
set -uo pipefail
cd "$(dirname "$0")/../.."
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE="supabase/tests/customer_card.test.mjs"
F=supabase/customer_card.sql

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f.sql"
restore() { cp "$BACKUP/f.sql" "$F"; }
trap 'restore; rm -rf "$BACKUP"' EXIT
PASS=0; FAIL=0

sub() {
  local old="$1" new="$2" n
  n=$(python3 - "$F" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1; fi
  python3 - "$F" "$old" "$new" <<'PY'
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
  if node "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if node "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) تُقرأ محادثةٌ ليست له ────────────────────────────────────────────────
#
# **وهذا أخطرُها.** الدالّةُ تتجاوز السياسة، فلو سقط هذا الشرطُ لَقرأ أيُّ
# مقدّمِ خدمةٍ بطاقةَ أيّ عميلٍ بمعرّفٍ يُخمَّن أو يُسرَّب.
run "(أ) بلا شرط «طرفُها»" \
  sub "  where c.id = p_conversation_id and c.provider_id = mine;" \
      "  where c.id = p_conversation_id;"

# ── ب) وتُفتح لغير مقدّمي الخدمة ────────────────────────────────────────────
run "(ب) بلا شرط مقدّم الخدمة" \
  sub "  if mine is null then
    raise exception 'هذه لمقدّمي الخدمة.' using errcode = '42501';
  end if;" \
      "  -- كُسر"

# ── ج) ويخرج البريدُ مع الصورة ──────────────────────────────────────────────
#
# **وهو ما قيل إنّه لن يخرج.** ولا يسقط هذا بسؤال «أتعمل الدالّة؟» — تعمل.
# يسقط لأنّ الأعمدةَ تُعدّ وتُفتَّش قيمُها عن `@`.
run "(ج) يخرج البريدُ مع الصورة" \
  sub "    u.avatar_path,
    u.governorate," \
      "    u.avatar_path,
    u.email,
    u.governorate,"

# ── د) ويُحسب سجلُّه مع كلّ المزوّدين ───────────────────────────────────────
#
# **وهذا تسريبُ منافسة، لا خطأَ حساب.** يرى مقدّمُ الخدمة كم حجز عميلُه عند
# غيره وكم أنفق عندهم.
run "(د) السجلُّ مع كلّ المزوّدين" \
  sub "    (select count(*)::integer from public.bookings b
      where b.user_id = customer and b.provider_id = mine)," \
      "    (select count(*)::integer from public.bookings b
      where b.user_id = customer),"

# ── هـ) ويصير «ما دُفع» هو «ما وُعد» ────────────────────────────────────────
#
# `total_price` بدل `paid_amount - refunded_amount`: فيُعرض على مقدّم الخدمة
# مالٌ لم يقبضه.
run "(هـ) يُحسب الموعودُ لا المدفوع" \
  sub "    (select coalesce(sum(b.paid_amount - b.refunded_amount), 0) from public.bookings b" \
      "    (select coalesce(sum(b.total_price), 0) from public.bookings b"

# ── و) وتُمنح للعموم ────────────────────────────────────────────────────────
#
# `anon` يعني من لا حسابَ له أصلاً. **ولا يسقط هذا بقياس ما تُرجعه** — يسقط
# لأنّ من لا جلسةَ له يُستدعى بها فيُقاس ردُّها.
run "(و) تُمنح لمن لا حساب له" \
  sub "grant execute on function public.api_customer_card(uuid) to authenticated;" \
      "grant execute on function public.api_customer_card(uuid) to authenticated, anon;
alter function public.api_customer_card(uuid) security invoker;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
