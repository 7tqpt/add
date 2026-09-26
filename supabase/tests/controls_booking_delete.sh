#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحذف الحجز — `api_delete_booking`.
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

S=../booking_delete.sql

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
  if timeout 600 node booking_delete.test.mjs >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 node booking_delete.test.mjs >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الحرز =="

# ── أ) كلُّ أحدٍ يحذف حجزَ كلّ أحد ────────────────────────────────────────
#
# **وهذا أخطرُ ما في دالّةٍ `security definer`**: تعمل بصلاحيّة كاتبها، فبلا
# فحصِ صاحبِ الحجز يُمحى حجزُ الناس بمعرّفه.
run "(أ) لا يُفحص صاحبُ الحجز" \
  sub "$S" \
"  if booking.user_id is distinct from me and not public.can_write_area('bookings') then
    raise exception 'لا تملك صلاحية حذف هذا الحجز';
  end if;" \
"  if false then
    raise exception 'لا تملك صلاحية حذف هذا الحجز';
  end if;"

# ── ب) والمجهولُ يُمنح التنفيذ ───────────────────────────────────────────
run "(ب) الدالّةُ ممنوحةٌ للزائر" \
  sub "$S" \
"grant execute on function public.api_delete_booking(uuid) to authenticated;" \
"grant execute on function public.api_delete_booking(uuid) to anon, authenticated;"

echo; echo "== وأبوابُ المنع =="

# ── ج) ويُمحى حجزٌ دخله مال ──────────────────────────────────────────────
#
# **ومرجعُ `payments` إليه `on delete set null`** — فيبقى مبلغٌ مدفوعٌ بلا
# حجزٍ يُنسب إليه، ولا يُعرف بعدها لمن دُفع ولا عمّاذا.
run "(ج) يُمحى ما دخله مال" \
  sub "$S" \
"  if paid > 0 or coalesce(booking.paid_amount, 0) > 0 then" \
"  if paid > 0 and coalesce(booking.paid_amount, 0) > 0 then"

# ── ج٢) ولا يُنظر في `payments` أصلاً ────────────────────────────────────
#
# **وبابان لا بابٌ واحد**: حجزٌ له صفُّ دفعٍ و`paid_amount` صفرٌ يقع —
# وكسرُ (ج) وحدَه لا يكشف ذلك.
run "(ج٢) لا يُنظر في صفوف الدفع" \
  sub "$S" \
"  select count(*) into paid from public.payments where booking_id = booking.id;" \
"  select 0 into paid;"

# ── د) ويُمحى حجزٌ دخل تسوية ─────────────────────────────────────────────
#
# **والقاعدةُ سترفضه بـ`restrict` على كلّ حال** — فالمقيسُ أن يُقال له
# لماذا بالعربيّة لا أن يخرج خطأُ مفتاحٍ أجنبيّ.
run "(د) لا يُفحص دخولُه تسويةً" \
  sub "$S" \
"  if exists (select 1 from public.settlement_items where booking_id = booking.id) then
    raise exception 'لا يُحذف حجزٌ دخل تسوية.';
  end if;" \
"  if false then
    raise exception 'لا يُحذف حجزٌ دخل تسوية.';
  end if;"

# ── هـ) ويُمحى حجزٌ عليه نزاعٌ مفتوح ─────────────────────────────────────
#
# الحجزُ سندُ النزاع، ومحوُه يُسقط ما تنظر فيه الإدارة.
run "(هـ) لا يُفحص النزاعُ المفتوح" \
  sub "$S" \
"       and status in ('open', 'investigating')" \
"       and status in ('resolved')"

echo; echo "== والحذفُ نفسُه =="

# ── و) ولا يُمحى شيءٌ أصلاً ──────────────────────────────────────────────
#
# **دالّةٌ تقول `deleted` ولا تحذف** تُقرأ نجاحاً وهي لا شيء.
run "(و) تقول deleted ولا تحذف" \
  sub "$S" \
"  delete from public.bookings where id = booking.id;" \
"  update public.bookings set cancel_reason = cancel_reason where id = booking.id;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
