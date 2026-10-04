#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبابِ محاولات الرمز — `verifyGate` في `phone-otp/verdict.mjs`
# ونداؤه في `index.ts`. تكسر كلَّ ضمانةٍ مرّةً، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

V=../functions/phone-otp/verdict.mjs
I=../functions/phone-otp/index.ts
BACKUP=$(mktemp -d)
cp "$V" "$BACKUP/v"; cp "$I" "$BACKUP/i"
restore() { cp "$BACKUP/v" "$V"; cp "$BACKUP/i" "$I"; }
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
  local out
  out=$(node phone_otp_verdict.test.mjs 2>&1)
  if echo "$out" | grep -q "كلُّ ما يُقاس أخضر"; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"; echo "$out" | grep -E "^❌" | sed 's/^/     /' | head -3
    PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if node phone_otp_verdict.test.mjs >/dev/null 2>&1; then echo "أخضر."; else echo "الأساسُ أحمر."; exit 1; fi
echo

# كما كان تماماً: الخطأُ يُكتب ثمّ يُمضى.
run "(أ) خطأُ دالّة الحدّ يُمضى كما كان" sub "$V" \
  "export function verifyGate(error, claim) {" \
  "export function verifyGate(error, claim) {
  if (error) return null;"

run "(ب) السماحُ بأيّ صدق" sub "$V" \
  "  if (claim.allowed === true) return null;" \
  "  if (claim.allowed || error) return null;"

run "(ج) index.ts يكتب في السجلّ ولا يعود" sub "$I" \
  "        return json(
          {
            error: gate.error ?? limitMessage(gate.reason, gate.wait)," \
  "        void (
          {
            error: gate.error ?? limitMessage(gate.reason, gate.wait),"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
