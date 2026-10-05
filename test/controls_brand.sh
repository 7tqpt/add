#!/usr/bin/env bash
# ضوابطُ سالبةٌ لهويّة «فرحتي» في اللوحة — `test/brand.test.ts`، ثمّ المقيسُ في
# المتصفّح (`tool/dashboard_shots.mjs`) لما لا يُقاس إلّا مرسوماً.
# تكسر كلَّ ضمانةٍ مرّةً، وتتأكّد أنّ ما يقيسها يحمرّ، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")/.."

FILES="src/index.css src/components/brand/Brand.tsx src/components/layout/Sidebar.tsx src/components/layout/UserMenu.tsx src/components/layout/Topbar.tsx src/pages/Login.tsx index.html"
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

# المقياسُ: unit (Vitest) أو browser (بناءٌ ثمّ لقطات)
run() {
  local kind="$1" name="$2"; shift 2
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  local out ok
  if [ "$kind" = unit ]; then
    out=$(npx vitest run test/brand.test.ts 2>&1)
    echo "$out" | grep -qE "Tests +[0-9]+ passed \(" && ok=1 || ok=0
  else
    npm run build >/dev/null 2>&1
    out=$(SHOTS="$BACKUP/shots" node tool/dashboard_shots.mjs 2>&1)
    echo "$out" | grep -q "كلُّ ما قيس أخضر" && ok=1 || ok=0
  fi
  if [ "$ok" = 1 ]; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "^ +(×|✗)|^❌" | sort -u | head -3 | sed 's/^/   /'
    PASS=$((PASS+1))
  fi
  restore
}

run unit "(أ) اللونُ الفاعلُ أزرقُ كما كان" sub src/index.css \
  "  --accent: #7b0f2e;
  --accent-ink: #ffffff;

  /* الذهبُ" "  --accent: #1d4ed8;
  --accent-ink: #ffffff;

  /* الذهبُ"

run unit "(ب) خطٌّ باسمٍ بلا ملفّ" sub src/index.css \
  "@font-face { font-family: 'IBM Plex Sans Arabic'; src: url('/fonts/IBMPlexSansArabic-600.ttf') format('truetype'); font-weight: 600; font-display: swap; }
" ""

run unit "(ج) العلامةُ القديمة" sub src/components/brand/Brand.tsx \
  'const LOGO = "/brand/farhati.png";' 'const LOGO = "/brand/logo.png";'

run unit "(د) «Profile» تعود" sub src/components/layout/UserMenu.tsx \
  "        {initialOf(user.email)}" "        <span>Profile</span>"

run unit "(هـ) التحيّةُ تنقلب عند الحادية عشرة" sub src/components/layout/Topbar.tsx \
  "  return now.getHours() < 12 ? 'صباح الخير' : 'مساء الخير'" \
  "  return now.getHours() < 11 ? 'صباح الخير' : 'مساء الخير'"

run unit "(و) الحرفُ رمزٌ لا حرف" sub src/components/layout/UserMenu.tsx \
  "  const letter = [...name].find((c) => /\\p{L}/u.test(c))" \
  "  const letter = [...name][0]"

run browser "(ز) القائمةُ بيضاءُ في المتصفّح" sub src/components/layout/Sidebar.tsx \
  "        style={{ background: 'linear-gradient(180deg, var(--side-from), var(--side-to) 62%, var(--side-from))' }}" \
  "        style={{ background: 'var(--surface)' }}"

run browser "(ح) الخطُّ لا يُحمَّل في المتصفّح" sub src/index.css \
  "@font-face { font-family: 'IBM Plex Sans Arabic'; src: url('/fonts/IBMPlexSansArabic-400.ttf')" \
  "@font-face { font-family: 'IBM Plex Sans Arabic'; src: url('/fonts/missing-400.ttf')"

run unit "(ط) صفحةُ الدخول بلا ورود" sub src/pages/Login.tsx \
  'style={{ backgroundImage: "url(/brand/roses.webp)" }}' 'style={{}}'

run browser "(ي) البطاقةُ تتبع الوضعَ الداكن فتسودّ" sub src/pages/Login.tsx \
  '          data-theme="light"
' ''

run browser "(ك) الحقلُ بـrem فيطول على جذر ١٧" sub src/index.css \
  ".login-field {
  height: 48px;" ".login-field {
  height: 3rem;"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
npm run build >/dev/null 2>&1
[ "$FAIL" = 0 ]
