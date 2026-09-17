#!/usr/bin/env bash
# ضوابطُ سالبةٌ لصورة الطرف الآخر في قائمة المحادثات.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **والدالّةُ `security definer` — تتجاوز سياسةَ `app_users` بتصميمها.**
# فحدُّها الوحيدُ ما كُتب في جسدها. وأخطرُ ما يُكسر هنا (أ): يسقط شرطُ
# «محادثاتي أنا»، فيقرأ أيُّ مستخدمٍ محادثاتِ الناس كلِّهم بأسمائهم وصورهم —
# **وهو أخطرُ ممّا كانت السياسةُ تحرسه أصلاً**.
set -uo pipefail
cd "$(dirname "$0")/../.."
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE="supabase/tests/conversation_avatars.test.mjs"
F=supabase/conversation_avatars.sql

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

# ── أ) تُرجع محادثاتِ الناس كلِّهم ──────────────────────────────────────────
run "(أ) بلا شرط «محادثاتي»" \
  sub "    and (c.user_id = me or c.provider_id = mine)" \
      "    and true"

# ── ب) ويعود مقدّمُ الخدمة بلا صورة ─────────────────────────────────────────
#
# وهو الحالُ الذي شُكي منه: حروفٌ في قائمته أبداً.
run "(ب) لا صورةَ لمقدّم الخدمة" \
  sub "      else coalesce((select u.avatar_path from public.app_users u
                      where u.id = c.user_id), '')" \
      "      else ''"

# ── ج) ويخرج البريدُ مع الصورة ──────────────────────────────────────────────
#
# **وهو ما قيل إنّه لن يخرج.** ولا يسقط بسؤال «أتعمل الدالّة؟» — تعمل. يسقط
# لأنّ الأعمدةَ تُعدّ وتُفتَّش قيمُها عن `@`.
run "(ج) يخرج البريدُ مع الصورة" \
  sub "    c.last_message_sender,
    case when c.user_id = me then 'customer' else 'provider' end as my_side," \
      "    c.last_message_sender,
    (select u.email from public.app_users u where u.id = c.user_id) as leaked,
    case when c.user_id = me then 'customer' else 'provider' end as my_side,"

# ── د) وتُمنح لمن لا حساب له ────────────────────────────────────────────────
run "(د) تُمنح لمن لا حساب له" \
  sub "grant execute on function public.api_my_conversations(uuid) to authenticated;" \
      "grant execute on function public.api_my_conversations(uuid) to authenticated, anon;
alter function public.api_my_conversations(uuid) security invoker;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
