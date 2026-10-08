#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«تفريغ المنتهية» — `api_admin_clear_promotions` في `promotions_clear.sql`.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE=promotions_clear.test.mjs
F=../promotions_clear.sql

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

# ── أ) يُفرِّغ غيرُ المالك ──────────────────────────────────────────────────
#
# **وهذا أخطرُها:** اختار صاحبُ المنصّة «المالك وحده»، وكلُّ مَن يكتب في المال
# يملك `can_write_area('finance')` — فيصير الزرُّ في يد «المدير» و«المحاسب».
run "(أ) «مدير» يُفرِّغ" sub "$F" \
"  if not public.is_owner() then" \
"  if not public.can_write_area('finance') then"

# ── ب) يُحذف طلبُ مزوّدٍ حوالتُه معلّقة ─────────────────────────────────────
run "(ب) يُحذف الطلبُ المعلَّق" sub "$F" \
"        or (pr.status = 'scheduled' and pr.payment_id is null and pr.ends_at < now())" \
"        or (pr.status = 'scheduled' and pr.ends_at < now())"

# ── ج) وتُحذف الجاريةُ — بلا شرط التاريخ ─────────────────────────────────────
run "(ج) الجاريةُ تُحذف" sub "$F" \
"        or (pr.status = 'active' and pr.ends_at < now())" \
"        or (pr.status = 'active')"

# ── د) ويبقى ما انقضى وعمودُه «جارية» ───────────────────────────────────────
run "(د) «انتهت مدّتها» تبقى" sub "$F" \
"        or (pr.status = 'active' and pr.ends_at < now())
" \
""

# ── هـ) وتضيع روابطُ الصور المتعدّدة — فتبقى ملفّاتها في التخزين ─────────────
run "(هـ) صورُ الحملة الواحدة لا تُرجَع كلُّها" sub "$F" \
"                  coalesce(g.image_urls, '{}') || array[g.image_url]) u" \
"                  array[g.image_url]) u"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
