#!/usr/bin/env bash
# ضوابطُ سالبةٌ لإخفاء خدمات غير الموثَّق من «استكشف» ولعلامة «قيد المراجعة»
# في «خدماتي». تكسر كلَّ ضمانةٍ مرّةً وتطبع ما سقط.
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/unlisted_services_test.dart"
A=lib/src/data/api.dart
S=lib/src/core/session.dart
V=lib/src/screens/services.dart

BACKUP=$(mktemp -d)
cp "$A" "$BACKUP/a"; cp "$S" "$BACKUP/s"; cp "$V" "$BACKUP/v"
restore() { cp "$BACKUP/a" "$A"; cp "$BACKUP/s" "$S"; cp "$BACKUP/v" "$V"; }
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

run "(أ) «استكشف» لا يُرشَّح" sub "$A" \
  "    return hidden == null ? rows : rows.where((s) => s.providerId != hidden).toList();" \
  "    return rows;"

run "(أ٢) فرعُ القاعدة لا يُرشَّح" sub "$A" \
  "    return _listed(rows.map(ServiceItem.fromMap).toList());" \
  "    return rows.map(ServiceItem.fromMap).toList();"

run "(أ٣) فرعُ «الأقرب» لا يُرشَّح" sub "$A" \
  "      return _listed((rows as List)
          .map((r) => ServiceItem.fromMap(r as Map<String, dynamic>))
          .toList());" \
  "      return (rows as List)
          .map((r) => ServiceItem.fromMap(r as Map<String, dynamic>))
          .toList();"

run "(ب) الجلسةُ لا تضبط الإخفاء" sub "$S" \
  "    Api.unlistedProviderId = id != null && providerStatus != 'verified' ? id : null;" \
  "    Api.unlistedProviderId = null;"

run "(ج) يُخفى عن الموثَّق أيضاً" sub "$S" \
  "    Api.unlistedProviderId = id != null && providerStatus != 'verified' ? id : null;" \
  "    Api.unlistedProviderId = id;"

run "(د) الخروجُ لا يمحو الإخفاء" sub "$S" \
  "    providerStatus = null;
    Api.unlistedProviderId = null;" \
  "    providerStatus = null;"

run "(هـ) «معروضة» على خدمات غير الموثَّق" sub "$V" \
  "  bool get _unlisted => _status != null && _status != 'verified';" \
  "  bool get _unlisted => false;"

run "(و) «قيد المراجعة» للمرفوض كذلك" sub "$V" \
  "                        ? (_status == 'pending' ? tr('قيد المراجعة') : tr('غير ظاهرة'))" \
  "                        ? tr('قيد المراجعة')"

run "(ز) السطرُ لا يُرسم" sub "$V" \
  "              note,
              Expanded(
                child: RefreshIndicator(" \
  "              Expanded(
                child: RefreshIndicator("

run "(ح) ولا يُرسم في القائمة الفارغة" sub "$V" \
  "                addBar,
                note,
                Expanded(
                  child: EmptyBlock(" \
  "                addBar,
                Expanded(
                  child: EmptyBlock("

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
