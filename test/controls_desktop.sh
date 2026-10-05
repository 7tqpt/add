#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبرنامج سطح المكتب — `test/desktop.test.ts`.
# تكسر كلَّ ضمانةٍ مرّةً، وتتأكّد أنّ الاختبارَ يحمرّ، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")/.."

FILES="src-tauri/tauri.conf.json .github/workflows/desktop.yml"
BACKUP=$(mktemp -d)
for f in $FILES; do mkdir -p "$BACKUP/$(dirname "$f")"; cp "$f" "$BACKUP/$f"; done
restore() { for f in $FILES; do cp "$BACKUP/$f" "$f"; done; }
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
  out=$(npx vitest run test/desktop.test.ts 2>&1)
  if echo "$out" | grep -qE "Tests +[0-9]+ passed \("; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "^ +×" | sort -u | head -3 | sed 's/^/   /'
    PASS=$((PASS+1))
  fi
  restore
}

run "(أ) صورُ القاعدة ممنوعةٌ كما كانت" sub src-tauri/tauri.conf.json \
  "blob: https://*.supabase.co; media-src" "blob:; media-src"

run "(ب) الصوتُ ممنوع" sub src-tauri/tauri.conf.json \
  "media-src 'self' blob: https://*.supabase.co;" "media-src 'self' blob:;"

run "(ج) النافذةُ باسمها القديم" sub src-tauri/tauri.conf.json \
  '"title": "فرحتي — لوحة الإدارة"' '"title": "لوحة تحكم سد — منصة حجوزات وتجهيز الأعراس"'

run "(د) المُثبِّتُ باسمه القديم" sub .github/workflows/desktop.yml \
  'cp "$f" "out/farhati-dashboard-' 'cp "$f" "out/sdd-dashboard-'

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
