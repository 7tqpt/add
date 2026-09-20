#!/usr/bin/env bash
# ضوابطُ سالبةٌ لاتّجاه سهم «هذا يُفتح».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/chevron_direction_test.dart"

K=lib/src/ui/kit.dart
B=lib/src/screens/my_bookings.dart

FILES=("$K" "$B")
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

echo; echo "== العطبُ الأصليُّ يعود =="

# ── أ) يُسأل الاتّجاهُ من جديدٍ في `CardTitleBar` ──────────────────────────
#
# **وهو العطبُ الذي كشفته اللقطةُ بعينه**: انعكاسان يُلغي أحدُهما الآخر،
# والسهمُ يشير إلى الخلف في العربيّة كلِّها.
run "(أ) يُقلب بيدٍ في CardTitleBar" \
  sub "$K" \
"          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.accentInk,
          )," \
"          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left
                : Icons.chevron_right,
            size: 20,
            color: AppColors.accentInk,
          ),"

# ── ب) وتُكتب الصورةُ المقلوبةُ في شاشةٍ بعيدة ────────────────────────────
#
# المواضعُ ثمانيةٌ ولا شاشةَ تجمعها — فيُتأكَّد أنّ المشطَ يبلغها كلَّها،
# لا `kit.dart` وحدَه.
run "(ب) chevron_left في «حجوزاتي»" \
  sub "$B" \
"                        const Icon(Icons.chevron_right, size: 20, color: AppColors.muted)," \
"                        const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),"

echo; echo "== والمشطُ لا يخدع نفسَه =="

# ── ج) ولا تُقرأ التعليقاتُ على أنّها شيفرة ───────────────────────────────
#
# الضابطُ المعكوس: لو كان المشطُ يعدّ التعليقاتِ لَما جاز أن يُذكر
# `chevron_left` في شرحِ العطب — ولَسقط الأساسُ نفسُه. وهو أخضرُ، فالمشطُ
# يميّز. ويُتأكَّد هنا أنّه يميّز **عن قصدٍ** لا لأنّه لا يقرأ شيئاً:
# يُزرع ذكرٌ حقيقيٌّ في شيفرةٍ حيّةٍ فيجب أن يسقط.
run "(ج) المشطُ يقرأ الشيفرةَ فعلاً" \
  sub "$K" \
"  const CardTitleBar(this.title, {super.key, this.badge, this.opens = false});" \
"  const CardTitleBar(this.title, {super.key, this.badge, this.opens = false});
  static const _unused = Icons.chevron_left;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
