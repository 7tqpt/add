#!/usr/bin/env bash
# ضوابطُ سالبةٌ لأعمدة مقدّم الخدمة ولحدِّ محاولات التحقّق.
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

P=../provider_columns.sql
V=../phone_verify.sql
A=../apply.sql

BACKUP=$(mktemp -d)
cp "$P" "$BACKUP/p"; cp "$V" "$BACKUP/v"; cp "$A" "$BACKUP/a"
restore() { cp "$BACKUP/p" "$P"; cp "$BACKUP/v" "$V"; cp "$BACKUP/a" "$A"; }
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

# `$1` اسمُ الكسر، `$2` الحزمةُ التي يجب أن تحمرّ، وما بعدهما أمرُ الكسر.
run() {
  local name="$1" suite="$2"; shift 2
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  if timeout 600 node "$suite" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط ($suite)"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
base_green=1
for s in provider_columns.test.mjs column_privileges.test.mjs phone_verify.test.mjs \
         views.rls.test.mjs; do
  if timeout 600 node "$s" >/dev/null 2>&1; then echo "  أخضر: $s"
  else echo "  أحمر: $s — لا معنى للضوابط."; base_green=0; fi
done
[ "$base_green" = 1 ] || exit 1

echo; echo "== الثغرةُ الأصليّةُ تعود: الأعمدةُ تُكشف =="

# ── أ) يعود المنحُ العامُّ على الجدول كلِّه ────────────────────────────────
#
# **وهو العطبُ بعينه**: منحٌ على الجدول ومنحٌ على أعمدةٍ منه يجتمعان، ولا
# يُضيّق الثاني الأوّل. فسطرٌ واحدٌ يُعيد البريدَ والجوّالَ والأرباحَ إلى
# كلّ من ملك المفتاحَ العامّ.
run "(أ) يعود المنحُ العامُّ على الجدول" provider_columns.test.mjs \
  sub "$P" \
"  execute 'revoke select on public.service_providers from anon, authenticated';" \
"  execute 'grant select on public.service_providers to anon, authenticated';"

# ── ب) ويدخل البريدُ والجوّالُ قائمةَ المسموح ─────────────────────────────
#
# كسرٌ أهدأُ من الأوّل وأقربُ إلى الواقع: من أراد أن يعرض رقمَ المزوّد في
# بطاقته أضافه إلى القائمة، ولا يسقط بناءٌ ولا يحمرّ محلّل.
run "(ب) البريدُ والجوّالُ في قائمة المسموح" provider_columns.test.mjs \
  sub "$P" \
"    'applied_at', 'verified_at', 'created_at'," \
"    'applied_at', 'verified_at', 'created_at', 'email', 'phone',"

# ── ج) ويُكشف المسحُ نفسُه ────────────────────────────────────────────────
run "(ج) الأرباحُ مكشوفةٌ — يراها المسحُ" column_privileges.test.mjs \
  sub "$P" \
"    'rating', 'reviews_count', 'completed_bookings'," \
"    'rating', 'reviews_count', 'completed_bookings', 'total_earnings',"

echo; echo "== والأبوابُ المفتوحةُ لأهلها لا تُغلق =="

# ── د) تُنزع الدالّةُ عن صاحب الملفّ ──────────────────────────────────────
#
# **وهذا الضابطُ يمنع «حجباً يكسر»**: نزعٌ يقفل شاشةَ المزوّد على أرباحه
# يخضرّ في فحص الحجب وحدَه، ويسقط التطبيقُ على جهاز صاحبه.
run "(د) صاحبُ الملفّ لا ينادي دالّتَه" provider_columns.test.mjs \
  sub "$P" \
"grant execute on function public.api_my_provider() to authenticated;" \
"-- نُزعت"

# ── هـ) وتُعيد الدالّةُ صفوفَ الجميع لا صفَّ صاحبها ───────────────────────
#
# وهي أخطرُ من الأولى: كلُّ مزوّدٍ يقرأ أرباحَ منافسيه وبريدَهم بنداءٍ واحد،
# والشاشةُ تعمل كما هي فلا يُرى شيء.
run "(هـ) الدالّةُ تُعيد صفوفَ المزوّدين كلِّهم" provider_columns.test.mjs \
  sub "$P" \
"  select * from public.service_providers where id = public.current_provider()" \
"  select * from public.service_providers"

# ── و) ويسقط حارسُ طريقة اللوحة ───────────────────────────────────────────
#
# `v_admin_providers` صارت `security definer` — فبلا `where public.is_admin()`
# تصير باباً خلفيّاً يقرأ منه كلُّ مسجَّلٍ ما مُنع منه في الجدول.
run "(و) طريقةُ اللوحة بلا حارسها" views.rls.test.mjs \
  sub "$P" \
"from public.service_providers p
where public.is_admin();" \
"from public.service_providers p;"

# ── ز) والنسخةُ التي في `apply.sql` كذلك ──────────────────────────────────
#
# **وهذه هي التي تُنسى**: تُصحَّح في ملفٍّ وتبقى مكسورةً في الآخر، فمن أعاد
# تشغيلَ `apply.sql` أعاد الثغرةَ وهو يحسب أنّه يحدّث اللوحة.
run "(ز) وملفُّ apply.sql بلا الحارس" views.rls.test.mjs \
  sub "$A" \
"from public.service_providers p
where public.is_admin();" \
"from public.service_providers p;"

echo; echo "== وحدُّ محاولات التحقّق =="

# ── ح) يُرفع الحدُّ عن المحاولات ──────────────────────────────────────────
#
# **وهو الحالُ الذي كان**: الإرسالُ محدودٌ والتحقّقُ مفتوح. خمسةُ آلافِ
# نداءٍ تُخمِّن رمزاً من أربع خانات.
run "(ح) لا حدَّ على المحاولات" phone_verify.test.mjs \
  sub "$V" \
"  if v_phone_15m >= 5 then" \
"  if v_phone_15m >= 5000000 then"

# ── ط) ويصير الحدُّ على الحساب وحدَه ──────────────────────────────────────
#
# **ويُلتفّ عليه بحسابات**: عشرةُ حساباتٍ تُفتح في دقائق = خمسون محاولةً على
# الرقم نفسِه. فالعدُّ على الرقم هو الذي يُغلق الباب.
run "(ط) الحدُّ على الحساب لا على الرقم" phone_verify.test.mjs \
  sub "$V" \
"   where phone = p_phone and created_at > now() - interval '15 minutes';

  if v_phone_15m >= 5 then" \
"   where user_id = v_user and created_at > now() - interval '15 minutes';

  if v_phone_15m >= 5 then"

# ── ي) وتُسجَّل المردودةُ كما تُسجَّل الممرَّرة ────────────────────────────
#
# فيمتدّ الحبسُ بكلّ نقرةٍ يائسةٍ ولا ينقضي أبداً — ومن أخطأ خمساً حُبس أبداً.
run "(ي) تُسجَّل المحاولةُ المردودة" phone_verify.test.mjs \
  sub "$V" \
"  -- ── على الرقم: وهو المستهدَف، فيُعدّ عليه أوّلاً ─────────────────────────
  select count(*), min(created_at) into v_phone_15m, v_oldest" \
"  insert into public.phone_otp_attempts (user_id, phone) values (v_user, p_phone);
  select count(*), min(created_at) into v_phone_15m, v_oldest"

# ── ك) وتُمنح دالّةُ المحو للمسجَّلين ─────────────────────────────────────
#
# **وهذا يُفرِغ الحدَّ كلَّه**: نداءٌ بين كلّ تخمينين يُصفّر العدّاد.
run "(ك) دالّةُ محو المحاولات ممنوحةٌ للمسجَّلين" phone_verify.test.mjs \
  sub "$V" \
"revoke all on function public.otp_clear_attempts(uuid, text)
  from public, anon, authenticated;" \
"grant execute on function public.otp_clear_attempts(uuid, text) to authenticated;"

# ── ل) ويُفتح جدولُ العدّاد للقراءة ───────────────────────────────────────
run "(ل) جدولُ المحاولات بلا حرز" column_privileges.test.mjs \
  sub "$V" \
"alter table public.phone_otp_attempts enable row level security;" \
"-- بلا حرز"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
