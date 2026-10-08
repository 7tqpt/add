#!/usr/bin/env bash
# ضوابطُ سالبةٌ لتقييد المزوّد بأقسامه — `provider_category_lock.sql`.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE=provider_category_lock.test.mjs
F=../provider_category_lock.sql

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"
restore() { cp "$BACKUP/f" "$F"; }
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
  local outp
  if outp=$(timeout 300 node "$SUITE" 2>&1); then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; echo "$outp" | grep '❌' | sed 's/^/     /'; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 node "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) العميلُ يرى الخدمةَ خارج أقسام صاحبها ─────────────────────────────────
run "(أ) المخفيّةُ تُرى" sub "$F" \
"                  where p.id = provider_id and p.status = 'verified')
     and public.service_in_provider_categories(provider_id, category_id))" \
"                  where p.id = provider_id and p.status = 'verified'))"

# ── ب) المزوّدُ يضيف في أيّ قسم ─────────────────────────────────────────────
#
# **وهذا لبُّ الطلب:** «كيف اقيد المقدم الخدمة ب القسام الذي اختارة».
run "(ب) يضيف في أيّ قسم" sub "$F" \
"  if not public.service_in_provider_categories(new.provider_id, new.category_id) then
    raise exception 'لا تُضاف خدمةٌ إلّا في قسمك المسجَّل.';" \
"  if false then
    raise exception 'لا تُضاف خدمةٌ إلّا في قسمك المسجَّل.';"

# ── ج) ويكتب أقسامَه بنفسه — السياسةُ القديمةُ تعود ──────────────────────────
run "(ج) يضيف لنفسه قسماً" sub "$F" \
"  using (public.can_write_area('directory') or public.can_write_area('catalog'))
  with check (public.can_write_area('directory') or public.can_write_area('catalog'));" \
"  using (provider_id = public.current_provider() or public.can_write_area('directory'))
  with check (provider_id = public.current_provider() or public.can_write_area('directory'));"

# ── د) وتُحجز المخفيّةُ برابطٍ قديم ──────────────────────────────────────────
run "(د) المخفيّةُ تُحجز" sub "$F" \
"  if found and not public.service_in_provider_categories(svc.provider_id, svc.category_id) then
    raise exception 'هذه الخدمة غير متاحة للحجز حالياً';" \
"  if false then
    raise exception 'هذه الخدمة غير متاحة للحجز حالياً';"

# ── هـ) وكلُّ تعديلٍ لمخفيّةٍ يُردّ — فلا يستطيع إصلاحها ─────────────────────
run "(هـ) تعديلُ المخفيّة يُردّ" sub "$F" \
"  if tg_op = 'UPDATE'
     and new.category_id is not distinct from old.category_id
     and new.provider_id is not distinct from old.provider_id then
    return new;
  end if;
" \
""

# ── و) والمزوّدُ يضبط أقسامَه بالدالّة ───────────────────────────────────────
run "(و) المزوّدُ يضبط أقسامَه" sub "$F" \
"  if not public.can_write_area('directory') then
    raise exception 'تغييرُ أقسام مقدّم الخدمة لمن يدير مقدّمي الخدمة';" \
"  if auth.uid() is null then
    raise exception 'تغييرُ أقسام مقدّم الخدمة لمن يدير مقدّمي الخدمة';"

# ── ز) ويُترك بلا قسم ─────────────────────────────────────────────────────────
run "(ز) بلا قسم" sub "$F" \
"  if coalesce(array_length(wanted, 1), 0) = 0 then" \
"  if false then"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
