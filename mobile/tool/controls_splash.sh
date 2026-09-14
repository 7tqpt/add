#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشاشة الانطلاق — الشعارُ المتحرّك.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/splash_test.dart test/loading_test.dart"
W=lib/src/screens/welcome.dart

BACKUP=$(mktemp -d)
cp "$W" "$BACKUP/w"
restore() { cp "$BACKUP/w" "$W"; }
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
  # shellcheck disable=SC2086
  if timeout 400 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
# shellcheck disable=SC2086
if timeout 400 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) المشهدُ يُعاد من الصفر في الترحيب ────────────────────────────────────
#
# **وهذا أخطرُها.** كان القوسُ ممنوعاً من شاشة الإقلاع لهذا السبب بعينه:
# حركةٌ تُقطع في منتصفها ثمّ تُستأنف من الصفر تُقرأ تعثّراً لا ترحيباً.
run "(أ) الترحيبُ يُعيد المشهدَ من الصفر" \
  sub "$W" \
"    _c.forward(from: introProgress());
    _amb ??= AnimationController(vsync: this, duration: _ambienceCycle)" \
"    _c.forward();
    _amb ??= AnimationController(vsync: this, duration: _ambienceCycle)"

# ── ب) والساعةُ تمضي قبل أن يسألها أحد ──────────────────────────────────────
#
# فيجد أوّلُ فاتحٍ للتطبيق المشهدَ منتهياً قبل أن يبدأ.
# **والكسرُ في الدالّة لا في الحقل:** `resetIntroClock` تُنادى قبل كلّ
# اختبارٍ فتمحو قيمةً ابتدائيّةً مكسورةً — فيمرّ الكسرُ ولا يُرى.
run "(ب) الساعةُ تبدأ ماضيةً لأوّل سائل" \
  sub "$W" \
"  final start = _introStart ??= now;" \
"  final start = _introStart ??= now.subtract(introDuration);"

# ── ج) والعلامةُ تتأخّر عن أكثر الإقلاعات ───────────────────────────────────
#
# أكثرُ الإقلاعات تنتهي قبل نصف الثانية: فعلامةٌ تبدأ بعدها لا يراها أحد،
# ويبقى فاتحُ التطبيق ينظر إلى أرضيّةٍ فارغة.
run "(ج) العلامةُ تبدأ بعد نصف الثانية" \
  sub "$W" \
"      Curves.easeOutCubic.transform((v / 0.38).clamp(0.0, 1.0));" \
"      Curves.easeOutCubic.transform(((v - 0.6) / 0.4).clamp(0.0, 1.0));"

# ── د) والاسمُ يصعد مع العلامة لا بعدها ─────────────────────────────────────
#
# فيُرى الاثنان دفعةً واحدةً، ويسقط الترتيبُ الذي يجعله مشهداً.
run "(د) الاسمُ يصعد مع العلامة" \
  sub "$W" \
"  static double nameAt(double v) => Curves.easeOutCubic
      .transform(((v - 0.34) / 0.36).clamp(0.0, 1.0));" \
"  static double nameAt(double v) => Curves.easeOutCubic
      .transform((v / 0.38).clamp(0.0, 1.0));"

# ── هـ) والدوّارُ يومض في وجه من عاد تحقّقُه سريعاً ─────────────────────────
#
# **وهي الضمانةُ التي كانت قبل هذا كلِّه.** شاشةٌ تومض في كلّ فتحةٍ تُقرأ
# متعثّرةً وإن كانت أسرعَ من غيرها.
run "(هـ) الدوّارُ يُكشف فوراً" \
  sub "$W" \
"  static const slowAfter = Duration(milliseconds: 1700);" \
"  static const slowAfter = Duration(milliseconds: 1);"

# ── و) ولا يُكشف أبداً لمن طال انتظارُه ─────────────────────────────────────
#
# ومن انتظر دقيقةً على شبكةٍ متعثّرةٍ ينظر إلى شاشةٍ لا تقول إنّ شيئاً يقع.
run "(و) الدوّارُ لا يُكشف أبداً" \
  sub "$W" \
"    _slowTimer = Timer(BootScreen.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });" \
"    _slowTimer = Timer(BootScreen.slowAfter, () {});"

# ── ز) والسطرُ الممرَّرُ يُهمَل ──────────────────────────────────────────────
run "(ز) السطرُ الممرَّرُ يُهمَل" \
  sub "$W" \
"                  widget.label ?? tr('جارٍ التحقق…')," \
"                  tr('جارٍ التحقق…'),"

# ── ح) وتقليلُ الحركة لا يُسكّن شيئاً ───────────────────────────────────────
#
# من طلبه من جهازه طلبه لسببٍ — دوارٌ أو صداع.
run "(ح) تقليلُ الحركة يُهمَل" \
  sub "$W" \
"    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    _c.forward(from: introProgress());" \
"    _c.forward(from: introProgress());"

# ── ط) والأرضيّةُ تومض بيضاءَ في أوّل إطار ──────────────────────────────────
#
# أوّلُ ما يُرى من التطبيق كلِّه.
run "(ط) الأرضيّةُ ليست أرضيّةَ الهويّة" \
  sub "$W" \
"      body: BrandBackdrop(
        child: AnimatedBuilder(" \
"      body: ColoredBox(
        color: Colors.white,
        child: AnimatedBuilder("

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
