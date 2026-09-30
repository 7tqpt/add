#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحركة الترحيب — البتلاتُ والمذنّبُ والبريقُ والموجةُ
# والنجومُ والورد.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**
# ليُرى أنّه سقط للسبب المقصود.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/welcome_motion_test.dart test/welcome_test.dart test/loading_test.dart"
F=lib/src/screens/welcome.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"
restore() { cp "$BACKUP/f" "$F"; }
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
    echo "$out" | grep -E "\[E\]$" | sed -E 's/^.*test\/([^:]+): /     • \1: /' | sort -u | head -8
    PASS=$((PASS+1))
  fi
  restore
}

# ── البتلات ─────────────────────────────────────────────────────────────────
run "(أ) سرعةٌ كسريّةٌ فتقفز عند تمام الدورة" sub "$F" \
  "  final fall = _frac(v * speed + phase);" \
  "  final fall = _frac(v * speed * 1.1 + phase);"

run "(ب) تنبت وتُقصّ بلا تدريج" sub "$F" \
  "    alpha: 0.8 * Curves.easeInOut.transform(edge)," \
  "    alpha: edge > 0 ? 0.8 : 0,"

run "(ج) تصعد لا تسقط" sub "$F" \
  "    y: -0.06 + 1.12 * fall," \
  "    y: 1.06 - 1.12 * fall,"

run "(د) تسقط معاً" sub "$F" \
  "  final phase = _frac(i * 0.3819660113);" \
  "  final phase = 0.0;"

run "(هـ) تنزل خلف الزرّين" sub "$F" \
  "                bottom: _doorsHeight,
                child: IgnorePointer(
                  child: Stage(
                    t: _c,
                    from: 0.7," \
  "                bottom: 0,
                child: IgnorePointer(
                  child: Stage(
                    t: _c,
                    from: 0.7,"

# ── الأضواء ─────────────────────────────────────────────────────────────────
run "(و) البريقُ يعود مع شريط الضوء" sub "$F" \
  "  const start = 0.78, span = 0.12;" \
  "  const start = 0.58, span = 0.12;"

run "(ز) المذنّبُ على قوسٍ لم يكتمل" sub "$F" \
  "painter: CometPainter(progress: t >= 1 ? cometAt(life) : null)," \
  "painter: CometPainter(progress: cometAt(life)),"

run "(ح) لا مذنّبَ أبداً" sub "$F" \
  "painter: CometPainter(progress: t >= 1 ? cometAt(life) : null)," \
  "painter: const CometPainter(),"

shimmer_over() {
  sub "$F" "                                      children: [
                                        Positioned.fill(" "                                      children: [
                                        ?child,
                                        Positioned.fill(" &&
  sub "$F" "                                        ),
                                        ?child,
                                      ]," "                                        ),
                                      ],"
}
run "(ط) البريقُ فوق «دخول»" shimmer_over

run "(ي) «دخول» في زاوية زرّه" sub "$F" \
  "                                      fit: StackFit.passthrough," ""

# ── الدخول ──────────────────────────────────────────────────────────────────
run "(ك) النجومُ تظهر معاً" sub "$F" \
  "  final from = 0.58 + 0.025 * i;" "  final from = 0.58;"

run "(ل) الرسّامُ يأخذ تمامَ الدخول" sub "$F" \
  "                painter: StarsPainter(t: life, entry: t)," \
  "                painter: StarsPainter(t: life),"

run "(م) الموجةُ باقيةٌ بعد المشهد" sub "$F" \
  "              if (ripple > 0 && ripple < 1)" "              if (ripple > 0)"

run "(ن) النفَسُ يطيل الورد" sub "$F" \
  "    1 - 0.018 * (0.5 - 0.5 * math.cos(2 * math.pi * v));" \
  "    1 + 0.018 * (0.5 - 0.5 * math.cos(2 * math.pi * v));"

run "(س) النفَسُ من أعلى الورد" sub "$F" \
  "              key: const ValueKey('rose-breath'),
              alignment: Alignment.bottomCenter," \
  "              key: const ValueKey('rose-breath'),
              alignment: Alignment.topCenter,"

run "(ع) الحركةُ لمن أطفأها" sub "$F" \
  "    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    // **ويُستأنَف من حيث وصل" \
  "    if (reduceMotion(context)) {
      _c.value = 1;
      _amb = AnimationController(vsync: this, duration: _ambienceCycle)..repeat();
      return;
    }
    // **ويُستأنَف من حيث وصل"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
