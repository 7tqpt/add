#!/usr/bin/env bash
# ضوابطُ سالبةٌ لغلاف خطّة العرس.
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

S=../plan_cover.sql

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
  if timeout 600 node plan_cover.test.mjs >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 node plan_cover.test.mjs >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الحرز =="

# ── أ) يسقط الحرزُ فتُقرأ خطّةُ غيرك ──────────────────────────────────────
#
# والمعرّفُ يُمرَّر من التطبيق، فبلا هذا السطر يرى كلُّ مسجَّلٍ صورةَ ما
# حجزه غيرُه بمعرّفٍ يُخمَّن أو يُسرَّب.
run "(أ) الدالّةُ بلا حرزها" \
  sub "$S" \
"     and pl.user_id = public.current_app_user()" \
"     and pl.user_id is not null"

# ── ب) وتُمنح للمجهول ─────────────────────────────────────────────────────
run "(ب) المجهولُ ينادي الدالّة" \
  sub "$S" \
"grant execute on function public.api_plan_cover(uuid) to authenticated;" \
"grant execute on function public.api_plan_cover(uuid) to authenticated, anon;"

echo; echo "== وأيُّ صورةٍ تُختار =="

# ── ج) ويسقط الترتيبُ فتصير الصورةُ غيرَ معيَّنة ──────────────────────────
#
# **وهذا أخبثُ ما في الدالّة**: بلا ترتيبٍ يُخرج Postgres صفّاً غيرَ معيَّن،
# فتمرّ التشغيلةُ مرّةً وتسقط أخرى بلا أن يتغيّر حرف. وصورةُ رأسٍ تتبدّل
# بين فتحةٍ وفتحةٍ تُقرأ عطباً.
run "(ج) بلا ترتيبٍ — الصورةُ غيرُ معيَّنة" \
  sub "$S" \
"   order by b.created_at, b.id, m.sort_order, m.created_at
   limit 1" \
"   limit 1"

# ── د) ويُرتَّب بتاريخ العرس لا بوقت الحجز ────────────────────────────────
#
# وحجوزُ الخطّة الواحدة في يوم العرس نفسِه غالباً، فالترتيبُ به يُخرج صفّاً
# غيرَ معيَّنٍ وهو يبدو مرتَّباً.
run "(د) الترتيبُ بتاريخ العرس" \
  sub "$S" \
"   order by b.created_at, b.id, m.sort_order, m.created_at" \
"   order by b.event_date"

# ── هـ) ويسقط ترتيبُ الصور داخلَ الخدمة ───────────────────────────────────
#
# فيصير الغلافُ آخرَ ما رُفع لا ما اختاره صاحبُ الخدمة أوّلاً.
run "(هـ) ترتيبُ صور الخدمة مهمَل" \
  sub "$S" \
"   order by b.created_at, b.id, m.sort_order, m.created_at" \
"   order by b.created_at, b.id, m.path desc"

echo; echo "== وما لا يُعدّ =="

# ── و) ويُورث الملغى رأسَ الخطّة ──────────────────────────────────────────
#
# فمن ألغى قاعةً بقيت صورتُها رأسَ خطّته — وهي أوّلُ ما يراه كلّما فتح.
run "(و) الملغى يُعطي غلافاً" \
  sub "$S" \
"     and b.status not in ('cancelled', 'rejected')" \
"     and b.status is not null"

# ── ز) وتدخل الفيديوهاتُ والأصوات ─────────────────────────────────────────
#
# و`service_media` تحمل الثلاثةَ في جدولٍ واحد، فبلا هذا الشرط يصير «الغلافُ»
# مسارَ مقطعِ صوتٍ — ولا صورةَ تُعرض، ويُقرأ عطباً في الشبكة.
run "(ز) الصوتُ والفيديو غلافان" \
  sub "$S" \
"     and m.kind = 'image'" \
"     and m.kind is not null"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
