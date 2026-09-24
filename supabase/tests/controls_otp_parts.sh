#!/usr/bin/env bash
# ضوابطُ سالبةٌ لأجزاء حدِّ المحاولات الثلاثة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وثلاثُ ضماناتٍ هنا لا واحدة**: أنّ الأجزاءَ هي الأصلُ نفسُه، وأنّ لكلٍّ
# إيصالاً يُقرأ في «Results»، وأنّ كلَّ جزءٍ أقصرُ من القطع الذي وقع مرّتين
# في محرّر Supabase. والثالثةُ هي علّةُ القسمة كلِّها — فإن لم تُقَس عادت
# الأجزاءُ تنتفخ حتى تنقطع من حيث لا يُنتبه.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

BACKUP=$(mktemp -d)
for n in 1 2 3; do cp "../phone_otp_$n.sql" "$BACKUP/$n"; done
restore() { for n in 1 2 3; do cp "$BACKUP/$n" "../phone_otp_$n.sql"; done; }
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

# ينفخ جزءاً بأسطر تعليقٍ حتى يتجاوز الحدّ.
bloat() {
  python3 - "$1" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write('-- حشو\n' * 100 + s)
PY
}

run() {
  local name="$1"; shift
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  if timeout 600 node phone_verify_attempts.test.mjs >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 node phone_verify_attempts.test.mjs >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== والأجزاءُ هي الأصل =="

# ── أ) يُبدَّل الحدُّ في الجزء دون أصله ───────────────────────────────────
#
# **وهذا هو الافتراقُ الذي يُخشى**: يُصحَّح الحدُّ في `phone_verify.sql`
# ويبقى الجزءُ على قديمه، فيُلصق الجزءُ ويُظنّ أنّ الأصلَ رُكّب.
run "(أ) الحدُّ في الجزء غيرُه في الأصل" \
  sub ../phone_otp_2.sql \
"  if v_phone_15m >= 5 then" \
"  if v_phone_15m >= 50 then"

# ── ب) وتُنزع جملةٌ من جزء ────────────────────────────────────────────────
#
# نزعُ نزع الصلاحيّة يترك الدالّةَ ممنوحةً لكلّ مسجَّل — والشاشةُ تعمل، ولا
# يُرى شيء.
run "(ب) جملةٌ ناقصةٌ من جزء" \
  sub ../phone_otp_2.sql \
"revoke all on function public.otp_claim_verify(uuid, text)
  from public, anon, authenticated;" \
"-- نُزعت"

echo; echo "== والإيصالُ يُقرأ =="

# ── ج) ويُحذف الإيصال ─────────────────────────────────────────────────────
#
# وبلا إيصالٍ يُقرأ في «Results» لا يعرف اللاصقُ أنّ لصقَه انقطع: لصقٌ
# يُقطع بعد `commit;` يُخرج «Success. No rows returned» — نجاحاً ظاهرُه تمام.
run "(ج) جزءٌ بلا إيصال" \
  sub ../phone_otp_3.sql \
"select 'المحو ✓' as \"تمّ\";" \
"-- بلا إيصال"

echo; echo "== والحجمُ دون القطع =="

# ── د) وينتفخ جزءٌ فوق الحدّ ──────────────────────────────────────────────
#
# **وهذه علّةُ القسمة كلِّها.** انقطع اللصقُ مرّتين — ٤٣٢ سطراً عند ١٥٠ ثمّ
# ١٧٢ عند ١٠٠ — في وسط `$$` فرُدَّ الملفُّ كلُّه. فجزءٌ يعود ينتفخ يعود
# بالعطب، ولا ينتبه أحدٌ حتى يقع عند اللصق.
run "(د) جزءٌ أطولُ من حدِّ اللصق" bloat ../phone_otp_1.sql

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
