#!/usr/bin/env bash
# ضوابطُ سالبةٌ لاختبارات الانتظار وشاشة البداية.
#
# **ولمَ هذا الملفّ أصلاً:** اختبارٌ أخضرُ لا يقول إلّا أنّه لم يسقط؛ وقد
# يكون لم يسقط لأنّه لا يقيس شيئاً. فيُكسر ما يدّعي حراستَه واحداً واحداً،
# ويُطلب أن يسقط. وما لم يسقط فحارسٌ في الاسم فقط.
#
# **و`flutter` ليست في المسار افتراضاً في هذه البيئة.** وقد سبق أن نجحت
# ثمانيةُ ضوابطَ في هذا المشروع وهي كذبٌ كلُّها، لأنّ الغلاف قرأ
# «command not found» نجاحاً. فيُصدَّر المسار، ويُشترط أساسٌ أخضرُ أوّلاً،
# ويُشترط سطرُ فشلٍ حقيقيٌّ لا مجرّدُ رمز خروج.
set -u
export PATH=/opt/flutter/bin:$PATH
cd "$(dirname "$0")/.."

FILE_KIT=lib/src/ui/kit.dart
FILE_WEL=lib/src/screens/welcome.dart
TEST=test/loading_test.dart

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

echo "== الأساس =="
if ! flutter test "$TEST" 2>&1 | grep -q 'All tests passed'; then
  echo "الأساسُ أحمر — لا معنى للضوابط قبل إصلاحه"; exit 1
fi
echo "أخضر."

cp "$FILE_KIT" /tmp/kit.bak
cp "$FILE_WEL" /tmp/wel.bak
restore() { cp /tmp/kit.bak "$FILE_KIT"; cp /tmp/wel.bak "$FILE_WEL"; }
trap restore EXIT

pass=0; fail=0
control() {  # الاسم، ثمّ الأمرُ الذي يكسر
  local name="$1"; shift
  restore
  "$@" || { echo "✗ $name — لم يُطبَّق الكسرُ أصلاً"; fail=$((fail+1)); return; }
  local out; out=$(flutter test "$TEST" 2>&1)
  # **يُطلب سطرُ فشلٍ صريحٌ لا رمزُ خروج:** خطأُ ترجمةٍ يعطي رمزاً غيرَ صفرٍ
  # أيضاً، فيُحسب الضابطُ ناجحاً وهو لم يُشغّل اختباراً واحداً.
  if echo "$out" | grep -qE '^\s*[0-9:]+ \+[0-9]+ -[1-9]'; then
    echo "✓ $name — سقط"
    pass=$((pass+1))
  else
    if echo "$out" | grep -q 'Error:'; then
      echo "✗ $name — لم يُترجَم (الكسرُ خاطئ لا الاختبار)"
    else
      echo "✗ $name — بقي أخضرَ: الحارسُ لا يحرس"
    fi
    fail=$((fail+1))
  fi
}

sub() { python3 - "$@" <<'PY'
import sys, pathlib
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path); t = p.read_text()
if t.count(old) != 1:
    sys.exit(f'الكسرُ لا ينطبق مرّةً واحدة ({t.count(old)})')
p.write_text(t.replace(old, new))
PY
}

echo
echo "== الضوابط =="

control "أ) الدوّارُ يقفز عند تمام دورته" \
  sub "$FILE_KIT" 'start: (v + tail) * turn' 'start: (v + tail * 0.75) * turn'

control "ب) القوسُ يقصر إلى صفر" \
  sub "$FILE_KIT" 'const minSweep = 0.05;' 'const minSweep = 0.0;'

control "ج) الذيلُ يسبق الرأس" \
  sub "$FILE_KIT" 'span * (head - tail)' 'span * (tail - head)'

control "د) الدوّارُ يلفّ لمن أطفأ الحركة" \
  sub "$FILE_KIT" '    if (reduceMotion(context)) {
      _c?.dispose();
      _c = null;
      return;
    }' '    if (false) { return; }'

control "هـ) المقودُ لا يُتلَف" \
  sub "$FILE_KIT" '  void dispose() {
    _c?.dispose();
    super.dispose();
  }' '  void dispose() {
    super.dispose();
  }'

control "و) كتلةُ الانتظار تومض فوراً" \
  sub "$FILE_KIT" '    if (widget.delay <= Duration.zero) {
      _show = true;
      return;
    }' '    _show = true;
    if (widget.delay <= Duration.zero) return;'

control "ز) مؤقّتُها لا يُلغى" \
  sub "$FILE_KIT" '    _timer?.cancel();
    super.dispose();' '    super.dispose();'

control "ح) السطرُ يُرسم بلونٍ لا يُقرأ على أرضيّته" \
  sub "$FILE_KIT" '            if (widget.labelColor == null)' '            if (true)'

control "ط) القوسان يُرسمان معاً" \
  sub "$FILE_WEL" '      ((outer - 0.25) / 0.75).clamp(0.0, 1.0);' '      outer;'

control "ي) القوسُ يظهر كاملاً في أوّل إطار" \
  sub "$FILE_WEL" "      Curves.easeInOutCubic.transform((v / 0.62).clamp(0.0, 1.0));" '      1.0;'

control "ك) الاسمُ يظهر مع القوس لا بعده" \
  sub "$FILE_WEL" '              Stage(
                t: t,
                from: 0.44,
                to: 0.76,' '              Stage(
                t: t,
                from: 0.0,
                to: 0.001,'

control "ل) شاشةُ الدخول تومض بالأبيض" \
  sub "$FILE_WEL" '    body: BrandBackdrop(
      child: LoadingBlock(' '    body: Builder(
      builder: (_) => LoadingBlock('

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
