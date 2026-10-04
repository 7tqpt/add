#!/usr/bin/env bash
# ضوابطُ سالبةٌ للفحص الأمنيّ الثاني — `security_fixes.sql` وأصوله.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً في **الأصل** (لا في الملفّ المركَّب)، ثمّ تُعيد
# تركيبَ `install.sql` و`security_fixes.sql` منه كما يُفعل عند كلّ تعديل —
# فلا يسقط الاختبارُ لأنّ المركَّبَ افترق عن أصله، بل لأنّ الحرزَ انكسر.
# **وتطبع ما سقط** ليُرى أنّه سقط للسبب المقصود.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

FILES="../policies.sql ../chat.sql ../coupons.sql ../location.sql ../document_guard.sql ../install.sql ../security_fixes.sql ../../tool/security_sql.mjs"
BACKUP=$(mktemp -d)
for f in $FILES; do cp "$f" "$BACKUP/$(basename "$f")"; done
restore() { for f in $FILES; do cp "$BACKUP/$(basename "$f")" "$f"; done; }
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

rebuild() {
  node ../../tool/security_sql.mjs install > ../install.sql &&
  node ../../tool/security_sql.mjs fixes > ../security_fixes.sql
}

run() {
  local name="$1"; shift
  restore
  if ! "$@" || ! rebuild; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  local out
  out=$(timeout 600 node security_fixes.test.mjs 2>&1)
  if echo "$out" | grep -q "كل اختبارات الفحص الأمني الثاني نجحت"; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "^❌" | cut -c1-140 | sed 's/^/     /' | head -4
    PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 node security_fixes.test.mjs >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi
echo

# ── المحادثات ───────────────────────────────────────────────────────────────
run "(أ) اللصقةُ لا تنزع سياسةَ الإدخال المباشر من القاعدة الحيّة" sub ../../tool/security_sql.mjs \
  "-- Source: policies.sql
drop policy if exists conversations_parties_write on public.conversations;" \
  "-- Source: policies.sql"

run "(ب) يُربط بالمحادثة حجزُ غير صاحبها" sub ../chat.sql \
  "    where b.id = p_booking_id and b.user_id = me and b.provider_id = p_provider_id" \
  "    where b.id = p_booking_id"

# ── التقييمات ───────────────────────────────────────────────────────────────
run "(ج) الزائرُ يُمنح user_id مع غيره" sub ../policies.sql \
  "     and column_name <> 'user_id';" \
  "     and column_name <> '';"

# ── المستندات ───────────────────────────────────────────────────────────────
run "(د) المستندُ يبقى بالحالة التي كتبها صاحبُه" sub ../document_guard.sql \
  "  new.status      := 'pending';" \
  "  new.status      := new.status;"

run "(هـ) المستندُ يُقبل في مجلّد غيره" sub ../document_guard.sql \
  "     and (left(new.file_url, 37) <> new.provider_id::text || '/'
          or position('..' in new.file_url) > 0) then" \
  "     and position('..' in new.file_url) > 0 then"

run "(و) الصعودُ من المجلّد يمرّ" sub ../document_guard.sql \
  "          or position('..' in new.file_url) > 0) then" \
  "          or false) then"

run "(ز) الحارسُ يحبس المسؤولَ أيضاً" sub ../document_guard.sql \
  "  if public.can_write_area('directory') then" \
  "  if false then"

# ── أكوادُ الخصم ────────────────────────────────────────────────────────────
run "(ح) لا حدَّ للأخطاء" sub ../coupons.sql \
  "  if misses >= 10 then" \
  "  if misses >= 1000 then"

run "(ط) الكودُ الخاطئُ يُرمى كما كان — فلا يُعدّ" sub ../coupons.sql \
  "    insert into public.coupon_checks (user_id, code, ok)
    values (me, upper(btrim(coalesce(p_code, ''))), false);
    return;" \
  "    insert into public.coupon_checks (user_id, code, ok)
    values (me, upper(btrim(coalesce(p_code, ''))), false);
    raise exception 'هذا الكود غير صحيح';"

run "(ي) الحجزُ يقبل كوداً لم يُتحقَّق منه" sub ../location.sql \
  "      raise exception 'تحقّق من الكود أولاً';" \
  "      null;"

# ── وترتيبُ اللصق ───────────────────────────────────────────────────────────
run "(ك) اللصقةُ تمرّ بلا حدود المحاولات" sub ../../tool/security_sql.mjs \
  "  if to_regprocedure('public.otp_claim_verify(uuid,text)') is null then" \
  "  if false then"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
