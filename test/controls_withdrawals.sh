#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«طلبات السحب» في اللوحة — `test/wallet.test.ts`، ثمّ المقيسُ
# في المتصفّح (`tool/dashboard_shots.mjs`). تكسر كلَّ ضمانةٍ مرّةً بشيفرةٍ صالحة،
# وتتأكّد أنّ ما يقيسها يحمرّ، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")/.."

FILES="src/services/wallet.ts src/pages/Withdrawals.tsx src/components/layout/nav.ts src/services/bookings.ts src/pages/Bookings.tsx src/pages/BookingDetail.tsx src/pages/Settlements.tsx"
BACKUP=$(mktemp -d)
for f in $FILES; do mkdir -p "$BACKUP/$(dirname "$f")"; cp "$f" "$BACKUP/$f"; done
restore() { for f in $FILES; do cp "$BACKUP/$f" "$f"; done; }
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
  local kind="$1" name="$2"; shift 2
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  local out green
  if [ "$kind" = unit ]; then
    out=$(npx vitest run test/wallet.test.ts test/invoice.test.ts 2>&1)
    echo "$out" | grep -qE "Tests +[0-9]+ passed \(" && green=1 || green=0
  else
    if ! npm run build >/dev/null 2>&1; then
      echo "✗ $name — البناءُ سقط، فالمقيسُ نسخةٌ قديمة"; FAIL=$((FAIL+1)); restore; return
    fi
    out=$(SHOTS="$BACKUP/shots" node tool/dashboard_shots.mjs 2>&1)
    echo "$out" | grep -q "كلُّ ما قيس أخضر" && green=1 || green=0
  fi
  if [ "$green" = 1 ]; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "^ +×|^❌" | sort -u | head -3 | sed 's/^/   /'
    PASS=$((PASS+1))
  fi
  restore
}

run unit "(أ) الأرقامُ العربيّةُ لا تُوحَّد" sub src/services/wallet.ts \
  "  const latin = (account ?? '').replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x660))" \
  "  const latin = (account ?? '')"

run unit "(ب) رفضُ السحب بلا سبب" sub src/services/wallet.ts \
  "  if (!paid && !note.trim()) throw new Error('اكتب سبب الرفض — يصل العميل')
  if (!isSupabaseConfigured) {
    const target = demoWithdrawals" \
  "  if (!isSupabaseConfigured) {
    const target = demoWithdrawals"

run unit "(ج) الاعتمادُ بأكثر ممّا حُسب" sub src/services/wallet.ts \
  "  if (approve && amount !== null && (amount <= 0 || amount > refund.amount)) {" \
  "  if (approve && amount !== null && amount < 0) {"

# لا يُحذف السطرُ: يبقى `Wallet` مستورَداً بلا استعمالٍ فيسقط البناءُ لا الفحص.
# فيُبدَّل اسمُه — والفحصُ يسأل القائمةَ عن «طلبات السحب».
run browser "(د) الصفحةُ تغيب عن القائمة" sub src/components/layout/nav.ts \
  "label: 'طلبات السحب', icon: Wallet" "label: 'السحوبات', icon: Wallet"

run browser "(هـ) رقمُ سجلّ الدفع لا يُعرض" sub src/pages/Withdrawals.tsx \
  "<span dir=\"ltr\" data-paid-account className=\"tnum\">{w.paid_account ?? '—'}</span>" \
  "<span dir=\"ltr\" data-paid-account className=\"tnum\"></span>"

run browser "(و) الرفضُ يُضغط بلا سبب" sub src/pages/Withdrawals.tsx \
  "        confirmDisabled={withdrawalAction !== null && !withdrawalAction.paid && !note.trim()}" \
  "        confirmDisabled={false}"

run unit "(ز) رقمُ الفاتورة لا يُبحث به" sub src/services/bookings.ts \
  "  return term.replace(/^inv-/i, 'BK-')" "  return term"

run unit "(ح) فاتورةٌ عشوائيّةٌ في التجربة" sub src/services/bookings.ts \
  "      invoice_number: issued ? booking.reference.replace(/^BK-/, 'INV-') : null," \
  "      invoice_number: issued ? \`INV-\${booking.id}\` : null,"

run browser "(ط) القائمةُ بلا رقم الفاتورة" sub src/pages/Bookings.tsx \
  "                          {invoiceLine(booking)}
                        </span>" "                          {invoiceLine(booking) ? '' : ''}
                        </span>"

run browser "(ي) صفحةُ الحجز بلا رقم الفاتورة" sub src/pages/BookingDetail.tsx \
  "                  <span>رقم الفاتورة</span>" "                  <span></span>"

run unit "(ك) رفضُ حساب المزوّد بلا سبب" sub src/services/wallet.ts \
  "  if (!approve && !note.trim()) throw new Error('اكتب سبب الرفض — يصل مقدّم الخدمة')" \
  "  if (approve && !note.trim() && note === 'never') throw new Error('')"

run browser "(ل) حساباتُ المزوّدين لا تُعرض" sub src/pages/Withdrawals.tsx \
  "      {accounts.data && accounts.data.length > 0 ? (" "      {accounts.data && accounts.data.length < 0 ? ("

run browser "(م) «مستحقات الشركاء» بلا تنبيه" sub src/pages/Settlements.tsx \
  "        data-settlements-note" "        data-settlements-old"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
npm run build >/dev/null 2>&1
[ "$FAIL" = 0 ]
