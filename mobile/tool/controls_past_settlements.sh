#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«تسويات سابقة» داخل «رصيد فرحتي» وحذفِ «مستحقّاتي» من القائمة
# — تكسر كلَّ ضمانةٍ مرّةً بشيفرةٍ صالحة، وتتأكّد أنّ الحزمةَ تحمرّ، وتطبع ما سقط.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/provider_wallet_test.dart test/provider_profile_test.dart"
FILES="lib/src/screens/provider_wallet.dart lib/src/screens/provider_profile.dart"

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

# ── أ) يعود البندُ المكرَّر إلى القائمة ──────────────────────────────────────
#
# **وهذا ما سأل عنه صاحبُ المنصّة:** «ليش مكرر». بابٌ ثانٍ لمالٍ واحد — يُفتح
# على الرصيد نفسِه فلا يُبنى شيءٌ مكسور، ويبقى السؤالُ قائماً.
run "(أ) «مستحقّاتي» تعود بنداً" sub lib/src/screens/provider_profile.dart \
"                MenuRow(
                  icon: Icons.support_agent_outlined," \
"                MenuRow(
                  icon: Icons.receipt_long_outlined,
                  label: tr('مستحقّاتي'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProviderWalletScreen()),
                  ),
                ),
                MenuRow(
                  icon: Icons.support_agent_outlined,"

# ── ب) القسمُ لا يُرسم — فتغيب التسوياتُ القديمةُ عن صاحبها ─────────────────
run "(ب) التسوياتُ القديمةُ تغيب" sub lib/src/screens/provider_wallet.dart \
"                  if (list.isEmpty) return const SizedBox.shrink();" \
"                  if (list.isNotEmpty || list.isEmpty) return const SizedBox.shrink();"

# ── ج) ويُرسم لمن لا تسويةَ له — عنوانٌ فوق فراغ ────────────────────────────
run "(ج) القسمُ لمن لا تسويةَ له" sub lib/src/screens/provider_wallet.dart \
"                  if (list.isEmpty) return const SizedBox.shrink();
" \
""

# ── د) الصافي وحده بلا المقبوض والعمولة ─────────────────────────────────────
run "(د) العمولةُ لا تُكتب" sub lib/src/screens/provider_wallet.dart \
"        KeyValue(tr('عمولة المنصّة'), formatMoney(s.commission))," \
""

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
