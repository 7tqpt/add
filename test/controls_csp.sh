#!/usr/bin/env bash
# ضوابطُ سالبةٌ لسياسة المحتوى — `netlify.toml` و`test/csp.test.ts`.
# تكسر كلَّ ضمانةٍ مرّةً، وتتأكّد أنّ الاختبارَ يحمرّ، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")/.."

T=netlify.toml
H=index.html
BACKUP=$(mktemp -d)
cp "$T" "$BACKUP/t"; cp "$H" "$BACKUP/h"
restore() { cp "$BACKUP/t" "$T"; cp "$BACKUP/h" "$H"; }
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
  out=$(npx vitest run test/csp.test.ts 2>&1)
  if echo "$out" | grep -qE "Tests +[0-9]+ passed \("; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"; echo "$out" | grep -E "^ +(×|✗|FAIL)|^ FAIL" | sort -u | head -3 | sed 's/^/   /'
    PASS=$((PASS+1))
  fi
  restore
}

run "(أ) سكربتُ الثيم يُعدَّل ولا تُبدَّل بصمتُه" sub "$H" \
  "if (t === 'dark' || t === 'light')" "if (t === 'dark' || t === 'light' || false)"

run "(ب) يُسمح بكلّ نصٍّ مضمَّن" sub "$T" \
  "script-src 'self' 'sha256-" "script-src 'self' 'unsafe-inline' 'sha256-"

run "(ج) لا قناةَ حيّةَ مع Supabase" sub "$T" \
  "https://*.supabase.co wss://*.supabase.co;" "https://*.supabase.co;"

run "(د) تُؤطَّر في أيّ صفحة" sub "$T" \
  "frame-ancestors 'none'" "frame-ancestors *"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
