#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقتَي المزوّد: «الطلبات» و«خدماتي».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/card_title_test.dart test/services_fab_above_nav_test.dart \
       test/service_category_dropdown_test.dart test/service_delete_test.dart"
F=lib/src/screens/services.dart
K=lib/src/ui/kit.dart
R=lib/src/screens/requests.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$K" "$BACKUP/k"; cp "$R" "$BACKUP/r"
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/k" "$K"; cp "$BACKUP/r" "$R"; }
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

echo; echo "== رأسُ البطاقة =="

# ── أ) يعود العنوانُ حبراً أبيضَ على شريطٍ نبيذيّ ────────────────────────
#
# **وهو الشكلُ القديم** — بدّله صاحبُ المنصّة بتصميمين أرسلهما، واختار أن
# تتبعه الشاشتان معاً.
run "(أ) العنوانُ أبيضُ على نبيذيّ" \
  sub "$K" \
"                  color: AppColors.ink,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[" \
"                  color: AppColors.accentInk,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...["

# ── ب) وصبغةُ الشارة تعود اثنتَي عشرةَ بالمئة ───────────────────────────
#
# **وعندها يعطي كهرمانيُّ «بانتظار مقدّم الخدمة» ‎٤٫٤٤:١‎** — تحت العتبة.
# وهو أكثرُ الحالات وقوعاً في هذه الشاشة.
run "(ب) صبغةُ الشارة تحت العتبة" \
  sub "$K" \
"              color: colour.withValues(alpha: 0.10)," \
"              color: colour.withValues(alpha: 0.12),"

# ── ج) ولونُ شارة الطلب مكتوبٌ لا من الحالة ─────────────────────────────
#
# فيخرج «منفَّذ» بلون الانتظار، وتُقرأ الحالُ من اللمحة خطأً.
run "(ج) لونُ شارة الطلب ثابتٌ مكتوب" \
  sub "$R" \
"                    badgeColor: bookingStatusColor(b.status)," \
"                    badgeColor: AppColors.warning,"

# ── د) وشارةُ الخدمة بلونٍ واحدٍ للحالين ────────────────────────────────
#
# فتُقرأ الموقوفةُ معروضةً بلمحةٍ، ويسأل صاحبُها لماذا لا تصله طلبات.
run "(د) الموقوفةُ بلون المعروضة" \
  sub "$F" \
"                    badgeColor: s.isActive ? AppColors.good : AppColors.muted," \
"                    badgeColor: AppColors.good,"

echo; echo "== وزرُّ القبول =="

# ── هـ) ويعود نبيذيّاً ──────────────────────────────────────────────────
#
# اختار صاحبُ المنصّة الطَّفليَّ بعد أن عُرض عليه أنّه يفترق عن سائر
# الأزرار — فرجوعُه نقضٌ لاختياره بلا أن يُسأل.
run "(هـ) «قبول» نبيذيٌّ لا طَفليّ" \
  sub "$R" \
"                              backgroundColor: AppColors.brand," \
"                              backgroundColor: AppColors.accent,"

echo; echo "== وشريطُ «خدمة جديدة» =="

# ── و) يعود أوّلَ صفٍّ في القائمة ───────────────────────────────────────
#
# **فيختفي مع القائمة حين لا خدمةَ أصلاً** — وهي أوّلُ حالٍ يقع فيها كلُّ
# مزوّدٍ جديد، فيبقى بلا بابٍ يُضيف منه. وقد وقع هذا في أوّل صياغة.
run "(و) لا بابَ إلى الإضافة لمن لا خدمةَ له" \
  sub "$F" \
"          if (rows.isEmpty) {
            return Column(
              children: [
                addBar,
                Expanded(
                  child: EmptyBlock(" \
"          if (rows.isEmpty) {
            return Column(
              children: [
                const SizedBox.shrink(),
                Expanded(
                  child: EmptyBlock("

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
