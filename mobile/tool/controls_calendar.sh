#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشاشة «تقويمي».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/availability_test.dart test/chevron_direction_test.dart"
F=lib/src/screens/availability.dart
K=lib/src/ui/kit.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"
restore() { cp "$BACKUP/f" "$F"; }
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
  if timeout 900 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 900 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== سهما الشهر =="

# ── أ) يعودان صورةً واحدة ────────────────────────────────────────────────
#
# **وهو العطبُ الذي كان**: `chevron_right` في الزرّين معاً، فسهمُ «السابق»
# وسهمُ «التالي» يشيران إلى جهةٍ واحدة.
run "(أ) السهمان صورةٌ واحدة" \
  sub "$F" \
"          icon: Icons.arrow_back_ios_new,
          tooltip: tr('الشهر السابق')," \
"          icon: Icons.arrow_forward_ios,
          tooltip: tr('الشهر السابق'),"

# ── ب) وسهمُ «السابق» يتقدّم ─────────────────────────────────────────────
#
# **ولا يُسأل الشكلُ وحدَه**: سهمٌ صحيحُ الصورة يفعل عكسَ ما يقول.
run "(ب) «السابق» يتقدّم شهراً" \
  sub "$F" \
"          tooltip: tr('الشهر السابق'),
          onTap: () => onShift(-1)," \
"          tooltip: tr('الشهر السابق'),
          onTap: () => onShift(1),"

echo; echo "== والأيام المغلقة =="

# ── ج) ويُعرض زرُّ فتحٍ ليومٍ أغلقه حجز ─────────────────────────────────
#
# **والخادمُ سيردّه**: اليومُ أغلقته القاعدةُ بحجزٍ مؤكّد، ولا يُفتح إلّا
# بإلغاء الحجز. فزرٌّ هنا وعدٌ يُكسر بضغطةٍ في وجه صاحبه.
run "(ج) زرُّ فتحٍ ليومٍ أغلقه حجز" \
  sub "$F" \
"    final booked = mark.byBooking;
    final tone = booked ? AppColors.booked : AppColors.critical;" \
"    final booked = false;
    final tone = mark.byBooking ? AppColors.booked : AppColors.critical;"

# ── د) ولونُ الصفّ واحدٌ للحالين ────────────────────────────────────────
#
# فيُقرأ المحجوزُ مغلَقاً بيده، ويُطلب فتحُه.
run "(د) المحجوزُ بلون ما أغلقه صاحبُه" \
  sub "$F" \
"    final tone = booked ? AppColors.booked : AppColors.critical;" \
"    final tone = AppColors.critical;"

echo; echo "== وخطُّ الزرّ =="

# ── هـ) ويعود الأسلوبُ العاري إلى `styleFrom` ───────────────────────────
#
# **فتُرسم «إعادة فتح» مربّعاتٍ بيضاء**: أسلوبٌ عارٍ يحلّ محلَّ أسلوب
# الثيمة كلِّه، ومعه عائلةُ الخطّ. وقد وقع وخرج في اللقطة.
run "(هـ) أسلوبٌ عارٍ يُذهب عائلةَ الخطّ" \
  sub "$F" \
"                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )," \
"                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12),
              ),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
