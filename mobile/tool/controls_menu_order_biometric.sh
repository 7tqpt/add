#!/usr/bin/env bash
# ضوابطُ سالبةٌ لترتيب أبواب الشاشتين ولصفّ البصمة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/menu_order_test.dart test/account_biometric_row_test.dart"

A=lib/src/screens/account.dart
P=lib/src/screens/provider_profile.dart

FILES=("$A" "$P")
BACKUP=$(mktemp -d)
for i in "${!FILES[@]}"; do cp "${FILES[$i]}" "$BACKUP/$i"; done
restore() { for i in "${!FILES[@]}"; do cp "$BACKUP/$i" "${FILES[$i]}"; done; }
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
  if timeout 600 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== ضوابطُ ترتيب «حسابي» =="

# ── أ) يعود بابُ المزوّد إلى آخر المجموعة ──────────────────────────────────
run "(أ) بابُ المزوّد يعود سادساً" \
  sub "$A" \
"              label: provider
                  ? tr('التبديل إلى وضع مقدّم الخدمة')
                  : tr('أريد تقديم خدمة')," \
"              label: provider
                  ? tr('التبديل إلى وضع مقدّم الخدمة ')
                  : tr('أريد تقديم خدمة '),"

echo; echo "== ضوابطُ صفّ البصمة =="

# ── ب) ويذهب الصفُّ من القائمة ─────────────────────────────────────────────
run "(ب) لا صفَّ بصمةٍ أصلاً" \
  sub "$A" \
"            if (appLock.enabled && _canBiometric)" \
"            if (false && appLock.enabled && _canBiometric) // ignore: dead_code"

# ── ج) ويُعرض لجهازٍ لا حسّاسَ فيه ─────────────────────────────────────────
#
# مفتاحٌ يُرفع فلا يقع شيءٌ أسوأُ من مفتاحٍ غائب.
run "(ج) يُعرض بلا حسّاس" \
  sub "$A" \
"            if (appLock.enabled && _canBiometric)" \
"            if (appLock.enabled)"

# ── د) ويُعرض بلا قفلٍ تحته ────────────────────────────────────────────────
run "(د) يُعرض بلا قفل" \
  sub "$A" \
"            if (appLock.enabled && _canBiometric)" \
"            if (_canBiometric)"

# ── هـ) ولا يصل التفضيلُ الخزنةَ ───────────────────────────────────────────
#
# **وهذا أخطرُها لأنّه لا يُرى عطباً**: المفتاحُ يرتفع في العين، والرسالةُ
# تُقال، ولا شيءَ يُكتب — فيعود صاحبُه بعد إقلاعٍ فيجده منخفضاً ولا يفهم.
run "(هـ) التفضيلُ لا يصل الخزنة" \
  sub "$A" \
"      await appLock.setBiometric(on);" \
"      if (!on) await appLock.setBiometric(on);"

# ── و) وتُكتب البصمةُ بلا أن تُقرأ ─────────────────────────────────────────
#
# مفتاحٌ يَعِد بما لم يُختبَر: يرتفع بلا تجربة، فإن أخفق الحسّاسُ يومَ
# الحاجة وجد صاحبُه وعداً لم يُوفَّ به.
run "(و) تُكتب بلا تجربة" \
  sub "$A" \
"      if (on && !await biometrics.authenticate()) {" \
"      if (false && on && !await biometrics.authenticate()) { // ignore: dead_code"

echo; echo "== ضوابطُ ترتيب المزوّد =="

# ── ز) وتعود «العودة إلى وضع العميل» إلى آخر القائمة ───────────────────────
run "(ز) «العودة» تعود سابعةً" \
  sub "$P" \
"                MenuRow(
                  icon: Icons.swap_horiz,
                  label: tr('العودة إلى وضع العميل'),
                  onTap: () => widget.session.switchTo(provider: false),
                )," \
"                MenuRow(
                  icon: Icons.swap_horiz,
                  label: tr('العودة إلى وضع العميل '),
                  onTap: () => widget.session.switchTo(provider: false),
                ),"

# ── ح) ويعود الفاصلُ فيقطع البطاقة ─────────────────────────────────────────
run "(ح) عودةُ الفاصل" \
  sub "$P" \
"                MenuRow(
                  icon: Icons.workspace_premium_outlined," \
"                const MenuGap(),
                MenuRow(
                  icon: Icons.workspace_premium_outlined,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
