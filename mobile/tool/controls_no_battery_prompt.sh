#!/usr/bin/env bash
# ضابطٌ سالبٌ لمنع حوار البطّاريّة: لا يُفتح من أيّ موضعٍ تلقائيّاً.
#
# يكسر الضمانةَ كسراً واحداً ويتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط بالكسر
# ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/notification_tone_test.dart"
C=lib/src/screens/customer_shell.dart
P=lib/src/screens/provider_shell.dart
E=lib/src/screens/explore.dart

FILES=("$C" "$P" "$E")
BACKUP=$(mktemp -d)
for i in "${!FILES[@]}"; do cp "${FILES[$i]}" "$BACKUP/$i"; done
restore() { for i in "${!FILES[@]}"; do cp "$BACKUP/$i" "${FILES[$i]}"; done; }
trap 'restore; rm -rf "$BACKUP"' EXIT
PASS=0; FAIL=0

revive() {
  python3 - "$1" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
anchor = "  @override\n  void initState() {\n    super.initState();\n"
assert s.count(anchor) >= 1, p
s = s.replace(
    anchor,
    anchor + "    askBatteryExemptionOnce();\n",
    1,
)
s = "import '../core/notification_tone.dart';\n" + s
io.open(p, 'w', encoding='utf-8').write(s)
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

echo; echo "== الحوارُ يعود =="

# ── أ) يعود في قشرة العميل ────────────────────────────────────────────────
#
# **وهو ما شكا منه بعينه**: «العميل يحسب فيه شيءٌ غلط».
run "(أ) يعود في قشرة العميل" revive "$C"

# ── ب) ويعود في قشرة المزوّد ──────────────────────────────────────────────
run "(ب) يعود في قشرة المزوّد" revive "$P"

# ── ج) ويعود في شاشةٍ ثالثةٍ لم تكن تناديه ────────────────────────────────
#
# **والضابطُ الذي يمنع عودتَه من باب.** لو كان المشطُ يقرأ القشرتين وحدَهما
# لَمرّ هذا — ومن أضافه غداً في «استكشف» أعاد الشكوى ولا شيءَ يمنعه.
run "(ج) يعود في شاشةٍ ثالثة" revive "$E"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
