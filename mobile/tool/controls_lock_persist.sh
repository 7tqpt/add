#!/usr/bin/env bash
# ضوابطُ سالبةٌ لعدّاد محاولات القفل في الخزنة، ولمنع النسخ الاحتياطيّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`
# و`android/` ثمّ يعيدهما.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/lock_attempts_persist_test.dart test/app_lock_test.dart test/lock_screen_test.dart"
L=lib/src/core/app_lock.dart
M=android/app/src/main/AndroidManifest.xml
R=android/app/src/main/res/xml/data_extraction_rules.xml

BACKUP=$(mktemp -d)
cp "$L" "$BACKUP/l"; cp "$M" "$BACKUP/m"; cp "$R" "$BACKUP/r"
restore() { cp "$BACKUP/l" "$L"; cp "$BACKUP/m" "$M"; cp "$BACKUP/r" "$R"; }
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

run "(أ) الإقلاعُ لا يقرأ العدّ" sub "$L" \
  "    _wrong = _enabled ? int.tryParse(await _read(_keyWrong) ?? '') ?? 0 : 0;" \
  "    _wrong = 0;"

run "(ب) الخطأُ لا يُكتب في الخزنة" sub "$L" \
  "    await _write(_keyWrong, '\$_wrong');" \
  "    // لا كتابة"

run "(ج) من بلغ الحدَّ يُسأل بعدها" sub "$L" \
  "    if (exhausted) return false;
    if (await lockVerify(pin)) {" \
  "    if (await lockVerify(pin)) {"

run "(د) الفتحُ الصحيحُ لا يمحو العدَّ من الخزنة" sub "$L" \
  "      _left = false;
      await _write(_keyWrong, null);
      notifyListeners();
      return true;" \
  "      _left = false;
      notifyListeners();
      return true;"

run "(هـ) إزالةُ القفل تُبقي العدّ" sub "$L" \
  "  await _write(_keyWrong, null);
  await _write(_keyLegacyAfter, null);" \
  "  await _write(_keyLegacyAfter, null);"

run "(و) النسخُ الاحتياطيُّ مسموح" sub "$M" \
  'android:allowBackup="false"' 'android:allowBackup="true"'

run "(ز) النقلُ من جهازٍ إلى جهاز يحمل التفضيلات" sub "$R" \
  "    <device-transfer>
        <exclude domain=\"root\" />
        <exclude domain=\"file\" />
        <exclude domain=\"database\" />
        <exclude domain=\"sharedpref\" />" \
  "    <device-transfer>
        <exclude domain=\"root\" />
        <exclude domain=\"file\" />
        <exclude domain=\"database\" />"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
