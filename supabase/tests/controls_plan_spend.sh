#!/usr/bin/env bash
# ضوابطُ سالبةٌ لمصروف الخطّة حسب القسم.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وكسرٌ يُسقط الحزمةَ بعطبٍ في الصياغة ضابطٌ كاذبٌ كذلك**: يحمرّ لسببٍ
# غير الذي يدّعيه. فكلُّ كسرٍ هنا يُتحقَّق من وقوعه أوّلاً (المرساةُ تطابق
# مرّةً واحدة)، والسطرُ المكسورُ SQL صحيحٌ يعمل.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

S=../plan_spend.sql

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
  if timeout 600 node plan_spend.test.mjs >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 node plan_spend.test.mjs >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الحرز =="

# ── أ) يسقط الحرزُ فتُقرأ خطّةُ غيرك ──────────────────────────────────────
#
# **وهو أخطرُ ما في الدالّة.** المعرّفُ يُمرَّر من التطبيق، فبلا هذا السطر
# يقرأ كلُّ مسجَّلٍ ميزانيةَ أيِّ عرسٍ ومَا دُفع فيه بمعرّفٍ يُخمَّن أو يُسرَّب.
run "(أ) الدالّةُ بلا حرزها" \
  sub "$S" \
"    and pl.user_id = public.current_app_user()" \
"    and pl.user_id is not null"

# ── ب) وتُمنح للمجهول ─────────────────────────────────────────────────────
#
# والمفتاحُ العامُّ في كلّ جهازٍ نُزّل فيه التطبيق، فمنحُ `anon` يعني أنّ
# `current_app_user()` تعود فارغةً — ومن كتب حرزَه بـ`is not null` وحدَه
# انكشف كلُّ شيء. وهذان الكسران يُقرآن معاً.
run "(ب) المجهولُ ينادي الدالّة" \
  sub "$S" \
"grant execute on function public.api_plan_spend_by_category(uuid) to authenticated;" \
"grant execute on function public.api_plan_spend_by_category(uuid) to authenticated, anon;"

echo; echo "== وما يُعدّ وما لا يُعدّ =="

# ── ج) ويُعدّ الملغى ──────────────────────────────────────────────────────
#
# وحجزٌ أُلغي لا يُنفق عليه أحد، وعدُّه يُري صاحبَه مصروفاً لم يخرج من جيبه —
# ٩٩٩ ألفاً في هذا الاختبار.
run "(ج) الملغى داخلَ الحساب" \
  sub "$S" \
"    and b.status not in ('cancelled', 'rejected')" \
"    and b.status is not null"

# ── د) و«المدفوع» يصير «المحجوز» ──────────────────────────────────────────
#
# **والرقمان يفترقان دائماً ما دام عربونٌ لم يُكمَّل**، فدالّةٌ تردّ الرقمَ
# نفسَه في العمودين تُخفي الالتزامَ القادم وتُري إنفاقاً لم يقع.
run "(د) المدفوعُ هو المحجوز" \
  sub "$S" \
"    coalesce(sum(b.paid_amount), 0)            as spent," \
"    coalesce(sum(b.total_price), 0)            as spent,"

echo; echo "== والقسمُ قسمُ خدمته =="

# ── هـ) ويُفكّ ربطُ القسم بالخدمة ─────────────────────────────────────────
#
# فيُنسب مبلغُ كلّ حجزٍ إلى كلّ قسمٍ في القاعدة: الشاشةُ تمتلئ أشرطةً،
# والمجموعُ يصير أضعافَ ما حُجز.
run "(هـ) القسمُ غيرُ مربوطٍ بخدمته" \
  sub "$S" \
"  join public.service_categories c on c.id = s.category_id" \
"  join public.service_categories c on true"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
