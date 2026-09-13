#!/usr/bin/env bash
# ضوابطُ سالبةٌ لفتح القفل بالبصمة.
#
# **وما لا يسقط بالكسر ضمانةٌ كاذبة.** وأخطرُ ما يُحرَس هنا أنّ الرمزَ لا
# يسقط: بصمةٌ بلا رمزٍ تحتها قفلٌ يحبس صاحبَه يومَ يُخفق حسّاسُه.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/biometric_test.dart
L=lib/src/core/app_lock.dart
S=lib/src/screens/lock.dart

BACKUP=$(mktemp -d); cp "$L" "$BACKUP/l"; cp "$S" "$BACKUP/s"
restore() { cp "$BACKUP/l" "$L"; cp "$BACKUP/s" "$S"; }
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
  if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# أ) **البصمةُ تُلغي لوحةَ الأرقام** — وهو أخطرُ ما يمكن أن يقع هنا: من
#    أخفق حسّاسُه أو مُحيت بصماتُه بترقيةِ نظامٍ يبقى محبوساً عن حسابه.
run "أ) اللوحةُ تسقط مع البصمة" sub "$S" \
  "                _Pad(onDigit: _push, onBack: _back, busy: _busy)," \
  "                if (!_canBiometric)
                  _Pad(onDigit: _push, onBack: _back, busy: _busy),"

# ب) **كان هنا ضابطٌ ثانٍ فسقط هو نفسُه.**
#
#    كتبتُ في الشاشة رايةً «لا تُسأل البصمةُ مرّتين»، وكتبتُ لها ضابطاً
#    ينزعها. **فنُزعت وبقيت الحزمةُ خضراء** — لأنّ الطلبَ يقع في
#    `initState` وحدَه، وهو لا يُنادى إلّا مرّةً في عمر الحال. فكانت حرزاً
#    من شيءٍ لا يقع. فحُذفت الرايةُ وحُذف ضابطُها، ولم يُترك حرزٌ لا يُقاس.

# ج) **وإخفاقُ البصمة يُعدّ محاولةً خاطئة** — فيُخرَج حسابُ من أخفق حسّاسُه
#    خمسَ مرّاتٍ وهو صاحبُه. وعدُّ المحاولات حرزٌ من تجريب الرموز لا من
#    حسّاسٍ لا يقرأ.
run "ج) الإخفاقُ يُعدّ محاولة" sub "$L" \
  "    if (!await biometrics.authenticate()) return false;" \
  "    if (!await biometrics.authenticate()) {
      _wrong++;
      notifyListeners();
      return false;
    }"

# د) **وتُشغَّل البصمةُ بلا رمزٍ مضبوط** — قفلٌ لا مخرجَ منه.
run "د) بصمةٌ بلا رمز" sub "$L" \
  "  if (on && !await lockIsSet()) throw tr('فعّل قفل التطبيق أولاً.');" \
  ""

# هـ) **والزرُّ يُعرض بلا سؤال الحسّاس** — فمن شغّلها ثمّ محا بصماتِه من
#     إعدادات جهازه يرى زرّاً يضغطه فلا يقع شيء.
run "هـ) زرٌّ بلا حسّاس" sub "$S" \
  "    final ok = await biometrics.available();" \
  "    final ok = widget.lock.biometricEnabled;"

# و) **وإطفاءُ القفل لا يُسقط البصمةَ من الخزنة** — فيعود من فعّل القفلَ بعد
#    شهرٍ فيجد بصمةً يُسأل عنها ولم يطلبها اليوم.
run "و) البصمةُ تبقى بعد إطفاء القفل" sub "$L" \
  "  await _write(_keyBiometric, null);
" \
  ""

# ز) **والأرضيّةُ تعود بيضاء** — فيسقط الرأسُ الأحمرُ وتفترق الشاشةُ عن
#    شاشة الدخول، وهما الوحيدتان اللتان تُريان قبل التطبيق.
run "ز) لا رأسَ أحمر" sub "$S" \
  "      backgroundColor: AppColors.accent," \
  "      backgroundColor: AppColors.surface,"

# ح) **ورمزُ البصمة يُترك للون الزرّ** — فيخرج حبراً داكناً لا نبيذيّاً،
#    وهو ما أخرجه صاحبُ المنصّة بالصورة.
run "ح) الرمزُ ليس نبيذيّاً" sub "$S" \
  "                                color: AppColors.accent,
                              )," \
  "                              ),"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
