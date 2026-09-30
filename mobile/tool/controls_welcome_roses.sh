#!/usr/bin/env bash
# ضوابطُ سالبةٌ للترحيب — الوردُ والزخرفةُ والنجومُ والزرُّ الذهبيّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`
# ثمّ يعيدها، فحزمةٌ تجري في أثناء ذلك تقرأ شيفرةً مكسورةً وتحمرّ بلا سبب.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/welcome_test.dart test/loading_test.dart"
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
  if timeout 900 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

# ينقل طبقةَ الورد كما هي — بقيودها نفسِها — إلى ما قبل طبقة القوس.
#
# **ولا يُبدَّل ما في الطبقتين**: جُرّب ذلك أوّلاً فصارت الزخرفةُ في طبقةٍ
# بلا حدٍّ أعلى، فانهار التخطيطُ واحمرّت الحزمةُ كلُّها — **سقوطٌ لسببٍ
# غيرِ المقيس**، وهو ضابطٌ كاذبٌ كالذي لا يسقط.
roses_under() {
  python3 - "$F" <<'PY2'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
roses = """            Positioned(
              left: 0,
              right: 0,
              bottom: _doorsHeight + 6,
              child: IgnorePointer(
                child: _Bloom(
                  t: _c,
                  life: _amb,
                  from: 0.55,
                  to: 0.95,
                  child: const RepaintBoundary(child: WelcomeRoses()),
                ),
              ),
            ),
"""
arch = "            Padding(\n              padding: EdgeInsets.all(Space.xl),"
if s.count(roses) != 1 or s.count(arch) != 1:
    sys.exit(1)
s = s.replace(roses, "").replace(arch, roses + arch)
open(p, 'w', encoding='utf-8').write(s)
PY2
}

echo; echo "== الطبقات =="

# ── أ) الوردُ تحت القوس ─────────────────────────────────────────────────
#
# **وهو ما خرج في أوّل رسمة**: القوسُ مرسومٌ على الورد لا الوردُ عليه.
run "(أ) الوردُ تحت القوس" roses_under

# ── ب) الوردُ ينزل خلف الزرّين ──────────────────────────────────────────
run "(ب) الوردُ خلف الزرّين" sub "$F" \
"              bottom: _doorsHeight + 6," \
"              bottom: 0,"

# ── ج) والزخرفةُ تمتدّ خلفهما — وقد رُئيت من داخل «إنشاء حساب» ─────────
run "(ج) الزخرفةُ خلف الزرّين" sub "$F" \
"              top: 0,
              bottom: _doorsHeight," \
"              top: 0,
              bottom: 0,"

# ── د) والوردُ يعلو حتى يغطّي الوعدَ على الجوال القصير ──────────────────
run "(د) الوردُ يغطّي الوعد" sub "$F" \
"              bottom: _doorsHeight + 6," \
"              bottom: _doorsHeight + 160,"

echo; echo "== الزرّ والحركة =="

# ── هـ) و«دخول» ذهبٌ مصمتٌ كما كان ─────────────────────────────────────
run "(هـ) الزرُّ بلا تدرّج" sub "$F" \
"                            gradient: welcomeGold," \
"                            color: AppColors.goldOnAccent,"

# ── و) والوردُ خارجَ المشهد — يظهر تامّاً قبل أن يُرسم القوس ────────────
#
# «احتفظ بالأنيميشن»: وردٌ يسبق الحركةَ ليس منها. (وصار دخولُه تفتّحاً في
# `_Bloom` لا صعوداً في `Stage` — والكسرُ نفسُه: ينزعه.)
run "(و) الوردُ خارجَ المشهد" sub "$F" \
"                child: _Bloom(
                  t: _c,
                  life: _amb,
                  from: 0.55,
                  to: 0.95,
                  child: const RepaintBoundary(child: WelcomeRoses()),
                )," \
"                child: const WelcomeRoses(),"

echo; echo "== النجوم =="

# ── ز) نجومٌ لا تومض — صورةٌ لا حياة ───────────────────────────────────
run "(ز) النجومُ ساكنة" sub "$F" \
"  final wave = 0.5 + 0.5 * math.sin(2 * math.pi * (v * speed + phase));" \
"  final wave = 0.5 + 0.0 * math.sin(2 * math.pi * (v * speed + phase));"

# ── ح) ووميضٌ بسرعةٍ كسريّة — يقفز عند تمام الدورة ─────────────────────
run "(ح) الوميضُ يقفز عند تمام الدورة" sub "$F" \
"  final speed = 1 + (i % 3);" \
"  final speed = 1.5 + (i % 3);"

# ── ط) ونجومٌ تنطفئ تماماً — أضواءٌ لا نجوم ────────────────────────────
run "(ط) النجومُ تنطفئ" sub "$F" \
"  return (x: x, y: y, r: r, alpha: 0.35 + 0.65 * wave);" \
"  return (x: x, y: y, r: r, alpha: wave);"

# ── ي) والذرّاتُ تعود ────────────────────────────────────────────────────
run "(ي) الذرّاتُ تعود" sub "$F" \
"                key: const ValueKey('stars')," \
"                key: const ValueKey('motes'),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
