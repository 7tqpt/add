#!/usr/bin/env bash
# ضوابطُ سالبةٌ لسطر الإصدار — «الإصدار 1.1.1» بلا رقم البناء، ورقمُ البناء لا يُصفَّر.
# تكسر كلَّ ضمانةٍ مرّةً بشيفرةٍ صالحة، وتتأكّد أنّ الحزمةَ تحمرّ، وتطبع ما سقط.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/polish_test.dart test/app_update_test.dart"
FILES="lib/src/core/app_version.dart pubspec.yaml"

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
  out=$(timeout 900 flutter test -r expanded $SUITE 2>&1)
  if echo "$out" | grep -q "All tests passed"; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  elif echo "$out" | grep -q "Compilation failed"; then
    echo "✗ $name — لم يُبنَ، فلم يُقس شيء"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "\[E\]$" | sed -E 's/^.*test\/([^:]+): /     • \1: /' | sort -u | head -4
    PASS=$((PASS+1))
  fi
  restore
}

# ── أ) يعود رقمُ البناء إلى السطر — «بدون (127)هذا العدد» ──────────────────
run "(أ) رقمُ البناء في السطر" sub lib/src/core/app_version.dart \
"String get appVersionLabel => 'الإصدار \$appVersionName';" \
"String get appVersionLabel => 'الإصدار \$appVersionName (\$appBuild)';"

# ── ب) ويُصفَّر رقمُ البناء معه — فيرفض Android الحزمةَ فوق القديمة ──────────
run "(ب) رقمُ البناء يُصفَّر" sub lib/src/core/app_version.dart \
"const appBuild = 138;" \
"const appBuild = 1;"

# ── ج) ويفترق الاسمُ عن pubspec ─────────────────────────────────────────────
run "(ج) الاسمُ يفترق عن pubspec" sub pubspec.yaml \
"version: 1.1.1+138" \
"version: 2.8.1+138"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
