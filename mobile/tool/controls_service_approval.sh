#!/usr/bin/env bash
# ضوابطُ سالبةٌ لموافقة الإدارة على خدمةٍ خارج أقسام صاحبها (ج) — تكسر كلَّ ضمانةٍ
# مرّةً بشيفرةٍ صالحة، وتتأكّد أنّ الحزمةَ تحمرّ، وتطبع ما سقط.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/service_approval_test.dart"
FILES="lib/src/screens/services.dart lib/src/data/demo.dart"

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

# ── أ) ما خارج أقسامه لا يُقال تحت الحقل ─────────────────────────────────────
run "(أ) لا يُقال إنّها تنتظر" sub lib/src/screens/services.dart \
"                !_mine.contains(_categoryId) &&" \
"                _mine.contains(_categoryId) &&"

run "(ب) أقسامُه لا تُقرأ" sub lib/src/screens/services.dart \
"      if (mounted) setState(() => _mine = ids);" \
"      if (mounted) setState(() {});"

run "(ج) «تنتظر» لما وُوفق عليه بعينه" sub lib/src/screens/services.dart \
"                (widget.service == null || widget.service!.categoryId != _categoryId)) ...[" \
"                true) ...["

run "(د) المنتظرةُ «معروضة»" sub lib/src/screens/services.dart \
"                        : s.approval == 'pending'
                            ? tr('بانتظار موافقة الإدارة')" \
"                        : false
                            ? tr('بانتظار موافقة الإدارة')"

run "(هـ) سببُ الرفض لا يُكتب" sub lib/src/screens/services.dart \
"                          ? trf('لم تقبلها الإدارة: {0} — عدّلها فتعود للمراجعة.', [s.approvalNote])" \
"                          ? tr('لم تقبلها الإدارة.')"

# ووضعُ العرض «خادمٌ» يُقاس ما وصله — فإن قَبِل ما خارج أقسامه بلا موافقةٍ سقط.
run "(و) ما خارج أقسامه يُقبل" sub lib/src/data/demo.dart \
"      ? (demoProviderCategoryIds.contains(category) ? 'approved' : 'pending')" \
"      ? 'approved'"

run "(ز) المرفوضةُ لا تعود للمراجعة" sub lib/src/data/demo.dart \
"  final recompute = before == null || before.categoryId != category || before.approval == 'rejected';" \
"  final recompute = before == null || before.categoryId != category;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
