#!/usr/bin/env bash
# ضوابطُ سالبةٌ لأقسام المزوّد وموافقة الإدارة (ج) — `provider_category_lock.sql`.
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

# ── أ) العميلُ يرى ما لم يُوافَق عليه ────────────────────────────────────────
run "(أ) المنتظرةُ تُرى" sub "$F" \
"     and approval = 'approved'
     and exists (select 1 from public.service_providers p" \
"     and exists (select 1 from public.service_providers p"

# ── ب) وما خارج أقسامه يُقبل بلا موافقة — لبُّ الطلب «بعلم الادارة» ───────────
run "(ب) خارج أقسامه يظهر فوراً" sub "$F" \
"      else 'pending' end;" \
"      else 'approved' end;"

# ── ج) والمزوّدُ يكتب موافقتَه بنفسه ─────────────────────────────────────────
run "(ج) يوافق على خدمته" sub "$F" \
"    new.approval      := old.approval;
" \
""

# ── د) ويكتب أقسامَه بنفسه — السياسةُ القديمةُ تعود ──────────────────────────
run "(د) يضيف لنفسه قسماً" sub "$F" \
"  using (public.can_write_area('directory') or public.can_write_area('catalog'))
  with check (public.can_write_area('directory') or public.can_write_area('catalog'));" \
"  using (provider_id = public.current_provider() or public.can_write_area('directory'))
  with check (provider_id = public.current_provider() or public.can_write_area('directory'));"

# ── هـ) وتُحجز المنتظرةُ برابطٍ قديم ─────────────────────────────────────────
run "(هـ) المنتظرةُ تُحجز" sub "$F" \
"  if found and svc.approval <> 'approved' then" \
"  if false then"

# ── و) والمرفوضةُ تبقى مرفوضةً وإن عدّلها ────────────────────────────────────
run "(و) المرفوضةُ لا تعود للمراجعة" sub "$F" \
"              or new.provider_id is distinct from old.provider_id
              or old.approval = 'rejected';" \
"              or new.provider_id is distinct from old.provider_id;"

# ── ز) وإضافةُ القسم لا تقبل خدماتِه فيه ─────────────────────────────────────
run "(ز) إضافةُ القسم لا تقبل" sub "$F" \
"     and approval <> 'approved'
     and category_id = any (wanted);" \
"     and approval <> 'approved'
     and false;"

# ── ح) وحذفُ القسم ينقض الموافقةَ على خدمةٍ بعينها ──────────────────────────
run "(ح) حذفُ القسم ينقض الموافقةَ الفرديّة" sub "$F" \
"     and approval = 'approved'
     and approval_at is null
     and category_id = any (coalesce(removed, '{}'));" \
"     and approval = 'approved'
     and category_id = any (coalesce(removed, '{}'));"

# ── ط) والرفضُ بلا سبب ──────────────────────────────────────────────────────
run "(ط) رفضٌ بلا سبب" sub "$F" \
"  if not p_approve and btrim(coalesce(p_note, '')) = '' then" \
"  if false then"

# ── ي) والمزوّدُ يراجع خدمتَه ────────────────────────────────────────────────
run "(ي) المزوّدُ يراجع" sub "$F" \
"  if not (public.can_write_area('directory') or public.can_write_area('catalog')) then
    raise exception 'مراجعةُ الخدمات لمن يدير مقدّمي الخدمة';" \
"  if auth.uid() is null then
    raise exception 'مراجعةُ الخدمات لمن يدير مقدّمي الخدمة';"

# ── ك) وما كان قائماً خارج أقسامه يبقى ظاهراً بعد اللصق ──────────────────────
run "(ك) القائمُ لا يُراجَع" sub "$F" \
"update public.provider_services s
   set approval = 'pending'" \
"update public.provider_services s
   set approval = 'approved'"

# ── ل) والموافقةُ على خدمةٍ لا تضيف قسمَها — «ليش عن المزود جالس يظهر الملبوسات» ──
run "(ل) الموافقةُ لا تضيف القسم" sub "$F" \
"    insert into public.provider_categories (provider_id, category_id)
    values (svc.provider_id, svc.category_id)
    on conflict do nothing;
    get diagnostics added = row_count;" \
"    added := 0;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
