#!/usr/bin/env bash
# ضوابطُ سالبةٌ لموضع زرّ «خدمة جديدة» فوق الشريط الزجاجيّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/services_fab_above_nav_test.dart"

S=lib/src/screens/services.dart

BACKUP=$(mktemp -d)
cp "$S" "$BACKUP/s"
restore() { cp "$BACKUP/s" "$S"; }
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

echo; echo "== الضوابط =="

# ── أ) يعود الزرُّ خلفَ الشريط ─────────────────────────────────────────────
#
# **وهو العطبُ الذي شُكي منه بعينه**: الزرُّ في الشجرة، ويُرى طرفُه، ولا
# يُضغط. فلو لم يسقط هذا الضابطُ لَعاد العطبُ يوماً ولم تقل الحزمةُ شيئاً.
run "(أ) الزرُّ يعود خلفَ الشريط" \
  sub "$S" \
"        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)," \
"        padding: EdgeInsets.zero,"

# ── ب) ويُرفع برقمٍ مكتوبٍ باليد لا يكفي ───────────────────────────────────
#
# رقمٌ يُنسخ اليومَ يبقى على قدره القديم يومَ يتغيّر الشريط — فيعود الزرُّ
# خلفه ولا يقول أحدٌ شيئاً.
run "(ب) رقمٌ مكتوبٌ باليد" \
  sub "$S" \
"        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)," \
"        padding: const EdgeInsets.only(bottom: 40),"

# ── ج) ويطير الزرُّ ارتفاعَ الشريط مرّتين ──────────────────────────────────
#
# **وهذا ما وقع فعلاً**: جُمعت ثوابتُ الشريط فوق ما تقوله السقّالةُ أصلاً.
# ولم يكشفه اختبارٌ يسأل «أهو فوق الشريط؟» — فهو فوقه في الحالين.
run "(ج) الزرُّ يطير مرّتين" \
  sub "$S" \
"        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)," \
"        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom +
              GlassNavBar.barHeight +
              GlassNavBar.raise,
        ),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
