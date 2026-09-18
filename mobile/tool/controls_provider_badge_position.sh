#!/usr/bin/env bash
# ضوابطُ سالبةٌ لموضع شارة الحال في رأس ملفّ المزوّد.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/provider_badge_position_test.dart"

K=lib/src/ui/kit.dart

BACKUP=$(mktemp -d)
cp "$K" "$BACKUP/k"
restore() { cp "$BACKUP/k" "$K"; }
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

# ── أ) تعود الشارةُ إلى سطرٍ تحت المحافظة ──────────────────────────────────
#
# وهو الحالُ الذي شُكي منه بعينه: سطرٌ ثالثٌ يطول به الرأس.
run "(أ) الشارةُ تعود سطراً تحتها" \
  sub "$K" \
"                        if (!badgeBesideTitle && badge.isNotEmpty)
                          Row(" \
"                        if (false && !badgeBesideTitle && badge.isNotEmpty) // ignore: dead_code
                          Row("

# ── ب) وتنزل شارةُ «حسابي» من سطر الاسم إلى سطر البريد ─────────────────────
#
# **شاشتان تتشاركان الودجتَ**، فكسرُ إحداهما يمرّ في الأخرى لو لم تُقَس.
run "(ب) شارةُ «حسابي» تنزل" \
  sub "$K" \
"                        if (!badgeBesideTitle && badge.isNotEmpty)
                          Row(" \
"                        if (badge.isNotEmpty)
                          Row("

# ── ج) و`Flexible` تنتقل إلى الشارة بدل المحافظة ───────────────────────────
#
# فتُقَصّ الحالُ بنقاطٍ («قيد المرا…») وتبقى المحافظةُ كاملة — والحالُ هي
# المعلومة. **ولا يسقط هذا إلّا بعرضٍ ضيّقٍ يُقاس عمداً.**
run "(ج) تُقَصّ الشارةُ لا المحافظة" \
  sub "$K" \
"                              Flexible(child: _subtitleText()),
                              const SizedBox(width: Space.sm),
                              _GoldBadge(badge)," \
"                              _subtitleText(),
                              const SizedBox(width: Space.sm),
                              Flexible(child: _GoldBadge(badge)),"

# ── د) ومن لا محافظةَ له تضيع شارتُه ───────────────────────────────────────
#
# الشارةُ تُرفع إلى سطرٍ غيرِ موجودٍ فلا تُرسم أصلاً.
run "(د) شارةٌ تضيع بلا محافظة" \
  sub "$K" \
"                      if (subtitle.isEmpty && !badgeBesideTitle && badge.isNotEmpty) ...[" \
"                      if (false && subtitle.isEmpty && !badgeBesideTitle && badge.isNotEmpty) ...[ // ignore: dead_code"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
