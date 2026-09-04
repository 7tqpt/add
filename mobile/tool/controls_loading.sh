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
  # **ومهلةٌ على كلّ تشغيل — وهذا سطرٌ دُفع ثمنُه.** ضابطٌ كسر الشيفرةَ
  # كسراً جعل اختباراً يدور بلا نهاية، فبقي `flutter test` معلَّقاً إحدى
  # وأربعين دقيقةً والسكربتُ ينتظره صامتاً. **والصمتُ يُقرأ عملاً جارياً**،
  # فلا يُعرف أنّه توقّف إلّا بالنظر في قائمة العمليات.
  #
  # ومهلةٌ منقضيةٌ ليست نجاحاً للضابط: أن تُعلَّق الشيفرةُ المكسورةُ شيءٌ،
  # وأن يسقط الاختبارُ الحارسُ شيءٌ آخر. فتُذكر على وجهها.
  local out; out=$(timeout 180 flutter test "$TEST" 2>&1)
  local code=$?
  if [ "$code" -eq 124 ]; then
    echo "⏱ $name — عُلِّق ولم يسقط (يحتاج نظراً على حدة)"
    fail=$((fail+1)); return
  fi
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
  sub "$FILE_WEL" '              Stage.at(t, 0.44, 0.76),' '              Stage.at(t, 0.0, 0.001),'

control "ث) البريقُ يُحسب ولا يُرسم — ميزةٌ مبنيّةٌ وميّتة" \
  sub "$FILE_WEL" '      mark = ShaderMask(' '      mark = Opacity(opacity: 1, child: mark); mark = Builder(builder: (_) => mark); if (false) mark = ShaderMask('

control "ل) شاشةُ الدخول تومض بالأبيض" \
  sub "$FILE_WEL" '    body: BrandBackdrop(
      child: LoadingBlock(' '    body: Builder(
      builder: (_) => LoadingBlock('

# ── الحياةُ بعد الدخول ──────────────────────────────────────────────────────

control "م) الشاشةُ تموت بعد الدخول — لا ذرّةَ ولا بريق" \
  sub "$FILE_WEL" '    _amb ??= AnimationController(vsync: this, duration: _ambienceCycle)
      ..repeat();' '    _amb = null;'

control "ن) الحياةُ تدور دورةً واحدةً ثمّ تقف" \
  sub "$FILE_WEL" '      ..repeat();' '      ..forward();'

control "س) سرعةُ الذرّة كسرٌ من الدورة فتقفز عند تمامها" \
  sub "$FILE_WEL" '  final speed = 1 + (i % 3);' '  final speed = 1.4 + (i % 3);'

control "ع) الذرّةُ تنبثق في أسفلها ولا تُولد" \
  sub "$FILE_WEL" '    alpha: math.sin(p * math.pi).clamp(0.0, 1.0),' '    alpha: 1.0,'

control "ف) الذرّاتُ تصعد كلُّها في صفٍّ واحدٍ بسرعةٍ واحدة" \
  sub "$FILE_WEL" '  final phase = _frac(i * 0.7548776662);
  final lane = _frac(i * 0.6180339887);' '  final phase = 0.0;
  final lane = 0.5;'

control "ص) الذرّةُ تخرج عن حدّ المنطقة" \
  sub "$FILE_WEL" '    x: (0.07 + 0.86 * lane + sway).clamp(0.0, 1.0),' '    x: 0.07 + 3.0 * lane + sway,'

control "ق) البريقُ لا يهدأ — خلفيّةٌ متحرّكةٌ دائمة" \
  sub "$FILE_WEL" "  const share = 0.35; // نصيبُ المرور من نصف الدورة" '  const share = 1.0;'

control "ر) البريقُ يُولد داخل الإطار ولا يدخل من حافّته" \
  sub "$FILE_WEL" '  return -0.3 + 1.6 * (g / share);' '  return 0.1 + 0.8 * (g / share);'

control "ش) البريقُ يمرّ مرّةً في الدورة لا مرّتين" \
  sub "$FILE_WEL" '  final g = _frac(v * 2);' '  final g = _frac(v * 1);'

control "ت) العلامةُ تبتلع اللمسَ تحتها" \
  sub "$FILE_WEL" '    return IgnorePointer(child: mark);' '    return mark;'

echo
echo "== الحصيلة: $pass سقطت، $fail لم تسقط =="
[ "$fail" -eq 0 ]
