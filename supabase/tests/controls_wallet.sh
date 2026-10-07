#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«رصيد فرحتي» — `wallet.sql` ورقمُ الفاتورة في `coupons.sql`.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً بشيفرةٍ صالحة، وتتأكّد أنّ `wallet.test.mjs`
# يحمرّ — **وتطبع ما سقط** ليُرى أنّه سقط للسبب المقصود. ورقمُ الفاتورة يُكسر
# في الأصل ثمّ تُركَّب حزمةُ التحصين منه كما يُفعل عند كلّ تعديل.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

FILES="../wallet.sql ../coupons.sql ../security_hardening.sql"
BACKUP=$(mktemp -d)
for f in $FILES; do cp "$f" "$BACKUP/$(basename "$f")"; done
restore() { for f in $FILES; do cp "$BACKUP/$(basename "$f")" "$f"; done; }
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

rebuild() { node ../../tool/security_sql.mjs hardening > ../security_hardening.sql; }

run() {
  local name="$1"; shift
  restore
  if ! "$@" || ! rebuild; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  local out
  out=$(timeout 600 node wallet.test.mjs 2>&1)
  if echo "$out" | grep -q "كلُّ ما قيس أخضر"; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "^❌|^error" | cut -c1-150 | sed 's/^/     /' | head -3
    PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 node wallet.test.mjs >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi
echo

run "(أ) إبلاغٌ بلا رقم المحوِّل" sub ../wallet.sql \
  "  if length(public.wallet_norm(sender)) < 6 then" "  if false then"

run "(ب) الاسترجاعُ المحسوبُ يدخل الرصيدَ بلا اعتماد" sub ../wallet.sql \
  "  if new.kind = 'refund' and new.wallet_state is null then
    new.wallet_state := 'pending';
  end if;" "  if new.kind = 'refund' and new.wallet_state is null then
    new.wallet_state := 'pending';
    perform public.wallet_credit_refund(new, new.amount);
  end if;"

run "(ج) السحبُ إلى أيّ رقم" sub ../wallet.sql \
  "     and public.wallet_norm(p.payer_account) = acct" "     and acct <> ''"

run "(د) الرقمُ لا يُوحَّد (أرقامٌ عربيّة)" sub ../wallet.sql \
  "             translate(coalesce(p_account, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')," \
  "             coalesce(p_account, '')," 

run "(هـ) السحبُ لا يُحجز من الرصيد" sub ../wallet.sql \
  "  insert into public.wallet_entries (user_id, amount, kind, withdrawal_id, note)
  values (me, -p_amount, 'withdrawal', wd.id, 'طلب سحب ' || wd.reference);" \
  "  insert into public.wallet_entries (user_id, amount, kind, withdrawal_id, note)
  select me, -p_amount, 'withdrawal', wd.id, 'طلب سحب ' || wd.reference where false;"

run "(و) رفضُ السحب لا يُعيد المبلغ" sub ../wallet.sql \
  "  if not p_paid then
    -- الرفضُ يُعيد" \
  "  if false then
    -- الرفضُ يُعيد"

run "(ز) الدفعُ من رصيدٍ لا يكفي" sub ../wallet.sql \
  "  if bal < due then" "  if bal < 0 then"

run "(ح) «ردّ المبلغ» لا يدخل الرصيد" sub ../wallet.sql \
  "  if new.kind <> 'refund' and old.status = 'paid' and new.status = 'refunded' then" \
  "  if false then"

run "(ط) الاعتمادُ بأكثر ممّا حُسب" sub ../wallet.sql \
  "  if p_approve and (amount <= 0 or amount > pay.amount) then" \
  "  if p_approve and amount <= 0 then"

run "(ي) رفضُ الاسترجاع لا يُعيده للحجز" sub ../wallet.sql \
  "  if pay.booking_id is not null and credited < pay.amount then" \
  "  if false then"

run "(ك) الغريبُ يرى الدفتر" sub ../wallet.sql \
  "  using (user_id = public.current_app_user() or provider_id = public.current_provider()
         or public.can_read_area('finance'));

drop policy if exists wallet_withdrawals_owner_read" \
  "  using (true);

drop policy if exists wallet_withdrawals_owner_read"

run "(ل) رقمُ الفاتورة عشوائيٌّ كما كان" sub ../coupons.sql \
  "      case when booking.reference like 'BK-%' then 'INV-' || substr(booking.reference, 4)" \
  "      case when false then ''"

run "(م) التنفيذُ لا يُدخل رصيدَ المزوّد" sub ../wallet.sql \
  "  if new.status = 'completed' and old.status is distinct from 'completed'" \
  "  if false and old.status is distinct from 'completed'"

run "(ن) السحبُ إلى حسابٍ لم يُوثَّق" sub ../wallet.sql \
  "  if acc.status <> 'verified' then" "  if acc.status = 'never' then"

run "(س) تغييرُ الحساب يُبقيه موثَّقاً" sub ../wallet.sql \
  "        holder_name = excluded.holder_name, status = 'pending', note = ''," \
  "        holder_name = excluded.holder_name, note = '',"

run "(ع) التسويةُ تحتسب ما دخل الرصيد" sub ../wallet.sql \
  "       and not exists (select 1 from public.wallet_entries e where e.booking_id = b.id and e.kind = 'earning')" \
  "       and true"

run "(ف) رفضُ سحب المزوّد لا يعود لرصيده" sub ../wallet.sql \
  "    values (wd.user_id, wd.provider_id, wd.amount, 'withdrawal_reversal', wd.id," \
  "    values (wd.user_id, null, wd.amount, 'withdrawal_reversal', wd.id,"

run "(ص) مزوّدٌ يرى حركاتِ غيره" sub ../wallet.sql \
  "  using (user_id = public.current_app_user() or provider_id = public.current_provider()
         or public.can_read_area('finance'));

drop policy if exists wallet_withdrawals_owner_read" \
  "  using (user_id = public.current_app_user() or provider_id is not null
         or public.can_read_area('finance'));

drop policy if exists wallet_withdrawals_owner_read"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
