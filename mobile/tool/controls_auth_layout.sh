#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشاشة الدخول ومربّع «تذكّرني».
#
# **وما لا يسقط بالكسر ضمانةٌ كاذبة.** وأخطرُ ما يُحرَس هنا أنّ المربّعَ
# يفعل شيئاً: مربّعٌ يُرفع ويُخفض ولا يقع شيء كذبٌ في شاشة.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/auth_layout_test.dart
A=lib/src/screens/auth.dart
S=lib/src/core/session.dart
R=lib/src/screens/recover_password.dart
F=lib/src/ui/auth_frame.dart

BACKUP=$(mktemp -d); cp "$A" "$BACKUP/a"; cp "$S" "$BACKUP/s"; cp "$R" "$BACKUP/r"; cp "$F" "$BACKUP/f"
restore() { cp "$BACKUP/a" "$A"; cp "$BACKUP/s" "$S"; cp "$BACKUP/r" "$R"; cp "$BACKUP/f" "$F"; }
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

# أ) **ويسقط سطرُ «أهلاً بعودتك»** من تحت العنوان — وهو من صورة صاحب
#    المنصّة. (وكان هنا ضابطُ «الرأس الأحمر» فصار الرأسُ نبيذيّاً بتدرّجٍ في
#    إطارٍ مشترك، وضوابطُه في `controls_auth_frame.sh`.)
run "أ) لا سطرَ تحت العنوان" sub "$A" \
  "              : tr('أهلاً بعودتك')," \
  "              : null,"

# ب) **و«تذكّرني» يُعرض في وجه الإنشاء** — ومن يُنشئ حساباً لا جلسةَ سابقةً
#    تُذكر، فمربّعٌ يسأله عنها يسأله عن لا شيء.
run "ب) المربّعُ في وجه الإنشاء" sub "$A" \
  "    if (!_signUp)
      Padding(" \
  "    if (true)
      Padding("

# ج) **والاختيارُ لا يصل الخزنة** — يُرى في الشاشة ولا يُحفظ.
#
#    **وهذا هو الضابطُ الذي لا يسقط بلا سؤال الخزنة:** `Checkbox` يعرض ما
#    في `_remember` على كلّ حال، فسؤالُ الشاشة يمرّ.
run "ج) الاختيارُ لا يصل الخزنة" sub "$S" \
  "    await setRemember(remember);
" \
  ""

# د) **والإقلاعُ لا يسأل الراية** — فيبقى داخلاً من طلب ألّا يبقى.
run "د) الإقلاعُ لا يسأل" sub "$S" \
  "    final remember = await rememberIsOn();" \
  "    const remember = true;"

# هـ) **والزرُّ المحاطُ لا يقلب الوجه** — فيقف من ليس له حسابٌ عند شاشة
#     دخولٍ لا بابَ فيها.
run "هـ) الزرُّ لا يقلب الوجه" sub "$A" \
  "              _signUp = !_signUp;" \
  "              _signUp = false;"

# و) **والبطاقةُ تعود داخلَ البطاقة في شاشة الاستعادة** — صندوقٌ في صندوق،
#    وهو ما أخرجه صاحبُ المنصّة بسؤالٍ قبل الدمج.
#
#    (وكانت مرساتُه وأختُه بعده على `_recoverStep` في `auth.dart`، وقد
#    انتقلت الاستعادةُ إلى شاشتها قبل هذا — فكانتا لا تكسران شيئاً وتُعدّان
#    ضابطين. ونُقلتا إلى موضع الضمانة اليوم.)
run "و) بطاقةٌ داخل البطاقة" sub "$R" \
  "          ..._stepBody()," \
  "          AppCard(children: _stepBody()),"

# ز) **ولا سهمَ رجوعٍ في رأس الاستعادة** — فيُحبس من دخلها بزرّ الجهاز وحدَه.
run "ز) لا سهمَ في الرأس" sub "$F" \
  "                              const BackButton(color: AppColors.goldOnAccent)" \
  "                              const SizedBox(width: 48)"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
