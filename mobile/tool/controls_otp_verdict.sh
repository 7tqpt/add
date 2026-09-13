#!/usr/bin/env bash
# ضوابطُ سالبةٌ لقرار قبول رمز واتساب.
#
# **وما لا يسقط بالكسر ضمانةٌ كاذبة.** وأوّلُ ضابطٍ هنا هو العطبُ نفسُه الذي
# وقع: يُعاد السؤالُ إلى `verified` وحدَه، فيجب أن يسقط ردُّ الخادم الحيّ.
#
# **وموضعُه هنا مع إخوته وإن كان يحرس ملفّاً خارج `mobile/`** — الضوابطُ في
# موضعٍ واحدٍ يُقرأ، لا في موضعين يُنسى أحدُهما.
set -uo pipefail
cd "$(dirname "$0")/../.."
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

V=supabase/functions/phone-otp/verdict.mjs
SUITE=supabase/tests/phone_otp_verdict.test.mjs

BACKUP=$(mktemp -d); cp "$V" "$BACKUP/v"
restore() { cp "$BACKUP/v" "$V"; }
trap 'restore; rm -rf "$BACKUP"' EXIT
PASS=0; FAIL=0

sub() {
  local old="$1" new="$2" n
  n=$(python3 - "$V" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1; fi
  python3 - "$V" "$old" "$new" <<'PY'
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

# أ) **وهذا هو العطبُ بعينه.** بقي يومين يردّ كلَّ رمزٍ صحيح، ولم يُمسكه
#    شيءٌ لأنّ القرارَ لم يكن يُقاس.
run "أ) السؤالُ عن verified وحدَه (العطبُ الأصليّ)" sub \
  "  return body.verified === true || body.status === true;" \
  "  return body.verified === true;"

# ب) **والقبولُ بلا شرطٍ ثقبٌ لا عطب** — يؤكّد به كلُّ أحدٍ رقمَ كلِّ أحد.
run "ب) يُقبل كلُّ ردّ" sub \
  "  return body.verified === true || body.status === true;" \
  "  return true;"

# ج) **وحالةُ HTTP تُهمَل** — فيُقبل ردُّ وسيطٍ يعيد صفحةً فيها الكلمة.
run "ج) حالةُ HTTP مهمَلة" sub \
  "  if (!httpOk) return false;" \
  ""

# د) **وردٌّ ليس JSON يُقرأ قبولاً** — صفحةُ ٥٠٢ من وسيطٍ تؤكّد رقماً.
run "د) ما ليس JSON يُقبَل" sub \
  "    // ردٌّ ليس JSON — صفحةُ خطأ من وسيطٍ مثلاً. ولا يُقرأ قبولاً.
    return false;" \
  "    return true;"

# هـ) **والصِدقُ العابرُ يكفي** — فنصُّ \"false\" يُقرأ قبولاً، وهو نصٌّ
#     غيرُ فارغٍ فيصدق.
run "هـ) صِدقٌ عابرٌ لا تطابقٌ تامّ" sub \
  "  return body.verified === true || body.status === true;" \
  "  return Boolean(body.verified) || Boolean(body.status);"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
