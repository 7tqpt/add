#!/usr/bin/env bash
# ضوابطُ سالبةٌ لصورة الطرف الآخر في قائمة المحادثات.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (ب): تُرسَل صورةُ العميل إلى مقدّم الخدمة.** وهو كسرٌ
# يبدو إحساناً — صورةٌ للطرفين — وهو في الحقيقة كسرٌ لسياسةٍ صريحة: «العميل
# يرى ويعدّل حسابه هو. لا يرى حسابات غيره إطلاقاً». وصفُّ `app_users` يحمل
# البريدَ والجوالَ والحالة، لا الصورةَ وحدَها.
set -uo pipefail
cd "$(dirname "$0")/../.."
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE="supabase/tests/chat.test.mjs"
F=supabase/chat.sql

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/chat.sql"
restore() { cp "$BACKUP/chat.sql" "$F"; }
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
  if node --test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if node --test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) لا صورةَ لأحد ────────────────────────────────────────────────────────
run "(أ) العمودُ فارغٌ للطرفين" \
  sub "      then coalesce(sp.logo_path, '')" \
      "      then ''"

# ── ب) وتُرسَل صورةُ العميل إلى مقدّم الخدمة ────────────────────────────────
#
# **وهذا كسرٌ يبدو إحساناً.** والوصلُ يمرّ بسياسة المتصل، فما يعود ليس صورةً
# بل لا شيء — ومع ذلك تُكتب الشيفرةُ كأنّها تعمل. ولو وُسِّعت السياسةُ ليعمل
# لَكُشف معها البريدُ والجوالُ والحالة.
run "(ب) صورةُ العميل لمقدّم الخدمة" \
  sub "    else ''
  end as other_avatar" \
      "    else (select u.avatar_path from public.app_users u where u.id = c.user_id)
  end as other_avatar"

# ── ج) ويسقط الوصلُ فتختفي المحادثاتُ بلا مزوّد ─────────────────────────────
#
# `on delete set null` يُبقي المحادثةَ للعميل بعد حذف مزوّدها — ووصلٌ داخليٌّ
# يُخفيها من قائمته، فتختفي رسائلُه بلا سبب.
run "(ج) وصلٌ داخليٌّ يبتلع المحادثات" \
  sub "left join public.service_providers sp on sp.id = c.provider_id" \
      "join public.service_providers sp on sp.id = c.provider_id"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
