#!/usr/bin/env bash
# ضوابطُ سالبةٌ لجدولة الحملات — `expire_promotions` في `banners.sql`.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE=banners_schedule.test.mjs
F=../banners.sql

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

# ── أ) تعود الدورةُ ترفع كلَّ مجدول — ومنه طلبُ مزوّدٍ لم يدفع ─────────────────
#
# **وهذا أخطرُها:** ظهورٌ مدفوعٌ يُعطى بلا مال، ولا يشكو منه أحد.
run "(أ) الدورةُ تُظهر من لم يدفع" \
  sub "$F" \
"     and payment_id is null
" \
""

# ── ب) ولا ترفع لافتةَ الإدارة في موعدها ────────────────────────────────────
run "(ب) لافتةُ الغد تبقى مجدولةً أبداً" \
  sub "$F" \
"     set status = 'active'
   where status = 'scheduled'" \
"     set status = 'scheduled'
   where status = 'scheduled'"

# ── ج) وتُعرض المنقضيةُ ما دام عمودُها «جارية» ───────────────────────────────
run "(ج) اللافتةُ المنقضيةُ تُعرض" \
  sub "$F" \
"     and pr.status = 'active'
     and now() between pr.starts_at and pr.ends_at
     and coalesce(img.url, '') <> ''" \
"     and pr.status = 'active'
     and coalesce(img.url, '') <> ''"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
