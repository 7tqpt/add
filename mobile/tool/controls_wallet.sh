#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«رصيد فرحتي» ورقمِ الفاتورة في التطبيق — تكسر كلَّ ضمانةٍ
# مرّةً بشيفرةٍ صالحة، وتتأكّد أنّ الحزمةَ تحمرّ، وتطبع ما سقط.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/wallet_test.dart test/invoice_number_test.dart test/provider_wallet_test.dart"
FILES="lib/src/data/demo.dart lib/src/screens/payment.dart lib/src/screens/wallet.dart lib/src/screens/booking_detail.dart lib/src/data/supabase.dart lib/src/screens/provider_wallet.dart"

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
  local name="$1"; shift
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  local out
  out=$(timeout 900 flutter test -r expanded $SUITE 2>&1)
  if echo "$out" | grep -q "All tests passed"; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  elif echo "$out" | grep -q "Compilation failed"; then
    echo "✗ $name — لم يُبنَ، فلم يُقس شيء"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "\[E\]$" | sed -E 's/^.*test\/([^:]+): /     • \1: /' | sort -u | head -4
    PASS=$((PASS+1))
  fi
  restore
}

run "(أ) الأرقامُ العربيّةُ لا تُوحَّد" sub lib/src/data/demo.dart \
  "    if (rune >= 0x660 && rune <= 0x669) buffer.writeCharCode(rune - 0x660 + 0x30);
    if (rune >= 0x6F0 && rune <= 0x6F9) buffer.writeCharCode(rune - 0x6F0 + 0x30);
  }
  final digits = buffer.toString();" \
  "  }
  final digits = buffer.toString();"

run "(ب) السحبُ إلى أيّ رقم" sub lib/src/data/demo.dart \
  "  if (!demoPaidAccounts.any((a) => walletNorm(a) == acct)) {" \
  "  if (demoPaidAccounts.isEmpty) {"

run "(ج) السحبُ لا يُحجز من الرصيد" sub lib/src/data/demo.dart \
  "  demoWalletEntries = [entry, ...demoWalletEntries];
  return entry;" \
  "  return entry;"

run "(د) الدفعُ من رصيدٍ لا يكفي يُضغط" sub lib/src/screens/payment.dart \
  "          onPressed: enough && !busy ? onPay : null," \
  "          onPressed: !busy ? onPay : null,"

run "(هـ) إبلاغٌ بلا رقم المحوِّل يُرسل" sub lib/src/screens/payment.dart \
  "    if (walletDigits(_senderRef.text).length < 6) {" \
  "    if (false) {"

run "(و) بطاقةُ الرصيد لمن لا رصيدَ له" sub lib/src/screens/payment.dart \
  "              if (balance <= 0) return const SizedBox.shrink();" \
  "              if (balance < 0) return const SizedBox.shrink();"

run "(ز) الاسترجاعُ المنتظرُ لا يُقال" sub lib/src/screens/wallet.dart \
  "              if (wallet.pendingRefunds > 0) ...[" \
  "              if (wallet.pendingRefunds < 0) ...["

run "(ح) رقمُ الفاتورة لا يُكتب تحت الحجز" sub lib/src/screens/booking_detail.dart \
  "                  if (number == null && !waiting) return const SizedBox.shrink();" \
  "                  if (number == null || !waiting) return const SizedBox.shrink();"

run "(ط) «Bad state:» قبل الرسالة" sub lib/src/data/supabase.dart \
  "  return text.replaceFirst(RegExp(r'^(Bad state|Exception|StateError): '), '');" \
  "  return text;"

run "(ي) المزوّدُ يسحب إلى حسابٍ لم يُوثَّق" sub lib/src/screens/provider_wallet.dart \
  "    final canWithdraw = account?.verified == true && !_editing && widget.wallet.balance > 0;" \
  "    final canWithdraw = account != null && widget.wallet.balance > 0;"

run "(ك) تغييرُ الحساب يُبقيه موثَّقاً" sub lib/src/data/demo.dart \
  "    method: method, account: account.trim(), holderName: holderName.trim(), status: 'pending'," \
  "    method: method, account: account.trim(), holderName: holderName.trim(), status: 'verified',"

run "(ل) ما ينتظر التنفيذ لا يُقال" sub lib/src/screens/provider_wallet.dart \
  "              if (wallet.pending > 0) ...[" "              if (wallet.pending < 0) ...["

run "(م) صافي الحجز بلا اسمه في الحركات" sub lib/src/screens/wallet.dart \
  "    'earning' => (icon: Icons.event_available_outlined, title: tr('حجزٌ منفَّذ'), color: AppColors.good)," ""

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
