#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«مستندات التوثيق» على صورة صاحب المنصّة — ثلاثُ خانات،
# والاختيارُ لا يرفع، والرفعُ كلُّه بزرٍّ واحد، وما رُفع في خانته بحاله.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/documents_test.dart"
D=lib/src/screens/documents.dart

BACKUP=$(mktemp -d)
cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/d" "$D"; }
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
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "\[E\]$" | sed -E 's/^.*test\/([^:]+): /     • \1: /' | sort -u | head -6
    PASS=$((PASS+1))
  fi
  restore
}

run "(أ) الخانةُ الثالثةُ بنوعٍ آخر" sub "$D" \
  "    (type: 'certificate', title: tr('صورة خاصة بالقسم المطلوب')," \
  "    (type: 'work_samples', title: tr('صورة خاصة بالقسم المطلوب'),"

run "(ب) الاختيارُ يرفع فوراً" sub "$D" \
  "    setState(() => (_picked[type] ??= []).add(file));" \
  "    await Api.uploadDocument(providerId: '', type: type, fileName: file.name, bytes: file.bytes);
    setState(() => (_picked[type] ??= []).add(file));"

run "(ج) الرفعُ يرفع الأولى من كلّ خانةٍ وحدَها" sub "$D" \
  "        while (list.isNotEmpty) {" \
  "        if (list.isNotEmpty) {"

run "(د) الإزالةُ لا تُزيل" sub "$D" \
  "                  onRemove: (i) => setState(() => _picked[slot.type]!.removeAt(i))," \
  "                  onRemove: (i) => setState(() {}),"

run "(هـ) ما رُفع لا يُعرض في خانته" sub "$D" \
  "                  uploaded: [for (final d in rows) if (d.type == slot.type) d]," \
  "                  uploaded: const [],"

run "(و) سببُ الرفض لا يُعرض" sub "$D" \
  "          if (doc.note.isNotEmpty)" "          if (false)"

run "(ز) لا حدَّ لحجم الصورة" sub "$D" \
  "    if (file.bytes.lengthInBytes > 10 * 1024 * 1024) {" \
  "    if (file.bytes.lengthInBytes > 100 * 1024 * 1024) {"

run "(ح) أيقونةُ الإضافة من المكتبة" sub "$D" \
  "              const _Mark('doc_fileplus', color: AppColors.accent, size: 44)," \
  "              const Icon(Icons.note_add_outlined, size: 44, color: AppColors.accent),"

# بارتفاعٍ يسع المحتوى بالخطّ العاديّ — فلا يسقط إلّا حيث يكبُر الخطّ.
run "(ط) صندوقُ الإضافة بارتفاعٍ ثابت" sub "$D" \
  "          constraints: const BoxConstraints(minHeight: 90)," \
  "          constraints: const BoxConstraints.tightFor(height: 96),"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
