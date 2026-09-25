#!/usr/bin/env bash
# ضوابطُ سالبةٌ لغلاف الحجز في `v_my_bookings`.
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

S=../booking_cover.sql

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
  if timeout 600 node booking_cover.test.mjs >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 node booking_cover.test.mjs >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الحرز =="

# ── أ) تصير الطريقةُ `security definer` ───────────────────────────────────
#
# **وهو البابُ الخلفيّ بعينه**: الطريقةُ تعمل حينئذٍ بصلاحيّة مالكها لا
# بصلاحيّة قارئها، فتتجاوز سياسةَ `bookings` — ويقرأ كلُّ مسجَّلٍ حجوزَ
# الناس كلِّهم: أسماءَهم وعناوينَهم وكم دفعوا. ولا يُرى في الشاشة شيء.
run "(أ) الطريقةُ تتجاوز سياسةَ جدولها" \
  sub "$S" \
"with (security_invoker = true) as" \
"with (security_invoker = false) as"

# ── ب) وتُمنح للمجهول ─────────────────────────────────────────────────────
#
# والمفتاحُ العامُّ في كلّ جهازٍ نُزّل فيه التطبيق.
run "(ب) المجهولُ يقرأ الطريقة" \
  sub "$S" \
"grant select on public.v_my_bookings to authenticated;" \
"grant select on public.v_my_bookings to authenticated, anon;"

echo; echo "== وأيُّ صورةٍ تُختار =="

# ── (ج) كان هنا ضابطٌ لنزع الترتيب، وسقط لأنّه كاذب ──────────────────────
#
# نُزعت `order by` فبقيت الحزمةُ خضراء. والعلّةُ ليست في الطريقة: على
# `service_media` فهرسٌ `(service_id, kind, sort_order)`، فمسحٌ به يُخرج
# الصفوفَ مرتَّبةً بـ`sort_order` وإن لم يُطلب ترتيب. فالجوابُ صحيحٌ هنا
# بالصدفة لا بالضمانة.
#
# **وهذا لا يعني أنّ الترتيبَ زائد**: المخطِّطُ يختار غيرَ الفهرس على
# أحجامٍ أخرى، فيخرج صفٌّ غيرُ معيَّن. لكنّه لا يُقاس في قاعدةٍ في الذاكرة
# بثلاثة صفوف، **فحُذف الضابط** — ضابطٌ لا يسقط يُقرأ ضمانةً وهو فراغ.
# ويبقى الترتيبُ في الملفّ، ويحرسه (د) أدناه.

# ── د) ويُرتَّب بآخر ما رُفع ──────────────────────────────────────────────
#
# فيخالف غلافُ الخدمة في «حجوزاتي» غلافَها في «استكشف» — وهما صورتان
# لخدمةٍ واحدة.
run "(د) ترتيبٌ يخالف صفحةَ الخدمة" \
  sub "$S" \
"    order by m.sort_order, m.created_at" \
"    order by m.created_at desc"

# ── هـ) وتدخل المقاطعُ ────────────────────────────────────────────────────
#
# فيصير «الغلافُ» مسارَ مقطعٍ لا صورةَ فيه — ولا يُعرض شيء، ويُقرأ عطباً
# في الشبكة.
run "(هـ) الفيديو والصوتُ أغلفة" \
  sub "$S" \
"    where m.service_id = b.service_id and m.kind = 'image'" \
"    where m.service_id = b.service_id"

echo; echo "== والأعمدةُ كما في الجدول =="

# ── و) وتُسمّى الأعمدةُ يدويّاً فيسقط ما يُضاف لاحقاً ────────────────────
#
# **و`b.*` ليست كسلاً**: عدّادُ أعمدةٍ مكتوبٌ بيدٍ ينسى العمودَ الذي يُضاف
# بعد سنة، فتسقط بطاقةُ الحجز في التطبيق على `null` لا تُنقصها صورة.
run "(و) أعمدةٌ مسمّاةٌ بيدٍ لا نجمة" \
  sub "$S" \
"  b.*," \
"  b.id, b.reference, b.user_id, b.service_id, b.provider_id, b.event_date,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
