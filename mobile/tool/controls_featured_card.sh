#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبطاقة «مقدّم خدمة مميّز» على صورة صاحب المنصّة — تكسر كلَّ ضمانةٍ
# مرّةً بشيفرةٍ صالحة، وتتأكّد أنّ الحزمةَ تحمرّ، وتطبع ما سقط.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/featured_card_test.dart test/polish_test.dart"
FILES="lib/src/screens/home.dart"

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

H=lib/src/screens/home.dart

# ── أ) يعود الارتفاعُ القديم — فتفيض البطاقةُ الكبيرة بخطّ الجهاز ──────────────
run "(أ) الارتفاعُ القديم" sub $H \
"          height: 122 + 60 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0)," \
"          height: 96 + 56 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),"

run "(ب) العلامةُ في الزاوية اليسرى" sub $H \
"                            PositionedDirectional(
                              start: -2," \
"                            PositionedDirectional(
                              end: -2,"

run "(ج) العنوانُ القديم" sub $H \
"        SectionTitle(tr('مقدّم خدمة مميّز'))," \
"        SectionTitle('مزوّدون مميّزون'),"

run "(د) الاسمُ إلى الحافّة" sub $H \
"                      promo.providerName,
                      textAlign: TextAlign.center," \
"                      promo.providerName,
                      textAlign: TextAlign.start,"

run "(هـ) شارةُ القسم مربّعة" sub $H \
"                            borderRadius: BorderRadius.circular(999)," \
"                            borderRadius: BorderRadius.circular(5),"

run "(و) الصورةُ صغيرة" sub $H \
"                            imageUrl: Api.avatarUrl(promo.logoPath),
                            size: 64," \
"                            imageUrl: Api.avatarUrl(promo.logoPath),
                            size: 34,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
