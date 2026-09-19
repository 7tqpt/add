#!/usr/bin/env bash
# ضوابطُ سالبةٌ لصورة العميل في «آراء العملاء».
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **والدالّةُ `security definer` تُمنح لمن لا حسابَ له** — لأنّ صفحةَ المزوّد
# تُفتح قبل تسجيل الدخول. فحدُّها الوحيدُ ما كُتب في جسدها، وأخطرُ ما يُكسر
# هنا (ب): يسقط شرطُ «المنشورُ وحدَه»، فيُنشر للعالم ما أخفته الإدارةُ عمداً
# ومعه صورةُ صاحبه — **وهو أخطرُ ممّا كانت السياسةُ تحرسه أصلاً**.
set -uo pipefail
cd "$(dirname "$0")/../.."
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE="supabase/tests/review_avatars.test.mjs"
F=supabase/review_avatars.sql

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f.sql"
restore() { cp "$BACKUP/f.sql" "$F"; }
trap 'restore; rm -rf "$BACKUP"' EXIT
PASS=0; FAIL=0

sub() {
  local old="$1" new="$2" n
  n=$(python3 - "$F" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1; fi
  python3 - "$F" "$old" "$new" <<'PY'
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
  if node "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if node "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) لا صورةَ تصل أصلاً ──────────────────────────────────────────────────
#
# وهو الحالُ الذي شُكي منه: حرفٌ في قرصٍ نبيذيّ أبداً.
run "(أ) لا صورةَ تصل" \
  sub "    coalesce(u.avatar_path, '') as avatar_path" \
      "    '' as avatar_path"

# ── ب) ويُنشر المخفيُّ والمُبلَّغُ عنه ─────────────────────────────────────
#
# **وهذا أخطرُها.** الدالّةُ تتجاوز السياسةَ بتصميمها وتُمنح لمن لا حسابَ له،
# فلو سقط هذا السطرُ لَقرأ العالمُ ما أخفته الإدارةُ عمداً — ومعه صورةُ صاحبه
# واسمُه. ولا يسقط بسؤال «أتعمل الدالّة؟»: تعمل.
run "(ب) يُنشر المخفيّ" \
  sub "    and r.status = 'published'" \
      "    and true"

# ── ج) وتخلط مزوّداً بمزوّد ────────────────────────────────────────────────
#
# صفحةُ قاعةٍ تعرض آراءَ قاعةٍ أخرى — وهو كذبٌ على من يقرأ ليقرّر.
run "(ج) تخلط المزوّدين" \
  sub "  where r.provider_id = p_provider_id" \
      "  where (r.provider_id = p_provider_id or true)"

# ── د) ويختفي رأيُ من حُذف حسابُه ──────────────────────────────────────────
#
# `reviews.user_id` يقبل الفراغ (`on delete set null`). فوصلٌ داخليٌّ يُسقط
# **الرأيَ نفسَه** لا صورتَه — سمعةٌ تنقص بلا أن يُعلم لماذا.
run "(د) وصلٌ داخليٌّ يبتلع الرأي" \
  sub "  left join public.app_users u on u.id = r.user_id" \
      "  join public.app_users u on u.id = r.user_id"

# ── هـ) ويخرج البريدُ مع الصورة ────────────────────────────────────────────
#
# **وهو ما قيل إنّه لن يخرج.** ولا يسقط بسؤال «أتعمل الدالّة؟» — يسقط لأنّ
# الأعمدةَ تُعدّ وتُفتَّش قيمُها عن `@`.
run "(هـ) يخرج البريدُ مع الصورة" \
  sub "  created_at  timestamptz,
  avatar_path text
)" \
      "  created_at  timestamptz,
  avatar_path text,
  leaked      text
)"

# ── و) ويعود الفراغُ `null` لا نصّاً فارغاً ────────────────────────────────
#
# `null` يعبر إلى `Review.avatarPath` فيصير `''` بـ`??` — لكنّ الحزمةَ تسأل
# عمّا يصل من الخادم لا عمّا تفعله دارت به.
run '(و) الفراغُ `null` لا نصّاً فارغاً' \
  sub "    coalesce(u.avatar_path, '') as avatar_path" \
      "    u.avatar_path as avatar_path"

# ── ز) وتُمنع عمّن لا حسابَ له ─────────────────────────────────────────────
#
# صفحةُ المزوّد بابُ المنصّة إلى غير المسجَّلين — وتبويبُ التقييمات يسقط لهم
# وحدَهم، وهو عطبٌ لا يراه من جرّبه وهو مسجَّلُ الدخول.
run "(ز) تُمنع عمّن لا حسابَ له" \
  sub "grant execute on function public.api_provider_reviews(uuid) to anon, authenticated;" \
      "grant execute on function public.api_provider_reviews(uuid) to authenticated;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
