#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقة الميزانية ولأشرطة «تفاصيل المصروفات».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وكسرٌ يُسقط الحزمةَ بعطبٍ في الترجمة ضابطٌ كاذبٌ كذلك**: يحمرّ لسببٍ غير
# الذي يدّعيه. فكلُّ كسرٍ هنا يُتحقَّق من وقوعه أوّلاً (المرساةُ تطابق مرّةً
# واحدة)، والسطرُ المكسورُ Dart صحيحٌ يُصرَّف.
#
# ── وما يُقاس هنا وما يُقاس هناك ────────────────────────────────────────────
#
# الكسورُ (ح) و(ط) تقع في `demo.dart` لا في الشاشة: وضعُ العرض هو مصدرُ
# الأرقام في الاختبار، وكسرُه يُثبت أنّ الاختبارَ يقرأ ما يُحسب لا ما يُكتب.
# **وحرزُ القاعدة نفسِها يُضبط في مكانه** — `supabase/tests/controls_plan_spend.sh`
# يكسر `plan_spend.sql` خمسةَ كسور. ولا يُغني أحدُهما عن الآخر: الشاشةُ قد
# تعرض صواباً ما تحسبه القاعدةُ خطأً، والعكس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/plan_money_test.dart test/plan_test.dart"
F=lib/src/screens/plan.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/d" "$D"; }
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

echo; echo "== والأرقامُ الثلاثة =="

# ── أ) «المتبقّي» يصير «عليك لمقدّمي الخدمة» ──────────────────────────────
#
# **وهو الخلطُ بعينه**: الأوّلُ ما بقي من ميزانيّتك، والثاني ما بقي من ثمن
# حجوزاتك. ويفترقان هنا ٧٣٠ ألفاً — ومن خلطهما أرى صاحبَه مالاً في جيبه
# ليس فيه.
run "(أ) المتبقّي من الحجوزات لا من الميزانية" \
  sub "$F" \
"    final left = p.budget - spent;" \
"    final left = p.remainingAmount;"

# ── ب) و«المصروف» يصير «المحجوز» ──────────────────────────────────────────
#
# الميزانيةُ تُستهلك بالدفع لا بالحجز، ومن عدّ المحجوزَ مصروفاً أرى صاحبَه
# مالاً خرج ولم يخرج — ٢٥٥ ألفاً تصير ١٬٢٧٠٬٠٠٠.
run "(ب) المصروفُ هو المحجوز" \
  sub "$F" \
"    final spent = p.paidAmount;" \
"    final spent = p.totalCost;"

# ── ج) ونسبةُ الحلقة تُقاس بالمحجوز ───────────────────────────────────────
#
# **وهذا يُطمئن في غير موضعه**: ‎١٣٪‎ تصير ‎٦٤٪‎ والجيبُ كما هو.
run "(ج) الحلقةُ تقيس المحجوز" \
  sub "$F" \
"    final ratio = p.budget > 0 ? (spent / p.budget).clamp(0.0, 1.0) : 0.0;" \
"    final ratio = p.budget > 0 ? (p.totalCost / p.budget).clamp(0.0, 1.0) : 0.0;"

# ── د) ويُحذف سطرُ «عليك لمقدّمي الخدمة» ──────────────────────────────────
#
# حذفُه يُخفي التزاماً قائماً: ‎١٬٠١٥٬٠٠٠‎ مستحقّةٌ ولا يُقال عنها شيء.
run "(د) لا يُقال ما عليك لمقدّمي الخدمة" \
  sub "$F" \
"          child: Muted(
            trf('وعليك لمقدّمي الخدمة {0} من ثمن حجوزاتك.',
                [formatMoney(p.remainingAmount)]),
            size: 11,
          )," \
"          child: const SizedBox.shrink(),"

# ── هـ) ويعود الرقمُ الرابعُ بين الثلاثة ──────────────────────────────────
#
# **وهو ما رُفض في الصورة**: أربعةُ أرقامٍ متشابهةٍ تُقرأ واحداً، والعينُ لا
# تفرّق «المتبقّي» من «المتبقّي عليك».
run "(هـ) رقمٌ رابعٌ في الصدارة" \
  sub "$F" \
"                  KeyValue(tr('المتبقّي'), formatMoney(left < 0 ? 0 : left))," \
"                  KeyValue(tr('المتبقّي'), formatMoney(left < 0 ? 0 : left)),
                  KeyValue(tr('عليك'), formatMoney(p.remainingAmount)),"

echo; echo "== وأشرطةُ الأقسام =="

# ── و) والشريطُ يقيس المدفوعَ لا المحجوز ──────────────────────────────────
#
# والبطاقةُ تقول «توزيعُ حجوزاتك حسب القسم» — فشريطٌ يقيس المدفوعَ يقول
# غيرَ ما كُتب فوقه: قاعةٌ بـ‎٨٥٠‎ ألفاً تظهر ‎٢٥٥‎، وضيافةٌ بـ‎٤٢٠‎ تظهر صفراً.
run "(و) الشريطُ يقيس المدفوع" \
  sub "$F" \
"                        formatMoney(row.booked)," \
"                        formatMoney(row.spent),"

# ── ز) وتظهر البطاقةُ فارغةً ──────────────────────────────────────────────
#
# فمن لم يحجز شيئاً بعد — ومن لم تُشغَّل قاعدتُه — يُعرض عليه عنوانٌ تحته
# بياض، فيُقرأ عطباً في الشاشة وهو نقصٌ في البيانات.
run "(ز) عنوانٌ تحته بياض" \
  sub "$F" \
"    if (rows.isEmpty || booked <= 0) return const SizedBox.shrink();" \
"    if (rows.isEmpty && booked < 0) return const SizedBox.shrink();"

# ── ح) والنسبةُ تُكتب لا تُحسب ────────────────────────────────────────────
run "(ح) نسبةُ الشريط مكتوبةٌ لا محسوبة" \
  sub "$F" \
"                trf('{0}٪', ['\${(share * 100).round()}'])," \
"                trf('{0}٪', ['100']),"

echo; echo "== ومصدرُ الأرقام =="

# ── ط) ويُعدّ الملغى في التوزيع ───────────────────────────────────────────
#
# كما في القاعدة حرفاً — وهذا الكسرُ يُثبت أنّ اختبارَ الشاشة يقرأ ما يُحسب
# لا ما يُكتب يدوياً في `demo.dart`.
run "(ط) الملغى في التوزيع" \
  sub "$D" \
"    if (b.status == BookingStatus.cancelled || b.status == BookingStatus.rejected) continue;" \
"    if (b.status == BookingStatus.rejected) continue;"

# ── ي) ويدخل حجزٌ من خارج الخطّة ──────────────────────────────────────────
#
# **وهذا يُري صاحبَ العرس أنّه أنفق على عرسه ما أنفقه على غيره**: `b3`
# تصويرٌ قديمٌ بلا خطّة، ودخولُه يفتح قسماً ثالثاً لم يُحجز في هذه الخطّة.
run "(ي) حجزٌ من خارج الخطّة يدخل" \
  sub "$D" \
"    if (b.planId != planId) continue;" \
"    if (b.planId != null && b.planId != planId && false) continue;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
